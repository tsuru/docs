---
title: Installing Tsuru in a local Kubernetes cluster with Helm
---

# Installing Tsuru in a local Kubernetes cluster with Helm {#installing_tsuru_local}

This post will show how to install and configure Tsuru in a local
Kubernetes with Helm. All steps in this guide were done in Kubernetes
v1.24.0. While it might work for almost all Kubernetes versions, some
versions may break something. Feel free to report us in that case. You
need to have both minikube and kubectl previously installed on your
machine, if you don\'t have it yet, you can install it
[here](https://minikube.sigs.k8s.io/docs/start/), with minikube and
[kubectl](https://kubernetes.io/docs/tasks/tools/) properly installed,
let\'s get started. To create a local Kubernetes cluster using minikube,
run the command:

``` bash
$ minikube start —-kubernetes-version=v1.24.0
```

This example we use the docker driver to create a vm. If you want to use
another driver see [minikube supported
drivers](https://minikube.sigs.k8s.io/docs/drivers/). In relation to the
\--kubernetes-version in the future we will have other versions
available.

## Hardware Requirements

-   2 CPUs or more
-   12GB of free memory
-   20GB of free disk space
-   Installing Helm

Download a release of the [Helm
client](https://github.com/helm/helm/releases). With helm installed,
let\'s start

## Installing Tsuru

To install Tsuru and its dependencies we will use a helm chart

``` bash
$ helm repo add tsuru https://tsuru.github.io/charts
```

Now let\'s install the chart!

``` bash
$ helm install tsuru tsuru/tsuru-stack --create-namespace --namespace tsuru-system
```

Now you have tsuru installed!!

## Configuring Tsuru

Create the admin user on tsuru:

``` bash
$ kubectl exec -it -n tsuru-system deploy/tsuru-api -- tsurud root user create admin@admin.com# CHANGE IT TO YOUR ADMIN USER #
```

Use Port-forward to access tsuru and ingress controller:

Use to make a specific kubernetes api request. That means the system
running it needs access to the API server, and any traffic will get
tunneled over a single HTTP connection:

``` bash
$ kubectl port-forward --namespace tsuru-system svc/tsuru-api 8080:80 &
$ kubectl port-forward --namespace tsuru-system svc/tsuru-ingress-nginx-controller 8890:80 &
```

Obs: If you specified a port when you installed helm it will have to use
the same port in tsuru-ingress-nginx-controller.

Add the localhost to tsuru target and log in:

``` bash
$ tsuru target-add default https://localhost:8080 -s
$ tsuru login
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
