# Versions and rollback

Every successful build creates an app **version**: an integer counter per app, a version image in tsuru's registry, and the processes and `tsuru.yaml` settings extracted during the build. Normally only one version is deployed at a time, but tsuru can run several versions side by side, decide which of them receive traffic, and roll back to an older one in seconds because the image already exists.

## Seeing versions

```bash
$ tsuru app info -a myapp
```

Units are grouped as `Units [process web] [version 3] [routable]: 2`. A group without `[routable]` runs but is not in the router's pool. The internal addresses table gains a `Version` column when more than one version is deployed.

```bash
$ tsuru app deploy list -a myapp
```

Lists past deploys with `Image (Rollback)`, `Origin`, `User`, `Date (Duration)` and `Error`. Images followed by `(*)` are valid rollback targets: the deploy succeeded, the image still exists and rollback was not disabled for it. Use `--json` for the raw data, including the version number and the deploy message.

## Deploying several versions

By default a deploy replaces the running version. Two flags of `tsuru app deploy` (and of `tsuru app deploy rollback`) change that:

| Flag | Behaviour |
|------|-----------|
| `--new-version` | Deploys the new version next to the existing ones and leaves them untouched. The new version starts **unroutable**; make it routable when you are ready. |
| `--override-old-versions` | Deploys the new version as the only one, with as many replicas as all routable versions had together, then removes the old versions. Use it to collapse a multi-version app back to one. |

```bash
$ tsuru app deploy -a myapp --new-version .
$ tsuru app router version add 4 -a myapp       # start routing traffic to v4
$ tsuru app router version remove 3 -a myapp    # stop routing to v3
$ tsuru app deploy -a myapp --override-old-versions .
```

!!! note "Routable means a label, not a separate router"

    `tsuru app router version add/remove` toggles the `tsuru.io/is-routable` label on that version's Kubernetes Deployment. The app's Service selects routable pods only, so traffic is spread across the units of every routable version. The version must be deployed, otherwise the command fails with `no deployment found for version N`.

## Controlling one version

Process-level commands accept `--version` and `-p/--process`:

```bash
$ tsuru app stop -a myapp --version 3 -p web
$ tsuru app start -a myapp --version 3 -p web
$ tsuru app restart -a myapp --version 4
$ tsuru unit add 2 -a myapp --version 4 -p web
$ tsuru unit remove 1 -a myapp --version 3 -p web
```

When more than one version is deployed and you omit `--version`, these commands fail with `more than one version deployed, you must select one`. With a single version `--version` is optional.

### Autoscale and versions

An autoscale rule targets one version. After deploying with `--new-version`, move the existing rules to the new version:

```bash
$ tsuru unit autoscale swap -a myapp --version 4
```

The target version must be deployed and the app must already have an autoscale configured (since tsuru 1.29.1). See [Autoscale](autoscale.md).

## Rolling back

```bash
$ tsuru app deploy rollback -a myapp 3
$ tsuru app deploy rollback -a myapp registry.example.com/tsuru/app-myapp:v3 -y
```

The argument can be a version number, the full image name, or a unique suffix of it (such as `:v3`). No build happens: the stored image is deployed again through the normal rollout, with healthcheck gating as in any deploy. `tsuru rollback` is an alias. Flags:

```
  -a, --app string              The name of the app.
  -y, --assume-yes              Don't ask for confirmation.
      --new-version             Creates a new version for the current deployment while preserving existing versions
      --override-old-versions   Force replace all deployed versions by this new deploy
```

A rollback is refused when the version was already marked for removal by the garbage collector, or when rollback was disabled for it (`the selected version is disabled for rollback: <reason>`).

### Disabling rollback to a version

If a version is known to be bad, block it so nobody rolls back to it by mistake:

```bash
$ tsuru app deploy rollback update -a myapp -i registry.example.com/tsuru/app-myapp:v3 \
    --disable --reason "leaks credentials in logs"
$ tsuru app deploy rollback update -a myapp -i registry.example.com/tsuru/app-myapp:v3   # re-enable
```

`--reason` is mandatory with `--disable`. A disabled version loses its `(*)` in `tsuru app deploy list` (its `CanRollback` field becomes `false` in the JSON output) and `tsuru app deploy rollback` rejects it. This needs the `app.update.deploy.rollback` permission.

## Removing a version

```bash
$ tsuru app version remove -a myapp --version 3
```

Deletes the Kubernetes Deployments, Services and autoscalers of that version in the cluster. It is irreversible. Use it to retire a version that was deployed with `--new-version` and is no longer needed; remove it from routing first if traffic still reaches it.

## Image retention

Old version images are not kept forever. A garbage collector runs on the API server every 5 minutes and, per app:

- keeps the last `docker:image-history-size` successful versions (default 10), the latest successful version and any version currently deployed, whatever its age;
- never removes versions built with a custom tag (`tsuru app build -t`);
- removes versions whose deploy failed once their deploy event has finished;
- marks the rest for removal, then deletes their images from the registry and their records from the database.

A version marked for removal can no longer be used in a rollback. Admins can set `docker:gc:dry-run` to log what would be removed without deleting anything.

## Removed features

| Feature | Status |
|---------|--------|
| `tsuru app swap` (blue-green by swapping two apps' routes) | The API endpoint `POST /swap` returns `412 swapping is deprecated`; the client no longer ships the command. Use `--new-version` with `tsuru app router version add/remove` instead. |
| `tsuru app deploy rebuild` | The API endpoint still exists, but the builder refuses it with `app rebuild is deprecated`; the client no longer ships the command. Run a normal deploy. |
| `tsuru app deploy diff` | Returns `410 Gone`. |
