# Deploy Python apps

## Overview

Creating python applications with tsuru it is so easy. basically you need to maintain 3 files: Procfile, .python-version and requirements.txt


## Creating the app

To create an app, you use the command app create:

    ``` bash
    $ tsuru app create <app-name> <app-platform>
    ```

For Python, the app platform is, guess what, python! Let’s be over creative and develop a never-developed tutorial-app: a myapp

    ``` bash
    $ tsuru app create myapp python
    ```


## Application code

Basically we need to write 3 files and put on project directory: Procfile, .python-version and requirements.txt


### Procfile

This file is useful to identify how to execute your application, each line represents a tsuru process, usually process named web is responsabile to receive requests, important NOTE the app may listen requests following PORT envvar OR use the default port 8888

```
web: python app.py
```


### .python-version

This file is used to pick your version of python runtime.

```
3.9.1
```


### Python dependencies: requirements.txt

Is a well-known output of `pip freeze` command, use use this file to install all python dependencies on container

```
Flask==3.0.3
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
tsuru app deploy -a blog .
```