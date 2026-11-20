## tsuru service manifest set

Replaces the stored service permissions manifest with a JSON or YAML file.

### Synopsis

Replaces the stored service permissions manifest with a JSON or YAML file.
Requires API 1.31 or later. Operation validation and grant conflicts are checked by the server.
This is the permissions manifest, separate from the service-create/service-update configuration.

Examples:
  tsuru service manifest set my-service manifest.json
  tsuru service manifest set my-service manifest.yaml

Example YAML:
  enabled: true
  strict_actions: true
  legacy_compat: false
  operations:
    - method: POST
      path: /rules/{ruleId}/sync
      action: rules.sync

Equivalent JSON:
  {"enabled":true,"strict_actions":true,"legacy_compat":false,"operations":[{"method":"POST","path":"/rules/{ruleId}/sync","action":"rules.sync"}]}

```
tsuru service manifest set <service> <filename> [flags]
```

### Options

```
  -h, --help   help for set
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru service manifest](tsuru_service_manifest.md)	 - Manage service permissions manifests

