---
title: Installing Tsuru on Google Kubernetes Engine cluster with Helm
---

# Installing Tsuru on Google Kubernetes Engine cluster with Helm {#installing_tsuru_gke}

This post will show how to install and configure Tsuru on GKE with Helm.
All steps in this guide were done in Kubernetes v1.24.0. While it might
work for almost all Kubernetes versions, some versions may break
something. Feel free to report us in that case. You need to have both
gcloud and kubectl previously installed on your machine, if you don't
have it yet, you can install it
[here](https://cloud.google.com/sdk/docs/install/), with gcloud and
[kubectl](https://kubernetes.io/docs/tasks/tools/) properly installed,
let's get started. To create a Kubernetes cluster using gcloud, run the
command:

``` bash
$ gcloud beta container clusters create tsuru-cluster --image-type=COS --machine-type=e2-standard-4 --num-nodes "2" --zone=$YOUR_PREEFERED_ZONE
```

Download a release of the [Helm
client](https://github.com/helm/helm/releases). With helm installed,
let's start

## Installing Tsuru

To install Tsuru and its dependencies we will use a helm chart

``` bash
$ helm repo add tsuru https://tsuru.github.io/charts
```

Now let's install the chart!

``` bash
$ helm install tsuru tsuru/tsuru-stack --create-namespace --namespace tsuru-system
```

Now you have tsuru installed!!

## Configuring Tsuru

Create the admin user on tsuru:

``` bash
$ kubectl exec -it -n tsuru-system deploy/tsuru-api -- tsurud root user create admin@admin.com# CHANGE IT TO YOUR ADMIN USER #
```

Add the tsuru target and log in:

``` bash
$ export TSURU_HOST=$(kubectl get svc -n tsuru-system tsuru-api -o 'jsonpath={.status.loadBalancer.ingress[].ip}')
$ tsuru target-add gke http://$TSURU_HOST -s
$ tsuru login
```

Let's assign the correct IP to default router:

``` bash
$ export NGINX_HOST=$(kubectl get svc -n tsuru-system tsuru-ingress-nginx-controller -o 'jsonpath={.status.loadBalancer.ingress[].ip}')
$ helm upgrade tsuru tsuru/tsuru-stack --namespace tsuru-system -f values.yaml --set kubernetes-router.ingressExpose.domain=cloud.$NGINX_HOST.nip.io --set kubernetes-router.ingressExpose.port=80
```

Create one team:

``` bash
$ tsuru team create admin
```

Build Platforms:

``` bash
$ tsuru platform add python
$ tsuru platform add go
```

Create and Deploy tsuru-dashboard app:

``` bash
$ tsuru app create dashboard
$ tsuru app deploy -a dashboard --image tsuru/dashboard
```

Create an app to test:

``` bash
$ mkdir example-go
$ cd example-go
$ git clone https://github.com/tsuru/platforms.git
$ cd platforms/examples/go
$ tsuru app create example-go go
$ tsuru app deploy -a example-go .
```

Check the app info and get the url:

``` bash
$ tsuru app info -a example-go
```
