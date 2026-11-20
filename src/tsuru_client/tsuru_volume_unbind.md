## tsuru volume unbind

Unbinds a volume from an application.

### Synopsis

Unbinds a volume from an application.

```
tsuru volume unbind <volume-name> <mount point> [-a/--app <appname>] [flags]
```

### Options

```
  -a, --app string   The name of the app.
      --no-restart   prevents restarting the application
  -h, --help         help for unbind
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru volume](tsuru_volume.md)	 - Volumes allow applications running on tsuru to use external storage volumes mounted on their filesystem.

