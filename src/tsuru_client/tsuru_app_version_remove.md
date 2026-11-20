## tsuru app version remove

Removes a specific version of an application. This is irreversible and will remove all data related to that version.

### Synopsis

Removes a specific version of an application. This is irreversible and will remove all data related to that version.

```
tsuru app version remove [appname] [--version version] [flags]
```

### Options

```
  -a, --app string       The name of the app.
      --version string   Version number
  -h, --help             help for remove
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru app version](tsuru_app_version.md)	 - Manage app versions

