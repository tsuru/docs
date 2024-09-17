# Deploy Node.js applications


## Overview

Node.js is a widely recognized runtime, known for its ease of use, low learning curve, and large community. Deploying a Node.js application on Tsuru is an effortless task. You should have a package.json, Procfile, and tsuru.yaml.


## Creating the app

To create an app, you use the command app create:

``` bash
$ tsuru app create <app-name> <app-platform>
```

For NodeJS, the app platform is, guess what, nodejs! Let’s be over creative and develop a never-developed tutorial-app: a myapp

``` bash
$ tsuru app create myapp nodejs
```

## Application code

Basically we need to write 3 files and put on project directory: Procfile, package.json and tsuru.yaml

### Procfile

This file is useful to identify how to execute your application, each line represents a tsuru process, usually process named web is responsabile to receive requests, important NOTE the app may listen requests following PORT envvar OR use the default port 8888

```
web: node app.js
```

### package.json

This file is used to pick your nodejs version and install your dependencies.

```
{
  "name": "hello-world",
  "description": "hello world test on tsuru",
  "version": "0.0.1",
  "private": true,
  "dependencies": {
    "express": "4.21.x"
  },
  "engines": {
    "node": "20.17.0"
  }
}
```

### package-lock.json (strong recommended)

The package-lock.json file is crucial in Node.js projects for ensuring consistent and reproducible builds. Here's why generating and maintaining this file is important: ensures consistent dependency versions, speeds Up installations and improves security

## yarn.lock (optional)

first we check if there is a `yarn.lock` file in the root of your files. If so, we use [yarn](https://yarnpkg.com/); otherwise, we use [npm](https://www.npmjs.com/package/npm).

### tsuru.yaml

tsuru.yaml is used to tsuru specific settings, this may be the initial settings:

```
healthcheck:
  path: /
```

### Operating system dependencies: requirements.apt (optional)

list of ubuntu dependencies that will be installed, useful to install tools required for build process

example:
```
gcc
```


## Deploy application

Let's deploy our application with command

```
tsuru app deploy -a myapp .
```

## Install development dependencies

If you want to also install development dependencies, set the environment variable NPM_CONFIG_PRODUCTION=false

example:

```
tsuru env set -a myapp NPM_CONFIG_PRODUCTION=false
```

## package.json, .nvmrc or .node-version

The platform looks for desired node.js version in three places: .nvmrc, .node-version and package.json, the first value encountered will be used to instal the target version.