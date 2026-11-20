## tsuru config alias

Add an alias to a tsuru command. This allows you to create custom shortcuts for tsuru commands, making it easier to use the CLI.

### Synopsis

Add an alias to a tsuru command. This allows you to create custom shortcuts for tsuru commands, making it easier to use the CLI.
Examples:

# make 'deploy' map to 'app deploy'
$ tsuru config alias "app deploy" "deploy"
$ tsuru deploy <app-name>

# create a shorthand for 'app info':
$ tsuru config alias "app info" "ai"
$ tsuru ai <app-name>


```
tsuru config alias <alias> <command> [--delete/-d] [flags]
```

### Options

```
  -d, --delete   remove the provided alias instead of adding it
  -h, --help     help for alias
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru config](tsuru_config.md)	 - Manage tsuru client configuration. Config file is expected at $HOME/.config/tsuru/config.json

