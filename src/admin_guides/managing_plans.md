# Managing plans

## Overview

A plan describes how much CPU and memory each unit of an app gets. Every app has a plan, chosen at
`tsuru app create --plan` or, when omitted, the default plan of its pool. On Kubernetes the plan
becomes the resource requests and limits of the app containers.

A plan has these fields (`POST /plans` JSON names):

| Field | Description |
|-------|-------------|
| `name` | Plan name, unique. |
| `cpumilli` | CPU in millicores: `1000` is one vCPU/core, `100` is 10% of a core. `0` means no CPU request or limit. |
| `memory` | Memory in bytes. `0` means no memory request or limit. Any non-zero value below 4 MiB (4194304) is rejected with `The minimum allowed memory is 4MB`. |
| `default` | Marks the plan as the default one. Creating a plan with `default: true` removes the flag from every other plan, so there is at most one default plan. |
| `cpuBurst` | Object `{"default": <factor>, "maxAllowed": <factor>}`, see [CPU burst](#cpu-burst). |
| `runtimeClassName` | Kubernetes [RuntimeClass](https://kubernetes.io/docs/concepts/containers/runtime-class/) set on the pods of apps using the plan (for example `gvisor`). Empty means the cluster's default runtime. Since tsuru 1.30. |

When tsuru starts with no plan at all it seeds a set of plans named after their size (`c0.1m0.2`,
`c1m2`, `c4m8`, ...), with `c0.1m0.2` (100 millicores, 256 MiB) as default. You can remove them and
create your own.

## Creating a plan

=== "Tsuru client"

    ```bash
    $ tsuru plan create c1m2 -c 1 -m 2G
    $ tsuru plan create small -c 100m -m 256M --default
    ```

=== "Terraform"

    ```terraform
    resource "tsuru_plan" "c1m2" {
      name   = "c1m2"
      cpu    = "1" // or "100m" or "200%"
      memory = "2Gi"

      cpu_burst {
        default     = 1.1 # 10% of burst
        max_allowed = 2
      }
    }
    ```

[`tsuru plan create`](../tsuru_client/tsuru_plan_create.md) accepts CPU (`-c/--cpu`) as a number of
cores (`1`, `2`), as a percentage of a core (`50%` = 500 millicores) or as a Kubernetes quantity
(`100m`, `0.5`). Memory (`-m/--memory`) is bytes or a Kubernetes quantity: `K`, `M`, `G` are
decimal (`2G` is 2·10⁹ bytes), `Ki`, `Mi`, `Gi` are binary (`2Gi` is 2147483648 bytes).

The CLI can only set name, CPU, memory and `--default`. `cpuBurst` and `runtimeClassName` are
only settable through the API (or terraform, for `cpu_burst`) by sending JSON to `POST /plans`:

```bash
$ curl -X POST "$TSURU_TARGET/plans" \
    -H "Authorization: bearer $TSURU_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "c1m2-burst",
      "cpumilli": 1000,
      "memory": 2147483648,
      "cpuBurst": {"default": 1.2, "maxAllowed": 2},
      "runtimeClassName": "gvisor"
    }'
```

With the JSON content type the body is decoded straight into the plan, so `memory` must be an
integer number of bytes. Creating a plan requires the `plan.create` permission; the name is required
and an existing name is answered with `409 plan already exists`.

## Listing plans

```bash
$ tsuru plan list
+------------+------+--------+---------------------+---------+
| Name       | CPU  | Memory | CPU Burst (default) | Default |
+------------+------+--------+---------------------+---------+
| c0.1m0.2   | 10%  | 256Mi  |                     | true    |
| c1m2       | 100% | 2Gi    | up to 100%          | false   |
| c1m2-burst | 100% | 2Gi    | up to 120%          | false   |
+------------+------+--------+---------------------+---------+
```

CPU is printed as a percentage of one core. The `CPU Burst` column only appears when at least one
plan defines a burst. [`tsuru plan list`](../tsuru_client/tsuru_plan_list.md) flags:

- `-b/--bytes`: memory in bytes instead of `Mi`/`Gi`.
- `--kubernetes-friendly`: CPU requests and limits as Kubernetes quantities (`1`, `1200m`) instead
  of percentages, plus `Memory requests/limits`.
- `--show-max-cpu-burst-allowed`: adds the `CPU Burst (max customizable)` column, the ceiling users
  may pick with `tsuru app update --cpu-burst-factor`.

## Removing a plan

```bash
$ tsuru plan remove c1m2-burst
```

The plan is copied into the app document when the app is created or updated, so removing a plan does
not touch existing apps: they keep the CPU and memory of the removed plan until someone changes their
plan. The name just stops being accepted for new apps, `tsuru app update --plan` and
`tsuru app process update --plan`. Nothing stops you from removing the default plan; after that,
creating an app without `--plan` fails with `default plan not found` until another plan is marked
default. Removing requires `plan.delete`.

## Restricting plans per pool

The `plan` [pool constraint](managing_pools.md#pool-constraints) lists the plans the apps of a pool
may use. Creating an app with a plan outside the list fails with
`App plan "<plan>" is not allowed on pool "<pool>"`.

```bash
$ tsuru pool constraint set prod plan c1m2 c2m4 c4m8
```

The constraint also decides the default plan of the pool: with an allowlist without globs, the first
plan listed is the pool's default; with a glob or denylist, the first allowed plan (in name order) is
used; without a constraint the global default plan applies.

## CPU burst

On Kubernetes, `cpumilli` is the CPU **request** of each unit (divided by the cluster's
`overcommit-factor`/`cpu-overcommit-factor`, when set). The CPU **limit** is the request multiplied by
a burst factor, so `cpuBurst.default: 1.2` on a 1000 millicore plan gives `requests.cpu: 1` and
`limits.cpu: 1200m`. A factor of 1 (or none) means request and limit are equal. Memory has no burst:
request and limit are both the plan memory (the request is divided by `memory-overcommit-factor`
when set).

The factor used for a unit is resolved in this order:

1. The app override set with `tsuru app update --cpu-burst-factor` (bounded by `cpuBurst.maxAllowed`
   of the plan; exceeding it fails with `CPU burst exceeds the maximum allowed by plan`).
2. The plan's `cpuBurst.default`, when greater than 1.
3. The cluster custom data `cpu-burst-factor` (optionally prefixed with `<pool>:`), see
   [Managing clusters](managing_clusters.md). Values below 1 are ignored.

!!! note
    `maxAllowed` only limits the per-app override. A `cpuBurst.default` or cluster
    `cpu-burst-factor` above it is applied as is.

## Per-app overrides

Users with `app.update.planoverride` can change the resources of a single app without creating a
plan. The override is kept when the app changes plan; passing `0` removes it:

```bash
$ tsuru app update -a myapp --cpu 500m --memory 1Gi --cpu-burst-factor 1.5
$ tsuru app update -a myapp --cpu 0 --memory 0   # back to the plan values
```

`--cpu` accepts Kubernetes quantities (`0.5` equals `500m`), `--memory` accepts bytes or the suffixes
`E, P, T, G, M, K, Ei, Pi, Ti, Gi, Mi, Ki`, and `--cpu-burst-factor` must be `>= 1` (the CLI rejects
smaller values, so the burst override is removed by sending `planoverride.cpuBurst: 0` to
`PUT /apps/{app}` directly). `tsuru app info` shows overridden values as `(override)`. The update
restarts the app unless `--no-restart` is given.

## Plan per process

By default every process of an app uses the app plan. A process can use another plan with
[`tsuru app process update`](../tsuru_client/tsuru_app_process_update.md):

```bash
$ tsuru app process update myapp worker --plan c2m4
$ tsuru app process update myapp worker --default-plan   # back to the app plan
```

The plan must exist (`could not find plan "<name>"` otherwise) and, unlike the app plan, it is read
from the plan collection at every deploy, so removing a plan used by a process makes the next deploy
of that process fail. Per-process plans do not receive the app's `--cpu`/`--memory` overrides; those
apply to the app plan only.
