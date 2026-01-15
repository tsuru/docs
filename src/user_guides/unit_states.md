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
+---------+      to node       +----------+                 +---------+  healthcheck ok   +-------+
| created | ----------------→  | starting | --------------→ | started | ----------------→ | ready |
+---------+                    +----------+                 +---------+                   +-------+
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
| **ready** | Unit is up, running, and healthcheck is passing |
| **error** | Unit failed to start due to an application error |
| **stopped** | Unit has been stopped |
