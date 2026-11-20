# Operating the API server

`tsurud` is the tsuru API server. It is a single Go binary that reads `tsuru.conf`, talks to MongoDB and to the Kubernetes clusters you register, and serves the REST API that the `tsuru` client, the Terraform provider and the web dashboard use. This page covers the day-to-day of running it: subcommands, startup checks, migrations, health and debug endpoints, shutdown, TLS and the Helm chart. Configuration keys are documented in the [tsuru.conf reference](../reference/config.md); keys that are not there yet are explained inline.

## The tsurud binary

```
tsurud <command> [-c|--config /etc/tsuru/tsuru.conf] [command flags]
```

| Command | What it does |
|---------|--------------|
| `api` | Validates the configuration and starts the HTTP (and HTTPS) server. This is the long-running process. |
| `version` | Prints `tsurud version <version> (git commit <hash>)`. |
| `migrate` | Runs the pending mandatory migrations, or one optional migration with `--name`. See [Migrations](#migrations). |
| `migrate-list` | Lists every registered migration with its `Mandatory?` and `Executed?` status. |
| `root-user-create <email>` | Creates (or updates) a user and gives it the `AllowAll` role, which carries every permission (`*`) in the global context. Use it once to bootstrap an installation, then create proper roles and remove it. With the `native` scheme it prompts for a password; with other schemes it only records the e-mail. |

Every command accepts `-c`/`--config` and reads `/etc/tsuru/tsuru.conf` by default. All of them open the configuration file and initialise the database-backed services before running, so even `tsurud version` needs a readable `tsuru.conf` with the `database:*` keys set.

The `api` command has two flags:

| Flag | Effect |
|------|--------|
| `-t` | Run the startup configuration checks and exit. Use it in CI or in a Helm pre-install hook to test a `tsuru.conf` before rolling it out. There is no long form. |
| `-d`, `--dry` | Load the configuration and build the full HTTP router, but do not listen. Mostly useful for tests. |

The process also reacts to two signals: `SIGHUP` re-reads the configuration file (values that are read on every request, such as `request-id-header`, pick up the change; values read once at startup, such as `listen`, do not), and `SIGUSR1` dumps all goroutine stacks to stdout. A [gops](https://github.com/google/gops) agent is started at launch so you can inspect the process locally with the `gops` tool.

## Startup configuration checks

`tsurud api` (with or without `-t`) refuses to start unless these keys are present:

| Key | Check |
|-----|-------|
| `listen` | Must be set (see [`listen`](../reference/config.md#listen)). |
| `host` | Must be set. It is the public URL of the API; it is shown on the index page, exported to app units as `TSURU_HOST` and used to validate TLS certificates. |
| `database:url`, `database:name` | Must be set. See [Database access](../reference/config.md#database-access). |
| `database:driver` | Optional, but when set it must be `mongodb`. |
| `provisioner` | Must be `kubernetes`. If the key is missing or set to `docker`, tsurud looks for the legacy `docker:*` keys and fails with `Config error: you should configure docker.` |

Beyond these hard checks, startup also loads every router from `routers:*`, resolves `auth:scheme` (default `native`), initialises the Kubernetes provisioner, event throttling and the image garbage collector, and runs every registered [health checker](#health-checks). A failing checker is logged as `WARNING: "MongoDB" is not working` but does not stop the server.

## Migrations

tsurud does not migrate data on its own. After upgrading the binary, run:

```bash
$ tsurud migrate-list
+-----------------------------+------------+-----------+
| Name                        | Mandatory? | Executed? |
+-----------------------------+------------+-----------+
| migrate-docker-images       | true       | true      |
| migrate-apps-kubernetes-crd | true       | false     |
+-----------------------------+------------+-----------+
$ tsurud migrate
```

Migrations are plain functions registered inside tsurud and tracked in the `migrations` collection of the tsuru database, so each one runs once per installation.

| Form | Behaviour |
|------|-----------|
| `tsurud migrate` | Runs every mandatory migration that has not run yet, in registration order, and records each success. |
| `tsurud migrate -n` / `--dry` | Prints what would run without executing or recording anything. |
| `tsurud migrate --name <name>` | Runs one *optional* migration. Fails with `migration is mandatory` if you name a mandatory one, and with `migration already executed` if it already ran. |
| `tsurud migrate --name <name> -f` / `--force` | Re-runs an optional migration that already executed. `-f` without `--name` is rejected (`mandatory migrations can only run once`). |

Two migrations are registered in tsuru 1.34, both mandatory and there are currently no optional ones:

- `migrate-docker-images`: a no-op on Kubernetes installations (it only does work when `provisioner` is `docker`).
- `migrate-apps-kubernetes-crd`: creates the `App` custom resources that the Kubernetes provisioner keeps for every existing app.

Run `tsurud migrate` from a pod or host that has the same `tsuru.conf` as the API, ideally with the old API instances already stopped. Both commands connect to MongoDB and, for the CRD migration, to every registered cluster.

## Health checks

`GET /healthcheck` (and `/healthcheck/`) is unauthenticated and is what the Helm chart uses for liveness and readiness probes.

| Request | Response |
|---------|----------|
| `GET /healthcheck` | `200 WORKING`. No component is checked; it only proves the process is serving requests. |
| `GET /healthcheck?check=all` | Runs every registered checker and returns one line per checker, `<name>: <status> (<duration>)`. Returns `500` if any of them fails. |
| `GET /healthcheck?check=MongoDB` | Runs only the named checker(s). Repeat `check=` for several. Unknown names are ignored. |

The only checker registered in tsuru 1.34 is `MongoDB`, which pings the database:

```
$ curl -s https://tsuru.example.com/healthcheck?check=all
MongoDB: WORKING (3.141ms)
```

A failing checker reports `fail - <error>`. Requests to `/healthcheck` and `/metrics` are not written to the access log.

## Info, metrics and debug endpoints

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `GET /info` | Any valid token | JSON with the running version: `{"version":"1.34.0 (git commit abc123)"}`. |
| `GET /metrics` | **None** | Prometheus exposition of every tsuru metric plus the Go runtime metrics. See [Observability](observability.md#prometheus-metrics). |
| `GET /debug/goroutines` | Token with the `debug` permission | Stack dump of every goroutine. |
| `GET /debug/pprof/` and `/debug/pprof/{cmdline,profile,symbol,heap,goroutine,threadcreate,block,trace}` | Token with the `debug` permission | Standard Go `net/http/pprof` handlers. |
| `GET /debug/fgprof` | Token with the `debug` permission | [fgprof](https://github.com/felixge/fgprof) wall-clock profile. |

The `/debug/*` handlers check the `debug` permission on the token, so give it only to the operators' role (`tsuru role permission add <role> debug`). `/metrics` and `/healthcheck` have no authentication at all: if the API is reachable from the Internet, block those paths at your ingress or load balancer and scrape `/metrics` from inside the cluster.

```bash
# CPU profile of a running API, 30 seconds
$ curl -s -H "Authorization: bearer $TOKEN" "https://tsuru.example.com/debug/pprof/profile?seconds=30" -o cpu.prof
$ go tool pprof cpu.prof
```

## Graceful shutdown

On `SIGTERM` or `SIGINT` tsurud stops accepting new connections and waits for in-flight requests (including long deploy streams and `tsuru app log -f` connections) to finish, then runs the registered shutdown handlers: the instance tracker, open log streams, the Kubernetes provisioner and the certificate reloader. Each phase is bounded by [`shutdown-timeout`](../reference/config.md#shutdown-timeout) (seconds, default `600`). Progress is printed to stdout as `[shutdown] ...` lines.

Set `terminationGracePeriodSeconds` on the pod to at least `shutdown-timeout`, otherwise Kubernetes kills the process while deploys are still streaming. The Helm chart hard-codes `600` for this reason.

## TLS

Set [`use-tls: true`](../reference/config.md#use-tls) and point [`tls:cert-file`](../reference/config.md#tls-cert-file) and [`tls:key-file`](../reference/config.md#tls-key-file) to PEM files. With only `listen` set, that address becomes the HTTPS listener; set [`tls:listen`](../reference/config.md#tls-listen) as well to serve HTTP on `listen` and HTTPS on `tls:listen` at the same time. tsurud watches the certificate files and reloads them when they change, so cert-manager renewals need no restart; [`tls:validate-certificate`](../reference/config.md#tls-validate-certificate) additionally refuses to offer a certificate that is expired, untrusted, or does not match the hostname in `host`. [`server:read-timeout`](../reference/config.md#server-read-timeout) and [`server:write-timeout`](../reference/config.md#server-write-timeout) apply to both listeners.

## Index page

`GET /` returns an HTML page that tells users the API address (`host`), whether self-registration is enabled (`auth:user-registration`) and whether the native login is in use. It is unauthenticated. Set [`disable-index-page: true`](../reference/config.md#disable-index-page) to remove the route (the API then returns `404` on `/`), or change its contents with [`index-page-template`](../reference/config.md#index-page-template).

## Request IDs and CORS

`request-id-header` names an HTTP header (for example `X-Request-ID`) that tsurud propagates through a request. When set, tsurud uses the incoming value if the client sent one, otherwise generates a UUID, and writes it to the access log as `[Request-ID: ...]` (or `request.requestID` in JSON logs). It is unset by default, so there is no request ID unless you configure it. Put your load balancer's request-ID header here to correlate its logs with tsurud's.

`cors:allowed-origins` is a list of origins; when it is non-empty tsurud answers CORS preflights for those origins with every method and header allowed, and logs `Cors enabled` at startup. Leave it unset unless a browser application (such as a dashboard served from another domain) calls the API directly.

## Instance tracker

tsurud is usually run with several replicas. Each replica advertises itself (hostname, IP addresses and the ports from `listen`/`tls:listen`) so that the others can find it: events record which instance ran them, and the in-memory app log service fans `tsuru app log` requests out to every live instance (see [Observability](observability.md#application-logs)). Peer requests are authenticated with `auth:peer:token`, which must be identical on every replica.

| Key | Default | Meaning |
|-----|---------|---------|
| `tracker:update-interval` | `15` | Seconds between heartbeats written to MongoDB. |
| `tracker:stale-timeout` | `50` | Seconds without a heartbeat before an instance is considered gone. |
| `tracker:interface` | `eth0`, then `en0`, then the first interface | Network interface whose addresses are advertised. |
| `tracker:ipv4-only` | `true` | Advertise only IPv4 addresses. |
| `tracker:use-kubernetes` | `false` | Discover instances from the EndpointSlices of a Kubernetes Service instead of MongoDB heartbeats. Requires `tracker:kubernetes-namespace` and `tracker:kubernetes-service`, and the pod's service account must be allowed to list EndpointSlices. |

## Running with the Helm chart

The [`tsuru-api` chart](https://github.com/tsuru/charts) runs the `tsuru/api` image, whose entrypoint is `/usr/local/bin/tsurud` with `api` as the default argument; the chart does not override the container command. `tsuru.conf` is rendered from `tsuruConfig.*` values into a ConfigMap mounted at `/etc/tsuru`, and a checksum annotation on the pod template restarts the pods when it changes. Secrets listed in `secretKeys` are injected as upper-cased environment variables. The chart sets `use-tls: true`, listens on `0.0.0.0:8080` (HTTP) and `0.0.0.0:8443` (HTTPS) by default, mounts the TLS secret (yours, or one issued by cert-manager) at `/mnt/tls`, probes `/healthcheck` for liveness (after a 90 s initial delay) and readiness, and uses a 600 s termination grace period. `tsuruConfig.log.disableSyslog` defaults to `true` because the container has no syslog daemon; keep it that way or tsurud fails at startup with `unable to initialize logging`.

To run a migration with the chart's configuration:

```bash
$ kubectl -n tsuru-system exec deploy/tsuru-api -- tsurud migrate-list
$ kubectl -n tsuru-system exec deploy/tsuru-api -- tsurud migrate
```
