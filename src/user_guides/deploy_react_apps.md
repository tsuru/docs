# Deploy React.js Applications


## Overview

The major advantage of React applications is that are just static files to serve to a browser, react.js has its build process that generates .js, .css, and index.html files ready to deploy, cause of this concept we divide the process into three phases: Creating the app, build and deploy


## Creating the app

To create an app, you use the command app create:

``` bash
$ tsuru app create <app-name> static
```

## Build

Let's create an app using a well-known guide: https://github.com/facebook/create-react-app


After creating, let's generate a build directory using the following:

``` bash
$ npm run build
```


## Deploy

Well, now we have the build directory with all static files, the next step is to add two files to the build directory: tsuru.yml and nginx.conf, both are suggestions that work for most react apps:

``` bash
$ cd build
$ wget https://raw.githubusercontent.com/tsuru/platforms/refs/heads/master/examples/static-reactjs/nginx.conf
$ wget https://github.com/tsuru/platforms/blob/master/examples/static-reactjs/tsuru.yml
$ tsuru app deploy -a <app-name> .
```