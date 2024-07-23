# Deploy Go applications

## Overview

Lauching Go applications with Tsuru is remarkably simple. basically you need to maintain well-known files: main.go, go.mod, go.sum and tsuru.yaml

## Creating the app

To create an app, you use the command app create:

``` bash
$ tsuru app create <app-name> <app-platform>
```

For GO, the app platform is, guess what, go! Let’s be over creative and develop a never-developed tutorial-app: a myapp

``` bash
$ tsuru app create helloworld go
```

## Application code

A simple web application in Go main.go:



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

    err := http.ListenAndServe(":" + port, nil)
    if err != nil {
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

To create go.mod file:

``` bash
$ go mod init github.com/tsuru/helloworld
```

please update `github.com/tsuru/helloworld` to the correct git repository


Create the tsuru.yaml file:

``` yaml
healthcheck:
  path: /healthcheck
  method: GET
  status: 200
```

## Deploy

You can just run tsuru app deploy command and your project will be deployed:

``` bash
$ tsuru app deploy -a helloworld .
```

tsuru will compile and run the application automatically.

It’s done! Now we have a simple go project deployed on tsuru.

Now we can access your app in the URL displayed in app info (“helloworld.192.168.50.4.nip.io” in this case).


# Deploy multiple processes application

Teams often design their applications to distribute responsibilities across multiple processes, such as an API and a worker. While these processes might share the same repository, they typically have different entry points.

Our GO platform simplifies handling this scenario, but it's essential to standardize your application.

## Entry points

You must organize the entry points in the filesystem to look like this:

```

# to create myapp-api binary
cmd/myapp-api/main.go


# to create myapp-worker binary
cmd/myapp-worker/main.go
```

you can put every shared package outside of directory cmd.


for each binary you need to specify on `Procfile`
```
web: myapp-api
worker: myapp-worker
```