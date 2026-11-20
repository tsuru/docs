# tsuru.conf reference

tsuru uses a configuration file in [YAML](http://www.yaml.org/) format. This document describes
every key that `tsurud` (tsuru 1.34) reads, what it means, its type and its default. Keys not
listed here are ignored by the server.

## Notation

tsuru uses a colon to represent nesting in YAML. So, whenever this document says something like `key1:key2`, it refers to the value of the `key2` that is nested in the block that is the value of `key1`. For example, `database:url` means:

```yaml
database:
  url: <value>
```

Durations given as "seconds" are plain numbers (`30`), not Go duration strings; the few keys that
take a duration string (`15m`, `1h`) say so.

## HTTP server

tsuru provides a REST API that supports HTTP and HTTP/TLS (HTTPS).

### listen

Address the HTTP server listens on. Format: `<host>:<port>`; the host may be omitted (`:8080`).
**Required** (checked at startup). When `use-tls` is `true` and `tls:listen` is not set, this
address is used for HTTPS instead and no plain HTTP listener is started.

### host

Public URL of the API, for example `https://tsuru.example.com`. **Required** (checked at
startup). It is shown on the index page, exported to app units as the `TSURU_HOST` environment
variable and its hostname is what `tls:validate-certificate` checks the certificate against.

### shutdown-timeout

Seconds to wait for in-flight requests when the API shuts down (SIGTERM or SIGQUIT). Integer.
Default: `600`.

### use-tls

Whether tsuru should serve HTTPS. Boolean. Default: `false`.

### tls:listen

Address of the HTTPS listener. When both this and `listen` are set tsuru runs two servers, HTTP on
`listen` and HTTPS here. Default: the value of `listen` when `use-tls` is `true`.

### tls:cert-file

Path to the PEM X.509 certificate (leaf first, intermediates after). **Required** if `use-tls` is
`true`. The certificate and key are reloaded automatically when the files change; there is no
interval to configure.

### tls:key-file

Path to the PEM private key. **Required** if `use-tls` is `true`.

### tls:validate-certificate

Validate the certificate chain against the system roots, its validity period and the hostname
from `host`, and keep re-validating until expiry. An invalid certificate is not offered to clients.
Boolean. Default: `false`.

### server:read-timeout

Maximum seconds to read a request, applied to both listeners. Integer. Default: `0` (no timeout).

### server:write-timeout

Maximum seconds to write a response. Integer. Default: `0` (no timeout). Long-running
endpoints such as deploy and log streaming need this to stay `0` or be large.

### disable-index-page

Disable the HTML index page served at `/`. Boolean. Default: `false`.

### index-page-template

Path to a custom [Go template](http://golang.org/pkg/text/template/) for the index page. Default:
built-in template. Available variables:

- `tsuruTarget`: the `host` value
- `userCreate`: boolean, value of `auth:user-registration`
- `nativeLogin`: boolean, `true` when `auth:scheme` is `native` or unset
- `getConfig`: function returning any configuration value by key

### reset-password-template

Path to a custom template for the password-reset email (native scheme). Variables: `Token`,
`UserEmail`, `Creation`, `Used`. Default: built-in template.

### reset-password-successfully-template

Path to a custom template for the email that carries the new password. Variables: `password`,
`email`. Default: built-in template.

## Database access

tsuru uses MongoDB to store data.

### database:url

MongoDB connection string. **Required** (checked at startup). A value without the `mongodb://`
scheme gets it prepended. Examples: `127.0.0.1:27017`,
`mongodb://user:password@127.0.0.1:27017/database?replicaSet=rs0`.

### database:name

Database name. **Required** (checked at startup). Example: `tsuru`.

### database:driver

Database driver. Optional; when set it must be `mongodb`, the only supported driver.

## Email configuration

Used only by the native scheme to send password-reset emails.

### smtp:server

SMTP server address. Format: `<host>:<port>`; `:25` is appended when no port is given.
Required for password reset.

### smtp:user

SMTP user, also used as the sender address. Required for password reset.

### smtp:password

SMTP password. When set tsuru authenticates with PLAIN; when empty it sends unauthenticated.

## Authentication configuration

tsuru supports the `native`, `oauth`, `oidc` and `multi` schemes. See
[Authentication](../admin_guides/authentication.md) for how they behave.

### auth:scheme

Authentication scheme. Default: `native`. Options: `native`, `oauth`, `oidc`, `multi`.

### auth:user-registration

Allow users to self-register (`tsuru user-create`, or first login with `oauth` and `oidc`).
Boolean. Default: `false`.

### auth:hash-cost

Bcrypt cost for native passwords, between `4` and `31`; a value outside that range fails user
creation. Higher is slower and more secure. Integer. Default: `10`. Only for `native`.

### auth:token-expire-days

Validity of native login tokens in days. Integer. Default: `7`. Only for `native`.

### auth:max-simultaneous-sessions

Maximum number of live login tokens per user; on each login the oldest tokens beyond this number
are removed. Integer. Default: unlimited. Only for `native`.

### auth:peer:token

Shared secret the API replicas use to call each other (log fan-out, see
[Tracker](#tracker)). Must be identical on every replica. Default: a well-known constant (the
SHA-256 of `tsuru`), so set it in any deployment reachable by untrusted clients.

### OAuth configuration (auth:oauth)

Used when `auth:scheme` is `oauth`. See [RFC 6749](http://tools.ietf.org/html/rfc6749). The first
six keys are required; login fails when any of them is missing.

| Setting | Description |
|---------|-------------|
| `auth:oauth:client-id` | OAuth client ID. **Required** |
| `auth:oauth:client-secret` | OAuth client secret. **Required** |
| `auth:oauth:scope` | Single scope string requested. **Required** |
| `auth:oauth:auth-url` | Authorization URL. **Required** |
| `auth:oauth:token-url` | Token exchange URL. **Required** |
| `auth:oauth:info-url` | User info URL; must return JSON with an `email` field. **Required** |
| `auth:oauth:callback-port` | Local port the CLI listens on for the browser redirect. Default: a random free port |
| `auth:oauth:collection` | MongoDB collection for tokens. Default: `oauth_tokens` |

### OIDC configuration (auth:oidc)

Used when `auth:scheme` is `oidc`. Defaults come from `auth/oidc/oidc.go`.

| Setting | Description |
|---------|-------------|
| `auth:oidc:client-id` | Client ID registered at the provider (public client, PKCE). **Required** |
| `auth:oidc:scopes` | List of scopes, for example `[openid, email, profile]`. **Required** |
| `auth:oidc:auth-url` | Provider authorization endpoint. **Required** |
| `auth:oidc:token-url` | Provider token endpoint. **Required** |
| `auth:oidc:jwks-url` | JSON Web Key Set URL used to verify tokens. Without it every request fails. **Required** |
| `auth:oidc:callback-port` | Local port the CLI listens on for the redirect. Default: a random free port |
| `auth:oidc:groups-in-claims` | Replace the user's groups with the token `groups` claim on every request. Default: `false` |
| `auth:oidc:auto-create-personal-team` | Create a team for each newly registered user. Default: `false` |
| `auth:oidc:jwks-refresh-interval` | Minimum interval between JWKS refreshes, as a duration string (`1h`). Default: `15m` |
| `auth:oidc:valid-claims` | Map of claim name to required value, for example `{aud: tsuru}`. Default: none |

### Multiple schemes (auth:multi)

Available since tsuru 1.16. Set `auth:scheme` to `multi` to enable more than one scheme at
once, for example native passwords for automation accounts and OIDC for people. Each enabled
scheme is configured with its own keys as usual.

| Setting | Description |
|---------|-------------|
| `auth:multi:schemes` | List of scheme names to enable, in order. Example: `[oidc, native]`. **Required** |
| `auth:multi:default-scheme` | Scheme reported as default by `GET /auth/schemes`, which is what `tsuru login` uses when `--scheme` is not given. Default: the first entry of `auth:multi:schemes` |

Login and token validation try each scheme in the list order and stop at the first one that
succeeds. Users choose a specific scheme with `tsuru login --scheme <name>`.

```yaml
auth:
  scheme: multi
  multi:
    schemes:
    - oidc
    - native
    default-scheme: oidc
  oidc:
    client-id: tsuru
    auth-url: https://idp.example.com/authorize
    token-url: https://idp.example.com/token
    jwks-url: https://idp.example.com/.well-known/jwks.json
```

## Quota management

Quotas set here are the starting values given to new apps, users and teams; `tsuru app quota
change`, `user quota change` and `team quota change` override them per object.

### quota:units-per-app

Maximum units a new app may have. Integer; `-1` means unlimited. Default: unlimited.

### quota:apps-per-user

Maximum apps a new user may own. Integer; `-1` means unlimited. Default: unlimited.

### quota:apps-per-team

Maximum apps a new team may own. Integer; `-1` means unlimited. Default: unlimited.

## Logging and observability

Server logs go to syslog, a file and/or stderr; several outputs may be enabled at once. See
[Observability](../admin_guides/observability.md) for the full picture.

### debug

Enable debug-level server logging (also enables verbose output of the `api` routers). Boolean.
Default: `false`.

### log:file

Path to a log file. Default: none (no file logging).

### log:disable-syslog

Do not log to the local syslog. Boolean. Default: `false`. Set it to `true` in containers,
where there is usually no syslog daemon and startup fails otherwise.

### log:syslog-tag

Tag used for syslog messages. Default: `tsurud`.

### log:use-stderr

Also write logs to stderr. Boolean. Default: `false`.

### log:format

Format of the HTTP access log written to stdout. `json` for one JSON object per request; any
other value (or unset) gives the plain-text format.

### log:app-log-service

Backend for application logs. `memory-standalone` keeps logs in this instance's memory only;
`memory` keeps them in memory and fans `tsuru app log` requests out to every live API replica
found by the [tracker](#tracker). Default: `memory-standalone`.

### log:app-log-memory-buffer-bytes

Size in bytes of the in-memory log buffer kept per app. Integer. Default: `1048576` (1 MiB).

### request-id-header

Name of an HTTP header (for example `X-Request-ID`) that tsurud reads from incoming requests,
generates when absent, writes to the access log and forwards to service brokers. Default: unset
(no request IDs).

### cors:allowed-origins

List of origins allowed by CORS. When non-empty tsurud answers preflights for them with every
method and header allowed. Default: empty (CORS disabled).

### Tracing

Distributed tracing is not configured in `tsuru.conf`. Set the standard `OTEL_*` environment
variables on the tsurud process; see
[Tracing with OpenTelemetry](../admin_guides/observability.md#tracing-with-opentelemetry).

## Provisioner and Kubernetes

### provisioner

Must be `kubernetes`, the only provisioner built into tsuru 1.34. **Required** in practice: when
the key is missing or set to `docker`, the startup checker looks for the legacy `docker:*` cluster
keys and refuses to start with `Config error: you should configure docker.`

### kubernetes:use-pool-namespaces

Create one namespace per pool (`tsuru-<pool>`) instead of putting every app in `default`. Boolean.
Default: `false`. A cluster's `namespace` custom data overrides the prefix either way.

### kubernetes:headless-service-port

Port exposed by the per-process headless Service. Integer. Default: the value of
`docker:run-cmd:port` (`8888`).

### kubernetes:api-timeout

Timeout in seconds for each call to the Kubernetes API. Number. Default: `60`.

### kubernetes:pod-ready-timeout

Seconds to wait for a pod to become ready. Number. Default: `60`.

### kubernetes:pod-running-timeout

Seconds to wait for a pod to reach the Running state (for example during a build or `tsuru app
run`). Number. Default: `600`.

### kubernetes:deployment-progress-timeout

Seconds a rollout may go without progress before the deploy is rolled back. Number. Default:
`600`.

### kubernetes:attach-after-finish-timeout

Seconds to keep reading a container's output after it has finished. Number. Default: `60`.

### kubernetes:log-level

Verbosity passed to the Kubernetes client library (`glog -v`). Integer. Default: `0` (off).

### kubernetes:register-node

Boolean, default `false`. Read into the provisioner configuration but not used by any code path
in 1.34; it has no effect.

### kubernetes:keda:prometheus-address-template

Go template for the Prometheus server URL used by KEDA-based autoscalers that do not set their
own `prometheusAddress`. The only template variable is `{{.namespace}}`, for example
`http://prometheus.{{.namespace}}.svc:9090`. Default: none; creating such an autoscaler fails
when it is unset.

### clusters:defaults:\<key\>

Default value for any cluster custom data key, used when neither the pool-scoped nor the
cluster-wide entry is set on the cluster itself. Example: `clusters:defaults:overcommit-factor:
1`. The recognised keys are listed in
[Cluster custom data](../admin_guides/managing_clusters.md#cluster-custom-data). Default: none.

## Registry and images

The `docker:` prefix is historical: these keys date from the Docker provisioner but are still
read by the image and deploy code used with Kubernetes. Only the keys below are read; any other
`docker:*` key, including the legacy `docker:cluster:*`, `docker:collection`, `docker:deploy-cmd`
and `docker:run-cmd:bin`, is ignored (the checker reads `docker:cluster:*` only when
`provisioner` is not `kubernetes`).

### docker:registry

Registry host (optionally with a path) where app and platform images are pushed, for example
`registry.example.com:5000`. Default: none, which only works when the cluster custom data
`registry` is set. The cluster value wins when both exist.

### docker:registry-auth:username

Username sent to the build service when pushing to `docker:registry`. Default: none.

### docker:registry-auth:password

Password for `docker:registry-auth:username`. Default: none.

### docker:registry-auth:insecure

Allow the build service to push over plain HTTP or with an untrusted certificate. Boolean.
Default: `false`.

### docker:repository-namespace

Path segment placed between the registry and the app name in image names
(`<registry>/<namespace>/app-<name>:v1`). Default: `tsuru`.

### docker:resolve-registry-name

Resolve the hostname in `docker:registry` to its IP address when building image names. Boolean.
Default: `false`.

### docker:image-history-size

Number of successful deploy images kept per app for rollback; older ones are removed by the
image garbage collector. Integer. Default: `10`.

### docker:max-layers

Every Nth deploy (and every deploy after `tsuru app update --platform`) builds from the platform
image instead of the previous app image, to stop image layers from piling up. Integer. Default:
`10`.

### docker:gc:dry-run

Make the image garbage collector only mark images without deleting them. Boolean. Default:
`false`. When the key is absent each GC run records a `fetch config error` on its event and
still sweeps, so set it explicitly.

### docker:run-cmd:port

Port the web process is expected to listen on; exported to units as `PORT` and `port`. Also the
default of `kubernetes:headless-service-port`. Default: `8888`.

### docker:healthcheck:max-time

Minimum seconds a deploy waits for the readiness healthcheck declared in `tsuru.yaml` before
giving up; a longer `healthcheck.deploy_timeout_seconds` in the app wins. Integer. Default:
`120`.

### docker:uid

Numeric user ID set as `runAsUser` on app containers. Integer; a negative value leaves the image
default. Default: `1000`. (`docker:user` and `docker:ssh:user` are read alongside it but the
username is not applied on Kubernetes.)

## Apps and jobs

### apps:bootstrap:image

Image deployed automatically when an app is created, so that it has running units before its
first `tsuru app deploy`. Default: none (no bootstrap deploy).

### apps:dashboard-url:template

Go template rendered into the `dashboardURL` field of `tsuru app info`. It receives the app
info structure, so `{{.Name}}`, `{{.Pool}}`, `{{.Cluster}}` and the other fields of `tsuru app
info --json` are available. Example: `https://grafana.example.com/d/apps?var-app={{.Name}}`.
Default: none.

### jobs:dashboard-url:template

Same as above for `tsuru job info`, rendered with the job info structure. Default: none.

## Routers

Routers declared in the configuration use the format `routers:<router name>`. Routers can
also be created at runtime with `tsuru router add` (dynamic routers); a dynamic router cannot
reuse the name of a configured one.

### routers:\<name\>:default

Use this router for apps that do not pick one. Boolean. Default: `false`.

### routers:\<name\>:type

Router implementation. Default: the router name. Use `api` for routers that implement the
[Router API](router_api.md), such as [kubernetes-router](https://github.com/tsuru/kubernetes-router).

### routers:\<name\>:api-url

Base URL of the router API. **Required** for `type: api`.

### routers:\<name\>:debug

Log every request to the router API. Boolean. Default: the value of the global `debug`.

### routers:\<name\>:multi-cluster

Send the pool and cluster headers (`X-Tsuru-Pool-Name`, `X-Tsuru-Cluster-Name`, ...) on every
request to the router API, so one router can serve several clusters. Default: `false`.

### routers:\<name\>:headers

Map of extra headers sent on every router API request. Each value is a string or a list of
strings:

```yaml
headers:
  X-CUSTOM-HEADER: my-value
```

### routers:\<name\>:readinessGates

List of pod readiness gate condition types added to the pods of apps using this router, so a
unit only becomes ready once the router has registered it. Default: none.

```yaml
routers:
  ingress:
    type: api
    api-url: http://kubernetes-router.tsuru-system:8077
    default: true
    readinessGates:
    - tsuru.io/router-ready
```

Any other key under `routers:<name>` is passed through to the router implementation as its
configuration and exposed by `tsuru router info`.

## Volumes

### volume-plans:\<plan\>:\<provisioner\>

Volume plans offered to users. `<provisioner>` is `kubernetes`; its options are `plugin`,
`storage-class`, `capacity` and `access-modes`, documented with their rules in
[Volume plans](../user_guides/volumes.md#volume-plans), together with an example. Default: none
(no volumes can be created).

## Events

### event:throttling

List of limits on how many events of a kind may start on a target within a window. Default:
empty (no throttling). Each entry has:

| Key | Description |
|-----|-------------|
| `target-type` | Target type (`app`, `job`, `pool`, `service-instance`, `team`, `user`, `cluster`, `volume`, ...). Required. |
| `kind-name` | Event kind (`app.deploy`, `app.update`, ...). Omitted: applies to every kind on that target type; a spec with a kind wins over one without. |
| `limit` | Maximum events in the window. Integer. |
| `window` | Window length in seconds. Integer. |
| `all-targets` | Count across all targets of the type instead of per target. Boolean. Default: `false`. |
| `wait-finish` | Also count events still running that started before the window. Boolean. Default: `false`. |

```yaml
event:
  throttling:
  - target-type: app
    kind-name: app.deploy
    limit: 3
    window: 600
```

See [Server configuration](../admin_guides/events.md#server-configuration) for the error users
get and how throttling interacts with locks.

### events:suppress-sensitive-envs

Hide the values of private environment variables in `app.deploy` events returned by the API.
Boolean. Default: `false`.

## Services and tags

### tag:service-addr

Address (`host:port`) of a tag service implementing the tsuru tag gRPC API, used to validate tags
on apps and service instances. The connection is plaintext. Default: none (tags are accepted
without validation).

### proxy:\<host\>

HTTP proxy URL used when tsurud connects to `<host>`. It applies to event webhook URLs, image
registries (including ECR) and the GCP auth plugin; the Kubernetes API itself uses the cluster's
`httpProxy` custom data instead. Example: `proxy:registry.example.com: http://proxy:3128`.
Default: none.

## Tracker

tsurud replicas advertise themselves so that peers can find them; this is what the `memory`
app-log service and event instance stamps rely on. See
[Instance tracker](../admin_guides/operating_tsurud.md#instance-tracker).

### tracker:update-interval

Seconds between heartbeats written to MongoDB. Number. Default: `15`.

### tracker:stale-timeout

Seconds without a heartbeat before an instance is considered gone. Number. Default: `50`.

### tracker:interface

Network interface whose addresses are advertised. Default: `eth0`, then `en0`.

### tracker:ipv4-only

Advertise only IPv4 addresses. Boolean. Default: `true`.

### tracker:use-kubernetes

Discover replicas from the EndpointSlices of a Kubernetes Service instead of MongoDB
heartbeats. Boolean. Default: `false`. Requires the pod to run in-cluster and the two keys below.

### tracker:kubernetes-namespace

Namespace of the Service used for discovery. **Required** when `tracker:use-kubernetes` is `true`.

### tracker:kubernetes-service

Name of the Service whose EndpointSlices list the tsurud pods. **Required** when
`tracker:use-kubernetes` is `true`.

## Sample configuration

The smallest file that passes the startup checks and boots against a Kubernetes cluster. Add
the cluster afterwards with `tsuru cluster add`, and a router under `routers:` before creating
apps.

```yaml
listen: "0.0.0.0:8080"
host: https://tsuru.example.com
provisioner: kubernetes

database:
  url: mongodb://mongodb.tsuru-system:27017
  name: tsuru

auth:
  scheme: native
  user-registration: false
  peer:
    token: <random secret shared by all replicas>

docker:
  registry: registry.example.com
  repository-namespace: tsuru
  gc:
    dry-run: false

routers:
  ingress:
    type: api
    api-url: http://kubernetes-router.tsuru-system:8077
    default: true

log:
  disable-syslog: true
  use-stderr: true
  format: json
```

The `tsuru-api` Helm chart still emits a few keys that tsurud 1.34 no longer reads; they are
harmless and can be dropped from custom values: `queue:mongo-url`, `queue:mongo-database`,
`admin-team`, `tls:auto-reload:interval` (certificates are now reloaded on file change) and
`docker:cluster:*` (only consulted when `provisioner` is not `kubernetes`).
