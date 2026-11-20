## tsuru pool list

List all pools available for deploy.

### Synopsis

List all pools available for deploy.

```
tsuru pool list pool-list [flags]
```

### Options

```
      --json          Display in JSON format
  -n, --name string   Filter pools by name
  -q, --only-name     Display only pools name
  -t, --team string   Filter pools by team 
  -h, --help          help for list
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru pool](tsuru_pool.md)	 - A pool is used by provisioners to allocate space within a cluster for running applications.

