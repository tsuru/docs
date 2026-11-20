# Managing routers

## Overview

A router is the component that exposes an app to its users: it receives the app's address, cnames
and certificates from tsuru and configures load balancers, ingresses or gateways to send traffic to
the app units. Tsuru itself does not route traffic. It talks to a router through the
[Router API](../reference/router_api.md): every router has `type: api` and an `api-url` of a service
implementing that contract, such as [kubernetes-router](https://github.com/tsuru/kubernetes-router).

The old in-process router implementations (Router V1) were removed (since tsuru 1.20.6); `api` is the only
registered type, and `tsuru router add` rejects any other with `router type "<type>" is not
registered`.

Routers are declared in one of two ways, which coexist and are listed together by
[`tsuru router list`](../tsuru_client/tsuru_router_list.md):

- **Static routers** in `tsuru.conf`, under `routers:<name>`.
- **Dynamic routers** stored in the database and managed with `tsuru router add/update/remove`.

## Static routers in tsuru.conf

```yaml
routers:
  ingress-router:
    type: api
    api-url: http://kubernetes-router.tsuru-system:8077/api/ingress-nginx
    default: true
    multi-cluster: true
    debug: false
    headers:
      X-Custom-Header: my-value
    readinessGates:
      - tsuru.io/router-ready
```

| Key | Description |
|-----|-------------|
| `type` | Required. `api`. |
| `api-url` | Required for `api`. Base URL of the router API. |
| `default` | Marks this router as the default one when more than one router exists. |
| `multi-cluster` | Send the pool and cluster headers (`X-Tsuru-Pool-Name`, `X-Tsuru-Pool-Provisioner`, `X-Tsuru-Cluster-Name`, `X-Tsuru-Cluster-Provisioner`, `X-Tsuru-Cluster-Addresses` and, with the cluster custom data `propagate-kubeconfig=true`, `X-Tsuru-Cluster-Kube-Config`) on every request, so one router instance can serve apps in several clusters. |
| `debug` | Log every request and response sent to the router. |
| `headers` | Extra headers (string or list of strings) added to every request. |
| `readinessGates` | Pod readiness gates added to the `web` pods of apps using this router, see [Readiness gates](#readiness-gates). |

Each key is also documented in the [configuration reference](../reference/config.md#routers).
Changing a static router requires editing the file and restarting `tsurud`.

## Dynamic routers

Dynamic routers take the same configuration as a JSON object and need no restart. They require the
`router.create`, `router.update` and `router.delete` permissions.

=== "Tsuru client"

    ```bash
    $ tsuru router add ingress-router api \
        --config '{"api-url": "http://kubernetes-router.tsuru-system:8077/api/ingress-nginx", "multi-cluster": true}' \
        --readiness-gate tsuru.io/router-ready
    $ tsuru router update ingress-router api --config '{"debug": true}'
    $ tsuru router info ingress-router
    $ tsuru router remove ingress-router
    ```

=== "Terraform"

    ```terraform
    resource "tsuru_router" "ingress-router" {
      name            = "ingress-router"
      type            = "api"
      readiness_gates = ["tsuru.io/router-ready"]
      config          = <<-EOT
        api-url: "http://kubernetes-router.tsuru-system:8077/api/ingress-nginx"
        multi-cluster: true
        EOT
    }
    ```

[`tsuru router update`](../tsuru_client/tsuru_router_update.md) merges `--config` into the stored
configuration key by key; a key set to `null` is deleted. Rules:

- A dynamic router cannot use the name of a router declared in `tsuru.conf`: `router named "<name>"
  already exists in config`. Adding a name that is already dynamic answers `409 dynamic router
  already exists`.
- There is no `default` field for dynamic routers. The default router is chosen as described in
  [Default router and routers per pool](#default-router-and-routers-per-pool).
- `tsuru router remove` only removes the definition. Apps still pointing at it fail to deploy
  (`router "<name>" not found`), so remove it from every app first with `tsuru app router remove`.

`tsuru router list` shows dynamic routers as `api (dynamic)` and, for every router, the `Info` the
router API reports; `tsuru router info <name>` also prints the readiness gates and config. Users
without `router.create` do not see the config, and users without a global `app.create` only see the
routers allowed in the pools of their teams.

## Readiness gates

A readiness gate is a Kubernetes pod condition that must be `True` before the pod counts as ready.
When a router declares readiness gates (`readinessGates` in `tsuru.conf` or `--readiness-gate`), tsuru
adds them to the `web` process pods of every app using that router (other processes are not
affected). The router implementation is expected to set the condition once the pod is registered in
the load balancer, so a rollout only proceeds when new units are actually reachable.

## kubernetes-router

[kubernetes-router](https://github.com/tsuru/kubernetes-router) is the reference implementation of
the Router API. It runs as a pod in the cluster, listens on `:8077` and serves the API under
`/api` and `/api/<mode>`, where `<mode>` selects one of the controller modes enabled with
`-controller-modes` (the first enabled mode is used for plain `/api`):

| Mode | Resources created per app |
|------|---------------------------|
| `service` (or `loadbalancer`) | A `Service` of type LoadBalancer named `<app>-router-lb`. Router opts can become Service labels through `-opts-to-label`, and `-pool-labels` adds labels per pool (`POOL={"LABEL":"VALUE"}`). |
| `ingress` | An `Ingress` per app (and one per cname) with host `<app>.<-ingress-domain>` (`-ingress-domain`, default `local`, takes precedence over the `domain-suffix` opt; the `domain` opt replaces the host entirely). Router opts listed in `-opts-to-ingress-annotations key=annotation` become Ingress annotations; `-ingress-class` sets the class (`-use-ingress-class-name` writes `spec.ingressClassName` instead of the annotation) and `-ingress-annotations-prefix` prefixes option names that are not mapped. |
| `ingress-nginx` | Same as `ingress` with `-ingress-class nginx` and `-ingress-annotations-prefix nginx.ingress.kubernetes.io` preset. |
| `istio-gateway` | An Istio `Gateway` and `VirtualService`, selecting the gateway pods with `-istio-gateway.gateway-selector`. |
| `gateway-api` | Gateway API `HTTPRoute`s attached to the `Gateway` named by `-gateway-name`/`-gateway-namespace`; `-acme-issuer` is the cert-manager ClusterIssuer used when `tls-acme=true`. |

Every mode points its resource at the `Service` tsuru creates for the app's web process: tsuru sends
the Service name and namespace of each routable process version with the backend, so the router
never guesses names. Other useful flags: `-k8s-namespace` (default `tsuru`) for the router's own
resources, `-k8s-labels`/`-k8s-annotations` added to everything it creates, `-ingress-http-port` and
`-ingress-address-scheme` for the address reported back to tsuru, `-cert-file`/`-key-file` to serve
HTTPS, and `-clusters-file` to enable multi-cluster mode (a YAML `clusters:` list with `name`,
`address`, `token`/`ca` or `authProvider`/`exec`; the cluster is picked by the `X-Tsuru-Cluster-Name`
header, or built from `X-Tsuru-Cluster-Kube-Config` when present). Requests are authenticated with
HTTP basic auth when `ROUTER_API_USER` and `ROUTER_API_PASSWORD` are set; pass them to tsuru through
the router `headers` (`Authorization: Basic ...`).

Besides the opts you map yourself, kubernetes-router understands `exposed-port`, `domain`,
`domain-suffix`, `domain-prefix`, `route`, `tls-acme`, `tls-acme-cname`, `http-only`,
`external-traffic-policy` and `all-prefixes`. Tsuru always adds `tsuru.io/app-pool`,
`tsuru.io/app-teamowner` and `tsuru.io/app-teams` to the opts it sends.

## Routers of an app

An app can have several routers. The first one is set at creation (`tsuru app create --router`,
`--router-opts key=value`, or `--router none` for an app without any router); the others are
managed with [`tsuru app router`](../tsuru_client/tsuru_app_router.md):

=== "Tsuru client"

    ```bash
    $ tsuru app router add ingress-router -a myapp -o tls-acme=true -o domain-suffix=example.com
    $ tsuru app router update ingress-router -a myapp -o tls-acme=false
    $ tsuru app router list -a myapp
    $ tsuru app router remove ingress-router -a myapp
    ```

=== "Terraform"

    ```terraform
    resource "tsuru_app_router" "ingress" {
      app  = tsuru_app.myapp.name
      name = "ingress-router"

      options = {
        "tls-acme"      = "true"
        "domain-suffix" = "example.com"
      }
    }
    ```

- `-o/--opts` values are passed verbatim to the router implementation; `app router update` replaces
  the whole set of opts of that router.
- The router must be allowed in the app's pool (`router "<name>" is not available for pool "<pool>".
  Available routers are: ...`) and cannot be added twice (`router already linked to this app`). Adding
  a router whose cname is already registered by another app in the same router is refused.
- The permissions are `app.update.router.add`, `app.update.router.update` and
  `app.update.router.remove`.
- `tsuru app update` does not change routers anymore: the API answers `updating router was
  deprecated, please add the wanted router and remove the old one`. The `app swap` API is also
  deprecated (`swapping is deprecated`) and has no client command.

`tsuru app router list` and `tsuru app info` show one row per router with its opts, the addresses
reported by the router and the backend `Status` the router returns (for example `ready`, or
`not ready` with a detail), so a misconfigured ingress shows up there before users notice.

## Default router and routers per pool

When an app is created without `--router`, tsuru picks:

1. the first value listed in the `router` [pool constraint](managing_pools.md#pool-constraints) of
   the app's pool, when the constraint is an allowlist without globs;
2. with a glob or denylist constraint, the only allowed router if exactly one remains;
3. otherwise the router flagged `default: true` in `tsuru.conf`, or the only router when just one
   exists. If none matches, creation fails with `No default router found`.

The same `router` constraint also restricts which routers `tsuru app router add` accepts in that
pool:

```bash
$ tsuru pool constraint set prod router ingress-router
$ tsuru pool constraint set "dev_*" router internal-router --denylist
```

## Rebuilding routes

Tsuru resends the whole backend (addresses of every routable version, cnames, certificate issuers,
team, tags, healthcheck and opts) to each router of the app after deploys, unit changes and
app or router updates. If a router lost state, for example after its resources were deleted by hand, force it with:

```bash
$ tsuru app routes rebuild -a myapp
```

It requires the `app.admin.routes` permission and reports one `Updating router [<name>]` section per
router.
