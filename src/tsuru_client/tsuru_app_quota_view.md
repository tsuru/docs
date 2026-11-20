## tsuru app quota view

Displays the current usage and limit of the given app.

### Synopsis

Displays the current usage and limit of the given app.

```
tsuru app quota view <app-name> [flags]
```

### Options

```
  -a, --app string   The name of the app.
      --json         Show JSON
  -h, --help         help for view
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru app quota](tsuru_app_quota.md)	 - Quotas are used to safeguard the cluster against undesired or excessive scaling.

