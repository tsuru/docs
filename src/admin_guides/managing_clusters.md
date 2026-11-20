# Managing clusters

## Overview

A cluster is a Kubernetes installation registered in tsuru. The kubernetes provisioner deploys the apps of a
[pool](managing_pools.md) into the cluster associated with that pool; a pool without an explicit cluster uses the
cluster flagged as **default** for its provisioner.

When tsuru itself runs inside Kubernetes and no cluster is registered yet, the provisioner registers a cluster named
`local` (default, authenticated with the in-cluster service account and with `disable-default-node-selector=true`) and,
if no pool exists, a default pool also named `local`.

## Adding a cluster

In order to create a cluster, you should create a terraform resource or invoke `tsuru cluster add`:

=== "Tsuru client"

    The CLI exposes the address/certificate style of authentication. `kubeConfig` and `httpProxy` (below) are only
    available through the API and terraform.

    ```bash
    $ tsuru cluster add cluster1 kubernetes --addr https://mycluster-addr \
        --cacert ca.crt --clientcert client.crt --clientkey client.key \
        --pool pool1 --custom namespace=tsuru
    ```

    Instead of client certificates you can authenticate with a bearer token (`--custom token=<token>`) or basic auth
    (`--custom username=<user> --custom password=<pass>`). `--default` makes this the default cluster.

=== "Terraform"

    Read the full documentation of the [tsuru_cluster resource](https://registry.terraform.io/providers/tsuru/tsuru/latest/docs/resources/cluster).

    ```terraform
    resource "tsuru_cluster" "test_cluster" {
      name              = "test_cluster"
      tsuru_provisioner = "kubernetes"
      default           = true
      http_proxy        = "http://myproxy.io:3128"
      custom_data = {
        "namespace"        = "tsuru"
        "overcommit-factor" = "2"
      }
      kube_config {
        cluster {
          server                     = "https://myclusteraddr"
          certificate_authority_data = "server-ca"
        }
        user {
          # when GKE
          auth_provider {
            name = "gcp"
          }
          # otherwise fill some of the options below based on your cluster authentication mode
          client_certificate_data = "client-cert"
          client_key_data         = "client-key"
          token                   = "token"
          username                = "username"
          password                = "password"
        }
      }
    }
    ```

### kubeConfig and httpProxy

The cluster API object (`POST /1.3/provisioner/clusters`) accepts two fields the CLI does not expose:

- `kubeConfig`: a `{cluster, user}` pair with the same schema as a kubeconfig file entry (server, CA data, client
  certificates, token, basic auth, `auth_provider` or `exec` plugins). When set, `kubeConfig.cluster.server` is
  required and `addresses` (more than one), `cacert`, `clientcert` and `clientkey` are rejected.
- `httpProxy`: an HTTP proxy URL used to reach the Kubernetes API server. Only applied together with `kubeConfig`.

Terraform maps them to the `kube_config` block and `http_proxy` attribute shown above.

## Listing clusters

```bash
$ tsuru cluster list
+----------+-------------+------------------------+-------------------------+---------+-------+
| Name     | Provisioner | Addresses              | Custom Data             | Default | Pools |
+----------+-------------+------------------------+-------------------------+---------+-------+
| cluster1 | kubernetes  | https://mycluster-addr | namespace=tsuru         | true    | pool1 |
|          |             |                        | overcommit-factor=2     |         | pool2 |
+----------+-------------+------------------------+-------------------------+---------+-------+
```

`--name`/`--pool` filter the list, `--only-name` prints just the names and `--json` prints the raw objects. For a
cluster configured through `kubeConfig` the Addresses column shows `kubeConfig.cluster.server`. For users without the
`cluster.admin` permission the list hides the `token` and `password` custom data entries and the client key.

```bash
$ tsuru cluster info cluster1
Name:         cluster1
Provisioner:  kubernetes
Addresses:    https://mycluster-addr
Default:      true
Pools:        pool1
              pool2

Custom Data:
+-------------------+-------+
| Key               | Value |
+-------------------+-------+
| namespace         | tsuru |
| overcommit-factor | 2     |
+-------------------+-------+
```

## Cluster custom data

Custom data is a free-form `key=value` map on the cluster that tunes the kubernetes provisioner. Set it at creation with
`--custom`, or later with:

```bash
$ tsuru cluster update cluster1 kubernetes --add-custom max-surge=50% --add-custom pool1:max-surge=1
$ tsuru cluster update cluster1 kubernetes --remove-custom pool1:max-surge
```

Resolution order for a key (`configForContext` in `provision/kubernetes/cluster.go`):

1. `<pool>:<key>` in the cluster custom data (per-pool override, only for keys marked *per pool* below);
2. `<key>` in the cluster custom data;
3. `clusters:defaults:<key>` in `tsuru.conf`, which applies to every cluster.

`tsuru provisioner info kubernetes` prints the help text of each key as known by the server.

| Key | Per pool | Meaning | Default |
|-----|----------|---------|---------|
| `namespace` | | Namespace for tsuru custom resources, and prefix of app namespaces when `kubernetes:use-pool-namespaces` is enabled (`<namespace>-<pool>`) | `tsuru` for CRs; `default` for apps (`tsuru-<pool>` with pool namespaces) |
| `token` | | Bearer token used to connect to the cluster | |
| `username`, `password` | | Basic auth credentials (both required; take precedence over `token`) | |
| `overcommit-factor` | yes | CPU and memory requests are divided by this factor | `1` (values below 1 are treated as 1) |
| `cpu-overcommit-factor` | yes | Overcommit factor for CPU requests only | unset |
| `memory-overcommit-factor` | yes | Overcommit factor for memory requests only | unset |
| `cpu-burst-factor` | yes | CPU limit = request multiplied by this factor | unset (values below 1 ignored) |
| `namespace-labels` | yes (key is the namespace name) | Extra labels for dynamically created namespaces, `k1=v1,k2=v2` | |
| `disable-headless` | yes | Do not create the headless service of each process | `false` |
| `max-surge` | yes | Deployment rollout maxSurge | `100%` |
| `max-unavailable` | yes | Deployment rollout maxUnavailable | `0` |
| `disable-secrets` | yes | Inline private env vars in the pod spec instead of referencing a Secret | `false` |
| `single-pool` | | The whole cluster belongs to one pool: no node selector or affinity is added to pods. The cluster must have exactly one pool | `false` |
| `ephemeral-storage` | yes | Ephemeral storage limit of app containers | `100Mi` |
| `pre-stop-sleep` | yes | Seconds slept in the container preStop hook | `10` |
| `disable-default-node-selector` | | Do not add the `tsuru.io/pool` node selector to pods | `false` |
| `base-services-annotations` | | YAML/JSON map of annotations added to the base (routable) Service of each process | |
| `all-services-annotations` | | YAML/JSON map of annotations added to every Service created for the app | |
| `registry` | | Registry where app images are pushed/pulled for this cluster | global `docker:registry` |
| `registry-insecure` | | Use plain HTTP for the registry | `false` |
| `disable-platform-build` | | Refuse platform image builds in this cluster | `false` |
| `disable-pdb` | yes | Do not create PodDisruptionBudgets | `false` |
| `enable-versioned-services` | | Always create one Service per `{process, version}`; by default they only exist during multi-version deploys | `false` |
| `docker-config-json` | | Contents of a `~/.docker/config.json` mounted into the deploy-agent container (registry credentials) | |
| `dns-config-ndots` | yes | `ndots` in the pod dnsConfig | unset (Kubernetes default, 5) |
| `build-service-address` | yes | gRPC address of the build service (deploy-agent v2); required for build v2 | |
| `build-service-tls` | yes | Connect to the build service with TLS | `false` |
| `build-service-tls-skip-verify` | yes | Skip certificate verification for the build service | `false` |
| `job-event-creation` | | Record Kubernetes events of Jobs as tsuru events | `false` |
| `topology-spread-constraints` | yes | Topology spread constraints applied to app pods | |
| `debug-container-image` | | Image for `tsuru app shell` ephemeral debug containers | `tsuru/netshoot` |
| `propagate-kubeconfig` | | Send the cluster `kubeConfig` to service and router APIs (see multi-cluster) | `false` |

## Multi-cluster

Each pool is bound to one cluster (`tsuru cluster add --pool`, `tsuru cluster update --add-pool/--remove-pool`, or the
terraform `tsuru_cluster_pool` resource); pools without a binding fall back to the default cluster. One cluster can
serve many pools, and the custom data `<pool>:` prefix lets a shared cluster behave differently per pool.

Service and router APIs receive the location of the app they are acting on through HTTP headers
(`provision/pool/multicluster`):

| Header | Value |
|--------|-------|
| `X-Tsuru-Pool-Name`, `X-Tsuru-Pool-Provisioner` | Pool of the app |
| `X-Tsuru-Cluster-Name`, `X-Tsuru-Cluster-Provisioner` | Cluster bound to that pool (omitted when there is none) |
| `X-Tsuru-Cluster-Addresses` | One header per cluster address |
| `X-Tsuru-Cluster-Kube-Config` | Base64 JSON of `kubeConfig`, only when custom data `propagate-kubeconfig=true` and the cluster has a `kubeConfig` |

Use `propagate-kubeconfig` for services or routers (for example the kubernetes-router) that need to talk to the same
cluster as the app, keeping in mind it ships the cluster credentials to those services.

## Optional components

- **KEDA** is optional. Without the `scaledobjects.keda.sh` CRD the provisioner only manages plain HPAs; autoscale rules
  with schedules or Prometheus triggers fail with an explicit error telling that KEDA is not installed (since tsuru 1.32).
  Prometheus triggers also need `kubernetes:keda:prometheus-address-template` in `tsuru.conf`.
- **VPA** is optional in the same way: recommendations are only read when its CRD exists.

## Removing a cluster

If you want to remove a cluster, use `tsuru cluster remove` or undeclare the `tsuru_cluster` resource on terraform:

```bash
$ tsuru cluster remove cluster1
```
