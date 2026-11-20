# Metadata, labels and annotations

Metadata lets you attach Kubernetes labels and annotations to the objects tsuru creates for an app or a job, without touching the cluster directly. It is also where per-process settings live: each process of an app can carry its own labels, annotations and plan.

## Setting metadata

```bash
$ tsuru metadata set team=payments cost-center=42 -a myapp -t label
$ tsuru metadata set prometheus.io/scrape=true -a myapp -t annotation
```

| Flag | Description |
|------|-------------|
| `-a, --app` / `-j, --job` | The app or job to change. One of the two is required. |
| `-t, --type` | `label` or `annotation`. Required; there is no default. |
| `-p, --process` | Apply to one process of the app instead of the whole app. Ignored for jobs. |
| `--no-restart` | Save without restarting the app. |

Setting metadata is an app update: tsuru merges the new items into the existing ones (same name replaces the value) and, unless `--no-restart` is given, restarts the app so the new labels and annotations reach the running units. See [tsuru metadata set](../tsuru_client/tsuru_metadata_set.md).

!!! note "`tsuru app metadata` is deprecated"
    `tsuru app metadata set/get/unset` still work but are deprecated in favour of `tsuru metadata set/get/unset`, which take the same flags and also accept `-j`.

## Getting metadata

```bash
$ tsuru metadata get -a myapp
Labels:
	cost-center: 42
	team: payments
Annotations:
	prometheus.io/scrape: true

Metadata for process: "worker"
Labels:
	queue: high
```

`--json` prints the app-level metadata as JSON. See [tsuru metadata get](../tsuru_client/tsuru_metadata_get.md).

## Unsetting metadata

```bash
$ tsuru metadata unset cost-center -a myapp -t label
$ tsuru metadata unset queue -a myapp -p worker -t label
```

See [tsuru metadata unset](../tsuru_client/tsuru_metadata_unset.md).

## Per-process metadata

Pass `-p <process>` to scope labels or annotations to a single process:

```bash
$ tsuru metadata set queue=high -a myapp -p worker -t label
```

When tsuru builds the Kubernetes objects for a process it starts from the app-level metadata and overlays the process-level items, so a process entry with the same name wins over the app-level one for that process only.

## Validation

tsuru checks app-level metadata before saving it:

- Names starting with `tsuru.io/` are rejected with `prefix tsuru.io/ is private`; tsuru uses that prefix for its own labels.
- Label and annotation names must be valid Kubernetes qualified names (an optional DNS-subdomain prefix, a `/`, then up to 63 characters of letters, digits, `-`, `_` or `.`, starting and ending with an alphanumeric). Annotation names are compared in lower case.
- Label values must be valid Kubernetes label values (up to 63 characters, same character set, may be empty). Annotation values are free text.
- The sum of all annotation names and values must stay under 256 kB, the same cap Kubernetes applies.

Invalid metadata returns HTTP 400 with the Kubernetes validation message.

## Where labels and annotations land

| Object | Labels | Annotations |
|--------|--------|-------------|
| App Deployment (one per process and version) | yes | yes |
| App pod template, so every unit | yes | yes |
| Job CronJob and job pod template | yes (tsuru's own labels cannot be overwritten) | yes |
| App Service | no | only through `app.tsuru.io/k8s-service` (below) |
| App or job ServiceAccount | no | only through `*.tsuru.io/service-account-annotations` (below) |

Two annotations are interpreted by tsuru itself rather than copied as-is. Their value must be a JSON object of string keys and values:

```bash
$ tsuru metadata set -a myapp -t annotation \
    'app.tsuru.io/k8s-service={"cloud.google.com/neg": "{\"ingress\": true}"}'
$ tsuru metadata set -a myapp -t annotation \
    'app.tsuru.io/service-account-annotations={"iam.gke.io/gcp-service-account": "sa@project.iam.gserviceaccount.com"}'
```

`app.tsuru.io/k8s-service` adds the annotations to the Kubernetes Services tsuru creates for the app (per process). `app.tsuru.io/service-account-annotations` adds them to the app's ServiceAccount; for jobs use `job.tsuru.io/service-account-annotations`. These prefixes are `app.tsuru.io/` and `job.tsuru.io/`, not the reserved `tsuru.io/`.

## Metadata on jobs

Jobs accept the same labels and annotations with `-j`:

```bash
$ tsuru metadata set owner=data-eng -j nightly-report -t label
$ tsuru metadata get -j nightly-report
```

They are applied to the CronJob and to the pods it starts. `-p` has no meaning for jobs and is ignored.

## Plan per process

Since tsuru 1.19.1, each process may use a plan different from the app plan. Only the plan name is stored per process; CPU and memory come from that plan.

```bash
$ tsuru app process update myapp worker --plan c2m4
$ tsuru app process update myapp worker --default-plan
```

| Flag | Description |
|------|-------------|
| `-p, --plan` | The plan the process should use. It must exist (`tsuru plan list`). |
| `--default-plan` | Drop the per-process plan and fall back to the app plan. |
| `--no-restart` | Save without restarting the app. |

The change restarts the app unless `--no-restart` is given. See [tsuru app process update](../tsuru_client/tsuru_app_process_update.md).

`tsuru app info` shows a `Process plans:` table whenever at least one process has its own plan; otherwise it shows the single app `Plan:`:

```
Process plans:
+-----------+--------+
| Process   | Plan   |
+-----------+--------+
| (default) | c1m2   |
| worker    | c2m4   |
+-----------+--------+
```

The `(default)` row is the app plan, with an extra `Overrides` column when `tsuru app update --cpu/--memory` overrides are set.

## The `processes` field in the API

Both `tsuru metadata set -p` and `tsuru app process update` are `PUT /apps/{app}` calls with a `processes` list. `POST /apps` (app create) accepts the same field, so you can create an app with per-process metadata and plans in one request:

```bash
$ curl -X PUT -H "Authorization: bearer $TOKEN" -H "Content-Type: application/json" \
    $TSURU_TARGET/1.0/apps/myapp -d '{
  "processes": [
    {"name": "worker", "plan": "c2m4",
     "metadata": {"labels": [{"name": "queue", "value": "high"}]}}
  ]
}'
```

Each entry is merged by `name`: a non-empty `plan` replaces the stored one (`"$default"` clears it), and `metadata` items are merged like app-level metadata (`"delete": true` on an item removes it). Entries left with no plan and no metadata are pruned. Updating `processes` requires the `app.update.processes` permission.

## Related

- [tsuru metadata](../tsuru_client/tsuru_metadata.md) command reference
- [tsuru.yaml](tsuru_yaml.md) for process commands and health checks
- [Environment variables](environment_variables.md)
