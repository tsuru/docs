# Deploying applications

A deploy takes your code (or a ready-made container image), turns it into an app version, and rolls that version out to the app's units. Every deploy flavour goes through the same `tsuru app deploy` command and the same build pipeline; they differ only in what you send and who builds the image.

## Deploy flavours

| Flavour | Command | Who builds the image | When to use |
|---------|---------|----------------------|-------------|
| Source files | `tsuru app deploy -a <app> .` | tsuru, using the app's platform | Default for apps on an official platform ([Go](deploy_go_apps.md), [Node.js](deploy_nodejs_apps.md), [Python](deploy_python_apps.md), [React](deploy_react_apps.md)) |
| Dockerfile | `tsuru app deploy -a <app> --dockerfile .` | tsuru, from your container file | The platforms do not fit your stack; see [Deploy using Dockerfile](deploy_using_dockerfile.md) |
| Container image | `tsuru app deploy -a <app> -i <image>` | You, in your own CI | You already publish images to a registry |

Flavours are mutually exclusive: the client refuses files together with `--image`, and the API rejects `image` combined with `dockerfile` or uploaded files.

### Source files

```bash
$ tsuru app deploy -a myapp .                 # whole current directory
$ tsuru app deploy -a myapp mysite/           # a specific directory
$ tsuru app deploy -a myapp ./app.jar ./Procfile
$ tsuru app deploy -a myapp --files-only ./my-code/main.go ./tsuru_stuff/Procfile
```

`-f/--files-only` drops the base directories and places each file in the root of the app tree. Paths matching rules in `.tsuruignore` (same syntax as `.gitignore`, read from the current directory) are not uploaded; with `--dockerfile` the client also honours `.dockerignore`.

The app must have a platform for this flavour; the platform image is the base of the build. Platforms are managed by admins, see [Managing platforms](../admin_guides/managing_platforms.md).

### Container image

```bash
$ tsuru app deploy -a myapp -i registry.example.com/my-company/app:v42
```

The app does not need a platform (the same is true for `--dockerfile` and rollback). deploy-agent builds `FROM <image>`, pushes the result to tsuru's registry as the new version image, and extracts `Procfile` and `tsuru.yaml` (also `tsuru.yml`, `app.yaml`, `app.yml`) from the image's `WORKDIR`. When neither a Procfile nor `processes:` in tsuru.yaml exist, the image `ENTRYPOINT`/`CMD` becomes the `web` process.

## Common flags

| Flag | Effect |
|------|--------|
| `-m, --message <msg>` | Stored as the version description and with the deploy record (`tsuru app deploy list --json`) |
| `--new-version` | Keeps the versions already deployed and adds this one next to them (not routable until you say so) |
| `--override-old-versions` | Replaces every deployed version with this one, with the sum of their replicas |

Multi-version deploys and how to route or roll back between versions are covered in [Versions and rollback](app_versions.md).

## What happens during a deploy

1. The API creates an `app.deploy` event (visible in `tsuru event list -k app.deploy -t app -v <app>`) and keeps the HTTP connection open, streaming the build output.
2. The kubernetes builder opens a gRPC stream to the deploy-agent running in the app's pool and sends one of three build kinds: `APP_BUILD_WITH_SOURCE_UPLOAD`, `APP_BUILD_WITH_CONTAINER_FILE` or `APP_BUILD_WITH_CONTAINER_IMAGE`, plus the app's environment variables and the destination image name.
3. deploy-agent drives BuildKit. For source uploads it generates a Containerfile `FROM <platform image>`, copies the archive to `/home/application/current` and runs the platform's `/var/lib/tsuru/deploy` script followed by each entry of `hooks.build` from [tsuru.yaml](tsuru_yaml.md) as `sh -lc <hook>`. For Dockerfile and image deploys there is no `hooks.build` step; your Dockerfile `RUN` instructions play that role.
4. deploy-agent returns the extracted `Procfile`/`tsuru.yaml`; tsuru records the processes and healthchecks in the new version.
5. The provisioner creates a Kubernetes Deployment per process for the new version and waits for its units to pass the healthcheck. On success the old version is removed (unless `--new-version` was used); on failure the service is rolled back to the previous version and the deploy fails.

!!! note "Where `hooks.build` runs"

    Build hooks run inside the image build, with the app's env vars loaded. They do not run on the units; use `hooks.restart` for that.

## Build without deploying

`tsuru app build` runs steps 1 to 4 and stops: it produces a version image but does not change the running app.

```bash
$ tsuru app build -a myapp -t rc1 .
```

`-t/--tag` names the image tag. Like a source deploy, it requires the app to have a platform. You can deploy the result later with `tsuru app deploy -i <image>` or `tsuru app deploy rollback <image>`. Images built with a custom tag are never removed by the image garbage collector.

## Listing deploys

```bash
$ tsuru app deploy list -a myapp
```

Columns are `Image (Rollback)`, `Origin`, `User`, `Date (Duration)` and `Error`. Images marked with `(*)` can be used with `tsuru app deploy rollback`. Add `--json` for machine-readable output.

## Bootstrap deploy on app create

When the admin sets `apps:bootstrap:image` in the API config, every `tsuru app create` ends with an internal `bootstrap deploy` event that deploys that image to the new app, so the app has running units from the start (since tsuru 1.29.4). Without this setting an app has no units until its first deploy.

## Environment variables during the build

The app's env vars (your `tsuru env set` values plus service-bound ones) are passed to the build as a BuildKit secret named `tsuru-app-envvars`. The platform build loads it automatically; in your own Dockerfile mount it explicitly:

```dockerfile
RUN --mount=type=secret,id=tsuru-app-envvars,target=/var/run/secrets/envs.sh \
    . /var/run/secrets/envs.sh && your-build-command
```

Secrets are not stored in image layers. See [Environment variables](environment_variables.md) for how env vars reach the running units.

## Cancelling a deploy

A deploy is cancellable while the image is being built. Find the event and cancel it:

```bash
$ tsuru event list -k app.deploy -t app -v myapp --running
$ tsuru event cancel <event-id> "wrong branch" -y
```

Once the build finishes and the rollout to units starts, the event is marked non-cancellable and runs to completion (or rolls back on its own).

## Troubleshooting

- **`Healthcheck Timeout of Xs exceeded`**: the new units did not pass the healthcheck in time. The wait is `healthcheck.deploy_timeout_seconds` from tsuru.yaml, floored by the server-side `docker:healthcheck:max-time` (default 120s). Raise it for slow-starting apps, see [tsuru.yaml](tsuru_yaml.md).
- **`Deployment Progress Timeout of Xs exceeded`**: Kubernetes could not make the Deployment progress (image pull errors, insufficient resources, crash loops). The limit is `kubernetes:deployment-progress-timeout` (default 10 minutes). Check unit states with `tsuru app info` and [Unit states](unit_states.md).
- **Build fails**: the build log is streamed to your terminal and kept in the event; `tsuru event info <event-id>` shows it again.
- **App starts but misbehaves**: `tsuru app log -a myapp -l 100 -f` tails unit logs; `-s`/`-u` filter by source or unit. See [Recovering an application](recovering_app.md).
- **`can't deploy app without platform`**: a source-files deploy on an app created without a platform. Use `--dockerfile` or `-i`, or recreate the app with a platform.
