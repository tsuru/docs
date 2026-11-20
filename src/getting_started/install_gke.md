---
title: Installing Tsuru on Google Kubernetes Engine cluster with Helm
---

# Installing Tsuru on Google Kubernetes Engine cluster with Helm {#installing_tsuru_gke}

This guide installs tsuru on GKE with the `tsuru-stack` Helm chart. You need `gcloud`, `kubectl`,
`helm` and the [tsuru client](../user_guides/install_client.md) installed.

## Create the cluster

``` bash
gcloud container clusters create tsuru-cluster \
  --image-type=COS_CONTAINERD --machine-type=e2-standard-4 --num-nodes=2 \
  --zone=$YOUR_PREFERRED_ZONE
gcloud container clusters get-credentials tsuru-cluster --zone=$YOUR_PREFERRED_ZONE
```

## What the chart installs

The chart and its dependencies are described in the
[minikube guide](install_minikube.md#what-the-chart-installs): tsuru-api, MongoDB, a container
registry, deploy-agent with BuildKit, kubernetes-router and ingress-nginx. On GKE the API and the
ingress controller get `LoadBalancer` services with public IPs. `tsurud` registers the cluster it
runs in as cluster `local` with a default pool `local` on first start, so no `cluster add` is needed.

!!! warning "Registry"

    The bundled registry speaks plain HTTP inside the cluster. The chart tells BuildKit and
    tsuru to treat it as insecure, and the `registryAliases` DaemonSet rewrites `/etc/hosts` on
    every node so the kubelet resolves `tsuru-registry.tsuru-system.svc.cluster.local`. This is
    fine for a trial. For anything else disable it (`--set registry.enabled=false`) and point
    `tsuru-api.tsuruConfig.clusters.defaults.registry` at Artifact Registry or another TLS
    registry, with `registry-insecure` removed.

## Install tsuru

``` bash
helm repo add tsuru https://tsuru.github.io/charts
helm repo update

helm install tsuru tsuru/tsuru-stack --create-namespace --namespace tsuru-system
```

Wait for the pods and for both load balancers to get an IP:

``` bash
kubectl get pods -n tsuru-system -w
kubectl get svc -n tsuru-system tsuru-api tsuru-ingress-nginx-controller
```

## Point the router at the ingress IP

Apps are published under a wildcard domain served by ingress-nginx. Set it to the controller's IP
with a `nip.io` name (or your own DNS zone):

``` bash
export NGINX_HOST=$(kubectl get svc -n tsuru-system tsuru-ingress-nginx-controller -o 'jsonpath={.status.loadBalancer.ingress[].ip}')
helm upgrade tsuru tsuru/tsuru-stack --namespace tsuru-system --reuse-values \
  --set kubernetes-router.ingressExpose.domain=cloud.$NGINX_HOST.nip.io \
  --set kubernetes-router.ingressExpose.port=80
```

## Create the first administrator and log in

``` bash
kubectl exec -it -n tsuru-system deploy/tsuru-api -- tsurud root-user-create admin@example.com

export TSURU_HOST=$(kubectl get svc -n tsuru-system tsuru-api -o 'jsonpath={.status.loadBalancer.ingress[].ip}')
tsuru target add gke http://$TSURU_HOST -s
tsuru login admin@example.com
```

The API is reachable over plain HTTP on a public IP at this point. Before real use put TLS in
front of it (`tsuru-api.service.httpsOnly`, or an ingress with a certificate) and switch to an
SSO scheme, see [Authentication](../admin_guides/authentication.md).

## Create a team, install platforms, deploy

``` bash
tsuru team create admin
tsuru platform add python
tsuru platform add go

git clone https://github.com/tsuru/platforms.git
cd platforms/examples/go
tsuru app create example-go go
tsuru app deploy -a example-go .
tsuru app info -a example-go
```
