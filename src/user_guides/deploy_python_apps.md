# Deploy Python apps

## Overview

A Python app on tsuru needs a `Procfile`, a dependency file and, optionally, a way to pin the
Python version. Everything else is handled by the [`python` platform](platforms.md).

## Creating the app

``` bash
tsuru app create myapp python
```

## Application code

### Procfile

Each line is a tsuru process; `web` receives HTTP traffic and must listen on the `PORT` env var
(default `8888`). See [Procfile](procfile.md).

```
web: gunicorn app:app
```

### Dependencies

The platform looks for these files in the project root, in this order, and uses the first one
found:

| File | Installed with | Version pin via |
|---|---|---|
| `poetry.lock` | `poetry install` | `PYTHON_POETRY_VERSION` |
| `uv.lock` | `uv sync` | `PYTHON_UV_VERSION`; honours `UV_INDEX_URL`/`UV_EXTRA_INDEX_URL` |
| `Pipfile.lock` | `pipenv install --system --deploy` | |
| `requirements.txt` | `pip install -r requirements.txt` | `PYTHON_PIP_VERSION` |
| `setup.py` | `pip install -e ./` | `PYTHON_PIP_VERSION` |

A minimal `requirements.txt`:

```
Flask==3.0.3
gunicorn==23.0.0
```

### Python version

The version is chosen from the first of these that is present:

1. `python_version` in `Pipfile.lock`
2. `python-versions` in `poetry.lock`
3. `requires-python` in `uv.lock`
4. the `PYTHON_VERSION` environment variable (`tsuru env set -a myapp PYTHON_VERSION=3.13`)
5. a `.python-version` file
6. the latest Python 3.x the platform knows about

Lockfiles win over `PYTHON_VERSION` because a mismatch would make them fail; the deploy log warns
when both are set and disagree. Use a full version (`3.13.1`) or a partial one (`3.13`, `3.13.x`)
to get the newest patch. The list of available versions is fetched from python.org when the
platform image is built, so update the platform (`tsuru platform update python`) to pick up new
releases.

### Operating system packages (optional)

`requirements.apt` lists Ubuntu packages, one per line, installed before your Python dependencies.
Useful for build tools such as `gcc` or `libpq-dev`.

## Deploy

``` bash
tsuru app deploy -a myapp .
```

A full working example is in
[tsuru/platforms `examples/python`](https://github.com/tsuru/platforms/tree/master/examples/python).
