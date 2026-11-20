# Deploy React.js and other static sites

## Overview

A React build is just static files. tsuru serves them with the [`static` platform](platforms.md),
an nginx setup that serves whatever is in the deployed directory. The flow has two steps on your
machine (build the site) and one on tsuru (deploy the build directory).

## Creating the app

``` bash
tsuru app create <app-name> static
```

## Build

Generate the production build with your toolchain, for example:

``` bash
npm run build
```

## Deploy

Add two files to the build directory and deploy it. The examples below work for most
single-page apps: `nginx.conf` rewrites unknown paths to `index.html`, `tsuru.yml` declares the
healthcheck.

``` bash
cd build
wget https://raw.githubusercontent.com/tsuru/platforms/refs/heads/master/examples/static-reactjs/nginx.conf
wget https://raw.githubusercontent.com/tsuru/platforms/refs/heads/master/examples/static-reactjs/tsuru.yml
tsuru app deploy -a <app-name> .
```

## Customizing nginx

- **`nginx.conf`** in the deployed root replaces the platform's default
  [`nginx.conf`](https://github.com/tsuru/platforms/blob/master/static/etc/nginx.conf). Start from a
  copy of it: it contains directives tsuru relies on, such as `port_in_redirect off` and listening on
  `PORT`. The platform validates the file with `nginx -t` during the deploy.
- **`NGINX_PKG`** picks the Ubuntu nginx flavour installed at deploy time: `nginx` (default),
  `nginx-core`, `nginx-full`, `nginx-light` or `nginx-extras`. Any other value fails the deploy.

    ``` bash
    tsuru env set -a <app-name> NGINX_PKG=nginx-extras
    ```
