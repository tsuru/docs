---
title: Installing Tsuru in a local Kubernetes cluster with Helm
---

# Installing Tsuru in a local Kubernetes cluster with Helm {#installing_tsuru_local}

This guide installs tsuru and everything it needs into a local [minikube](https://minikube.sigs.k8s.io/docs/start/)
cluster with the `tsuru-stack` Helm chart. You need `minikube`, `kubectl`, `helm` and the
[tsuru client](../user_guides/install_client.md) installed.

## Hardware requirements

- 2 CPUs or more
- 12 GB of free memory
- 20 GB of free disk space

## Create the cluster

``` bash
minikube start
```

The example uses the docker driver; see the [minikube drivers](https://minikube.sigs.k8s.io/docs/drivers/)
for alternatives.

## What the chart installs

`tsuru-stack` is an umbrella chart. It deploys, in the `tsuru-system` namespace:

| Component | Chart | Purpose |
|---|---|---|
| tsuru-api | `tsuru-api` | the API server (`tsurud`) |
| MongoDB | bitnami `mongodb` | tsuru's datastore |
| Container registry | `docker-registry` | stores app images, plain HTTP, in-cluster only |
| deploy-agent + BuildKit | `deploy-agent` | builds app images |
| kubernetes-router | `kubernetes-router` | exposes apps through ingress-nginx |
| ingress-nginx | `ingress-nginx` | ingress controller, class `tsuru-nginx` |

There is no Redis or any queue service: tsuru keeps everything in MongoDB. MongoDB, the
registry and ingress-nginx can each be disabled (`mongodb.enabled`, `registry.enabled`,
`ingress-nginx.enabled=false`) when you bring your own.

Because `tsurud` runs inside the cluster it manages, it registers that cluster by itself: on
the first start with no clusters configured it creates a cluster named `local` (default, with
`disable-default-node-selector=true`) and a default pool also named `local`. You do not need
`tsuru cluster add` or `tsuru pool add` to get started. See
[Managing clusters](../admin_guides/managing_clusters.md) and
[Managing pools](../admin_guides/managing_pools.md) for the full picture.

On minikube the chart also enables `registryAliases`, a DaemonSet that adds
`tsuru-registry.tsuru-system.svc.cluster.local` to each node's `/etc/hosts`, so the kubelet can
pull app images from the in-cluster registry by its service name.

## Install tsuru

``` bash
helm repo add tsuru https://tsuru.github.io/charts
helm repo update

helm install tsuru tsuru/tsuru-stack --create-namespace --namespace tsuru-system
```

Wait until every pod in `tsuru-system` is `Running`:

``` bash
kubectl get pods -n tsuru-system -w
```

## Create the first administrator

``` bash
kubectl exec -it -n tsuru-system deploy/tsuru-api -- tsurud root-user-create admin@example.com
```

Use your own e-mail. The command prompts for a password and gives the user every permission,
see [Authentication](../admin_guides/authentication.md#bootstrapping-the-first-administrator).

## Reach the API and the apps

Port-forward the API server and the ingress controller:

``` bash
kubectl port-forward --namespace tsuru-system svc/tsuru-api 8080:80 &
kubectl port-forward --namespace tsuru-system svc/tsuru-ingress-nginx-controller 8890:80 &
```

Apps get addresses under `cloud.127.0.0.1.nip.io:8890` (`kubernetes-router.ingressExpose`
in the chart values). If you change the port there, change the port-forward too.

Add the target and log in:

``` bash
tsuru target add default http://localhost:8080 -s
tsuru login admin@example.com
```

## Create a team and install platforms

``` bash
tsuru team create admin
tsuru platform add python
tsuru platform add go
```

Platforms are built inside the cluster by deploy-agent; see
[Managing platforms](../admin_guides/managing_platforms.md) and the
[platforms overview](../user_guides/platforms.md).

## Deploy a test app

``` bash
git clone https://github.com/tsuru/platforms.git
cd platforms/examples/go
tsuru app create example-go go
tsuru app deploy -a example-go .
tsuru app info -a example-go
```

Open the address shown by `app info` in your browser.
