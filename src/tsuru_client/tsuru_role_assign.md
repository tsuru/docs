## tsuru role assign

Assign an existing role to a user, token or group with some context value.

### Synopsis

Assign an existing role to a user, token or group with some context value.

```
tsuru role assign <role-name> <user-email>|<token-id>|group:<group-id> [<context-value>] [flags]
```

### Options

```
  -h, --help   help for assign
```

### Options inherited from parent commands

```
      --config string   Tsuru configuration file path to use
      --target string   Tsuru server endpoint
      --verbosity int   Verbosity level: 1 => print HTTP requests; 2 => print HTTP requests/responses
```

### SEE ALSO

* [tsuru role](tsuru_role.md)	 - Manage roles.

