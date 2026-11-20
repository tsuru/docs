# Tokens

tsuru accepts three kinds of credential in the `Authorization: bearer <token>` header. All three go through the same permission checks; they differ in who they represent and how they are managed.

| Credential | Represents | Expires | Permissions come from | Created with |
|------------|------------|---------|-----------------------|--------------|
| Session token | A person who ran `tsuru login` | Yes (scheme dependent, see [Authentication](authentication.md)) | The user's roles and groups | `tsuru login` |
| User API key | A person, without a login | Never | The user's roles and groups | `tsuru token show` |
| Team token | An automation owned by a team | Optional | Only the roles assigned to the token | `tsuru token create` |

Team tokens are the recommended credential for CI pipelines, Terraform and bots: they survive the departure of the person who created them, carry only the permissions you give them and can expire. User API keys exist for compatibility and the CLI marks them as deprecated.

## Team tokens

### Creating

```bash
$ tsuru token create -i deploy-bot -t myteam -d "Deploys from CI" -e 720h
Token "deploy-bot" created: 7f2e...c91a
```

| Flag | Description |
|------|-------------|
| `-i, --id` | Unique identifier, used later to refer to the token and to assign roles. Lowercase letters, digits and hyphens, up to 40 characters, starting with a letter. Default: `<team>-<first 5 characters of the token>`. |
| `-t, --team` | Team responsible for the token. Optional when you have `team.token.create` in exactly one team, or when only one team exists. |
| `-d, --description` | Free text shown by `token info` and `token list`. |
| `-e, --expires` | Lifetime as a Go duration with a mandatory unit (`30m`, `24h`, `720h`). `0` or unset means it never expires. The API receives it as `expires_in` seconds. |

Creating a token requires the `team.token.create` permission in the team's context. The token value is printed only by `create` and `update --regenerate`; store it in your secret manager right away.

A new token has no permissions at all. Give it roles exactly as you would a user, passing the token ID where the email would go:

```bash
tsuru role assign app-deployer deploy-bot myteam
tsuru role dissociate app-deployer deploy-bot myteam
```

The token's permissions are the union of the roles assigned to it; it does not inherit anything from its team or its creator. Assigning a role to a token requires `role.update.assign`, and you can only delegate permissions you hold yourself, see [Managing roles](managing_roles.md#assign-roles-to-identities).

### Listing and inspecting

```bash
tsuru token list
tsuru token info <token-id>
```

`token list` shows the tokens of every team where you have `team.token.read` (all teams with a global grant), with ID, team, creation and expiry dates, last access and roles. `token info` needs `team.token.read` in the token's team and additionally prints the description and the creator email.

The `Token` value is only shown when you hold every permission granted by the roles assigned to that token; otherwise the field is blank. This stops a team member from reading a token that is more powerful than they are. The `Last Access` field is updated every time the token authenticates a request, which is how you spot tokens that are no longer used.

### Updating, regenerating and deleting

```bash
tsuru token update deploy-bot -d "Deploys from GitHub Actions"   # change description
tsuru token update deploy-bot -e 2160h                           # new expiry, 90 days from now
tsuru token update deploy-bot -e -1s                             # remove the expiry
tsuru token update deploy-bot --regenerate                       # new value, old one stops working
tsuru token delete deploy-bot
```

`-e 0` (or omitting the flag) keeps the current expiry; a negative duration removes it. `--regenerate` prints the new value and invalidates the previous one immediately; roles and the ID are kept, so pipelines only need the new secret. Updating requires `team.token.update` and deleting `team.token.delete`, both in the token's team.

A token that still owns apps cannot be deleted (`cannot remove team token who owns apps`): transfer or remove the apps first.

### How team tokens appear to services and events

A team token is not a user, but many places expect an email. tsuru represents the token as `<token-id>@tsuru-team-token`: that is the owner of apps the token creates and, since tsuru 1.29.3, the value sent to service brokers in the `user` parameter and the `X-Tsuru-User` header when a token binds or creates a service instance (older versions sent the bare token ID). Events record the owner as a token named by its ID.

## User API keys

Every user can have one API key: a token with the same permissions as the user and no expiry, meant for scripts run under a personal account.

```bash
tsuru token show                    # prints the key, generating it on first use
tsuru token regenerate              # new key, the old one stops working
tsuru token show -u other@example.com
tsuru token regenerate -u other@example.com
```

Both commands call `GET` and `POST /users/api-key` (with `?user=<email>` when `-u` is given). They are guarded by two dedicated permissions, which take the `user` context (the user's email) or the global context:

- `apikey.read` to see a key with `token show`;
- `apikey.update` to regenerate one.

No user has these permissions by default: an administrator must grant them through a role. Granting them to a role with global context lets everyone use API keys; granting them per user, or to a group, lets you decide who may have one and effectively disables API keys for everyone else. `-u` works for any administrator with the permission in that user's context, which is also how you rotate the key of someone who left.

tsuru records `apikey_last_access` and `apikey_usage_counter` on the user document in the `users` collection every time a key authenticates a request. These fields are not shown by the CLI, but a query against the database tells you which keys are still in use before you regenerate them.

## Using a token from automation

The CLI reads `TSURU_TOKEN` and `TSURU_TARGET` before the files written by `tsuru login` and `tsuru target`, so a job needs no interactive login:

```bash
export TSURU_TARGET=https://tsuru.example.com
export TSURU_TOKEN=7f2e...c91a
tsuru app deploy -a myapp -i registry.example.com/myapp:1.2.3
```

Alternatively register the target once with [`tsuru target add <label> <target> -s`](../tsuru_client/tsuru_target_add.md) and only export `TSURU_TOKEN`. While `TSURU_TOKEN` is set, `tsuru login` refuses to run and an HTTP 401 is reported as `Invalid session - maybe invalid defined token on TSURU_TOKEN envvar`.

Calling the API directly:

```bash
curl -H "Authorization: bearer $TSURU_TOKEN" "$TSURU_TARGET/1.0/apps"
```

### Terraform

The [`tsuru_token` resource](https://github.com/tsuru/terraform-provider-tsuru/blob/main/docs/resources/token.md) of terraform-provider-tsuru manages team tokens:

```terraform
resource "tsuru_token" "deploy_bot" {
  token_id    = "deploy-bot"
  team        = "myteam"
  description = "Deploys from CI"
  expires     = "720h"
}
```

`team` is the only required argument. `token_id` is generated when omitted, `expires` takes the same duration format as the CLI, and `regenerate_on_update = true` makes any change produce a new token value. The value is available as the sensitive `token` attribute; `created_at`, `creator_email`, `expires_at`, `last_access` and `roles` are read-only. Existing tokens are imported with `terraform import tsuru_token.deploy_bot deploy-bot`. Roles are not managed by this resource; assign them with `tsuru role assign`.

## Security notes

- **Least privilege**: give team tokens the narrowest role that works, in the context of a single team, pool or app. A token with a global role is as powerful as an administrator.
- **Prefer team tokens over API keys**: an API key is the person, with all their permissions and no expiry, and it keeps working after they leave the team.
- **Set an expiry**: `-e` on create or update. tsuru rejects an expired token with `team token expired`; renew it with `token update -e` before that date.
- **Rotate**: `token update --regenerate` (team) and `token regenerate` (API key) revoke the old value instantly. Regenerate whenever a secret may have leaked, for example after it appeared in a log.
- **Audit**: `token list` shows the last access of every team token; tokens never used or unused for months should be deleted. Token creation, updates, deletions and role assignments are recorded as events.
- **Keep secrets out of version control**: the value is only printed on creation and regeneration; put it in your CI secret store or a Terraform-managed secret, never in the repository.
