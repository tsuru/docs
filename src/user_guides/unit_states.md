# Unit states

## Overview

The unit status indicates what is happening with a unit in your application. You can check the unit status using the `tsuru app info` command:

```bash
$ tsuru app info -a tsuru-dashboard
Application: tsuru-dashboard
Platform: python
...
Units: 1
+---------------------------------------+-------+
| Unit                                  | State |
+---------------------------------------+-------+
| tsuru-dashboard-web-9cf863c2c1-63c2c1 | ready |
+---------------------------------------+-------+
```

## State flow

The unit state follows this lifecycle:

```
                                              start          +---------+
+----------+                          +--------------------→| stopped |
| building |                          |                     +---------+
+----------+                          |                          ↑
     ↑                                |                          |
     |                                |                        stop
   deploy                             |                          |
     |                                |                          |
     ↓           assigned             ↓                          |
+---------+      to node       +----------+                 +---------+
| created | ----------------→  | starting | --------------→ | started |
+---------+                    +----------+                 +---------+
                                    |                           ↑ |
                                    |                           | |
                                    ↓                           | |
                                +-------+                       | |
                                | error | ←---------------------+ |
                                +-------+ ←-----------------------+
```

## State descriptions

| State | Description |
|-------|-------------|
| **created** | Initial status of a unit |
| **building** | Unit is being provisioned by the provisioner (e.g., during deployment) |
| **starting** | Container has been started |
| **started** | Unit is up and running |
| **error** | Unit failed to start due to an application error |
| **stopped** | Unit has been stopped |
| **succeeded** | Unit finished successfully (jobs and one-off processes) |

`ready`, as shown by `tsuru app info`, is not a state of its own. It is displayed for a
`started` unit whose readiness check (the `healthcheck` in `tsuru.yaml`) is passing, which
is also when the unit receives traffic from the router.
