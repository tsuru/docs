# Tsuru client (CLI)

The Tsuru command-line interface (CLI), also known as `tsuru`, is crucial tool for application developers using Tsuru.
It empowers developers to perform a wide range of operations and efficiently manage the full lifecycle of their applications with just a few simple commands.
With `tsuru`, developers gain the ability to create and deploy applications effortlessly, while also providing real-time troubleshooting capabilities.

## Install

### Pre-built binaries

#### Linux

=== "Debian-based (Debian, Ubuntu, Mint, etc)"

    ``` bash
    curl -fsSL https://packagecloud.io/install/repositories/tsuru/stable/script.deb.sh | sudo bash
    sudo apt-get install tsuru-client
    ```

=== "RHEL-based (Fedora, CentOS, etc)"

    ``` bash
    curl -fsSL https://packagecloud.io/install/repositories/tsuru/stable/script.rpm.sh | sudo bash
    sudo yum install tsuru-client
    ```

=== "Arch Linux-based (Arch Linux, Manjaro, etc)"

    ``` bash
    yay -S tsuru-bin
    ```

=== "Others"

    ``` bash
    curl -fsSL https://tsuru.io/get | bash
    ```

#### MacOS

=== "Homebrew (preferred)"

    ``` bash
    brew tap tsuru/homebrew-tsuru
    brew install tsuru
    ```

=== "From script"

    ``` bash
    curl -fsSL https://tsuru.io/get | bash
    ```

#### Windows

If you are using Windows Subsystem for Linux (WSL), you can install Tsuru by following the same steps as would for [Linux](#linux).
However, if you are not using WSL, you will need downloading a Windows-specific archive (ZIP compressed) directly from [tsuru-client releases](https://github.com/tsuru/tsuru-client/releases).


#### Docker

If you are unable to install the Tsuru CLI system-wide, an alternative option is to use the Tsuru CLI container image using Docker.
By the way this container image is highly recommended for configuring CI/CD pipelines.

``` bash
docker run -t tsuru/client:latest tsuru version
```

The above command executes the `tsuru version` command using the latest version of Tsuru client's container image.

### Building from source code

As Tsuru CLI's source is written in Golang, building it from the source code requires the [installation of Go](https://go.dev/doc/install) previously.
After doing that, you only need to run the below command to build and install Tsuru CLI from the source:

``` bash
go install github.com/tsuru/tsuru-client/cmd/tsuru@latest
```

Ensure that you add the Go's bin directory to the system's path (`$PATH`), as shown below.

``` bash
export PATH=${PATH}:$(go env GOPATH)/bin
```

## Verify the installation

To verify your CLI installation, use the `tsuru version` command.

``` bash
tsuru version
```

The command output should look like `Client version: X.Y.Z`.
If you do not see anything like this, try to reinstall or use another installation method.
