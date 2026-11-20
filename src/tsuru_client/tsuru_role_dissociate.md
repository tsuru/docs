## tsuru role dissociate

Dissociate an existing role from a user, token or group for some context value.

### Synopsis

Dissociate an existing role from a user, token or group for some context value.

```
tsuru role dissociate <role-name> <user-email>|<token-id>|group:<group-id> [<context-value>] [flags]
```

### Options

```
  -h, --help   help for dissociate
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru role](tsuru_role.md)	 - Manage roles.

