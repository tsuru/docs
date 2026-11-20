# Service API workflow

A tsuru *service* is an HTTP API that you, the service provider, run. tsuru calls it when
users create, bind, inspect and remove service instances. This page describes every request
tsuru makes, in the order a service sees them, and what tsuru does with each answer.

The rendered OpenAPI contract is in the [Service API reference](../reference/service_api.md).
The user side (CLI commands, flags, what users see) is in
[Using services](../user_guides/service_instances.md). For a walkthrough with code, see
[Building your service](build.md).

## Every request

**Authentication.** tsuru uses HTTP basic authentication on every request. The username is
the `username` from the service manifest, or the service `id` when `username` is empty; the
password is the manifest `password`.

**Endpoint.** tsuru calls `endpoint.production` from the manifest. If the endpoint has no
scheme, `http://` is assumed. For instances of a [multi-cluster](multi_cluster.md) service,
tsuru first looks for an endpoint named after the cluster the instance pool maps to and falls
back to `production`.

**Headers.** `Accept: application/json` is always sent. The other headers depend on context:

| Header | When |
|--------|------|
| `X-Tsuru-User` | Requests tied to a tsuru event (create, update, remove, bind, unbind, non-`GET` proxy). Email of the user who triggered the event. |
| `X-Tsuru-Eventid` | Same requests. Hex id of the tsuru event, useful to correlate your logs with `tsuru event info`. |
| request-id header | Only when the tsuru API is configured with `request-id-header` **and** the user request carried that header. The header name is whatever the config says (`X-Request-Id` in the spec example). |
| `X-Tsuru-Pool-Name`, `X-Tsuru-Pool-Provisioner` | Requests about an instance that has a pool (multi-cluster services), and `GET /resources/plans` when the user passes `--pool`. |
| `X-Tsuru-Cluster-Name`, `X-Tsuru-Cluster-Provisioner`, `X-Tsuru-Cluster-Addresses` | Same as above, when the pool maps to a cluster. `X-Tsuru-Cluster-Addresses` is repeated once per address. |
| `X-Tsuru-Cluster-Kube-Config` | Same as above, only when the cluster has custom data `propagate-kubeconfig=true`. Base64 of the JSON-encoded kubeconfig. |

Plans, status and info requests are not tied to an event, so they carry no `X-Tsuru-User`
or `X-Tsuru-Eventid`. The same is true for `GET` requests through the proxies.

**Connection.** Each request uses a fresh connection (`Connection: close`) with a 15 second
dial timeout and a 5 minute overall timeout. Long operations should return quickly and
report progress through `GET /resources/<name>/status`.

**Errors.** Any status code that tsuru does not list below is a failure. tsuru reads the body
and shows the user `invalid response: <body> (code: <status>)`, so put a human readable
message in the body.

## Encoding

By default tsuru sends request bodies as `application/x-www-form-urlencoded`. Lists are
repeated keys (`tags=a&tags=b`) and instance or bind parameters are flattened as
`parameters.<key>=<value>` (nested keys are joined with dots).

A service registered with `encoding: json` (a field of the `POST /services` API, see
[Building your service](build.md#encoding); since tsuru 1.30) receives
`application/json` bodies instead: one object with camelCase keys, lists as JSON arrays and
`parameters` as a nested object. Note the event id key is `eventid` in form mode and
`eventID` in JSON mode.

The same `POST /resources` request in both encodings:

```http
POST /resources HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Accept: application/json
Authorization: Basic bXlzcWw6czNjcjN0
X-Tsuru-User: alice@example.com
X-Tsuru-Eventid: 68a1f0c2e5d4b3a2c1000001

name=mydb&team=myteam&user=alice%40example.com&eventid=68a1f0c2e5d4b3a2c1000001&tags=prod&tags=billing&plan=small&description=Billing+DB&parameters.storage=50
```

```http
POST /resources HTTP/1.1
Content-Type: application/json
Accept: application/json
Authorization: Basic bXlzcWw6czNjcjN0
X-Tsuru-User: alice@example.com
X-Tsuru-Eventid: 68a1f0c2e5d4b3a2c1000001

{"name":"mydb","team":"myteam","description":"Billing DB","plan":"small","tags":["prod","billing"],"eventID":"68a1f0c2e5d4b3a2c1000001","user":"alice@example.com","parameters":{"storage":"50"}}
```

`GET` requests never carry a body in either mode. `DELETE` requests do carry a body.

Responses are always expected as JSON, except the status endpoint which returns plain text.

## GET /resources/plans

Called by `tsuru service plan list`, `tsuru service info` and `tsuru service instance info`
(to show the plan description).

**Request:** no body. For a multi-cluster service, the user's `--pool` is translated into the
`X-Tsuru-Pool-*` and `X-Tsuru-Cluster-*` headers above; tsuru never adds a `pool` query
parameter.

**Response:**

| Code | What tsuru does |
|------|-----------------|
| 200 | Body is a JSON array of `{"name": ..., "description": ...}`. |
| 400 with `{"msg": "...", "missing_params": ["cluster"]}` | tsuru tells the user `You must provide the pool name, available pools: ...`. Use this when your multi-cluster service cannot answer without a pool. |
| anything else | Treated as an empty plan list; no error is shown. |

```json
[
  {"name": "small", "description": "1 vCPU, 1 GiB"},
  {"name": "large", "description": "4 vCPU, 8 GiB"}
]
```

## POST /resources

Called by `tsuru service instance add`. tsuru saves the instance only after this call
succeeds.

**Request fields** (form key / JSON key):

| Form | JSON | Content |
|------|------|---------|
| `name` | `name` | Instance name. It is the identifier used in every later path. |
| `team` | `team` | Owner team. |
| `user` | `user` | Email of the user creating the instance. |
| `eventid` | `eventID` | tsuru event id. |
| `tags` (repeated) | `tags` (array) | Tags; absent when there are none. |
| `plan` | `plan` | Plan name; absent when the user gave none. |
| `description` | `description` | Free text; absent when empty. |
| `parameters.<key>` | `parameters` (object) | Values from `--plan-param key=value`. |

**Response:**

| Code | What tsuru does |
|------|-----------------|
| 2xx | Instance created. Any 2xx works; 201 is conventional. |
| 409 | Creation fails with `instance already exists in the service API`. |
| other | Creation fails with your body as the message. |

## PUT /resources/&lt;name&gt;

Called by `tsuru service instance update`. Optional: answer 404 if you do not support it.

**Request fields:** `description`, `team`, `tags`, `plan`, `user`, `eventid` and
`parameters.<key>` (JSON: `description`, `team`, `tags`, `plan`, `user`, `eventID`,
`parameters`). In form mode every key is sent even when empty; in JSON mode empty
`description`, `plan`, `tags` and `parameters` are omitted. The values are the full new
state of the instance, not a diff.

**Response:**

| Code | What tsuru does |
|------|-----------------|
| 2xx | Instance updated. |
| 404 | Ignored; tsuru saves the update on its side. |
| other | Update fails with your body as the message. |

## DELETE /resources/&lt;name&gt;

Called by `tsuru service instance remove`. tsuru refuses to remove an instance that still has
bound apps, unless the user passes `-f/--force`, which unbinds each app first (see
`DELETE /resources/<name>/bind-app`).

**Request fields:** `user`, `eventid` (JSON: `user`, `eventID`).

**Response:**

| Code | What tsuru does |
|------|-----------------|
| 2xx | Instance removed from tsuru. |
| 404 | Removal fails with `instance does not exist in the service API`. |
| other | Removal fails with your body as the message. |

With `--ignore-errors` tsuru prints the error in the command output and removes the instance
from its database anyway, whatever your answer was.

## POST /resources/&lt;name&gt;/bind-app

Called by `tsuru service instance bind -a <app>`. The JSON object you return becomes the
app's private environment variables (and an entry in `TSURU_SERVICES`, see
[TSURU_SERVICES variable](environment_variables.md)).

**Request fields** (form key / JSON key):

| Form | JSON | Content |
|------|------|---------|
| `app-name` | `appName` | App name. |
| `app-hosts` (repeated) | `appHosts` | Every external address of the app (router addresses). |
| `app-host` | not sent | First element of `app-hosts`, kept for old services. Absent when the app has no address. |
| `app-internal-hosts` (repeated) | `appInternalHosts` | Internal (cluster) addresses of the app, one per process/port. |
| `app-pool-name` | `appPoolName` | Pool of the app. |
| `app-pool-provisioner` | `appPoolProvisioner` | Provisioner of that pool. |
| `app-cluster-name` | `appClusterName` | Cluster the app pool maps to; absent when there is none. |
| `app-cluster-provisioner` | `appClusterProvisioner` | Provisioner of that cluster. |
| `app-cluster-addresses` (repeated) | `appClusterAddresses` | API addresses of that cluster. |
| `user` | `user` | Email of the user binding. |
| `eventid` | `eventID` | tsuru event id. |
| `parameters.<key>` | `parameters` (object) | Bind parameters given by the user. |

**Response:**

| Code | What tsuru does |
|------|-----------------|
| 2xx | Body must be a JSON object whose values are **strings**; each key becomes an environment variable. A non-string value (for example a bare number) makes the bind fail. |
| 404 | tsuru retries once with the legacy `POST /resources/<name>/bind` and the same body. If that also returns 404 the bind fails with `instance does not exist in the service API`. |
| 412 | Bind fails with `instance is not ready yet`. Return this while the instance is still provisioning. |
| other | Bind fails with your body as the message. |

If a later step of the bind fails on the tsuru side (for example setting the app
environment), tsuru rolls back by calling `DELETE /resources/<name>/bind-app` with the same
app, so unbind must tolerate an app you have just bound.

```json
{
  "MYSQL_HOST": "10.10.10.10",
  "MYSQL_PORT": "3306",
  "MYSQL_USER": "mydb",
  "MYSQL_PASSWORD": "s3cr3t"
}
```

## DELETE /resources/&lt;name&gt;/bind-app

Called by `tsuru service instance unbind -a <app>`, by `service instance remove -f` for
each bound app, and as the rollback of a failed bind.

**Request fields:** `app-name`, `app-hosts` (repeated), `app-host` (first host), `user`,
`eventid` (JSON: `appName`, `appHosts`, `user`, `eventID`).

**Response:**

| Code | What tsuru does |
|------|-----------------|
| 2xx | App unbound; tsuru removes the variables from the app. |
| 404 | Treated as already unbound; tsuru continues and removes the variables. |
| other | Unbind fails, unless the user passed `--force`, in which case the error is printed and tsuru removes the binding anyway. |

If the unbind fails on the tsuru side afterwards, tsuru re-binds by calling
`POST /resources/<name>/bind-app` again.

## PUT /resources/&lt;name&gt;/binds/jobs/&lt;job&gt;

Called by `tsuru service instance bind -j <job>` (since tsuru 1.15). Same contract as
`bind-app`, but the job name is in the path and there is no legacy fallback.

**Request fields** (form key / JSON key):

| Form | JSON | Content |
|------|------|---------|
| `job-name` | `jobName` | Job name (same as in the path). |
| `user` | `user` | Email of the user binding. |
| `eventid` | `eventID` | tsuru event id. |
| `job-pool-name` | `jobPoolName` | Pool of the job; absent if the pool cannot be found. |
| `job-cluster-name` | `jobClusterName` | Cluster the job pool maps to; absent when there is none. |

**Response:** 2xx with a JSON object of string environment variables (used on the job's
next run), 404 for `instance does not exist in the service API`, 412 for
`instance is not ready yet`, anything else fails with your body as the message.

## DELETE /resources/&lt;name&gt;/binds/jobs/&lt;job&gt;

Called by `tsuru service instance unbind -j <job>` and as the rollback of a failed job bind.

**Request fields:** `user`, `eventid` (JSON: `user`, `eventID`).

**Response:** same handling as `DELETE /resources/<name>/bind-app`: 2xx unbinds, 404 is
treated as already unbound, anything else fails unless `--force` was given.

## GET /resources/&lt;name&gt;/status

Called by `tsuru service instance info`, which prints `Service instance "<name>" is <status>`.

**Request:** no body, no event headers.

| Code | Status shown to the user |
|------|--------------------------|
| 200 | The response body, verbatim (plain text, keep it short). |
| 202 | `pending` |
| 204 | `up` |
| 404 | `not implemented for this service` |
| 500 | `down` |
| other | The `info` command fails with your body as the message. |

## GET /resources/&lt;name&gt;

Extra information about an instance, shown by `tsuru service instance info` (as custom
info rows) and included in `tsuru service info`. Optional.

**Request:** no body, no event headers.

**Response:** 200 with a JSON array of `{"label": ..., "value": ...}` objects, both strings.
tsuru turns it into a map, so labels must be unique. Any other status means "no extra
info" and is not an error.

```json
[
  {"label": "Address", "value": "10.46.6.241"},
  {"label": "Instances", "value": "2"}
]
```

## Proxy: any method on /resources/&lt;name&gt;/&lt;path&gt;

Everything else your service offers per instance (scale, rotate a credential, fetch
metrics...) is reached through a tsuru proxy. Users call one of these tsuru routes, usually
from a [client plugin](../user_guides/plugins.md) you ship:

- `/services/{service}/proxy/{instance}?callback=<path>`
- `/services/{service}/resources/{instance}/<path>`

Both accept `GET`, `POST`, `PUT`, `PATCH` and `DELETE`.

tsuru forwards the request to `<endpoint>/resources/<instance>/<path>`:

- Method, body and the user's request headers are forwarded; tsuru adds basic auth, the
  headers listed in [Every request](#every-request) and rewrites `Host`.
- The query string is forwarded minus `callback` and tsuru's internal routing parameters.
- `<path>` is cleaned (`path.Clean`); a path that uses `..` to escape `/resources/<instance>`
  is rejected before reaching you.
- Non-`GET` requests to the reserved paths `bind-app`, `bind-job`, `bind` and the bare
  instance path (`/resources/<instance>`) are rejected with a 400, so users cannot bind or
  delete through the proxy. `GET /resources/<instance>` is allowed.
- Non-`GET` requests create a tsuru event (`service-instance.update.proxy` or the
  manifest action), so they carry `X-Tsuru-User` and `X-Tsuru-Eventid`; `GET` does
  not.

The caller needs the `service-instance.update.proxy` permission on the instance, or a
finer-grained action if you publish a [permissions manifest](permissions_manifest.md).
Your service receives the response status as-is: whatever you return is streamed back to
the user.

## Service-level proxies

Two more routes reach the service itself rather than an instance. Both accept `GET`, `POST`,
`PUT`, `PATCH` and `DELETE` and both use the `production`
endpoint only.

- `/services/proxy/service/{service}?callback=<path>` forwards to
  `<endpoint>/<path>` verbatim, with no `/resources` prefix. It requires `service.update.proxy`
  on the service, which normally means a member of its owner team. Use it for operator
  endpoints.
- `/services/{service}/authenticated-resources/<path>` forwards to
  `<endpoint>/authenticated-resources/<path>`. tsuru checks only that the caller is
  authenticated: **there is no permission check**. Non-`GET` requests carry
  `X-Tsuru-User`; `GET` does not, so do not expose user-specific data on `GET`
  under this prefix.

## Checklist for a new service

1. Serve over HTTPS and validate basic auth on every route; the username defaults to the
   service `id`.
2. Implement `GET /resources/plans` returning `[{"name", "description"}]`.
3. Implement `POST /resources`, `DELETE /resources/<name>`,
   `POST`/`DELETE /resources/<name>/bind-app` and
   `PUT`/`DELETE /resources/<name>/binds/jobs/<job>`. Return 409 on duplicate create, 404
   for unknown instances, 412 while provisioning.
4. Return environment variables as a flat JSON object of **strings**.
5. Make bind and unbind idempotent: tsuru calls them again on rollback.
6. Read lists as repeated form keys (`tags`, `app-hosts`, `app-internal-hosts`,
   `app-cluster-addresses`) and parameters as `parameters.<key>`; or opt into
   `encoding: json`.
7. Implement `GET /resources/<name>/status` (204 when ready, 202 while pending) and,
   optionally, `GET /resources/<name>` and `PUT /resources/<name>`.
8. Put a readable message in the body of every error response.
9. For a multi-cluster service, read the `X-Tsuru-Pool-*`/`X-Tsuru-Cluster-*` headers and
   answer `GET /resources/plans` with the 400 `missing_params` convention when the pool is
   required. See [Multi-cluster services](multi_cluster.md).
10. Register it with `tsuru service create manifest.yaml` and test with
    `tsuru service instance add` and `tsuru service instance info`.

See the [Service API reference](../reference/service_api.md) for the rendered OpenAPI
contract and [Using services](../user_guides/service_instances.md) for what users run.
