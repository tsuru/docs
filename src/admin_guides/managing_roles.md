# Managing roles

## Overview

Roles are groups of permissions that can be assign to users in order to determine
which actions they can take on Tsuru. Those roles can be created with multiples permissions
and then applied to one or more users while the reach of those roles can be determined by the
context attach to them. You can check the role managing options with [Tsuru`s client](../user_guides/install_client.md)
command ``tsuru role``

### Permissions

Tsuru has a fixed number of permissions that may change which releases (mostly adding new ones).
Permissions in tsuru work in a hierarchical fashion and are
represented using a dot notation. Granting access to a top-level permission
implies access to all permissions below it.

To list all permissions available you can use [Tsuru`s client](../user_guides/install_client.md)
and execute a ``tsuru permission list``. It will list all the permissions available on the current
installation of Tsuru

As an example, consider the following permissions:

* ``app.update.env.set``
* ``app.update.env.unset``
* ``app.deploy``

If an user has access only to ``app.update.env.set``, only this specific action
is available to them. However, it's also possible to grant access to the broader
``app.update`` permission which will allow users to both set and unset
environment variables, but not deploy the applications. If we want to allow a
user to execute all actions related to an application, the even broader
permission ``app`` can be used.

### Contexts

When applying permissions to a user one do so in regard to a context. Each
permission declares which contexts can be used and it's possible see the
available contexts using the command ``tsuru permission-list``. When a
permission is assigned to a user it needs a context and a value for the chosen
context. Examples of available contexts are:

* ``team``
* ``app``
* ``global``

If a user have the ``app.deploy`` permission for the ``team`` named ``myteam``
it means that they can only deploy applications which ``myteam`` has access. The
same way, it's possible to assign the same ``app.deploy`` permission to a user
with the context ``app`` for one application named ``myappname``. This means the
user can now deploy this specific application called ``myappname``.

The ``global`` context is a special case. It's available to all permissions and
means that the permission always applies. In the previous scenario, if a user
have the ``app.deploy`` permission with a ``global`` context it means that they
can deploy **any** application.

## Create role

=== "Tsuru client"

    ``` bash
    tsuru role add <ROLE-NAME> <CONTEXT>
    ```

    ``` bash
    tsuru role add app_reader_restarter team
    ```


=== "Terraform"

    Not possible yet


After the role is created, all wanted permissions should be added the this role

=== "Tsuru client"

    ``` bash
    tsuru role permission add <ROLE-NAME> <PERMISSIONS>...
    ```

    ``` bash
    tsuru role permission add app_reader_restarter app.read app.update.restart
    ```


=== "Terraform"

    Not possible yet

Once all the permissions are added, the role can be assign to an user/token/group
and attached to one of the possible contexts

## Update role

You can update roles with new permissions, context, description or change its
name. To add new permissions you can just repeat the step above made during
the role creation. Other changes are made with the client command ``tsuru role update``

=== "Tsuru client"

    ``` bash
    tsuru role update <ROLE-NAME> [-d/--description <DESCRIPTION>] [-c/--context <CONTEXT>] [-n/--name <NEW-NAME>]
    ```

    ``` bash
    tsuru role update app_reader_restarter -c app
    ```


=== "Terraform"

    Not possible yet

## Remove role

Once a role is not needed anymore, it can be removed

=== "Tsuru client"

    ``` bash
    tsuru role remove <ROLE-NAME>
    ```

    ``` bash
    tsuru role remove app_reader_restarter
    ```


=== "Terraform"

    Not possible yet