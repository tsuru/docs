# Platforms overview

A platform is the base image a source-files deploy builds on. It brings the language runtime and a
`/var/lib/tsuru/deploy` script that installs your dependencies and, where needed, compiles your code.
When you run `tsuru app deploy -a <app> .`, deploy-agent copies your files on top of the platform
image and runs that script (see [Deploying](deploying.md#what-happens-during-a-deploy)). Apps deployed with
`--dockerfile` or `--image` do not use a platform at all.

Platforms are installed by administrators with `tsuru platform add <name>`
([Managing platforms](../admin_guides/managing_platforms.md)); `tsuru platform list` shows the ones
available on your installation. The official images live in
[tsuru/platforms](https://github.com/tsuru/platforms) and are published to Docker Hub as `tsuru/<name>`.
Every one is based on `tsuru/base-platform:24.04` (Ubuntu 24.04), except `buildpack` which is based
on herokuish.

## Official platforms

| Platform | Picks the runtime version from | Installs dependencies from | Notes |
|---|---|---|---|
| [`go`](https://github.com/tsuru/platforms/tree/master/go) | `GO_VERSION` env var, then the `go` directive in `go.mod` (closest stable match), else latest | `go mod download` | [guide](deploy_go_apps.md); default Procfile `web: ./tsuru-app` |
| [`python`](https://github.com/tsuru/platforms/tree/master/python) | `Pipfile.lock` > `poetry.lock` > `uv.lock` > `PYTHON_VERSION` > `.python-version` > latest 3.x | `poetry.lock`, `uv.lock`, `Pipfile.lock`, `requirements.txt` or `setup.py` | [guide](deploy_python_apps.md) |
| [`nodejs`](https://github.com/tsuru/platforms/tree/master/nodejs) | `.nvmrc` > `.node-version` > `engines.node` in `package.json` > current LTS | `yarn.lock` (yarn) else `package.json` (npm) | [guide](deploy_nodejs_apps.md) |
| [`static`](https://github.com/tsuru/platforms/tree/master/static) | n/a (nginx from Ubuntu, `NGINX_PKG` selects the flavour) | none | serves the deployed directory; [guide](deploy_react_apps.md) |
| [`ruby`](https://github.com/tsuru/platforms/tree/master/ruby) | `RUBY VERSION` in `Gemfile.lock` > `.ruby-version` > 3.1.6 | `Gemfile` via bundler | `RUBY_REPO`, `GEM_SOURCE` env vars for mirrors |
| [`java`](https://github.com/tsuru/platforms/tree/master/java) | platform image | `pom.xml` via maven, or a prebuilt jar | default Procfile starts Tomcat; `JAVA_MAX_MEMORY` |
| [`php`](https://github.com/tsuru/platforms/tree/master/php) | `php.version` in `tsuru.yaml` (8.2 to 8.5 installed) | `composer.json` when `php.composer` is true | frontend `apache`/`nginx`, interpreter `fpm`/`mod_php`, `php.extensions` list |
| [`perl`](https://github.com/tsuru/platforms/tree/master/perl) | platform image | `cpanfile.snapshot` > `cpanfile` via carton | |
| [`lua`](https://github.com/tsuru/platforms/tree/master/lua) | platform image (Lua 5.3) | `tsuru-1.0-1.rockspec` via luarocks | |
| [`ballerina`](https://github.com/tsuru/platforms/tree/master/ballerina) | platform image (Swan Lake 2201.13.1) | `bal build` | |
| [`buildpack`](https://github.com/tsuru/platforms/tree/master/buildpack) | detected by the buildpack | Heroku buildpacks through herokuish | for stacks without a dedicated platform |
| [`scratch`](https://github.com/tsuru/platforms/tree/master/scratch) | n/a | none | bare Ubuntu, for shipping prebuilt binaries with a Procfile |

Each platform's README in the repository is the authoritative description of its environment
variables and files; the table summarizes them as of November 2026.

## What every platform supports

- **Procfile** and **tsuru.yaml** as described in [Procfile](procfile.md) and [tsuru.yaml](tsuru_yaml.md).
  The deploy script copies a default Procfile when your code has none and `tsuru.yaml` has no `processes:`.
- **`requirements.apt`**: a list of Ubuntu packages, one per line, installed with `apt-get` before
  the platform's own steps. **`repositories.apt`** adds extra APT sources first. Both are handled by
  `base-platform`, so they work on every platform above except `buildpack`.
- **Build hooks**: `hooks.build` entries from tsuru.yaml run after the platform script.
- **Env vars at build time**: your app's environment variables are available to the deploy script,
  which is how the `*_VERSION` and mirror variables in the table are read.
