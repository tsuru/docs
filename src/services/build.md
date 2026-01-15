# Building your service

This guide shows how to turn your existing cloud service into a tsuru service.

## Overview

To create a service you need to:

1. Implement a provisioning API that tsuru will call via HTTP
2. Create a YAML manifest file describing your service

## Creating your service API

You can use any programming language or framework. This tutorial uses [Flask](http://flask.pocoo.org).

### Authentication

tsuru uses basic authentication. See the [service API workflow](api.md) for details.

For Flask, you can use the decorator from this [Flask snippet](http://flask.pocoo.org/snippets/8/).

### Prerequisites

```bash
$ pip install flask
```

### Minimal Flask application

Create `api.py`:

```python
from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello World!"

if __name__ == "__main__":
    app.run()
```

Run with:

```bash
$ python api.py
 * Running on http://127.0.0.1:5000/
```

### Listing available plans

**Endpoint:** `GET /resources/plans`

```python
import json

@app.route("/resources/plans", methods=["GET"])
def plans():
    plans = [
        {"name": "small", "description": "small instance"},
        {"name": "medium", "description": "medium instance"},
        {"name": "big", "description": "big instance"},
        {"name": "giant", "description": "giant instance"}
    ]
    return json.dumps(plans)
```

### Creating new instances

**Endpoint:** `POST /resources`

```python
from flask import request

@app.route("/resources", methods=["POST"])
def add_instance():
    name = request.form.get("name")
    plan = request.form.get("plan")
    team = request.form.get("team")
    # use the given parameters to create the instance
    return "", 201
```

### Updating service instances

**Endpoint:** `PUT /resources/<name>` (optional)

```python
@app.route("/resources/<name>", methods=["PUT"])
def update_instance(name):
    description = request.form.get("description")
    tags = request.form.get("tag")
    team = request.form.get("team")
    plan = request.form.get("plan")
    # use the given parameters to update the instance
    return "", 200
```

### Binding instances to apps

**Endpoint:** `POST /resources/<name>/bind-app`

```python
import json
from flask import request

@app.route("/resources/<name>/bind-app", methods=["POST"])
def bind_app(name):
    app_host = request.form.get("app-host")
    # use name and app_host to bind the service instance and the application
    envs = {"SOMEVAR": "somevalue"}
    return json.dumps(envs), 201
```

### Unbinding instances from apps

**Endpoint:** `DELETE /resources/<name>/bind-app`

```python
@app.route("/resources/<name>/bind-app", methods=["DELETE"])
def unbind_app(name):
    app_host = request.form.get("app-host")
    # use name and app-host to remove the bind
    return "", 200
```

### Whitelisting units

**Endpoint:** `POST/DELETE /resources/<name>/bind`

Handle access control when units are added or removed:

```python
@app.route("/resources/<name>/bind", methods=["POST", "DELETE"])
def access_control(name):
    app_host = request.form.get("app-host")
    unit_host = request.form.get("unit-host")
    # use unit-host and app-host for access control
    return "", 201
```

### Removing instances

**Endpoint:** `DELETE /resources/<name>`

```python
@app.route("/resources/<name>", methods=["DELETE"])
def remove_instance(name):
    # remove the instance named "name"
    return "", 200
```

### Checking the status of an instance

**Endpoint:** `GET /resources/<name>/status`

```python
@app.route("/resources/<name>/status", methods=["GET"])
def status(name):
    # check the status of the instance named "name"
    return "", 204
```

### Complete example

```python
import json
from flask import Flask, request

app = Flask(__name__)


@app.route("/resources/plans", methods=["GET"])
def plans():
    plans = [
        {"name": "small", "description": "small instance"},
        {"name": "medium", "description": "medium instance"},
        {"name": "big", "description": "big instance"},
        {"name": "giant", "description": "giant instance"}
    ]
    return json.dumps(plans)


@app.route("/resources", methods=["POST"])
def add_instance():
    name = request.form.get("name")
    plan = request.form.get("plan")
    team = request.form.get("team")
    return "", 201


@app.route("/resources/<name>/bind-app", methods=["POST"])
def bind_app(name):
    app_host = request.form.get("app-host")
    envs = {"SOMEVAR": "somevalue"}
    return json.dumps(envs), 201


@app.route("/resources/<name>/bind-app", methods=["DELETE"])
def unbind_app(name):
    app_host = request.form.get("app-host")
    return "", 200


@app.route("/resources/<name>", methods=["DELETE"])
def remove_instance(name):
    return "", 200


@app.route("/resources/<name>/bind", methods=["POST", "DELETE"])
def access_control(name):
    app_host = request.form.get("app-host")
    unit_host = request.form.get("unit-host")
    return "", 201


@app.route("/resources/<name>/status", methods=["GET"])
def status(name):
    return "", 204


if __name__ == "__main__":
    app.run()
```

## Creating a service manifest

Generate a template with:

```bash
$ tsuru service-template
```

This creates `manifest.yaml`:

```yaml
id: servicename
password: abc123
endpoint:
  production: production-endpoint.com
```

Update with your service details:

```yaml
id: servicename
username: username_to_auth
password: 1CWpoX2Zr46Jhc7u
endpoint:
  production: production-endpoint.com
  test: test-endpoint.com:8080
```

## Submitting your service API

Submit your service with:

```bash
$ tsuru service-create manifest.yaml
```

For more details, see the [service API workflow](api.md) and the [tsuru-client service management reference](https://tsuru-client.readthedocs.io/en/latest/reference.html#service-management).
