# Recovering an application

Your application may be down for a number of reasons. This guide helps you discover why and how to fix the problem.

## Check your application logs

tsuru aggregates stdout and stderr from every application process, making it easier to troubleshoot problems.

```bash
$ tsuru app log -a appname
```

Use the `-f` flag to follow logs in real-time:

```bash
$ tsuru app log -a appname -f
```

## Restart your application

Some application issues are solved by a simple restart. For example, your application may need to be restarted after a schema change to your database.

```bash
$ tsuru app restart -a appname
```

## Check the status of application units

View detailed information about your application, including the state of each unit:

```bash
$ tsuru app info -a appname
```

For more information about unit states, see [Unit states](unit_states.md).

## Open a shell to the application

You can use `tsuru app shell` to open a remote shell to one of the units of the application:

```bash
$ tsuru app shell -a appname
```

You can also specify a unit ID to connect to a specific unit:

```bash
$ tsuru app shell -a appname <unit-id>
```

This is useful for debugging issues directly inside the container.
