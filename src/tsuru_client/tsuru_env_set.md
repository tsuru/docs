## tsuru env set

Sets environment variables for an application or job.

### Synopsis

Sets environment variables for an application or job.

```
tsuru env set <NAME=value> [NAME=value] ... [-a/--app appname] [-j/--job jobname] [-p/--private] [--no-restart] [flags]
```

### Options

```
  -a, --app string   The name of the app.
  -j, --job string   The name of the job.
      --no-restart   Sets environment varibles without restart the application
  -p, --private      Private environment variables
  -h, --help         help for set
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru env](tsuru_env.md)	 - Manage environment variables from an app or job.

