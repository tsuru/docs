# Running development environment with Docker Compose

This guide will provide step-by-step instructions on how to set up and run a minimal Tsuru environment for building and testing Tsuru on your local machine.

## Pre-requisites

In order to follow this guide, you need to install and configure properly each tool listed below on your machine.

0. [git][Git - Install]
1. [Docker][Docker - Install] (or [podman][Podman - Install])
2. [Docker Compose][Docker Compose - Install]
3. [Minikube][Minikube - Getting started] (or other similar tools such as [kind][kind - Getting started], [k3s][k3s - Getting started], etc)
4. [tsuru](/docs/user_guides/install_client) (Tsuru CLI)
5. [yq][yq - Install]

You also need to checkout the [Tsuru][Tsuru's repository]'s source code from GitHub.

``` bash
git clone https://github.com/tsuru/tsuru.git
cd tsuru
```

Notice: All the following commands are executed within the `tsuru`'s root directory.

## Running Tsuru service components

First of all, you must prepare the Docker Compose execution by running:
``` bash
./misc/setup-docker-compose.sh
source .env
```

This command plays a important role by configuring network interfaces and generating config files according to your setup, so you are able to up/down services easily with Docker Compose commands.

To run all Tsuru service components in background mode, run:

``` bash
docker-compose up -d
```

If everything goes well, you have a fresh installation of Tsuru.

Now, we should create an admin user which is able to manage Tsuru's stuff from `tsuru` CLI.
For the purpose of this guide, the admin user will be identified as `admin@example.com`.
However, feel free to use your own email if you prefer.

``` bash
docker-compose exec tsuru-api tsurud root user create admin@example.com
# it will prompt you to create an password
```

Point your Tsuru CLI to use the current local installation and authenticate using the root user created above.

``` bash
tsuru target add --set-current development http://${TSURU_HOST_IP}:8080

tsuru login admin@example.com
# it will prompt you to fill the user password
```

## Integrate with local Kubernetes cluster

Create a local Kubernetes cluster making sure that the local container registry is trusted (it will be used to store Tsuru app/job's container images).

``` bash
minikube start --insecure-registry="${TSURU_HOST_IP}:5000"
```

After that, you should register this Kubernetes cluster as Tsuru cluster:

``` bash
KUBECONFIG=~/.kube/config # assuming minikube is using the default kubeconfig

tsuru cluster add my-cluster kubernetes \
    --addr       $(yq -r '.clusters[] | select(.name == "minikube") | .cluster.server' ${KUBECONFIG}) \
    --cacert     $(yq -r '.clusters[] | select(.name == "minikube") | .cluster["certificate-authority"]' ${KUBECONFIG}) \
    --clientcert $(yq -r '.users[] | select(.name == "minikube") | .user["client-certificate"]' ${KUBECONFIG}) \
    --clientkey  $(yq -r '.users[] | select(.name == "minikube") | .user["client-key"]' ${KUBECONFIG}) \
    --custom "registry=${TSURU_HOST_IP}:5000/tsuru" \
    --custom "registry-insecure=true" \
    --custom "build-service-address=dns:///${TSURU_HOST_IP}:8000" \
    --custom "build-service-tls=false" \
    --default
```

Click [here](https://docs.tsuru.io/stable/managing/clusters.html) to read more about Tsuru clusters.

Now, you have everything to run Tsuru locally. Happy hacking.

## Cleaning up

!!! warning "WARNING"

    Keep in mind that following this steps remove everything you did before and cannot be undone.

Logout and remove the Tsuru `development` target.

``` bash
tsuru logout
tsuru target remove development
```

Shutting down Docker Compose services:

``` bash
docker-compose down --volumes --rmi all
```

Removing the local Kubernetes cluster:

```
minikube delete --all
```


## Useful resources

* [Managing teams](/docs/admin_guides/managing_teams)
* [Managing pools](https://docs.tsuru.io/stable/managing/using-pools.html#adding-a-pool)
* [Managing users and permissions](https://docs.tsuru.io/stable/managing/users-and-permissions.html)
* [Managing platforms](https://docs.tsuru.io/stable/managing/create-platform.html)
* Deploy an app:
    * [Deploy an app with Dockerfile](/docs/user_guides/deploy_using_dockerfile/)

## FAQ

### How do I rebuild the Tsuru API after changing its source code?

During the development cycle, you can rebuild and relaunch the Tsuru API with your changes.
To do so, just run the code below:

``` bash
docker-compose up --build tsuru-api
```

## Troubleshooting

### I'm not able to register my Kubernetes cluster as Tsuru cluster

Tsuru requires to reach the Kubernetes (apiserver), so you need to make sure that Kubernetes is accessible from Tsuru's container network.
You can test the connectivity by running it from Tsuru:

``` bash
KUBECONFIG=~/.kube/config
KUBERNETES_ADDRESS=$(yq -r '.clusters[] | select(.name == "minikube") | .cluster.server' ${KUBECONFIG})

docker-compose exec tsuru-api wget --no-check-certificate -qO- ${KUBERNETES_ADDRESS}/healthz
```

If you don't see an output like `ok` as result of the above command, you might need to create your cluster using a bridge network.
Please follow to Minikube's documentation to know how to do that.

[git - Install]: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
[Tsuru's repository]: https://github.com/tsuru/tsuru.git
[Docker - Install]: https://docs.docker.com/engine/install
[Podman - Install]: https://podman.io/docs/installation
[Docker Compose - Install]: https://docs.docker.com/compose/install
[Minikube - Getting started]: https://minikube.sigs.k8s.io/docs/start
[kind - Getting started]: https://kind.sigs.k8s.io/
[k3s - Getting started]: https://k3s.io/
[yq - Install]: https://github.com/mikefarah/yq#install
