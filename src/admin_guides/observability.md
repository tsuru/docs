# Observability

This page describes what the tsuru API server (`tsurud`) emits about itself and about the applications it manages: its own logs, distributed traces, Prometheus metrics, application logs, the event audit trail, and the Kubernetes-side timeouts that most often explain a slow or failed deploy. Configuration keys link to the [tsuru.conf reference](../reference/config.md); keys not documented there yet are explained inline. For the endpoints themselves (`/healthcheck`, `/metrics`, `/debug/*`) see [Operating the API server](operating_tsurud.md).

## API logs

tsurud writes two different kinds of log lines.

**Internal log** (errors, warnings and, with [`debug: true`](../reference/config.md#debug), debug messages). Its destinations are additive:

| Key | Default | Effect |
|-----|---------|--------|
| [`log:disable-syslog`](../reference/config.md#log-disable-syslog) | `false` | Syslog is **on** by default. In a container without a syslog socket, tsurud fails at startup with `unable to initialize logging`; set this to `true` (the Helm chart does). |
| [`log:syslog-tag`](../reference/config.md#log-syslog-tag) | `tsurud` | Tag used for syslog messages. |
| [`log:file`](../reference/config.md#log-file) | unset | Also append to this file. |
| [`log:use-stderr`](../reference/config.md#log-use-stderr) | `false` | Also write to stderr. This is the usual choice on Kubernetes. |
| [`debug`](../reference/config.md#debug) | `false` | Emit debug-level messages (startup steps, auth scheme, routers loaded, ...). |

Every failed request is logged as `failure running HTTP request <METHOD> <path> (<status>): <error>`. Errors that carry a stack trace are followed by a `stack for error:` line. Clients can ask for the same detail in the response by sending the header `X-Tsuru-Verbosity: 1`.

**Access log**, one line per request, always written to **stdout** regardless of the keys above. `/healthcheck` and `/metrics` are not logged. The default format is plain text:

```
2026-11-20T10:15:42.123456789Z https POST /apps/myapp/deploy 200 "tsuru-client/1.34.0" in 8123.456000ms [Request-ID: 7f3c...]
```

With `log:format: json` each line is a JSON object, which is easier to ship to Loki, Elasticsearch or similar:

```json
{"time":"2026-11-20T10:15:42.123456789Z",
 "request":{"scheme":"https","method":"POST","path":"/apps/myapp/deploy","userAgent":"tsuru-client/1.34.0","requestID":"7f3c...","sourceIP":"10.0.3.17"},
 "response":{"statusCode":200,"durationMS":"8123.456000"},
 "auth":{"username":"alice@example.com","engine":"oidc"}}
```

`request.requestID` is only present when `request-id-header` is configured (see [Request IDs](operating_tsurud.md#request-ids-and-cors)). `request.sourceIP` (JSON format only, since tsuru 1.18) is the TCP peer address, not `X-Forwarded-For`, so behind a load balancer it shows the balancer's address. `auth` is present when the request carried a valid token; `engine` tells which scheme validated it (`native`, `oidc`, `oauth`, `team`, `apikey`, `peer`).

## Tracing with OpenTelemetry

Since tsuru 1.29 tsurud exports traces with the OpenTelemetry SDK over OTLP/gRPC (before that it used the Jaeger client). The exporter is configured with environment variables only; there are no `tsuru.conf` keys.

| Variable | Default | Meaning |
|----------|---------|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `localhost:4317` | `host:port` of the OTLP gRPC collector. The connection is **insecure** (plaintext), so point it at a collector sidecar or an in-cluster collector. |
| `OTEL_TRACES_SAMPLER_ARG` | `0.001` | Fraction of traces to sample (`1` samples everything). |
| `JAEGER_ENDPOINT` | | Legacy fallback for the endpoint, used only when `OTEL_EXPORTER_OTLP_ENDPOINT` is empty. It must now be an OTLP gRPC address. |
| `JAEGER_SAMPLER_PARAM` | | Legacy fallback for the sampling fraction; `OTEL_TRACES_SAMPLER_ARG` wins when both are set. |

Other Jaeger variables such as `JAEGER_AGENT_HOST` and `JAEGER_SAMPLER_TYPE` are no longer read. The Helm chart's `tracing.*` values still set those, so with tsuru 1.29 or later pass `OTEL_EXPORTER_OTLP_ENDPOINT` through the pod environment instead.

Sampling is not purely probabilistic: every **write** request (`POST`, `PUT`, `DELETE`) is always sampled, except `POST /node/status`, so deploys and other mutations are always traceable; `GET` requests follow the ratio. Spans are reported with service name `tsurud`, named `<METHOD> <route template>` (for example `POST /apps/{appname}/deploy`), tagged with the authenticated `user.name`, and marked as errors on HTTP 5xx. Incoming trace context is accepted and outgoing context propagated in both W3C `traceparent`/`baggage` and B3 (single `b3` header and `X-B3-*` headers), so a trace started at your ingress continues into tsurud and on to the Kubernetes API, routers and service brokers it calls.

## Prometheus metrics

`GET /metrics` serves the Prometheus text format and requires no authentication; restrict it at the network level and scrape it from inside the cluster (the Helm chart can create a `ServiceMonitor` with `serviceMonitor.enabled`). Besides the standard Go runtime and process metrics, tsuru 1.34 exposes the following families.

**HTTP and authentication**

| Metric | Labels | Meaning |
|--------|--------|---------|
| `tsuru_http_requests_total` | `status` (`1xx`..`5xx`), `method`, `path` (route template) | Requests served. Pre-populated with zero for every route so rates work from the first scrape. |
| `tsuru_http_request_duration_seconds` | `method`, `path` | Latency histogram (buckets from 1 ms to 30 s). |
| `tsuru_api_token_valid_total` | `engine` | Tokens accepted, by the scheme that validated them (since tsuru 1.17.1). |
| `tsuru_api_token_invalid_total` | | Tokens rejected by every scheme. A rising rate usually means an expired token in a CI job or a scanner. |
| `tsuru_oauth_request_duration_seconds`, `tsuru_oauth_request_errors_total` | | Calls to the OAuth provider, when `auth:scheme` is `oauth`. |

**Deploys, builds and jobs**

| Metric | Labels | Meaning |
|--------|--------|---------|
| `tsuru_app_deploys_total`, `tsuru_app_deploy_duration_seconds` | `app`, `status`, `kind`, `platform` | App deploys and their duration, by outcome and deploy kind. |
| `tsuru_app_builds_total`, `tsuru_app_build_duration_seconds` | `app`, `status`, `kind`, `platform` | `tsuru app build` runs. |
| `tsuru_job_started_total`, `tsuru_job_completed_total` | `job_name` | Job executions started and completed, taken from Kubernetes Job events. |
| `tsuru_job_failed_total` | `job_name`, `reason` | Executions that hit `BackoffLimitExceeded`. |

**Events and webhooks**

| Metric | Labels | Meaning |
|--------|--------|---------|
| `tsuru_events_current` | `kind` | Events running right now, e.g. `app.deploy`. |
| `tsuru_events_duration_seconds` | `kind` | Event duration histogram. |
| `tsuru_events_rejected_total` | `kind`, `reason` | Events refused by locks, throttling or blocks. |
| `tsuru_webhooks_calls_total`, `tsuru_webhooks_calls_error`, `tsuru_webhooks_latency_seconds` | | Webhook deliveries. |
| `tsuru_webhooks_event_queue_current` | | Events waiting for webhook processing. |

**Application logs** (see [below](#application-logs))

| Metric | Labels | Meaning |
|--------|--------|---------|
| `tsuru_logs_memory_received_total`, `tsuru_logs_memory_evicted_total` | `app` | Entries added to, and dropped from, the in-memory buffer. Evictions mean the buffer is too small for that app. |
| `tsuru_logs_memory_size`, `tsuru_logs_memory_length` | `app` | Current buffer size in bytes and in entries. |
| `tsuru_logs_memory_watch_dropped_total` | `app` | Messages dropped because a `tsuru app log -f` client was too slow. |
| `tsuru_logs_app_tail_current`, `tsuru_logs_app_tail_entries_total` | `app` | Active follow streams and entries sent to them. |

**Integrations and housekeeping**

| Metric | Labels | Meaning |
|--------|--------|---------|
| `tsuru_router_request_duration_seconds`, `tsuru_router_request_errors_total` | `router` | Calls to router APIs. |
| `tsuru_service_request_duration_seconds`, `tsuru_service_request_errors_total` | `service` | Calls to service brokers (bind, unbind, create instance, ...). |
| `tsuru_cluster_info` | `provisioner`, `name` | One series per registered cluster, value `1`. |
| `tsuru_cluster_pool` | `name`, `pool` | Pool-to-cluster mapping. |
| `tsuru_cluster_fetch_fail` | | `1` when the cluster list could not be read from MongoDB during the scrape. |
| `tsuru_gc_executions_total` (`phase`), `tsuru_gc_execution_duration_seconds`, `tsuru_gc_versions_marked_to_removal_total`, `tsuru_gc_registry_prune_*`, `tsuru_gc_storage_prune_*` | | Old-image garbage collector activity and failures. |
| `tsuru_node_status_not_found` | | Legacy node-status reports for unknown nodes. |

A useful first alert is `rate(tsuru_http_requests_total{status="5xx"}[5m])` per `path`, together with `tsuru_events_current{kind="app.deploy"}` staying high for longer than your deployment timeout.

## Application logs

`tsuru app log` reads from two places and merges them by timestamp:

1. **Kubernetes pod logs.** For every request tsurud asks the kubelet for the last *N* lines of each unit's container (`kubectl logs`-style), filtered by `--unit` and `--source` (process name). This is where the application's own stdout and stderr come from. Retention is whatever your cluster keeps: logs disappear with the pod, and the kubelet rotates large files. tsuru does not store them.
2. **The in-memory buffer.** Messages pushed to the API through `POST /apps/{app}/log` and the `/logs` websocket go to a per-app ring buffer inside each tsurud process, capped at `log:app-log-memory-buffer-bytes` bytes (default 1 MiB, oldest entries evicted first). It is lost whenever tsurud restarts. Job logs (`tsuru job log`) never use it; they come only from pod logs.

`log:app-log-service` chooses how the buffer behaves across replicas:

| Value | Behaviour |
|-------|-----------|
| `memory-standalone` (default) | Each replica serves only its own buffer, so with several replicas behind a load balancer two consecutive `tsuru app log` calls can return different buffered entries. |
| `memory` | The replica that receives the request fans out to every live replica (discovered through the [instance tracker](operating_tsurud.md#instance-tracker)), calls `GET /apps/{app}/log-instance` on each one authenticated with `auth:peer:token`, and merges the results. Use this whenever you run more than one replica. |

The request behind the client is `GET /apps/{app}/log?lines=N` with optional `source`, `unit`, `invert-source` and `follow=1`. In follow mode (`tsuru app log -f`) tsurud flushes the response at most every 500 ms and counts slow consumers in `tsuru_logs_memory_watch_dropped_total`. For durable application logs, ship pod logs from the cluster with your usual agent (Fluent Bit, Vector, Promtail); tsuru's buffer is a convenience for the last few minutes, not a log store.

## Auditing with events

Every mutation in tsuru (deploys, env changes, unit scaling, role assignments, cluster edits, ...) is recorded as an **event** with the user or token that triggered it, its source IP, the tsurud instance that ran it, start and end time, the parameters and the full output. Events are stored in MongoDB and queried with `tsuru event list` / `tsuru event info`; they can be exported as they happen through webhooks and blocked by rule. They are the audit trail of the platform. See [Events, blocks and webhooks](events.md).

## Kubernetes-side signals

Most "my deploy hangs" reports end in one of these provisioner timeouts, all in seconds under `kubernetes:` in `tsuru.conf`. When one fires, the deploy event fails with the timeout in its error, and the Kubernetes events of the pod (`kubectl -n <pool namespace> describe pod`) tell you why.

| Key | Default | What it bounds |
|-----|---------|----------------|
| `kubernetes:deployment-progress-timeout` | `600` | Time for the new Deployment rollout to complete. Exceeding it rolls the app back to the previous version. The usual causes are an image that crashes on start or insufficient cluster capacity. |
| `kubernetes:pod-running-timeout` | `600` | Time for a pod to reach `Running`, including the image pull. Slow registries and large images show up here. |
| `kubernetes:pod-ready-timeout` | `60` | Time for a running pod to pass its readiness probe (the `healthcheck` section of `tsuru.yaml`). |
| `kubernetes:attach-after-finish-timeout` | `60` | Time tsurud keeps an attach (`tsuru app run`, build pods) open after the container exits, waiting for the stream to drain. |
| `kubernetes:api-timeout` | `60` | Client-side timeout for each call to the Kubernetes API server. |

On the cluster itself, watch the pool namespaces for `ImagePullBackOff`, `CrashLoopBackOff` and `OOMKilled` pods, and the `tsuru.io/app-name` / `tsuru.io/app-process` labels let you group metrics from kube-state-metrics or your node agent per tsuru app and process.
