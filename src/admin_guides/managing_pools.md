# Managing pools

## Overview

Pool is used by provisioner to group applications to run on a specific cluster. In practical terms it is the target namespace and the target cluster for an application.

Tsuru has three types of pool: team, public and default.

Team's pools are segregated by teams, and the cloud administrator sets which teams may use them through a `team` pool
constraint. These pools are only accessible by members of those teams.

Public pools are accessible by any user.

Default pool is where apps are deployed when the app's creator doesn't choose a pool. Ideally this pool is for
experimentation and low profile apps, like service dashboards and "in development" apps. You can only have one default
pool.

Internally, public and default pools are just pools whose `team` constraint is `*` (every team): `--public` and
`--default` create that constraint for you. Because of that, a public or default pool cannot also list individual teams
(the API answers "Public/Default pool can't have teams."), and `--public=false` or `--default=false` just removes the
`*` value from the constraint.

## Adding a pool

In order to create a pool, you should invoke `tsuru pool add` or create a terraform resource. `--public` creates a
public pool and `--default` a default one; `-f` overrides the current default pool.

=== "Tsuru client"

    ```bash
    $ tsuru pool add pool1 --provisioner kubernetes
    $ tsuru pool add shared --provisioner kubernetes --public
    $ tsuru pool add sandbox --provisioner kubernetes --default -f
    ```

=== "Terraform"

    ```terraform
    resource "tsuru_pool" "pool1" {
      name              = "pool1"
      tsuru_provisioner = "kubernetes"
    }

    resource "tsuru_pool" "shared" {
      name              = "shared"
      public            = true
      tsuru_provisioner = "kubernetes"
    }

    resource "tsuru_pool" "sandbox" {
      name              = "sandbox"
      default           = true
      tsuru_provisioner = "kubernetes"
    }
    ```

## Updating a pool

```bash
$ tsuru pool update pool1 --public=true
$ tsuru pool update pool1 --default=true -f
```

`--public=true` / `--default=true` set the `team` constraint of the pool to `*`; `--public=false` / `--default=false`
remove `*` from it (other teams in the constraint are kept). `--default=true` fails if another default pool exists
unless `--force` (`-f`) demotes it; without `-f` the client asks for confirmation. Labels are changed with
`--add-labels` / `--remove-labels`, see [Labels and affinity](#labels-and-affinity).

## Associate pool to a kubernetes cluster

When you have more than one kubernetes cluster, it's necessary to associate the pool to its cluster; pools without an
association use the default cluster. See [Managing clusters](managing_clusters.md).

=== "Tsuru client"

    ```bash
    $ tsuru cluster update cluster2 kubernetes --add-pool pool2
    ```

=== "Terraform"

    ```terraform
    resource "tsuru_cluster_pool" "cluster-pool" {
      cluster = "cluster2"
      pool    = "pool2"
    }
    ```

## Pool constraints

Constraints restrict which resources can be used by the apps of a pool. A constraint has a pool expression, a field and
a list of values; both the pool expression and the values accept `*` as a glob (`dev_*` matches every pool starting with
`dev_`).

| Field | Restricts |
|-------|-----------|
| `team` | Teams allowed to create apps in the pool. `*` makes the pool public |
| `router` | Routers an app in the pool may use. The first value, when it is not a glob or denylist, is the pool's default router |
| `service` | Services whose instances can be bound to apps in the pool |
| `plan` | Plans allowed for apps in the pool. The first value, when it is not a glob or denylist, is the pool's default plan |
| `volume-plan` | Volume plans allowed in the pool |
| `cert-issuer` | Certificate issuers allowed for `tsuru certificate-issuer set` in the pool |

`tsuru pool constraint set` replaces the constraint for that pool expression and field; `--append` (`-a`) adds the values
to the existing list instead, and `--denylist` turns the list into a denylist (the API and terraform call it
`blacklist`). Setting a constraint with no values deletes it.

=== "Tsuru client"

    ```bash
    $ tsuru pool constraint set pool1 team team1 team2
    $ tsuru pool constraint set pool1 team team3 --append
    $ tsuru pool constraint set "dev_*" router prod_router --denylist
    $ tsuru pool constraint set prod_pool plan c1m1 c2m4
    $ tsuru pool constraint set prod_pool cert-issuer letsencrypt
    ```

=== "Terraform"

    ```terraform
    resource "tsuru_pool_constraint" "pool1-teams" {
      pool_expr = "pool1"
      field     = "team"
      values    = ["team1", "team2", "team3"]
    }

    resource "tsuru_pool_constraint" "dev-routers" {
      pool_expr = "dev_*"
      field     = "router"
      values    = ["prod_router"]
      blacklist = true
    }
    ```

When several constraints of the same field match a pool, only one applies: the one with the longest pool expression
wins, and among expressions of equal length the one with fewer `*` wins. So an exact pool name beats `dev_*`, which beats
`*`. Constraints of different fields are independent.

```bash
$ tsuru pool constraint list
+-----------------+--------+-------------------+-----------+
| Pool Expression | Field  | Values            | Blacklist |
+-----------------+--------+-------------------+-----------+
| dev_*           | router | prod_router       | true      |
| pool1           | team   | team1,team2,team3 | false     |
+-----------------+--------+-------------------+-----------+
```

## Labels and affinity

Pools carry an optional set of labels (`--labels key=value` on `tsuru pool add`, repeatable; `--add-labels key=value`
and `--remove-labels key` on `tsuru pool update`; `labels` map on the terraform `tsuru_pool` resource). When only
`--add-labels` is given the client sends just those labels, so pass every label you want to keep.

The kubernetes provisioner reads one label, `affinity`: a JSON Kubernetes
[Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) object
applied to every app pod of the pool. The value is validated when the pool is created or updated. When it contains a
`nodeAffinity`, it replaces the default `tsuru.io/pool=<pool>` node selector; otherwise the selector is kept alongside
the affinity.

```bash
$ tsuru pool add pool1 --provisioner kubernetes \
    --labels 'affinity={"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"kubernetes.io/arch","operator":"In","values":["amd64"]}]}]}}}'
```

Both are skipped when the cluster has the `single-pool` custom data; `disable-default-node-selector` skips only the
selector (see [Cluster custom data](managing_clusters.md#cluster-custom-data)).

By default every app runs in the `default` namespace of its cluster (or the cluster `namespace` custom data). With
`kubernetes:use-pool-namespaces: true` in `tsuru.conf`, each pool gets its own namespace, `tsuru-<pool>` (or
`<namespace>-<pool>`), and the `namespace-labels` custom data can label those namespaces.

## Listing pools

```bash
$ tsuru pool list
+-------+---------+-------------+--------------+----------------+
| Pool  | Kind    | Provisioner | Teams        | Routers        |
+-------+---------+-------------+--------------+----------------+
| local | default | kubernetes  |              | ingress-router |
+-------+---------+-------------+--------------+----------------+
| pool1 |         | kubernetes  | team1, team2 | ingress-router |
+-------+---------+-------------+--------------+----------------+
```

Kind is `public`, `default` or empty for team pools; the Teams column is empty for public and default pools. Use
`--team` or `--name` to filter, `--only-name` to print only names and `--json` for the raw objects.

```bash
$ tsuru pool info pool1
Name:         pool1
Provisioner:  kubernetes
Teams:        team1
              team2

Allowed:
+--------+----------------+
| Type   | Value          |
+--------+----------------+
| plan   | c1m1           |
|        | c2m4           |
+--------+----------------+
| router | ingress-router |
+--------+----------------+
| team   | team1          |
|        | team2          |
+--------+----------------+
```

"Allowed" lists, per constraint type, the existing resources that pass the constraints resolved for this pool; a
"Labels" table follows when the pool has labels.

## Removing a pool

If you want to remove a pool, use `tsuru pool remove` or undeclare the `tsuru_pool` resource on terraform:

```bash
$ tsuru pool remove pool1
```

## Changing the team owner of an app

An app can be handed to another team even when the teams cannot see each other's pools:

```bash
$ tsuru app update --app <app> --team-owner <teamB>
```

The pool of an app cannot be changed after creation. To move an app to another pool,
create a new app in the target pool and deploy it there.
