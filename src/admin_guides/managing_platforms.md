# Managing platforms

A platform is a well defined pack with installed dependencies for a language or
framework that a group of applications will need. Each platform is a Docker
image built from a Dockerfile; tsuru keeps every built version and uses the
latest one as the base image of application deploys.

## Installing the tsuru's platforms

Platforms are defined as Dockerfiles and tsuru already have a number of supported ones listed below:

- [Go](https://github.com/tsuru/platforms/tree/master/go)
- [Python](https://github.com/tsuru/platforms/tree/master/python)
- [Java](https://github.com/tsuru/platforms/tree/master/java)
- [NodeJS](https://github.com/tsuru/platforms/tree/master/nodejs)
- [PHP](https://github.com/tsuru/platforms/tree/master/php)
- [Ruby](https://github.com/tsuru/platforms/tree/master/ruby)
- [Perl](https://github.com/tsuru/platforms/tree/master/perl)
- [Lua](https://github.com/tsuru/platforms/tree/master/lua)
- [Ballerina](https://github.com/tsuru/platforms/tree/master/ballerina)
- [Static](https://github.com/tsuru/platforms/tree/master/static) (nginx)
- [Buildpack](https://github.com/tsuru/platforms/tree/master/buildpack) (Heroku-style buildpacks)
- [Scratch](https://github.com/tsuru/platforms/tree/master/scratch) (runs a prebuilt binary)

These platforms don't come pre-installed in tsuru, you have to add them to your
server using the `platform add` command.

For example, to install the Python platform from tsuru's platforms repository
you simply have to call:

```bash
tsuru platform add python
```

Without flags the client uses the official `tsuru/<name>` image from Docker
Hub. Use `-i` for an image hosted elsewhere, or `-d` for a Dockerfile (local
path or `http(s)` URL):

```bash
tsuru platform add python -i registry.company.com/tsuru/python
tsuru platform add python -d https://raw.githubusercontent.com/tsuru/platforms/master/python/Dockerfile
tsuru platform add python -d ./python/Dockerfile
```

`-i` and `-d` are mutually exclusive. Either way the server receives a
Dockerfile (`-i` becomes a one-line `FROM <image>`) and builds it, so the
platform image always lives in your own registry.

If your application is not currently supported by the platforms above,
you can create a new platform. See [creating a platform from scratch](#creating-a-platform-from-scratch)
for more information.

## How platform images are built

Platform builds run inside your Kubernetes clusters through the deploy-agent
build service configured on each cluster (`build-service-address`). tsuru
builds the image once per distinct registry across all clusters and pushes it
as `<registry>/<namespace>/<platform>:vN`, incrementing `N` on every build.
A cluster is skipped when it has no registry configured or when its custom data
sets `disable-platform-build: true` (see
[managing clusters](managing_clusters.md)); the command output lists the
skipped clusters. If no cluster builds the image, the command fails with
`no kubernetes nodes available`.

## Listing and inspecting platforms

```bash
tsuru platform list
tsuru platform info python
```

`platform list` shows each platform's name and status (`enabled` or
`disabled`); `platform info` adds the list of built image versions, newest
first. Both accept `--json`.

Users with `platform.create` or `platform.update` also see a `Source` column
when one is recorded: the Dockerfile the platform was last built from (since
tsuru 1.34). Users without those permissions never see the source (a Dockerfile
can name internal registries) and do not see disabled platforms at all.

## Updating a platform

```bash
tsuru platform update python                          # rebuild from the stored source
tsuru platform update python -i registry.company.com/tsuru/python
tsuru platform update python -d ./python/Dockerfile
```

Every update with `-i` or `-d` builds a new image version and records the
Dockerfile as the platform's source. Since tsuru 1.34 an update with no flags
rebuilds from that stored source, which is how you pick up a newer base image
or a new upstream `tsuru/<name>` tag without repeating the flags. When the
server has no source recorded (platform created before 1.34, or an older
server), the client falls back to the official `tsuru/<name>` image.

After a successful build every application on that platform is flagged so that
its next deploy is built on top of the new platform image instead of reusing
the previous application image.

### Disabling a platform

```bash
tsuru platform update python --disable
tsuru platform update python --enable
```

A disabled platform keeps working for the apps already on it. It is hidden
from `platform list` for regular users, and `app create`/`app update
--platform` reject it unless the caller holds `platform.create` or
`platform.update`. Use it to retire a platform gradually.

### Pinning an app to a platform version

Applications use the latest platform image by default. To build an app on a
specific version, pass `<platform>:vN` where `platform info` lists that
version:

```bash
tsuru app update -a myapp --platform python:v3
```

tsuru validates that the version exists in the app's registry.

## Removing a platform

```bash
tsuru platform remove python
```

Removal is refused while any application still uses the platform
(`Platform has apps. You must remove them before remove the platform.`). Move
those apps with `tsuru app update --platform` or remove them first.

## Creating a platform from scratch

### Overview

If you need a platform that's not already available in our [platforms
repository](https://github.com/tsuru/platforms) it's pretty easy to
create a new one based on an existing one.

Platforms are Docker images that are used to deploy your application
code on tsuru. tsuru provides a base image which platform developers can
use to build upon:
[base-platform](https://github.com/tsuru/base-platform). This platform
provides a base deployment script, which handles package downloading and
extraction in proper path, along with operating system package
management.

The only contract with tsuru is the executable `/var/lib/tsuru/deploy`, run
inside the image on every deploy. Every platform in the [repository](https://github.com/tsuru/platforms)
extends the base-platform adding the specifics of each platform. They
are a great way to learn how to create a new one.

### An example

Let's suppose we wanted to create a platform. First, let's define its
Dockerfile, following the layout of the official ones:

``` dockerfile
FROM tsuru/base-platform:24.04
COPY . /var/lib/tsuru/myplatform
RUN set -ex \
    && sudo /var/lib/tsuru/myplatform/install \
    && sudo rm -rf /var/lib/tsuru/myplatform/install /var/lib/apt/lists/* \
    && sudo cp /var/lib/tsuru/myplatform/deploy /var/lib/tsuru
```

In this file, we are extending the `tsuru/base-platform`, copying our
platform directory into `/var/lib/tsuru/myplatform`, running its `install`
script and placing the `deploy` script at `/var/lib/tsuru/deploy`, where
tsuru expects it. The base image runs as an unprivileged user, hence `sudo`.

The install script runs when we add or update the platform on tsuru.
It's the perfect place to install dependencies that every application
on its platform needs:

``` bash
#!/bin/bash -e

SOURCE_DIR=/var/lib/tsuru
source ${SOURCE_DIR}/base/rc/config

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl build-essential
```

As it can be seen, we are just installing some dependencies and
preparing the environment for our applications. The
`${SOURCE_DIR}/base/rc/config` provides some bootstrap configuration
that are usually needed.

Now, let's define our deploy script, which runs every time a deploy
occurs:

``` bash
#!/bin/bash -el

SOURCE_DIR=/var/lib/tsuru
source ${SOURCE_DIR}/base/rc/config
source ${SOURCE_DIR}/base/deploy

if [ -f ${CURRENT_DIR}/requirements.txt ]; then
    pushd ${CURRENT_DIR} && pip install -r requirements.txt
    popd
fi
```

Once again we run some base scripts to do some heavy lifting:
`${SOURCE_DIR}/base/rc/config` and `${SOURCE_DIR}/base/deploy`, which leave
the application code in `${CURRENT_DIR}`. After that, it's just a matter of
application specifics dependencies. The
[scratch](https://github.com/tsuru/platforms/tree/master/scratch) platform is
exactly this deploy script with nothing else, and the
[python](https://github.com/tsuru/platforms/tree/master/python) one shows a
complete install/deploy pair.

Now, we can move on and add our newly created platform.

### Adding your platform to tsuru

After creating you platform as a Dockerfile, you can add it to tsuru
using the client:

``` bash
$ tsuru platform add your-platform-name --dockerfile http://url-to-dockerfile
```

If you push your image to an Docker Registry, you can use:

``` bash
$ tsuru platform add your-platform-name -i your-user/image-name
```
