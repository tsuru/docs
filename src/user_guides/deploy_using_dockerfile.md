# Deploy using Dockerfile

The Tsuru official platforms do not support every language, framework, or runtime that your tech stack may require, nor do they intend to.
If you have a setup where the official platforms do not meet your needs, you have the option to deploy your app using its [Dockerfile][Dockerfile reference] (Containerfile).

!!! note "Comparison: container image x Dockerfile"

    The key difference between deploying an app using a container image and a Dockerfile lies in the developer's convenience.
    The former requires additional steps on the developer's side, such as building and publishing the container image, while the latter eliminates these requirements.

## Usage

The command argument `--dockerfile` (in the `tsuru app deploy` command) is the main difference among other types of deploy on Tsuru.
It defines the container file that generates the container image used in the following steps of the app's deployment process.
Along this command, you also can pass all deployable files to the app - these files will be available in the container image build context, so you can select these using the [COPY](https://docs.docker.com/engine/reference/builder/#copy)/[ADD](https://docs.docker.com/engine/reference/builder/#add) directives.

The anatomy of app deploy using Dockerfile follows:

``` { .bash .no-copy }
tsuru app deploy -a <APP NAME> \
    --dockerfile <PATH TO CONTAINER FILE> [--] [DEPLOYABLE FILES...]
```

The `--dockerfile` command argument value can be either a regular file or a directory.
When specifying a regular file, you have the explicit choice to select the container file.
On the other hand, when using a directory, the container file is implicitly chosen (see the heuristic mentioned below).

???+ notice "Heuristics for implicit container file name"

    When you pass a directory as argument value of `--dockerfile`, the Tsuru client tries to find the container file following these names (order matters):

    1. `Dockerfile.<APP NAME>` (e.g.  `Dockerfile.my-example-app`)
    2. `Containerfile.<APP NAME>` (e.g. `Containerfile.my-example-app`)
    3. `Dockerfile.tsuru`
    4. `Containerfile.tsuru`
    5. `Dockerfile`
    6. `Containerfile`

    The chosen file will be the first one that exists and can be read correctly.

In both cases, you can push the deployable file(s) to `tsuru app deploy` passing as command arguments (positional args in the end of command).
Those files can either be regular files, directories or symbolic links.
Thoses files will be available in the container image build context and you shoul pick them usin `COPY`/`ADD` directives inside the container image.

???+ tip "Excluding deployable files with ignore files (`.tsuruignore` and `.dockerignore`)"

    Please note that any deployable files can be excluded if they match a rule specified in the Tsuru ignore file (namely `.tsuruignore`) located in the current directory.
    Furthermore, when deploying using a Dockerfile, the Tsuru client also takes into account the Docker ignore file (namely `.dockerfile`) in the current directory to exclude specific files.

### Example

In this example, we are about to build and deploy an app written in Golang.
You can copy and paste the used files below (separated by tabs) - before you might want take a closer look at them, specially at `Dockerfile` and `main.go` files.


=== "Dockerfile"

    ``` dockerfile
    --8<-- "static/samples/dockerfile_v1/Dockerfile"
    ```

=== "main.go"

    ``` golang
    --8<-- "static/samples/dockerfile_v1/main.go"
    ```

=== "go.mod"

    ``` gomod
    --8<-- "static/samples/dockerfile_v1/go.mod"
    ```

=== "tsuru.yaml"

    ``` yaml
    --8<-- "static/samples/dockerfile_v1/tsuru.yaml"
    ```

To deploy into application `my-example-app` using its Dockerfile, you just need issue the below command:

``` bash
tsuru app deploy -a my-example-app --dockerfile .
```

## Advanced

### How can I access Tsuru env vars during container image build?

You are able to import the env vars configured on Tsuru app while running the deploy with Dockerfile.
To do so, you just need append the following snippet in the Dockerfile.

``` dockerfile
RUN --mount=type=secret,id=tsuru-app-envvars,target=/var/run/secrets/envs.sh \
    && . /var/run/secrets/envs.sh \
    ... following commands in this multi-command line are able to see the env vars from Tsuru
```

**NOTE**: That's a bit different than defining `ENV` directive, specially because they're not stored in the image layers.

## Limitations

1. You cannot use distroless based images on your final container image - although on intermediary stages is fine.[^1]
2. There's no support for setting build arguments.
3. There's no support to specify a particular platform - the only platform supported is `linux/amd64`.

[^1]: Tsuru requires a shell intepreter (e.g. `sh` or `bash`) to run hooks, app shell, etc.

[Dockerfile reference]: https://docs.docker.com/engine/reference/builder/
