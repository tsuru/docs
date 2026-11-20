# tsuru.conf reference

tsuru uses a configuration file in [YAML](http://www.yaml.org/) format. This document describes what each option means, and how it should look.

## Notation

tsuru uses a colon to represent nesting in YAML. So, whenever this document says something like `key1:key2`, it refers to the value of the `key2` that is nested in the block that is the value of `key1`. For example, `database:url` means:

```yaml
database:
  url: <value>
```

## HTTP server

tsuru provides a REST API that supports HTTP and HTTP/TLS (HTTPS).

### listen

Defines the address tsuru webserver will listen on. Format: `<host>:<port>`. You may omit the host (e.g., `:8080`). **Required**.

### shutdown-timeout

Seconds to wait when performing an API shutdown (via SIGTERM or SIGQUIT). Default: `600`.

### use-tls

Whether tsuru should use TLS. Default: `false`.

### tls:listen

If both this and `listen` are set, tsuru will start two webserver instances: HTTP on `listen` and HTTPS on `tls:listen`. Required if `use-tls` is true.

### tls:cert-file

Path to the X.509 certificate file. Required if `use-tls` is true.

### tls:key-file

Path to the private key file. Required if `use-tls` is true.

### tls:validate-certificate

Prevents invalid certificates from being offered to clients. Default: `false`.

### server:read-timeout

Maximum duration for reading requests. Default: `0` (no timeout).

### server:write-timeout

Maximum duration for writing responses. Default: `0` (no timeout).


### disable-index-page

Disable the API index page. Default: `false`.

### index-page-template

Custom [Go template](http://golang.org/pkg/text/template/) for the index page. Available variables:
- `tsuruTarget`: API target URL
- `userCreate`: boolean for user registration status
- `nativeLogin`: boolean for native auth scheme
- `keysEnabled`: boolean for SSH key management
- `getConfig`: function to query config values

### reset-password-template

Custom template for password reset emails. Variables: `Token`, `UserEmail`, `Creation`, `Used`.

### reset-password-successfully-template

Custom template for new password emails. Variables: `password`, `email`.

## Database access

tsuru uses MongoDB to store data.

### database:url

MongoDB connection string. **Required**. Examples:
- `127.0.0.1`
- `mongodb://user:password@127.0.0.1:27017/database`

### database:name

Database name. **Required**. Example: `tsuru`.

### database:driver

Database driver. Currently only `mongodb` is supported.

## Email configuration

For password recovery emails.

### smtp:server

SMTP server address. Format: `<host>:<port>`. Example: `smtp.gmail.com:587`.

### smtp:user

SMTP authentication user.

### smtp:password

SMTP authentication password.

## Authentication configuration

tsuru supports `native`, `oauth`, `oidc` and `multi` authentication schemes.

### auth:scheme

Authentication scheme. Default: `native`. Options: `native`, `oauth`, `oidc`, `multi`.

### auth:user-registration

Enable user registration. Default: `false`.

### auth:hash-cost

Bcrypt hash cost (4-31). Higher is more secure but slower. Default: `10`. Only for `native` scheme.

### auth:token-expire-days

Token validity in days. Default: `7`. Only for `native` scheme.

### auth:max-simultaneous-sessions

Maximum concurrent sessions per user. Default: unlimited.

### OAuth configuration (auth:oauth)

Used when `auth:scheme` is `oauth`. See [RFC 6749](http://tools.ietf.org/html/rfc6749).

| Setting | Description |
|---------|-------------|
| `auth:oauth:client-id` | OAuth client ID |
| `auth:oauth:client-secret` | OAuth client secret |
| `auth:oauth:scope` | Authentication scope |
| `auth:oauth:auth-url` | Authorization URL |
| `auth:oauth:token-url` | Token exchange URL |
| `auth:oauth:info-url` | User info URL (expects JSON with `email` field) |
| `auth:oauth:collection` | Database collection for tokens. Default: `oauth_tokens` |
| `auth:oauth:callback-port` | Callback port for authorization |

## Quota management

### quota:units-per-app

Default units per app. Default: unlimited.

### quota:apps-per-user

Default apps per user. Default: unlimited.

## Logging

tsuru supports syslog, stderr, and file logging.

### debug

Enable debug logging. Default: `false`.

### log:file

Path to log file.

### log:disable-syslog

Disable syslog. Default: `false`.

### log:syslog-tag

Syslog tag. Default: `tsurud`.

### log:use-stderr

Write logs to stderr. Default: `false`.

## Routers

Router configuration uses the format `routers:<router name>`.

### routers:\<name\>:default

Set as default router. Default: `false`.

### routers:\<name\>:type

Router implementation. **Required**. Use `api` for routers that implement the
[Router API](router_api.md), such as [kubernetes-router](https://github.com/tsuru/kubernetes-router).

### routers:\<name\>:api-url

Router manager API URL.

### routers:\<name\>:debug

Enable debug mode for router.

### routers:\<name\>:multi-cluster

Send the pool and cluster headers (`X-Tsuru-Pool-Name`, `X-Tsuru-Cluster-Name`, ...) on every
request to the router API, so one router can serve several clusters. Default: `false`.

### routers:\<name\>:headers

Custom headers for API requests:

```yaml
headers:
  - X-CUSTOM-HEADER: my-value
```



## Sample configuration

```yaml
listen: "0.0.0.0:8080"
debug: true
host: http://<machine-public-addr>:8080
# without this line tsurud expects the legacy `docker:` keys and refuses to start
provisioner: kubernetes

auth:
  user-registration: true
  scheme: native

database:
  url: <your-mongodb-server>:27017
  name: tsurudb

```
