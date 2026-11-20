# Recovering an application

Your application may be down for a number of reasons. This guide helps you discover why and how to fix the problem.

## Check your application logs

tsuru aggregates stdout and stderr from every application process, making it easier to troubleshoot problems.

```bash
tsuru app log -a appname
```

Use the `-f` flag to follow logs in real-time:

```bash
tsuru app log -a appname -f
```

Other useful flags (see [`tsuru app log`](../tsuru_client/tsuru_app_log.md)):

- `-l/--lines N`: number of lines to show (default 10).
- `-s/--source SOURCE`: only lines from the given log source (the source column of the output).
- `-u/--unit UNIT`: only lines from the given unit.
- `-f/--follow`: keep streaming new lines.

## Restart your application

Some application issues are solved by a simple restart. For example, your application may need to be restarted after a schema change to your database.

```bash
tsuru app restart -a appname
```

You can restart a single process, and a single deployed version, instead of the whole app:

```bash
tsuru app restart -a appname -p worker --version 3
```

## Check the status of application units

View detailed information about your application, including the state of each unit:

```bash
tsuru app info -a appname
```

For more information about unit states, see [Unit states](unit_states.md).

## Open a shell to the application

You can use `tsuru app shell` to open a remote shell to one of the units of the application:

```bash
tsuru app shell -a appname
```

You can also specify a unit ID to connect to a specific unit:

```bash
tsuru app shell -a appname <unit-id>
```

This is useful for debugging issues directly inside the container. Use `-i/--isolated` to open the shell in a new unit instead of one that is serving traffic.

### Debugging with an ephemeral container

If the application image has no shell or debugging tools, add `-d/--debug`:

```bash
tsuru app shell -a appname --debug <unit-id>
```

tsuru attaches an [ephemeral container](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/) named `tsuru-debugger` to the unit's pod and opens the shell there. Its image comes from the cluster custom data key `debug-container-image` (default `tsuru/netshoot`); a cluster admin sets it with `tsuru cluster update <cluster> kubernetes --add-custom debug-container-image=<image>`.

## Run one-off commands

`tsuru app run` executes a command in every unit of the app, in a single unit (`-o/--once`), or in a fresh ephemeral pod that is not serving traffic (`-i/--isolated`):

```bash
tsuru app run -a appname -i -- python manage.py migrate
```

The API aborts the command after 10 minutes, so long tasks belong in a [job](../tsuru_client/tsuru_job.md). Each run is a cancelable `app.run` event: find it with `tsuru event list -k app.run -r` and stop it with `tsuru event cancel <event-id> <reason>`.

## Checklist

1. `tsuru app info -a appname`: look at the unit states ([Unit states](unit_states.md)) and at which version each process is running.
2. `tsuru app log -a appname -u <unit>` for the units that are not ready.
3. `tsuru app restart -a appname -p <process> --version <n>` to restart only what is broken.
4. If units are healthy but the app is unreachable, `tsuru app routes rebuild -a appname` resyncs the router with the current units (requires the `app.admin.routes` permission).
