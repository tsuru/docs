# Autoscale

Autoscale lets tsuru add and remove units of an app process automatically, between a minimum and a maximum you choose. The decision can be driven by CPU usage, by a time schedule, by a Prometheus query, or by any combination of them. When more than one trigger is configured, the highest number of units requested by any trigger wins.

Autoscale is configured per process with [`tsuru autoscale set`](../tsuru_client/tsuru_autoscale_set.md) and removed with [`tsuru autoscale unset`](../tsuru_client/tsuru_autoscale_unset.md). The older `tsuru unit autoscale ...` commands are deprecated aliases of the same commands.

## Prerequisites

- The app must have at least one deploy. Without a deployed version the command fails with `no routable version found for app, at least one deploy is required before configuring autoscale`.
- Apps with more than one process must pass `-p/--process`; otherwise tsuru answers `process argument is required`.
- Schedule and Prometheus triggers need [KEDA](https://keda.sh) installed in the cluster of the app's pool. Without its CRDs the command fails with `cannot configure schedule/prometheus autoscale: KEDA is not installed in the cluster`. A CPU-only autoscale works with plain Kubernetes.
- Prometheus triggers also need a reachable Prometheus server, either passed in the trigger or configured by the tsuru admin (see [Prometheus triggers](#prometheus-triggers)).

## Plan, quota and limits

Autoscale works inside the limits that already apply to the app:

- `--max` cannot exceed the app's unit quota. If the app has a limited quota, a larger value is rejected with `maximum units cannot be greater than quota limit`. The default quota comes from [`quota:units-per-app`](../reference/config.md#quotaunits-per-app).
- CPU triggers are relative to the CPU of the app's [plan](../tsuru_client/tsuru_plan.md). The percentage is the target average CPU utilization of each unit compared with the plan's CPU.
- If the plan has no CPU defined, the `--cpu` value is taken as absolute millicores instead (`500m` means 500 millicores, and `50%` is converted to `500m`), and the 20-95% bounds below do not apply.

## CPU trigger

```bash
$ tsuru autoscale set -a my-app -p web --cpu 50% --min 2 --max 10
Unit auto scale successfully set.
```

This keeps the average CPU usage of the `web` units around 50% of the plan's CPU, never going below 2 or above 10 units.

| Flag | Description |
|------|-------------|
| `--cpu` | Target average CPU, as a percentage of the plan CPU (`50%`) or in millicores (`500m`). With a plan CPU, the value must be between `20%` and `95%`. |
| `--min` | Minimum units. Must be greater than 0. Default: `1`. |
| `--max` | Maximum units. Must be greater than `--min`. |

## Schedule triggers

A schedule raises the minimum number of units during a time window. Pass a JSON object to `--schedule`; repeat the flag for more than one window.

```bash
$ tsuru autoscale set -a my-app -p web --min 1 --max 5 \
    --schedule '{"name": "business-hours", "minReplicas": 3, "start": "0 8 * * 1-5", "end": "0 20 * * 1-5", "timezone": "America/Sao_Paulo"}'
Unit auto scale successfully set.
```

| Field | Description | Required |
|-------|-------------|----------|
| `start` | Cron expression (five fields) for the beginning of the window. | Yes |
| `end` | Cron expression for the end of the window. | Yes |
| `minReplicas` | Number of units to keep while the window is active. | Yes |
| `name` | Identifier for the window. Only lower case letters, numbers and dashes, starting with a letter. | No |
| `timezone` | IANA timezone name. Default: `UTC`. | No |

A schedule is implemented as a KEDA `cron` trigger. Outside the window the schedule asks for nothing and the other triggers (or `--min`) decide. Inside the window, `minReplicas` competes with the other triggers and the highest value wins, so a CPU trigger can still scale above it.

!!! note
    A schedule-only autoscale is valid: the units stay at `--min` outside the window and at `minReplicas` inside it.

## Prometheus triggers

A Prometheus trigger scales on the result of a PromQL query. Pass a JSON object to `--prometheus`; repeat the flag for more than one metric.

```bash
$ tsuru autoscale set -a my-app -p web --min 1 --max 20 \
    --prometheus '{"name": "requests-per-unit", "query": "sum(rate(http_requests_total{tsuru_app=\"my-app\"}[2m]))", "threshold": 100, "activationThreshold": 10, "prometheusAddress": "http://prometheus.monitoring:9090"}'
Unit auto scale successfully set.
```

| Field | Description | Required |
|-------|-------------|----------|
| `name` | Identifier for the trigger. Only lower case letters, numbers and dashes, starting with a letter. | Yes |
| `query` | PromQL query returning a single value. | Yes |
| `threshold` | Target value per unit. The desired number of units is the query result divided by this value. Must be greater than 0. | Yes |
| `activationThreshold` | Forwarded to KEDA's `activationThreshold`. Must not be negative. Default: `0`. | No |
| `prometheusAddress` | URL of the Prometheus server. When omitted, tsuru uses the address configured by the admin (below). | No |

In the example, with 1000 requests per second the autoscaler aims for 10 units.

!!! note "Default Prometheus address"
    The tsuru admin can set the config key `kubernetes:keda:prometheus-address-template` to a Go template rendered with the app's Kubernetes namespace as `{{.namespace}}`, for example `http://prometheus.{{.namespace}}.svc:9090`. Triggers without `prometheusAddress` use the rendered value. If the key is not set, a trigger without `prometheusAddress` is rejected. See the [configuration reference](../reference/config.md).

When `prometheusAddress` starts with `https://monitoring.googleapis.com`, tsuru attaches the KEDA `ClusterTriggerAuthentication` named `gcp-credentials` to the trigger; the admin must create it in the cluster.

## Combining triggers

All triggers can go in the same command. Running `tsuru autoscale set` again for the same process replaces the previous configuration entirely, so always pass the full set of triggers you want.

```bash
$ tsuru autoscale set -a my-app -p web --min 1 --max 10 --cpu 60% \
    --schedule '{"minReplicas": 4, "start": "0 6 * * *", "end": "0 18 * * *"}' \
    --prometheus '{"name": "queue-depth", "query": "sum(queue_messages{app=\"my-app\"})", "threshold": 50}'
```

## Scale-down behaviour

Scaling up follows the Kubernetes defaults. Scaling down is deliberately slow to avoid disrupting the app, and three flags tune it:

| Flag (shorthand) | Description | Default |
|------------------|-------------|---------|
| `--scale-down-percentage` (`--sdp`) | Maximum percentage of the current units removed per minute. | `10` |
| `--scale-down-units` (`--sdu`) | Maximum number of units removed per minute. | `3` |
| `--scale-down-stabilization-window` (`--sdsw`) | Seconds the metric must stay low before the first scale-down. | `300` |

The percentage and units policies are combined with the Kubernetes `Min` select policy: in each minute the autoscaler removes at most the smaller of the two. With the defaults, an app at 50 units loses at most 3 units per minute (3 is less than 10% of 50). Negative values are rejected.

```bash
$ tsuru autoscale set -a my-app -p web --cpu 50% --min 2 --max 30 --sdp 20 --sdu 5 --sdsw 600
```

## Validation rules

`tsuru autoscale set` is rejected when:

- `--min` is 0, or `--max` is not greater than `--min`;
- `--max` exceeds the app's unit quota;
- no trigger is given (`you have to configure at least one trigger between cpu, schedule and prometheus`);
- `--cpu` is outside 20-95% for an app whose plan has CPU, or is not a number;
- a schedule `start` or `end` is not a valid cron expression, or its `name` is invalid;
- a Prometheus trigger has an invalid or empty `name`, a `threshold` of 0 or less, or a negative `activationThreshold`;
- any scale-down value is negative.

## Interactions with other commands

**Manual scaling is blocked.** While a process has autoscale configured, `tsuru unit add` and `tsuru unit remove` for that process fail with `cannot add units to an app with autoscaler configured, please update autoscale settings`. Change `--min`/`--max` instead, or unset the autoscale first.

**App stop.** When a process is stopped (`tsuru app stop`), the KEDA scaled object is annotated with `autoscaling.keda.sh/paused-replicas: 0`, so KEDA does not scale it back up. The annotation is dropped on the next start or deploy. Plain CPU autoscales rely on the Kubernetes behaviour of not acting on a deployment with zero replicas.

**Deploys.** Each deploy re-applies the autoscale to the new deployment of the process, so the configuration survives deploys and restarts.

**Multiple versions.** An autoscale targets one deployment, chosen as the lowest routable version of the process when it is created. When you deploy a new version with `--new-version`, the autoscale keeps following the version it was attached to. To move it:

```bash
$ tsuru autoscale swap -a my-app --version 3
Unit auto scale successfully swapped.
```

The version must be currently deployed, and the app must already have an autoscale, otherwise the command fails. Removing a version (`tsuru app version remove`) also removes an autoscale attached to it.

## Inspecting the configuration

Autoscale settings show up in `tsuru app info`, one block per process:

```bash
$ tsuru app info -a my-app
...
Autoscale [process web] [version 2] [min units 1] [max units 5]:
+----------------------+-------------------------------------------------------+
| Triggers             | Trigger details                                       |
+----------------------+-------------------------------------------------------+
| CPU                  | Target: 50%                                           |
+----------------------+-------------------------------------------------------+
| Schedule             | Start: At 08:00 AM, Monday through Friday (0 8 * * 1-5) |
|                      | End: At 08:00 PM, Monday through Friday (0 20 * * 1-5)  |
|                      | Units: 3                                              |
|                      | Timezone: America/Sao_Paulo                           |
+----------------------+-------------------------------------------------------+
| Scale down behavior  | Units: 3                                              |
|                      | Percentage: 10%                                       |
|                      | Stabilization window: 300s                            |
+----------------------+-------------------------------------------------------+
```

The same data is available from the API at `GET /apps/{app}/units/autoscale`.

## Removing the autoscale

```bash
$ tsuru autoscale unset -a my-app -p web
```

The units stay at their current count; from then on you manage them with `tsuru unit add` and `tsuru unit remove`. Removing the app removes all of its autoscales.

## Version history

- Schedule triggers: since tsuru 1.19.1.
- Prometheus triggers and `kubernetes:keda:prometheus-address-template`: since tsuru 1.20.3.
- Scale-down behaviour flags: since tsuru 1.24.2.
- `tsuru autoscale swap`: since tsuru 1.29.1.
- KEDA is optional (CPU-only autoscale works without it): since tsuru 1.32.0.
