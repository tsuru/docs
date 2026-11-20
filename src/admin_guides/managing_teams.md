# Managing teams

## Overview

Its the main way of managing group of users as they work on related projects

## Creating a team

=== "Tsuru client"

    ``` bash
    tsuru team create <TEAM>
    ```


=== "Terraform"

    Not possible yet


## Managing team members

With a team created, you can add/remove users to this team by managing users roles/permissions.

### Adding members

=== "Tsuru client"

    ``` bash
    tsuru role assign <ROLE> <USER@EMAIL.COM> <TEAM>
    ```


=== "Terraform"

    Not possible yet

### Removing members

=== "Tsuru client"

    ``` bash
    tsuru role remove <ROLE> <USER@EMAIL.COM>
    ```


=== "Terraform"

    Not possible yet

## Team quota

Teams have a quota on the number of apps and jobs they can own (each app or job counts as one; units are not counted). The default comes from `quota:apps-per-team` in `tsuru.conf`. You can check and change the limit per team as needed

### Checking quota

=== "Tsuru client"

    ``` bash
    tsuru team quota view <TEAM>
    ```


=== "Terraform"

    Not possible yet

### Changing quota

=== "Tsuru client"

    ``` bash
    tsuru team quota change <TEAM> <NEW-LIMIT>
    ```


=== "Terraform"

    Not possible yet

## Removing a team

If a team is no longer needed you can remove it with the following

=== "Tsuru client"

    ``` bash
    tsuru team remove <TEAM>
    ```


=== "Terraform"

    Not possible yet