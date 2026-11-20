## tsuru shell

Opens a remote shell inside unit.

### Synopsis

Opens a remote shell inside unit.
You can access an app unit just giving app name, or specifying the id of the unit.
You can get the ID of the unit using the app-info command.

```
tsuru shell [unit-id] -a/--app <appname> [-i/--isolated] [flags]
```

### Options

```
  -a, --app string   The name of the app.
  -d, --debug        Enable debug mode
  -i, --isolated     Run shell in a new unit
  -h, --help         help for shell
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru](tsuru.md)	 - A command-line interface for interacting with tsuru

