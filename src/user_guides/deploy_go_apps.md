# Deploy Go applications

## Overview

A Go app on tsuru needs `go.mod`, your `.go` files and optionally a `Procfile` and `tsuru.yaml`.
The [`go` platform](platforms.md) downloads the toolchain, runs `go mod download` and builds your
binaries at deploy time.

## Creating the app

``` bash
tsuru app create helloworld go
```

## Application code

A minimal `main.go`:

``` golang
package main

import (
    "fmt"
    "net/http"
    "os"
)

func main() {
    http.HandleFunc("/", hello)
    http.HandleFunc("/healthcheck", healthcheck)

    port := os.Getenv("PORT")
    if port == "" {
        port = "8888"
    }
    if err := http.ListenAndServe(":"+port, nil); err != nil {
        panic(err)
    }
}

func hello(res http.ResponseWriter, req *http.Request) {
    fmt.Fprintln(res, "hello, world!")
}

func healthcheck(res http.ResponseWriter, req *http.Request) {
    fmt.Fprintln(res, "WORKING")
}
```

Create `go.mod` (replace the module path with your repository):

``` bash
go mod init github.com/tsuru/helloworld
go mod tidy
```

And a `tsuru.yaml`, see [tsuru.yaml](tsuru_yaml.md):

``` yaml
healthcheck:
  path: /healthcheck
```

### Go version

The toolchain version is chosen as follows:

1. the `GO_VERSION` environment variable, if set (`tsuru env set -a helloworld GO_VERSION=1.23`);
2. otherwise the `go` directive in `go.mod`.

An exact match of a published release is used when it exists. Otherwise the newest **stable**
release with that prefix is used (`1.23` picks the latest `1.23.x`; `1.23.x` works too). If nothing
matches, the latest stable Go is installed and the deploy log says so.

### Build and Procfile

- Without a `Procfile` the platform runs `go build -o tsuru-app` in the project root and uses its
  default Procfile, `web: ./tsuru-app`.
- With a `Procfile` it runs `go install ./...`, so every `main` package under the module ends up on
  `PATH` and the Procfile refers to binaries by name (see below).
- A `vendor/` directory switches the build to `-mod=vendor`.

## Deploy

``` bash
tsuru app deploy -a helloworld .
```

tsuru compiles and starts the application; `tsuru app info -a helloworld` shows its address.

## Multiple processes

Teams often split an application into an API and a worker that share one repository. Put one
`main` package per binary under `cmd/`:

```
cmd/myapp-api/main.go      # builds the myapp-api binary
cmd/myapp-worker/main.go   # builds the myapp-worker binary
```

Shared packages live outside `cmd/`. Reference each binary in the `Procfile`:

```
web: myapp-api
worker: myapp-worker
```

A full working example is in
[tsuru/platforms `examples/go`](https://github.com/tsuru/platforms/tree/master/examples/go).
