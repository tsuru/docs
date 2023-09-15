# Managing pools

## Overview

Pool is used by provisioner to group applications to run on a specific cluster and may use a dedicated nodes. in practical terms is the target namespace and the target cluster for an application.

Tsuru has three types of pool: team, public and default.

Team’s pool are segregated by teams, and cloud administrator should set teams in this pool manually. This pool are just accessible by team’s members.

Public pools are accessible by any user.

Default pool is where apps are deployed when app’s team owner don’t have a pool associated with it or when app’s creator don’t choose any public pool. Ideally this pool is for experimentation and low profile apps, like service dashboard and “in development” apps. You can just have 
one default pool.

## Adding a pool

In order to create a pool, you should invoke tsuru pool add or create a terraform resource:


=== "Tsuru client"

    ```bash
    $ tsuru pool add pool1 --provisioner kubernetes
    ```


=== "Terraform"

    ```bash
    resource "tsuru_pool" "pool1" {
      name = "pool1"

      tsuru_provisioner = "kubernetes"
    }
    ```

If you want to create a public pool you can do:

=== "Tsuru client"

    ```bash
    $ tsuru pool add pool1 --provisioner kubernetes --public
    ```


=== "Terraform"

    ```bash
    resource "tsuru_pool" "pool1" {
      name   = "pool1"
      public = true

      tsuru_provisioner = "kubernetes"
    }
    ```

If you want a default pool, you can create it with:

=== "Tsuru client"

    ```bash
    $ tsuru pool add pool1 --provisioner kubernetes --default

    # to override the default opol
    $ tsuru pool add pool1 --provisioner kubernetes --default -f
    ```


=== "Terraform"

    ```bash
    resource "tsuru_pool" "pool1" {
      name    = "pool1"
      default = true

      tsuru_provisioner = "kubernetes"
    }
    ```



## Associate pool to a kubernetes cluster

when you have more than one kubernetes cluster, it's necessary to associate pool to related cluster


=== "Tsuru client"

    ```bash
    $ tsuru cluster update cluster2 kubernetes --add-pool pool2
    ```


=== "Terraform"

    ```bash
    resource "tsuru_cluster_pool" "cluster-pool" {
      cluster = "pool2"
      pool    = "cluster2"
    }
    ```

## Set teams to a pool

Then you can use tsuru pool constraint set to add teams to the pool that you’ve just created:

=== "Tsuru client"

    ```bash
    $ tsuru pool constraint set pool1 team team1 team2
    $ tsuru pool constraint set pool2 team team3
    ```


=== "Terraform"

    ```bash
    resource "tsuru_pool_constraint" "my-pool-constraint1" {
        pool_expr = "pool1"
        field     = "team"
        values    = [
          "team1",
          "team2",
        ]
    }

    resource "tsuru_pool_constraint" "my-pool-constraint2" {
        pool_expr = "pool2"
        field     = "team"
        values    = [
          "team3",
        ]
    }
    ```

## Listing pools

To list pools you do:

```bash
$ tsuru pool list
+-------+--------+-------------+-------+----------------+
| Pool  | Kind   | Provisioner | Teams | Routers        |
+-------+--------+-------------+-------+----------------+
| pool1 |        | kubernetes  | team1 | ingress-router |
+-------+--------+-------------+-------+----------------+
| local | public | kubernetes  | team2 | ingress-router |
+-------+--------+-------------+-------+----------------+
```

## Removing a pool

If you want to remove a pool, use tsuru pool remove or undeclare tsuru_pool resource on terraform

```bash
$ tsuru pool remove pool1
```


## Moving apps between pools and teams

You can move apps from poolA to poolB and from teamA to teamB even when they dont have permission to see each other’s pools, this is made by using tsuru app update:

```bash
$ tsuru app update --app <app> --team-owner <teamB> --pool <poolB>
```