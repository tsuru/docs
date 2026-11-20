# tsuru.yaml

`tsuru.yaml` (or `tsuru.yml`) is a special file located in the root of your application. It describes deployment hooks, process configurations, health checks, startup checks, and Kubernetes-specific configurations.

## Deployment hooks

tsuru provides deployment hooks that allow you to run commands at specific points during deployment.

```yaml
hooks:
  restart:
    before:
      - python manage.py generate_local_file
    after:
      - python manage.py clear_local_cache
  build:
    - python manage.py collectstatic --noinput
    - python manage.py compress
```

### Available hooks

| Hook | Description |
|------|-------------|
| `restart:before` | Runs before each unit is restarted. Executes once per unit. |
| `restart:after` | Runs after each unit is restarted. Executes once per unit. |
| `build` | Runs during deployment when the image is being generated. |

### How hooks run

- `restart:before` commands are joined with `&&` and prepended to the process command; the whole thing runs as `/bin/sh -lc ...`, so if a hook fails the process never starts.
- `restart:after` commands are joined with `&&` and run as the container's Kubernetes `postStart` lifecycle hook (`sh -c`), in parallel with the process start.
- `build` commands run inside the image build, so their output is baked into the image.

## Process configurations

You can declare each process of your app in the tsuru.yaml file. This allows you to configure the command to run and the healthcheck/startupcheck for each process.

```yaml
processes:
  - name: web
    command: python app.py
    healthcheck:
      path: /
      scheme: http
    startupcheck:
      path: /startupcheck
      scheme: http
  - name: web-secondary
    command: python app2.py
    healthcheck:
      path: /
      scheme: http
```

### Process options

| Option | Description | Required |
|--------|-------------|----------|
| `name` | The name of the process | Yes |
| `command` | The command to run the process. When omitted, the command comes from the Procfile entry with the same name, or from the image `CMD` | No |
| `healthcheck` | Healthcheck configuration for the process | No |
| `startupcheck` | Startupcheck configuration for the process | No |

### Precedence

- When `processes:` is present, the top-level `healthcheck:` is ignored and the deploy prints a warning. Put the check under each process instead.
- A `processes[]` entry overrides a Procfile entry with the same name. An entry without `command` takes its command from the Procfile. If neither a Procfile nor any `command` exists, tsuru creates a single `web` process from the image `ENTRYPOINT` and `CMD`.
- Unknown healthcheck or startupcheck fields are not errors: the deploy prints `WARNING: invalid or deprecated healthcheck field ...` and ignores them. The old router-oriented fields `method`, `status`, `match`, `use_in_router` and `router_body` are among these.

!!! note "Healthcheck vs Startupcheck"
    - **healthcheck**: Monitors ongoing health after deployment. If it fails, the unit may be restarted or marked as unhealthy (removed from the router until healthy again).
    - **startupcheck**: Only runs during pod starts (deployments, scaling, restarts). Ensures the process is healthy before routing traffic. If it fails, the deployment is aborted and rolled back.

## Healthcheck

Health checks are called during deployment. tsuru ensures the health check passes before switching the router to the new units. If the health check fails, the deployment is aborted and your application remains available.

Health checks are also used by Kubernetes, so ensure the check is consistent to prevent units from being temporarily removed from the router.

### HTTP health check

```yaml
healthcheck:
  path: /healthcheck
  scheme: http
  headers:
    Host: test.com
    X-Custom-Header: xxx
  allowed_failures: 0
  interval_seconds: 10
  timeout_seconds: 60
  deploy_timeout_seconds: 180
```

### Command-based health check

```yaml
healthcheck:
  command: ["curl", "-f", "-XPOST", "http://localhost:8888"]
```

### Healthcheck options

| Option | Description | Default |
|--------|-------------|---------|
| `path` | Path to call for health check. Kubernetes expects status 200-399. | - |
| `scheme` | HTTP scheme (`http` or `https`). | `http` |
| `headers` | Additional HTTP headers (names should be capitalized). | - |
| `allowed_failures` | Failures before marking unhealthy. | `3` |
| `timeout_seconds` | Timeout for each health check call. | `60` |
| `deploy_timeout_seconds` | Timeout for first successful health check during deploy. | global config |
| `command` | Command to execute inside container. Exit 0 = healthy. Ignored if `path` is set. | - |
| `interval_seconds` | Interval between health checks. | `10` |
| `force_restart` | Restart unit after consecutive failures. Sets liveness probe in the Pod. | `false` |

### How checks map to Kubernetes probes

- `healthcheck` becomes the container's `readinessProbe`. With `force_restart: true` the same probe is also set as the `livenessProbe`.
- `startupcheck` becomes the `startupProbe`.
- `path` gets a leading `/` added if missing; `allowed_failures`, `interval_seconds` and `timeout_seconds` map to `failureThreshold`, `periodSeconds` and `timeoutSeconds`. HTTP checks pass on any 200-399 status.
- `deploy_timeout_seconds` is the time the deploy waits for the first successful check. It is floored by the server config `docker:healthcheck:max-time` (120 seconds when unset): a lower value in `tsuru.yaml` is raised to that minimum.

## Startupcheck

The startupcheck is similar to healthcheck but only runs during pod starts (deployments, scaling, restarts). It ensures the process is healthy before traffic is routed to it. If the startupcheck fails, the deployment is aborted and rolled back.

### HTTP startup check

```yaml
startupcheck:
  path: /startupcheck
  scheme: http
  headers:
    Host: test.com
    X-Custom-Header: xxx
  allowed_failures: 0
  interval_seconds: 10
  timeout_seconds: 60
```

### Command-based startup check

```yaml
startupcheck:
  command: ["curl", "-f", "-XPOST", "http://localhost:8888"]
```

### Startupcheck options

| Option | Description | Default |
|--------|-------------|---------|
| `path` | Path to call for startup check. Kubernetes expects status 200-399. | - |
| `scheme` | HTTP scheme (`http` or `https`). | `http` |
| `headers` | Additional HTTP headers (names should be capitalized). | - |
| `allowed_failures` | Failures before the check is considered failed. | `3` |
| `timeout_seconds` | Timeout for each startup check call. | `60` |
| `command` | Command to execute inside container. Exit 0 = passed. Ignored if `path` is set. | - |
| `interval_seconds` | Interval between startup check calls after a failure. | `10` |

## Multiple & Custom ports

You can configure which ports will be exposed on each process of your app.

```yaml
processes:
- name: process1
  ports:
  - name: main-port
    protocol: tcp
    target_port: 4123
    port: 8080
  - name: other-port
    protocol: udp
    port: 5000
- name: process2
```

### Port configuration options

| Option        | Description                         | Default             |
|---------------|-------------------------------------|---------------------|
| `name`        | Descriptive name for the port.      |                     |
| `protocol`    | Port protocol: `TCP` or `UDP`.      | `TCP`               |
| `target_port` | Port the process listens on.        | `port` value        |
| `port`        | Port exposed on Kubernetes service. | `target_port` value |

Either `port` or `target_port` must be specified. To expose no ports (e.g., for workers), leave the process field empty like `process2` in the example above.

### Limitations

- Health check uses the first configured port for each process
- Only the first port of the web process is exposed in the router
- Other ports can be accessed from apps in the same cluster using [Kubernetes DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#services): `appname-processname.namespace.svc.cluster.local`

### Legacy `kubernetes: groups:` form

Older files declare ports under `kubernetes: groups: <group>: <process>: ports:`. tsuru still parses it, but ports under `processes[]` win when both are present, so prefer `processes[].ports`. The legacy form looks like:

```yaml
kubernetes:
  groups:
    pod1:
      web:
        ports:
        - port: 8080
```
