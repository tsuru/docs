# Using services

A service is an external resource (a database, a cache, a message queue...) exposed to tsuru through a service API. As an app developer you do not run the service yourself: you create a **service instance** from one of the plans the service offers, then **bind** it to your apps and jobs, which receive the connection details as environment variables.

This page covers the user side. If you want to offer a service to tsuru users, see [Building your service](../services/build.md) and the [Service API workflow](../services/api.md).

## Discovering services and plans

```bash
$ tsuru service list
$ tsuru service plan list <service-name>
$ tsuru service doc get <service-name>
```

`tsuru service list` shows the services you have access to and their instances. `-j/--just-services` prints only service names; `-q/--only-name` prints `service instance` pairs; `--json` prints the instances as JSON.

`tsuru service plan list` shows the plans and their descriptions. Some services are **multi-cluster**: they have one endpoint per pool, so plans may differ by pool and the command may require `-p/--pool`. The same flag exists on `tsuru service info`.

```bash
$ tsuru service plan list rpaasv2 -p my-pool
```

`tsuru service doc get` prints the documentation the service maintainer registered, if any.

## Creating an instance

```bash
$ tsuru service instance add <service-name> <instance-name> [plan] -t <team> \
    [-d description] [-g tag]... [--plan-param key=value]... [--pool name]
```

| Flag | Meaning |
|------|---------|
| `-t, --team` | Team that owns the instance. Mandatory when you belong to more than one team. |
| `-d, --description` | Free text shown by `service instance info`. |
| `-g, --tag` | Tag. Repeat the flag to set several. |
| `--plan-param key=value` | Plan-specific parameter forwarded to the service API. Repeat for several. |
| `--pool` | Pool where the instance will run. Required for multi-cluster services, rejected for regular ones. |

Parameters are whatever the service documents (`tsuru service doc get`); tsuru stores them with the instance and sends them to the service as `parameters.<key>`. For a multi-cluster service the pool must also allow the service through a pool constraint, otherwise the request is rejected.

## Inspecting an instance

```bash
$ tsuru service instance info <service-name> <instance-name> [--json]
```

The output shows `Service`, `Instance`, `Pool` (multi-cluster only), `Apps` and `Jobs` bound to it, `Teams` (owner first), `Description`, `Tags`, `Plan`, any **custom info** the service returns, a `Status` line, the plan description and the `Parameters` set at creation or update time.

The status comes from a separate call to the service and is one of:

| Service answer | Shown as |
|----------------|----------|
| `200` with a body | the body, verbatim |
| `202` | `pending` |
| `204` | `up` |
| `404` | `not implemented for this service` |
| `500` | `down` |

!!! note
    The API (`GET /services/{service}/instances/{instance}`) also returns the `Cluster` the pool of a multi-cluster instance maps to. The CLI does not print this field.

## Binding to apps and jobs

```bash
$ tsuru service instance bind <service-name> <instance-name> -a <app> [--no-restart]
$ tsuru service instance bind <service-name> <instance-name> -j <job>
```

Binding asks the service for the credentials of this app or job and stores them as **private** environment variables of the app (not visible with `tsuru env get`). The app is restarted so the new variables take effect, unless you pass `--no-restart`. Jobs are never restarted: the variables are used on their next run.

The variables are whatever the service returns, plus `TSURU_SERVICES`, a JSON document listing every bound instance and its variables. See [TSURU_SERVICES environment variable](../services/environment_variables.md).

You need `service-instance.update.bind` on the instance **and** `app.update.bind` on the app (`job.update` for jobs).

## Unbinding

```bash
$ tsuru service instance unbind <service-name> <instance-name> -a <app> [--no-restart] [--force]
$ tsuru service instance unbind <service-name> <instance-name> -j <job> [--force]
```

Unbinding removes the variables from the app and tells the service to drop the credentials. `--force` completes the unbind on the tsuru side even if the service API call fails; use it when the service is gone or broken.

!!! note
    Since tsuru 1.25, `--force` on an **app** unbind needs no extra permission. For a **job** unbind it still requires `service.update` on the service, which is normally held by the service maintainers only.

## Sharing an instance with other teams

```bash
$ tsuru service instance grant <service-name> <instance-name> <team>
$ tsuru service instance revoke <service-name> <instance-name> <team>
```

Members of a granted team can see, bind and manage the instance according to their own permissions. The owner team cannot be revoked; change the owner with `service instance update -t` first.

## Updating an instance

```bash
$ tsuru service instance update <service-name> <instance-name> \
    [-t team] [-d description] [-p plan] \
    [-g tag]... [--remove-tag tag]... \
    [--plan-param key=value]... [--remove-param key]...
```

At least one field must change. Each field is guarded by its own permission, so a role may allow, for example, retagging but not changing the plan:

| Field | Permission |
|-------|------------|
| `-d, --description` | `service-instance.update.description` |
| `-t, --team` | `service-instance.update.teamowner` |
| `-p, --plan` | `service-instance.update.plan` |
| `-g, --tag`, `--remove-tag` | `service-instance.update.tags` |
| `--plan-param` (alias `--add-param`), `--remove-param` | `service-instance.update.parameters` |

Plan and parameter changes are forwarded to the service API, which may reject them.

## Filtering instances by tag

```bash
$ tsuru service list -g env=prod -g team=payments
```

`-g/--tag` can be repeated; an instance is listed only when it carries **all** the given tags. The other `service list` filters (`-s` service, `-n` name substring, `-o` pool, `-p` plan, `-t` team owner) are applied on top.

## Removing an instance

```bash
$ tsuru service instance remove <service-name> <instance-name> [-f] [--ignore-errors] [-y]
```

The command asks for confirmation unless `-y/--assume-yes` is given. An instance still bound to apps is refused; the error lists the bound apps.

| Flag | Effect |
|------|--------|
| `-f, --force` | Unbind every bound app first (each app is restarted), then remove. |
| `--ignore-errors` | Delete the instance from tsuru even if the service API returns an error. |

## Calling extra service endpoints

Some services expose extra operations on an instance (scaling a proxy, rotating a credential...). tsuru proxies them at `/services/{service}/proxy/{instance}?callback=<path>` with any HTTP method; the request reaches the service at `/resources/<instance>/<path>`. Non-`GET` requests to the reserved paths `bind`, `bind-app`, `bind-job` and the bare instance path are rejected, and `..` segments are refused.

The core CLI has no generic command for this; services ship their own [client plugin](plugins.md) that uses the proxy. You need `service-instance.update.proxy` on the instance, unless the service's permission manifest maps the path to a finer action.
