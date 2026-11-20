## tsuru service manifest get

Shows the stored service permissions manifest. Requires API 1.31 or later.

### Synopsis

Shows the stored service permissions manifest. Requires API 1.31 or later.
Without flags, displays settings and an operations table.
Use --json or --yaml for structured stdout, or --output to export a file.
The output format is inferred from .json, .yaml or .yml unless explicitly selected.
Other file extensions require --json or --yaml. Existing files are overwritten.

Examples:
  tsuru service manifest get my-service
  tsuru service manifest get my-service --json
  tsuru service manifest get my-service --yaml
  tsuru service manifest get my-service -o manifest.yaml

```
tsuru service manifest get <service> [--json | --yaml] [-o/--output FILE] [flags]
```

### Options

```
      --json            Show JSON
  -o, --output string   Write the manifest to a file
      --yaml            Show YAML
  -h, --help            help for get
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru service manifest](tsuru_service_manifest.md)	 - Manage service permissions manifests

