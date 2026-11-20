# Authentication

Every request to the tsuru API carries a token in the `Authorization: bearer <token>` header. How people obtain that token is decided by the `auth:scheme` setting in `tsuru.conf`. This page explains the available schemes, how to set each one up, how to bootstrap the first administrator and how sessions end. Tokens for automation (user API keys and team tokens) are covered in [Tokens](managing_tokens.md); the configuration keys are listed in the [configuration reference](../reference/config.md#authentication-configuration).

## Choosing a scheme

| `auth:scheme` | Who verifies the password | Best for |
|---------------|---------------------------|----------|
| `native` (default) | tsuru, with bcrypt-hashed passwords stored in its own database | Small installations, labs, automation accounts |
| `oidc` | An OpenID Connect provider (Keycloak, Okta, Google, Azure AD...). tsuru only validates the signed JWT | Teams that already have a company identity provider; group-based access |
| `oauth` | An OAuth 2.0 provider. tsuru exchanges the authorization code itself and reads the user email from an info URL | Legacy OAuth 2.0 providers without OIDC |
| `multi` | Any combination of the above, tried in order | Mixing OIDC for people with native accounts for scripts |

Whatever the scheme, user API keys, team tokens and the peer token (below) are always accepted in addition to it: when a request arrives tsuru tries the configured scheme first, then user API keys, then team tokens, then the peer token.

Clients discover the scheme with `GET /auth/schemes` (API 1.18), which returns one entry per enabled scheme with its public settings and a `default` flag; the older `GET /auth/scheme` returns a single entry. `tsuru login` calls `/auth/schemes` and uses the default scheme unless you pass [`-s/--scheme`](../tsuru_client/tsuru_login.md):

```bash
tsuru login                 # default scheme
tsuru login -s native       # force native when the default is oidc
```

If the scheme does not exist the client answers `scheme "x" is not found, valid schemes are: oidc, native`.

## Native scheme

With `native`, tsuru stores users and their bcrypt-hashed passwords and issues random session tokens.

### Creating users

```bash
tsuru user create <email>
```

The command asks for the password, which must have between 6 and 50 characters. Who can run it depends on [`auth:user-registration`](../reference/config.md#authuser-registration):

- `false` (default): only a logged-in user with the `user.create` permission can create accounts. Anyone else gets `User registration is disabled for non-admin users.`
- `true`: anyone who can reach the API can self-register.

`tsuru user remove [email]` removes an account. tsuru refuses when the user is the last member of a team.

### Logging in

```bash
$ tsuru login [email]
Email: user@example.com
Password:
Successfully logged in!
```

The client posts the password to `POST /users/{email}/tokens` and saves the returned token in `~/.tsuru/token` (and `~/.tsuru/token.d/<target-label>` when more than one target is configured). The token is valid for [`auth:token-expire-days`](../reference/config.md#authtoken-expire-days) days (default 7); after that commands fail with `Invalid session` and you log in again.

### Session limits

[`auth:max-simultaneous-sessions`](../reference/config.md#authmax-simultaneous-sessions) caps how many session tokens a user may hold. Each successful login that exceeds the limit deletes the user's oldest tokens, so the extra sessions (another laptop, a CI job logged in with a personal account) are silently logged out. Unset means unlimited. The limit does not apply to API keys or team tokens.

### Changing and resetting passwords

A logged-in user changes their own password with [`tsuru change-password`](../tsuru_client/tsuru_change-password.md), which asks for the current and new passwords.

A user who forgot the password runs [`tsuru reset-password`](../tsuru_client/tsuru_reset-password.md) in two steps:

```bash
tsuru reset-password user@example.com              # tsuru emails a reset token
tsuru reset-password user@example.com -t <token>   # tsuru generates a new random password and emails it
```

Both emails are sent through the [`smtp:*`](../reference/config.md#email-configuration) settings; the message bodies can be customised with `reset-password-template` and `reset-password-successfully-template`. The reset token is single use and only valid for the email it was issued to. Password reset is only available with the native scheme (directly or inside `multi`).

## OIDC scheme

With `oidc`, the identity provider authenticates the person and the tsuru CLI receives a JWT access token straight from the provider. tsuru never sees a password and keeps no session record: each request's JWT is verified against the provider's published keys.

### Configuration

| Setting | Description |
|---------|-------------|
| `auth:oidc:client-id` | Client ID registered at the provider. The CLI is a public client: no secret is needed, it uses PKCE (S256). **Required** |
| `auth:oidc:scopes` | List of scopes requested, for example `[openid, email, profile]`. Add the scope that makes the provider emit `groups` when using `groups-in-claims`. **Required** |
| `auth:oidc:auth-url` | Provider authorization endpoint the browser is sent to. **Required** |
| `auth:oidc:token-url` | Provider token endpoint the CLI exchanges the code at. **Required** |
| `auth:oidc:jwks-url` | URL of the JSON Web Key Set used to verify token signatures. Only RSA keys are supported; the key is selected by the token `kid` header (`default` when absent). Without it every authenticated request fails with `no jwks URLs`. **Required** |
| `auth:oidc:callback-port` | Local TCP port the CLI listens on for the browser redirect. Register `http://localhost:<port>` as redirect URI at the provider. Default: a random free port, which only works when the provider accepts any `localhost` port |
| `auth:oidc:groups-in-claims` | When `true`, the `groups` claim of the token replaces the user's groups in tsuru on every request. Default: `false` |
| `auth:oidc:auto-create-personal-team` | When `true`, a team is created for each newly registered user (see below). Default: `false` |
| `auth:oidc:jwks-refresh-interval` | Minimum interval between JWKS refreshes, as a duration (`1h`). Default: `15m` |
| `auth:oidc:valid-claims` | Map of claim name to value that every token must contain, for example `{aud: tsuru}`. A mismatch fails with `invalid claim "aud"`. Default: none |

The first four keys are what `GET /auth/schemes` reports to clients; if any is missing the endpoint, and therefore `tsuru login`, fails. User registration is controlled by the same [`auth:user-registration`](../reference/config.md#authuser-registration) key as the native scheme: with `true` the first login creates the user; with `false` the account must already exist in tsuru (created by an admin or by [`tsurud root-user-create`](#bootstrapping-the-first-administrator)), otherwise login fails with `user not found`.

### What `tsuru login` does

1. Fetches `/auth/schemes` and reads the client ID, scopes, URLs and callback port.
2. Starts an HTTP listener on `localhost:<callback-port>` and opens the browser at `auth-url` with a PKCE challenge. If the browser cannot be started it prints the URL to open by hand.
3. The provider redirects the browser to `http://localhost:<port>?code=...`; the CLI exchanges the code at `token-url` and prints `Successfully logged in via OIDC!` together with the token lifetime.
4. The token set is written to `~/.tsuru/token-v2.json` (and `~/.tsuru/token-v2.d/<target-label>.json`); the access token alone is also written to `~/.tsuru/token` for tools that read the legacy file.

Afterwards the CLI sends the access token as a bearer token. When it expires the CLI uses the refresh token to get a new one and rewrites both files. When the refresh fails (`your session has expired, please run "tsuru login"`) the CLI starts a new login by itself, unless `TSURU_TOKEN` is set.

Each request is validated by tsuru: signature against the JWKS, standard expiry, `valid-claims`, and a mandatory `email` claim (`email claim is missing` otherwise). The email identifies the tsuru user, so the provider must emit it.

### Group-based membership

Set `auth:oidc:groups-in-claims: true` and make the provider include a `groups` claim. On every request tsuru copies the claim into the user record, so users gain and lose access as soon as they present a token with a different `groups` claim, that is, after the next token refresh. Then give roles to groups instead of people:

```bash
tsuru role assign team-member group:platform-engineers myteam
tsuru role dissociate team-member group:platform-engineers myteam
```

A group does not need to be created beforehand; the first assignment creates it. A user's permissions are the union of their own roles and the roles of every group they belong to. `GET /teams/{name}/groups` (API 1.17) lists the groups that have roles in a team. The rules for who may assign roles are in [Managing roles](managing_roles.md#assign-roles-to-identities).

### Personal teams

With `auth:oidc:auto-create-personal-team: true`, registering a user also creates a team named after the local part of the email (`jane.doe` for `jane.doe@example.com`, normalised to a valid team name) tagged `personal`, with the user as its creator. If that name is taken the normalised full email is used. The user receives the default roles of a team creator (see [Default roles](managing_roles.md#default-roles)), which lets newcomers create apps without an admin assigning a team first. Team creation is best effort: a failure is logged and the login still succeeds. Available since tsuru 1.32.

## OAuth scheme

With `oauth`, `tsuru login` also opens the browser and listens on a local port, but the CLI sends the authorization code and its redirect URL to tsuru (`POST /auth/login`). tsuru exchanges the code using `auth:oauth:client-secret`, calls `auth:oauth:info-url` and takes the `email` field (and `groups`, if present) from the JSON answer. The provider token is stored in the `auth:oauth:collection` and is the user's session token; `tsuru logout` deletes it. Registration follows `auth:user-registration` as in the other schemes. The keys are listed in [OAuth configuration](../reference/config.md#oauth-configuration-authoauth).

## Multiple schemes

`auth:scheme: multi` enables several schemes at once, listed in `auth:multi:schemes`. Login, logout and user creation are forwarded to each enabled scheme that supports them, in order, stopping at the first success; token validation tries every scheme in order. The typical setup is `[oidc, native]`: people log in through the provider, service accounts use `tsuru login -s native`. See [Multiple schemes](../reference/config.md#multiple-schemes-authmulti) for the keys and the `default-scheme` reported to clients.

## Bootstrapping the first administrator

A fresh installation has no users and no roles. On the API server run:

```bash
tsurud root-user-create <email>
```

The command creates (or reuses) a global role named `AllowAll`, adds the permission `*` to it and assigns it to the user. If the user already exists it only assigns the role and prints `Root user successfully updated.`, so it also works to promote an existing account.

- With `native`, it asks for the password and its confirmation (`Passwords didn't match.` aborts).
- With `oidc` or `oauth`, no password is asked: the user record is created with the email only, and the person simply logs in through the provider. Since tsuru 1.32 (before that the command panicked under OIDC).
- With `multi`, user creation is delegated to the enabled schemes. The safest sequence is to create the user first (log in once through OIDC with registration enabled, or `tsuru user create` on native) and then run `root-user-create`, which then only assigns the role.

Once real roles exist, remove `AllowAll` from the bootstrap user or delete the user: the role grants every permission, including over other users' API keys.

## Peer token

tsurud instances call each other to aggregate application and job logs, authenticating with a shared secret from `auth:peer:token` sent as a bearer token. The token only grants `app.read.log` and `job.read.logs` globally, but **the default value is public** (the SHA-256 of the string `tsuru`), so always set your own value in production; otherwise anyone who can reach the API can read every log stream.

## Logging out

```bash
tsuru logout
```

The client calls `DELETE /users/tokens` and removes the local token files. With `native` and `oauth` that invalidates the session on the server. With `oidc` there is no server-side session to revoke: the local files are removed, and the access token stays technically valid until its expiry at the provider. Setting `TSURU_TOKEN` bypasses the stored session entirely; `tsuru login` refuses to run while it is set.
