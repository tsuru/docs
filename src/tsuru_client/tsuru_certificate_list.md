## tsuru certificate list

List App TLS certificates.

### Synopsis

List App TLS certificates.

```
tsuru certificate list [-a/--app appname] [-r/--raw] [flags]
```

### Options

```
  -a, --app string   The name of the app.
      --json         Display JSON format
  -r, --raw          Display raw certificates
  -h, --help         help for list
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru certificate](tsuru_certificate.md)	 - Certificate is used to manage SSL/TLS certificates for secure communication.

