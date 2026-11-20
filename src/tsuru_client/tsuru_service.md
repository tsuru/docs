## tsuru service

A service is a well-defined API that tsuru communicates with to provide extra functionality for applications.

### Options

```
  -h, --help   help for service
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru](tsuru.md)	 - A command-line interface for interacting with tsuru
* [tsuru service create](tsuru_service_create.md)	 - Creates a service based on a passed manifest. The manifest format should be a yaml and follow the standard described in the documentation (should link to it here)
* [tsuru service destroy](tsuru_service_destroy.md)	 - removes a service from catalog
* [tsuru service doc](tsuru_service_doc.md)	 - Manage Service Docs
* [tsuru service info](tsuru_service_info.md)	 - Displays a list of all instances of a given service (that the user has access
* [tsuru service instance](tsuru_service_instance.md)	 - Manage provisioned resources (like a database or proxy) that can be linked to an application.
* [tsuru service list](tsuru_service_list.md)	 - Retrieves and shows a list of instances of service the user has access.
* [tsuru service manifest](tsuru_service_manifest.md)	 - Manage service permissions manifests
* [tsuru service plan](tsuru_service_plan.md)	 - Manage service plans of a given service.
* [tsuru service template](tsuru_service_template.md)	 - Generates a manifest template file and places it in current directory
* [tsuru service update](tsuru_service_update.md)	 - Update service data, extracting it from the given manifest file.

