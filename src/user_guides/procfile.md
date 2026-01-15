# Procfile

## Overview

`Procfile` is a simple text file that describes the components required to run an application. It is the way to tell tsuru how to run your applications.

## Syntax

A `Procfile` is a plain text file named `Procfile` placed at the root of your application. Each process should be represented by a name and a command:

```
<name>: <command>
```

- **name**: A string which may contain alphanumerics and underscores. It identifies one type of process.
- **command**: A shell command line which will be executed to spawn a process.

## Example

```bash
web: gunicorn -w 3 wsgi
```

The `web` process is special in tsuru - it is responsible for receiving HTTP requests. Your web process must listen on the port specified by the `PORT` environment variable, or use the default port `8888`.

## Multiple processes

You can define multiple processes in a single Procfile:

```bash
web: gunicorn -w 3 wsgi
worker: python worker.py
scheduler: python scheduler.py
```

## Environment variables

You can reference your environment variables in the command:

```bash
web: ./manage.py runserver 0.0.0.0:$PORT
```

## Further reading

For more information about Procfiles, see the [honcho documentation](https://honcho.readthedocs.io/en/latest/using_procfiles.html).
