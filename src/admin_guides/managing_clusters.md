# Managing clusters

## Overview

Cluster is used by provisioner to deploy applications in a specific kubernetes installation.


## Adding a cluster

In order to create a cluster, you should create a terraform resource or invoke tsuru cluster add:




=== "Terraform"
    read the full documentation of [tsuru_cluster resource](https://registry.terraform.io/providers/tsuru/tsuru/latest/docs/resources/cluster)

    ```terraform
    resource "tsuru_cluster" "test_cluster" {
      name              = "test_cluster"
      tsuru_provisioner = "kubernetes"
      default           = true
      kube_config {
        cluster {
          server                     = "https://myclusteraddr"
          certificate_authority_data = "server-ca"
        }
        user {
          # when GKE
          auth_provider {
            name = "gcp"
          }
          # otherwise fill some of options based on our cluster authentication mode
          client_certificate_data = "client-cert"
          client_key_data         = "client-key"
          token                   = "token"
          username                = "username"
          password                = "password"
        }
      }
    }
    ```

=== "Tsuru client"

    the full options are offered only by terraform, the CLI version are just the simplified way to do

    ```bash
    $ tsuru cluster add cluster1 kubernetes --addr mycluster-addr
    ```


## Listing clusters

To list pools you do:

```bash
$ tsuru cluster list
+-------+-------------+-----------+---------------+---------+-------+
| Name  | Provisioner | Addresses | Custom Data   | Default | Pools |
+-------+-------------+-----------+---------------+---------+-------+
| local | kubernetes  |           |               | true    |       |
+-------+-------------+-----------+---------------+---------+-------+
```

## Removing a cluster

If you want to remove a cluster, use tsuru cluster remove or undeclare tsuru_cluster resource on terraform

```bash
$ tsuru cluster remove cluster1
```


