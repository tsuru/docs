# Deploy Node.js applications

## Overview

A Node.js app on tsuru needs a `package.json`, a `Procfile` and usually a `tsuru.yaml`. The
[`nodejs` platform](platforms.md) installs Node with nvm and your dependencies with npm or yarn.

## Creating the app

``` bash
tsuru app create myapp nodejs
```

## Application code

### Procfile

Each line is a tsuru process; `web` receives HTTP traffic and must listen on the `PORT` env var
(default `8888`). See [Procfile](procfile.md).

```
web: node app.js
```

### package.json

```json
{
  "name": "hello-world",
  "version": "0.0.1",
  "private": true,
  "dependencies": {
    "express": "4.21.x"
  },
  "engines": {
    "node": "22"
  }
}
```

### Node version

The platform reads the version from the first of these that exists: `.nvmrc`, `.node-version`,
`engines.node` in `package.json`. Any string nvm accepts works (`22`, `22.11.0`, `lts/jod`). With
none of them the platform installs the **current LTS** (`nvm install --lts`), which changes over
time, so pin a version for reproducible builds.

### Dependencies: npm or yarn

- With a `yarn.lock` the platform uses **yarn**. The yarn version comes from `engines.yarn`,
  `dependencies.yarn` or `devDependencies.yarn` in `package.json`, else a platform default. There is no
  pnpm support.
- Otherwise it runs `npm install`. Commit `package-lock.json` for reproducible installs.

Dependencies are installed with `--production` unless `NPM_CONFIG_PRODUCTION` is set to any value:

``` bash
tsuru env set -a myapp NPM_CONFIG_PRODUCTION=false
```

`node_modules` is kept between deploys when `package.json`, `package-lock.json` and `yarn.lock` did
not change, and always kept when `KEEP_NODE_MODULES` is set.

Mirrors: `NPM_REGISTRY` sets the package registry for npm and yarn (lockfile URLs are rewritten);
`NVM_NODEJS_ORG_MIRROR` sets where Node binaries are downloaded from.

### tsuru.yaml

Define the healthcheck so the router only sends traffic to ready units, see [tsuru.yaml](tsuru_yaml.md):

```yaml
healthcheck:
  path: /
```

### Operating system packages (optional)

`requirements.apt` lists Ubuntu packages, one per line, installed before `npm install`, for
example `gcc` for native modules.

## Deploy

``` bash
tsuru app deploy -a myapp .
```

A full working example is in
[tsuru/platforms `examples/nodejs`](https://github.com/tsuru/platforms/tree/master/examples/nodejs).
