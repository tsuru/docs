# Building your service

This guide shows how to turn an existing cloud service into a tsuru service: an HTTP API
that tsuru calls when users create, bind and remove instances, plus a YAML manifest that
registers it.

## Overview

To create a service you need to:

1. Implement the provisioning API described in the [Service API workflow](api.md).
2. Write a manifest and register it with `tsuru service create`.

The examples below use [FastAPI](https://fastapi.tiangolo.com) and the default
form encoding (`pip install fastapi uvicorn python-multipart`; the last one parses form
bodies). Every field name comes from the payloads tsuru actually sends; see the
[Service API workflow](api.md) for the full tables and response codes.

## Creating your service API

### Authentication

tsuru sends HTTP basic auth on every request. The username is the manifest `username`
(or the service `id` when there is none) and the password is the manifest `password`.
Reject anything else with 401.

```python
import secrets

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials

USERNAME, PASSWORD = "mysql", "s3cr3t"
basic = HTTPBasic(realm="tsuru")


def requires_auth(credentials: HTTPBasicCredentials = Depends(basic)):
    ok_user = secrets.compare_digest(credentials.username, USERNAME)
    ok_pass = secrets.compare_digest(credentials.password, PASSWORD)
    if not (ok_user and ok_pass):
        raise HTTPException(status_code=401, headers={"WWW-Authenticate": 'Basic realm="tsuru"'})


app = FastAPI(dependencies=[Depends(requires_auth)])
instances: dict[str, dict] = {}
```

Declaring the dependency on the application applies it to every route below.

### Reading the request

tsuru sends `application/x-www-form-urlencoded` bodies. Lists are repeated keys and
instance or bind parameters arrive as `parameters.<key>`. Read the raw form once per
request and use two helpers:

```python
def form_list(form, key):
    return form.getlist(key)


def parameters(form):
    return {k[len("parameters."):]: v
            for k, v in form.multi_items() if k.startswith("parameters.")}
```

If you register the service with `encoding: json` (see [Encoding](#encoding)) read
`await request.json()` (or declare a Pydantic model) and use the camelCase keys listed in the
[workflow page](api.md#encoding).

### Listing available plans

**Endpoint:** `GET /resources/plans`

```python
PLANS = [
    {"name": "small", "description": "1 vCPU, 1 GiB"},
    {"name": "large", "description": "4 vCPU, 8 GiB"},
]


@app.get("/resources/plans")
def plans():
    return PLANS
```

A multi-cluster service receives `X-Tsuru-Pool-Name` and `X-Tsuru-Cluster-*` headers here
and may answer `400 {"msg": "...", "missing_params": ["cluster"]}` when it needs a pool.
See [Multi-cluster services](multi_cluster.md).

### Creating new instances

**Endpoint:** `POST /resources`

```python
@app.post("/resources")
async def add_instance(request: Request):
    form = await request.form()
    name = form["name"]
    team = form["team"]
    user = form["user"]                  # email of the requesting user
    plan = form.get("plan")              # absent when the user gave none
    description = form.get("description")
    tags = form_list(form, "tags")       # tags=a&tags=b
    params = parameters(form)            # --plan-param key=value
    if name in instances:
        return Response("instance already exists", status_code=409)
    instances[name] = {"plan": plan, "team": team, "tags": tags, "params": params}
    return Response(status_code=201)
```

Return 409 when the name is taken; tsuru shows `instance already exists in the service API`
and does not save the instance.

### Updating service instances

**Endpoint:** `PUT /resources/<name>` (optional, tsuru ignores a 404)

```python
@app.put("/resources/{name}")
async def update_instance(name: str, request: Request):
    form = await request.form()
    inst = instances[name]
    inst["plan"] = form.get("plan")
    inst["team"] = form.get("team")
    inst["description"] = form.get("description")
    inst["tags"] = form_list(form, "tags")
    inst["params"] = parameters(form)
    return Response(status_code=200)
```

The body is the complete new state of the instance, not a diff.

### Binding instances to apps

**Endpoint:** `POST /resources/<name>/bind-app`

```python
@app.post("/resources/{name}/bind-app")
async def bind_app(name: str, request: Request):
    if name not in instances:
        return Response(status_code=404)
    if not instances[name].get("ready"):
        return Response(status_code=412)  # tsuru reports "instance is not ready yet"
    form = await request.form()
    app_name = form["app-name"]
    app_hosts = form_list(form, "app-hosts")          # external (router) addresses
    internal_hosts = form_list(form, "app-internal-hosts")
    pool = form.get("app-pool-name")
    cluster = form.get("app-cluster-name")
    cluster_addrs = form_list(form, "app-cluster-addresses")
    params = parameters(form)
    envs = {"MYSQL_HOST": "10.10.10.10", "MYSQL_PORT": "3306",
            "MYSQL_USER": app_name, "MYSQL_PASSWORD": new_password(app_name)}
    return JSONResponse(envs, status_code=201)
```

Every value in the returned object must be a string; tsuru rejects numbers. The variables
become private environment variables of the app and are listed in
[`TSURU_SERVICES`](environment_variables.md). The full field list, including
`app-host`, `app-pool-provisioner` and `app-cluster-provisioner`, is in the
[workflow page](api.md#post-resourcesnamebind-app).

If you only return 404 from this route tsuru falls back to the legacy
`POST /resources/<name>/bind`. New services should not implement `/bind`.

### Unbinding instances from apps

**Endpoint:** `DELETE /resources/<name>/bind-app`

```python
@app.delete("/resources/{name}/bind-app")
async def unbind_app(name: str, request: Request):
    form = await request.form()
    app_name = form["app-name"]
    app_hosts = form_list(form, "app-hosts")
    revoke_access(name, app_name)        # must succeed even if the app is not bound
    return Response(status_code=200)
```

tsuru also calls this route to roll back a bind that failed later on its side, so make it
idempotent.

### Binding and unbinding jobs

**Endpoints:** `PUT /resources/<name>/binds/jobs/<job>` and `DELETE` on the same path.

```python
@app.put("/resources/{name}/binds/jobs/{job}")
async def bind_job(name: str, job: str, request: Request):
    if name not in instances:
        return Response(status_code=404)
    form = await request.form()
    job_name = form["job-name"]                  # same as {job}
    pool = form.get("job-pool-name")
    cluster = form.get("job-cluster-name")
    envs = {"MYSQL_HOST": "10.10.10.10", "MYSQL_USER": job_name,
            "MYSQL_PASSWORD": new_password(job_name)}
    return JSONResponse(envs, status_code=201)


@app.delete("/resources/{name}/binds/jobs/{job}")
def unbind_job(name: str, job: str):
    revoke_access(name, job)
    return Response(status_code=200)
```

Jobs are not restarted on bind; the variables are used on the next run. Every request also
carries `user` and `eventid`.

### Removing instances

**Endpoint:** `DELETE /resources/<name>`

```python
@app.delete("/resources/{name}")
def remove_instance(name: str):
    if name not in instances:
        return Response(status_code=404)
    del instances[name]
    return Response(status_code=200)
```

tsuru only calls this once no app is bound (or after unbinding them with `-f`). With
`--ignore-errors` the user can drop the instance from tsuru even if you return an error.

### Checking the status of an instance

**Endpoint:** `GET /resources/<name>/status`

```python
@app.get("/resources/{name}/status")
def status(name: str):
    if name not in instances:
        return Response(status_code=404)  # shown as "not implemented for this service"
    if not instances[name].get("ready"):
        return Response(status_code=202)  # shown as "pending"
    return Response(status_code=204)      # shown as "up"
```

Users see the result in `tsuru service instance info <service> <instance>` as
`Service instance "<name>" is up`. Return 200 with a short text body to show your own
status string, or 500 for `down`.

### Extra information (optional)

**Endpoint:** `GET /resources/<name>`

```python
@app.get("/resources/{name}")
def info(name: str):
    return [{"label": "Address", "value": "10.10.10.10"},
            {"label": "Plan", "value": instances[name]["plan"]}]
```

The rows appear in `tsuru service instance info`. Anything other than 200 means "no extra
info". Any other path under `/resources/<name>/` is yours: users reach it through the
tsuru proxy described in the [workflow page](api.md#proxy-any-method-on-resourcesnamepath).

Run the service with `uvicorn service:app --host 0.0.0.0 --port 8080` (assuming the file is
`service.py`) and point the manifest `endpoint.production` at it.

## Creating a service manifest

Generate a template in the current directory:

```bash
$ tsuru service template
Generated file "manifest.yaml" in current directory
```

```yaml
id: servicename
username: username_to_auth
password: <random, 16 characters>
team: team_responsible_to_provide_service
endpoint:
  production: production-endpoint.com
multi-cluster: false
```

| Field | Meaning |
|-------|---------|
| `id` | Service name: at most 40 characters, lower case letters, numbers or dashes, starting with a letter. Users type it in every command. |
| `username` | Basic auth username. Optional; defaults to `id`. |
| `password` | Basic auth password. Required. |
| `team` | Owner team. Required; only its members can update, remove or proxy the service. |
| `endpoint.production` | Base URL of your API. `http://` is assumed when no scheme is given. |
| `multi-cluster` | Set `true` for a service that runs inside the users' clusters, one endpoint per cluster. Immutable after creation. See [Multi-cluster services](multi_cluster.md). |

The CLI reads only these fields and sends them as form values to `POST /services`. Two more
fields exist on the API but are not read from the manifest by the CLI:

- `endpoints`: a map of endpoint name to URL. tsuru picks the endpoint named after the
  instance's cluster and falls back to `production`.
- `encoding`: `form` (default) or `json`.

### Encoding

A service created with `encoding: json` receives `application/json` request bodies with
camelCase keys instead of form fields (since tsuru 1.30). The CLI does not send this field,
so set it through the API directly, for example:

```bash
$ curl -X POST https://tsuru.example.com/1.0/services \
    -H "Authorization: bearer $TSURU_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"id":"mysql","password":"s3cr3t","team":"dba","encoding":"json",
         "endpoints":{"production":"https://mysql-api.example.com"}}'
```

`PUT /services/<name>` accepts the same fields; `encoding` is kept when omitted, but
`tsuru service update` always sends `endpoint`, so it resets the `endpoints` map to
`production` only.

## Registering and managing the service

```bash
$ tsuru service create manifest.yaml       # register; "-" reads the manifest from stdin
$ tsuru service update manifest.yaml       # change username, password, team or endpoint
$ tsuru service info <id> [-p pool]        # instances and plans (as seen by tsuru)
$ tsuru service list                       # services you have access to
$ tsuru service destroy <id>               # refused while instances exist
```

`service create` needs the `service.create` permission on the owner team; `update` and
`destroy` need `service.update` and `service.delete` on the service, which owner team members
normally have.

## Next steps

- [Service API workflow](api.md): every request, field and response code.
- [Multi-cluster services](multi_cluster.md): one endpoint per cluster, pool headers,
  `missing_params` convention.
- [Service permissions manifest](permissions_manifest.md): fine-grained permissions for
  your proxy endpoints.
- [Service API reference](../reference/service_api.md): rendered OpenAPI contract.
- [Using services](../user_guides/service_instances.md): what your users will run.
