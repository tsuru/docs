# Environment variables

Environment variables are the way to pass configuration to your application without changing its code. tsuru stores them with the app and exports them to every unit, alongside a few variables it injects itself and the ones that come from bound service instances.

## Setting variables

```bash
$ tsuru env set DATABASE_URL=postgres://db.example.com/app LOG_LEVEL=info -a myapp
```

Values with spaces or shell characters must be quoted: `tsuru env set GREETING="hello world" -a myapp`.

| Flag | Description |
|------|-------------|
| `-a, --app` | The app to change. |
| `-j, --job` | Set variables on a [job](../tsuru_client/tsuru_env_set.md) instead of an app. |
| `-p, --private` | Mark every variable in this call as private: its value is masked in `tsuru env get` and is left out of the `app.update.env.set` event. |
| `--no-restart` | Save the variables without restarting the app. The new values only reach the units on the next restart or deploy. |

See [tsuru env set](../tsuru_client/tsuru_env_set.md) for the full reference.

By default a successful `env set` restarts the app. When several versions of the app are running at the same time, tsuru restarts every version that currently has units, not only the latest one. If the app has no units yet, nothing is restarted.

!!! note "Sensitive names"
    If a variable name contains `KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `CREDENTIAL`, `API_KEY` or `APIKEY` and you did not pass `-p`, the client prints a warning recommending `--private`. The variable is still set; the warning is advice only.

## Getting variables

```bash
$ tsuru env get -a myapp
DATABASE_URL=postgres://db.example.com/app
LOG_LEVEL=info
MYSQL_PASSWORD=*** (private variable managed by mysql/mydb)
TSURU_APPDIR=/home/application/current (managed by tsuru)
TSURU_APPNAME=myapp (managed by tsuru)
TSURU_SERVICES=*** (private variable managed by tsuru)
```

Pass variable names to show only those, or `--json` for machine-readable output. Private values are always rendered as `***`; the client never receives them.

```bash
$ tsuru env get DATABASE_URL LOG_LEVEL -a myapp
```

`tsuru app info` does not list environment variables; `tsuru env get` is the only place to see them.

## Unsetting variables

```bash
$ tsuru env unset LOG_LEVEL -a myapp
```

`env unset` accepts the same `-a`, `-j` and `--no-restart` flags as `env set`. See [tsuru env unset](../tsuru_client/tsuru_env_unset.md).

## Jobs

Jobs have their own set of variables. Use `-j` instead of `-a` with the same three commands:

```bash
$ tsuru env set BUCKET=reports -j nightly-report
$ tsuru env get -j nightly-report
```

The name rules and reserved names below apply to jobs as well. Setting a job variable updates the job definition; the next run picks it up.

## Name rules

A variable name must match `^[_a-zA-Z][_a-zA-Z0-9]*$`: letters, digits and underscore, not starting with a digit. An invalid name is rejected with HTTP 400:

```
There were errors validating environment variables: "1BAD" is not valid environment variable name: a valid environment variable name must consist of alphabetic characters, digits, '_' and must not start with a digit
```

Three names are reserved because tsuru manages them: `TSURU_APPNAME`, `TSURU_SERVICES` and `TSURU_APPDIR`. Trying to set one returns:

```
There were errors validating environment variables: cannot change an internal environment variable (TSURU_APPNAME)
```

## Conflicts with service variables

Variables exported by a bound service instance are owned by the bind. Since tsuru 1.20.3, `env set` refuses a name that a bind already provides:

```
Environment variable "MYSQL_PASSWORD" is already in use by service bind "mysql/mydb"
```

Unbind the instance, or pick another name.

## Variables injected by tsuru

Every unit also receives these variables.

| Variable | Value |
|----------|-------|
| `TSURU_APPNAME` | The app name. |
| `TSURU_APPDIR` | The directory where the application code lives in the image (`/home/application/current`). |
| `TSURU_SERVICES` | JSON describing every bound service instance and its variables. See [TSURU_SERVICES](../services/environment_variables.md). Marked private. |
| `TSURU_PROCESSNAME` | The name of the process this unit runs (`web`, `worker`, ...). |
| `TSURU_APPVERSION` | The deploy version number this unit is running. |
| `TSURU_HOST` | The tsuru API address (the `host` key of the server configuration). |
| `PORT` and `port` | The port a `web` process must listen on. `8888` unless the server configures `docker:run-cmd:port`. |

## How values reach the units

On Kubernetes, since tsuru 1.28.0 private variables are not written into the pod spec. tsuru keeps them in a Kubernetes Secret per process and version and references each key with `secretKeyRef`; only public variables appear as plain values in the Deployment. The secret content is hashed into the pod template annotation `tsuru.io/secret-sha256`, so a change in a private value rolls the pods even when nothing else changed. Jobs follow the same rule.

Cluster administrators can turn this off with the cluster custom data key `disable-secrets=true` (optionally prefixed by pool, `<pool>:disable-secrets`), in which case every variable, public or private, is written as a plain value. See [managing clusters](../admin_guides/managing_clusters.md).

!!! note "Literal `$` in values"
    Kubernetes expands `$(VAR)` references inside plain environment values. tsuru escapes every `$` as `$$` before writing a value into the pod spec, so your value arrives untouched.

## Related

- [tsuru env](../tsuru_client/tsuru_env.md) command reference
- [TSURU_SERVICES environment variable](../services/environment_variables.md)
- [tsuru.yaml](tsuru_yaml.md) for process definitions and hooks
