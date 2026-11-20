# Multi-cluster services

A regular service has one API endpoint, and tsuru calls it for every instance regardless of where the apps that use it run. A **multi-cluster** service is different: its instances live inside the same Kubernetes cluster as the apps that bind to them, so each instance belongs to a pool, and tsuru can route calls to a different provider endpoint per cluster. The typical example is a service that creates its resources (a proxy, a database, a queue) inside the app's own cluster. Multi-cluster services are available since tsuru 1.9.

This page is for service providers. Users create and bind instances as described in [Using services](../user_guides/service_instances.md); the request and response formats are in the [Service API workflow](api.md).

## Declaring a multi-cluster service

Set `multi-cluster: true` in the service manifest you pass to `tsuru service create` (the manifest `tsuru service template` generates already has the key, set to `false`):

```yaml
id: mydb
username: mydb
password: 1CWpoX2Zr46Jhc7u
team: platform
endpoint:
  production: https://mydb-api.example.com
multi-cluster: true
```

The flag is **immutable**: `tsuru service update` and `PUT /services/{name}` ignore it, so a service created as regular cannot become multi-cluster later (or the other way around). Create a new service instead.

## Instances need a pool

Every instance of a multi-cluster service must be created with `--pool`:

```bash
$ tsuru service instance add mydb orders-db small -t orders --pool prod-us
```

Without it the API rejects the request with `multi-cluster service instance requires a pool`. Instances of a regular service are the opposite: passing `--pool` fails with `regular (non-multi-cluster) service instance cannot belong to a pool`. The pool cannot be changed once the instance exists.

tsuru also checks that the pool allows the service through a [pool constraint](../admin_guides/managing_pools.md#pool-constraints) of field `service`. If it does not, the API answers `400 Service "mydb" is not available in pool "prod-us"`. An admin opens the pool to your service with:

```bash
$ tsuru pool constraint set prod-us service mydb --append
```

The same constraint is enforced when an app is bound to any service instance (multi-cluster or not): an app in a pool whose `service` constraint does not list the service gets `service "mydb" is not available for pool "prod-us"`.

## One endpoint per cluster

Every pool is bound to a cluster (see [Multi-cluster](../admin_guides/managing_clusters.md#multi-cluster) in the cluster guide). When tsuru needs to call the provider for an instance, it resolves the instance's pool to its cluster and picks the endpoint in this order:

1. `endpoints[<cluster-name>]`, the endpoint keyed by the **cluster name** (not the pool name);
2. `endpoints.production`, the default.

A pool with no cluster bound uses `production` directly. Instances of regular services always use `production`.

Endpoints are stored as a map on the service. The CLI only sends `endpoint.production` from the YAML, so register per-cluster endpoints through the API, as form fields `endpoints.<cluster-name>`:

```bash
$ curl -X POST -H "Authorization: bearer $TOKEN" https://tsuru.example.com/1.0/services \
    -d id=mydb -d username=mydb -d password=1CWpoX2Zr46Jhc7u -d team=platform \
    -d multi-cluster=true \
    -d endpoints.production=https://mydb-api.example.com \
    -d endpoints.gke-us=https://mydb-api.us.example.com \
    -d endpoints.gke-eu=https://mydb-api.eu.example.com
```

!!! warning
    `PUT /services/{name}` replaces the whole endpoint map with the one in the request, and `tsuru service update` sends only `production`. Running `tsuru service update` on a service with per-cluster endpoints silently drops them. Update multi-endpoint services through the API with the full map.

You do not need one endpoint per cluster. A single `production` endpoint that reads the headers below and talks to the right cluster itself is a valid design.

## What the provider receives

Every call about an instance that has a pool (create, update, bind, unbind, status, info, remove, proxied requests) carries these headers in addition to the ones listed under [every request](api.md) in the API workflow:

| Header | Value |
|--------|-------|
| `X-Tsuru-Pool-Name`, `X-Tsuru-Pool-Provisioner` | The instance's pool and its provisioner (`kubernetes`) |
| `X-Tsuru-Cluster-Name`, `X-Tsuru-Cluster-Provisioner` | The cluster bound to that pool; absent when the pool has no cluster |
| `X-Tsuru-Cluster-Addresses` | One header per cluster API server address |
| `X-Tsuru-Cluster-Kube-Config` | Base64 of the cluster's `kubeConfig` as JSON. Only when the cluster has custom data `propagate-kubeconfig=true` and a `kubeConfig` registered |

### propagate-kubeconfig

A provider that creates Kubernetes objects inside the app's cluster needs credentials for it. Instead of configuring them in the provider, the admin can set `tsuru cluster update <cluster> kubernetes --add-custom propagate-kubeconfig=true` and tsuru ships the cluster's `kubeConfig` in `X-Tsuru-Cluster-Kube-Config` on every call. Decode it with base64, parse the JSON (the same structure as a kubeconfig file) and build your client from it. Keep in mind the header carries cluster credentials: use HTTPS endpoints and do not log headers.

### Plans per pool

For a multi-cluster service `tsuru service plan list <service>` and `tsuru service info <service>` accept `-p/--pool`. tsuru then calls `GET /resources/plans` on the endpoint for that pool's cluster, with the pool and cluster headers above. Without `-p` the call goes to `production` with no pool headers.

If your plans depend on the cluster, answer a request without cluster headers with `400` and this body:

```json
{"missing_params": ["cluster"]}
```

tsuru turns it into `You must provide the pool name, available pools: prod-us, prod-eu` for the user, who retries with `-p`. The same lookup happens inside `tsuru service instance info`, which uses the instance's pool.

### Instance info

`GET /services/{service}/instances/{instance}` returns `Pool` and `Cluster` (the cluster the pool resolves to) for instances of a multi-cluster service. `tsuru service instance info` prints `Pool` but not `Cluster`.

### Binding

When an app is bound to an instance, `POST /resources/<instance>/bind-app` carries the **app's** location as well, so the provider can compare it with the instance's: `app-pool-name`, `app-pool-provisioner`, `app-cluster-name`, `app-cluster-provisioner` and `app-cluster-addresses` (repeated) in form encoding, or `appPoolName`, `appPoolProvisioner`, `appClusterName`, `appClusterProvisioner`, `appClusterAddresses` with `encoding: json`. `bind-job` sends `job-pool-name` and `job-cluster-name` (`jobPoolName`, `jobClusterName`). tsuru does not refuse a bind between an app and an instance in different pools; if your service only works inside one cluster, reject it yourself.

## Worked example

Two clusters, `gke-us` (pools `prod-us`, `staging-us`) and `gke-eu` (pool `prod-eu`). The provider `mydb` runs one API deployment per cluster, each creating databases in the cluster it runs in.

1. The admin binds pools to clusters and allows the service in them:

    ```bash
    $ tsuru cluster update gke-us kubernetes --add-pool prod-us --add-pool staging-us --add-custom propagate-kubeconfig=true
    $ tsuru cluster update gke-eu kubernetes --add-pool prod-eu --add-custom propagate-kubeconfig=true
    $ tsuru pool constraint set prod-us service mydb --append
    $ tsuru pool constraint set staging-us service mydb --append
    $ tsuru pool constraint set prod-eu service mydb --append
    ```

2. The provider registers the service with one endpoint per cluster name (see the `curl` above), keeping `production` as a fallback for pools in clusters it has no dedicated endpoint for.

3. A user lists plans and creates an instance:

    ```bash
    $ tsuru service plan list mydb
    Error: You must provide the pool name, available pools: prod-us, staging-us, prod-eu
    $ tsuru service plan list mydb -p prod-eu
    $ tsuru service instance add mydb orders-db small -t orders --pool prod-eu
    ```

    tsuru resolves `prod-eu` to `gke-eu`, calls `https://mydb-api.eu.example.com/resources` with `X-Tsuru-Pool-Name: prod-eu`, `X-Tsuru-Cluster-Name: gke-eu` and the kubeconfig header. An instance in `staging-us` would be created through `https://mydb-api.us.example.com`.

4. Binding an app in `prod-eu` sends `bind-app` to the same EU endpoint with `app-pool-name=prod-eu` and `app-cluster-name=gke-eu`.

What this gives you: data stays in the region of the app, each provider deployment only needs credentials for its own cluster, and users never see the cluster name; they only pick a pool.
