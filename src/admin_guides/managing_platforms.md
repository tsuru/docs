# Managing platforms

A platform is a well defined pack with installed dependencies for a language or
framework that a group of applications will need.

## Installing the tsuru's platforms


Platforms are defined as Dockerfiles and tsuru already have a number of supported ones listed below:

- [Go](https://github.com/tsuru/platforms/tree/master/go)
- [Python](https://github.com/tsuru/platforms/tree/master/python)
- [Java](https://github.com/tsuru/platforms/tree/master/java)
- [NodeJS](https://github.com/tsuru/platforms/tree/master/nodejs)
- [PHP](https://github.com/tsuru/platforms/tree/master/php)
- [Ruby](https://github.com/tsuru/platforms/tree/master/ruby)
- [Static](https://github.com/tsuru/platforms/tree/master/static)


These platforms don't come pre-installed in tsuru, you have to add them to your
server using the `platform add` command.

For example, to install the Python platform from tsuru's platforms repository
you simply have to call:

```bash
tsuru platform add python
```

If your application is not currently supported by the platforms above,
you can create a new platform. See :doc:`creating a platform</managing/create-platform>`
for more information.


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

Every platform in the [repository](https://github.com/tsuru/platforms)
extends the base-platform adding the specifics of each platform. They
are a great way to learn how to create a new one.

### An example

Let's suppose we wanted to create a nodejs platform. First, let's
define it's Dockerfile:

``` bash
FROM    tsuru/base-platform
ADD . /var/lib/tsuru/nodejs
RUN cp /var/lib/tsuru/nodejs/deploy /var/lib/tsuru
RUN /var/lib/tsuru/nodejs/install
```

In this file, we are extending the `tsuru/base-platform`, adding our
deploy and install scripts to the right place: `/var/lib/tsuru`.

The install script runs when we add or update the platform on tsuru.
It's the perfect place to install dependencies that every application
on it's platform needs:

``` bash
#!/bin/bash -le

SOURCE_DIR=/var/lib/tsuru
source ${SOURCE_DIR}/base/rc/config

apt-get update
apt-get install git -y
git clone https://github.com/creationix/nvm.git /etc/nvm
cd /etc/nvm && git checkout `git describe --abbrev=0 --tags`

cat >> ${HOME}/.profile <<EOF
if [ -e ${HOME}/.nvm_bin ]; then
    export PATH="${HOME}/.nvm_bin:$PATH"
fi
EOF
```

As it can be seen, we are just installing some dependencies and
preparing the environment for our applications. The
`${SOURCE_DIR}/base/rc/config` provides some bootstrap configuration
that are usually needed.

Now, let's define our deploy script, which runs every time a deploy
occurs:

``` bash
#!/bin/bash -le

SOURCE_DIR=/var/lib/tsuru
source ${SOURCE_DIR}/base/rc/config
source ${SOURCE_DIR}/base/deploy

export NVM_DIR=${HOME}/.nvm
[ ! -e ${NVM_DIR} ] && mkdir -p ${NVM_DIR}

. /etc/nvm/nvm.sh

nvm install stable

rm -f ~/.nvm_bin
ln -s $NVM_BIN ~/.nvm_bin

if [ -f ${CURRENT_DIR}/package.json ]; then
    pushd $CURRENT_DIR && npm install --production
    popd
fi
```

Once again we run some base scripts to do some heavy lifting:
`${SOURCE_DIR}/base/rc/config` and `${SOURCE_DIR}/base/deploy`. After
that, it's just a matter of application specifics dependencies using
npm.

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
