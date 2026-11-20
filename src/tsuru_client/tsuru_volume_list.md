## tsuru volume list

Lists existing persistent volumes.

### Synopsis

Lists existing persistent volumes.

```
tsuru volume list [flags]
```

### Options

```
      --json          Display in JSON format
  -n, --name string   Filter volumes by name
  -q, --only-name     Display only volumes name
  -p, --plan string   Filter volumes by plan
  -o, --pool string   Filter volumes by pool
  -t, --team string   Filter volumes by team owner
  -h, --help          help for list
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru volume](tsuru_volume.md)	 - Volumes allow applications running on tsuru to use external storage volumes mounted on their filesystem.

