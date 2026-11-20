# Managing teams

## Overview

Its the main way of managing group of users as they work on related projects.
A user is a member of a team when they hold a role whose context is `team`
with that team's name as the context value; group memberships work the same way.

## Creating a team

Tags are optional labels, repeat `--tag` for more than one.

=== "Tsuru client"

    ``` bash
    tsuru team create <TEAM>
    tsuru team create <TEAM> --tag <TAG> --tag <OTHER-TAG>
    ```


=== "Terraform"

    Not possible yet

The creating user receives the `team-create` default roles for the new team
(see [managing roles](managing_roles.md#default-roles)).

## Inspecting a team

=== "Tsuru client"

    ``` bash
    tsuru team list
    tsuru team info <TEAM>
    ```


=== "Terraform"

    Not possible yet

`team info` prints the team's tags, the applications owned by or shared with
the team, the pools the team may use and, when you hold the `team` permission,
every user with a team-scoped role for it together with those roles. The API
also exposes `GET /teams/{name}/users` and `GET /teams/{name}/groups` with the
users and groups holding team-scoped roles for the team.

## Updating a team

=== "Tsuru client"

    ``` bash
    tsuru team update <TEAM> --tag <TAG>
    tsuru team update <TEAM> -n <NEW-NAME>
    ```


=== "Terraform"

    Not possible yet

Renaming creates the new team, moves its apps, services, service instances,
volumes and pool constraints to the new name and then removes the old team.
Role assignments that use the old name as context value are not rewritten, so
reassign them after a rename.

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
    tsuru role dissociate <ROLE> <USER@EMAIL.COM> <TEAM>
    ```


=== "Terraform"

    Not possible yet

### Group-based membership

With the OIDC scheme and `auth:oidc:groups-in-claims: true`, tsuru copies the
`groups` claim of the token to the user on every request (see
[authentication](authentication.md#group-based-membership)). Assign the role to the group instead of
to each user; every member of the group inherits it:

=== "Tsuru client"

    ``` bash
    tsuru role assign <ROLE> group:<GROUP> <TEAM>
    tsuru role dissociate <ROLE> group:<GROUP> <TEAM>
    ```


=== "Terraform"

    Not possible yet

## Team quota

Teams have a quota on the number of apps and jobs they can own (each app or job counts as one; units are not counted). The default comes from [`quota:apps-per-team`](../reference/config.md) in `tsuru.conf`; when the key is absent new teams are unlimited. You can check and change the limit per team as needed

### Checking quota

=== "Tsuru client"

    ``` bash
    tsuru team quota view <TEAM>
    ```


=== "Terraform"

    Not possible yet

### Changing quota

The new limit is an integer or `unlimited`.

=== "Tsuru client"

    ``` bash
    tsuru team quota change <TEAM> <NEW-LIMIT>
    ```


=== "Terraform"

    Not possible yet

### User quota

Users have a separate quota on the apps they create, defaulting to
[`quota:apps-per-user`](../reference/config.md#quotaapps-per-user).

=== "Tsuru client"

    ``` bash
    tsuru user quota view <USER@EMAIL.COM>
    tsuru user quota change <USER@EMAIL.COM> <NEW-LIMIT>
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

Removal is refused (HTTP 403, "there are still references to it") while any
app or service instance still lists the team; the message names them. Move or
remove those first with `tsuru app revoke`, `tsuru app update --team-owner` or
`tsuru service instance revoke`. Jobs are not checked.
