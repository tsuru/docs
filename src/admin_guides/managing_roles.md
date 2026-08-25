# Managing permissions and roles

Tsuru uses role-based access control to decide which actions an identity can
perform and which resources it can act on. Administrators define a role, add
permissions to it, and assign the role to a user, group, or team token for a
specific context value.

The authorization model can be read from left to right:

```text
user, group, or team token
    -> role assignment
    -> role permissions
    -> matching resource context
    -> action allowed or denied
```

Access is additive. An identity may receive roles directly and, for users,
through groups. Tsuru combines the permissions from all applicable role
assignments. If none of them grants the requested action in a matching context,
the action is denied.

## Core concepts

- **Permission:** A named action or family of actions, such as `app.deploy` or
  `app.read`.
- **Role:** A reusable collection of permissions with one context type, such
  as `team` or `app`.
- **Role assignment:** A role attached to a user, group, or team token with a
  context value. For example, assigning a `team` role with the value `myteam`
  limits that role to resources related to `myteam`.
- **Context:** The scope in which a permission applies. A context consists of a
  type and, except for `global`, a value.

## Typical workflow

The following example creates a role that can inspect and restart applications
owned by a team.

First, inspect the permissions and contexts supported by the target Tsuru
installation:

```bash
tsuru permission list --tree
```

Create a role whose assignments will use team names as context values:

```bash
tsuru role add app-reader-restarter team \
  --description "Read and restart applications owned by one team"
```

Add the required permissions:

```bash
tsuru role permission add app-reader-restarter \
  app.read app.update.restart
```

Assign the role to a user for the `myteam` context:

```bash
tsuru role assign app-reader-restarter user@example.com myteam
```

Inspect the result:

```bash
tsuru role info app-reader-restarter
tsuru user info
```

The user can now read and restart applications related to `myteam`, but this
assignment does not grant the same actions for applications outside that team.

To remove the assignment without deleting the reusable role:

```bash
tsuru role dissociate app-reader-restarter user@example.com myteam
```

!!! note

    Roles, permissions, and assignments are separate objects. Removing a role
    assignment changes one identity's access. Removing a permission changes
    every assignment of that role. Removing the role removes the reusable role
    itself and is rejected while users still have it assigned.

## Permissions

Tsuru permission names form a hierarchy separated by dots. A granted
permission covers itself and every permission below it, but not its siblings.
For example:

- `app.update.env.set` grants only that action.
- `app.update.env` grants both `app.update.env.set` and
  `app.update.env.unset`.
- `app.update` grants all application update actions, but does not grant
  `app.deploy`.
- `app` grants all registered application actions.
- `*` grants every registered static permission.

Use the narrowest permission that supports the required work. Broad ancestors
are convenient, but they also include permissions added below that ancestor in
future Tsuru versions.

### Find available permissions

Permissions can change between Tsuru versions and installations. Query the
server instead of relying on a copied list:

```bash
tsuru permission list
tsuru permission list --tree
```

The output includes the context types supported by each permission. `global`
is available for every permission. Other contexts are defined on a permission
family and inherited by its descendants unless a more specific permission
defines a different set.

For example, the application permission family supports application, team, and
pool contexts, while `app.create` is limited to team and global contexts. A
role can only receive permissions compatible with the role's context type.

!!! warning

    The `*` permission and the `global` context solve different problems. `*`
    selects every static permission; `global` makes the permissions in one
    role assignment apply to every matching resource.

### Dynamic service-action permissions

Services with an enabled API manifest can declare named operations. Tsuru
exposes a dynamic permission for each operation using this format:

```text
service-action.<service-name>.<action>
```

For example, an action named `rules.sync` declared by the `acl` service becomes
`service-action.acl.rules.sync`. Dynamic permissions use the same hierarchical
rule as static permissions: `service-action.acl.rules` covers actions below
that prefix, and `service-action.acl` covers all declared actions for that
service.

Dynamic service-action permissions support `global`, `service`,
`service-instance`, and `team` contexts. They are listed by
`tsuru permission list` only while the corresponding service manifest is
enabled and declares the action. Removing or changing manifest actions may
conflict with roles that reference them, so review affected roles when updating
a service manifest.

Add a dynamic permission to a role with the same command used for static
permissions:

```bash
tsuru role permission add acl-operator service-action.acl.rules.sync
```

A single add request must contain either static permissions or dynamic
permissions; do not mix both kinds in one command invocation.

## Roles and assignments

A role stores a name, description, context type, and permission list. It does
not store a context value. The value is supplied each time the role is assigned,
which allows the same role to be reused for different teams or resources.

For example, the same `app-reader-restarter` role can be assigned to one user
for `team-a` and another user for `team-b`. Each assignment expands to the same
permissions with a different team context value.

### Manage a role

List and inspect roles before changing them:

```bash
tsuru role list
tsuru role info app-reader-restarter
```

Add or remove individual permissions:

```bash
tsuru role permission add app-reader-restarter app.read
tsuru role permission remove app-reader-restarter app.read
```

Permission changes affect every existing assignment of the role immediately.
The server authorizes these operations using role-management permissions, not
the permission being changed:

- Adding a permission requires the global
  `role.update.permission.add` permission or an ancestor such as
  `role.update`, `role`, or `*`.
- Removing a permission requires the global
  `role.update.permission.remove` permission or an ancestor.

When adding a static permission, the permission must exist and support the
role's context type. When adding a dynamic permission, it must refer to an
action declared by an enabled service manifest, or to a valid ancestor of such
an action, and support the role's context type. Static and dynamic permissions
cannot be added in the same request.

Removing a permission does not validate that the permission still exists or is
currently attached to the role. Removing an absent permission is a successful
no-op.

!!! danger "Permission-management privileges"

    The server does not require an administrator to possess a permission before
    adding it to or removing it from a role. Adding a permission to an already
    assigned role immediately expands the access of all its assignees. Treat
    `role.update.permission.add`, `role.update.permission.remove`, and their
    ancestors as security-administrator privileges.

Update the role's description, context type, or name:

```bash
tsuru role update app-reader-restarter \
  --description "Read and restart team applications"
tsuru role update app-reader-restarter --context app
tsuru role update app-reader-restarter --name app-operator
```

Changing a role affects its existing assignments. In particular, changing its
context type changes how stored context values are interpreted. Review all
assignments and permission compatibility before making this change.

Remove a role only after it is no longer assigned to users:

```bash
tsuru role remove app-reader-restarter
```

### Assign roles to identities

`tsuru role assign` accepts a user email, a team token ID, or a group prefixed
with `group:`:

```bash
# User
tsuru role assign app-reader-restarter user@example.com myteam

# Team token
tsuru role assign app-reader-restarter 6f9b1f6a-88d7-4b01-a132-bd44d35506df myteam

# Group
tsuru role assign app-reader-restarter group:platform-engineers myteam
```

Users receive permissions from both their direct role assignments and the
roles assigned to their groups. Team tokens receive permissions from their own
role assignments.

For a non-global role, the context value is required and Tsuru validates that
the referenced resource exists when the assignment is created. A global role
is assigned without a context value:

```bash
tsuru role assign platform-auditor user@example.com
```

To delegate a role, the acting administrator needs the global
`role.update.assign` permission or an ancestor. Tsuru also verifies that the
administrator holds every static permission in the role at the target context.
For each static permission, any of the following grants is sufficient:

- The exact permission at the exact context type and value.
- An ancestor permission at the exact context type and value.
- The permission or an ancestor with global context.

For example, assigning a team role containing `app.create` for `myteam`
requires `app.create` or an ancestor for `team:myteam`, or a corresponding
global grant.

Dynamic permissions are not included in this delegation check. A role that
contains only dynamic permissions can be assigned by anyone with
`role.update.assign`; a mixed role is checked only against its static
permissions.

Role dissociation has a similar rule. The administrator needs the global
`role.update.dissociate` permission or an ancestor and must hold every static
permission in the role at the supplied context. Consequently, an administrator
may have permission to dissociate roles but still be unable to revoke a role
whose static privileges exceed their own.

Unlike assignment, dissociation does not validate that the context value still
refers to an existing resource. It removes the exact role and context-value
pair; removing an assignment that is already absent is a successful no-op.

### Assignment endpoint behavior

The API applies the same authorization model to users, team tokens, and groups,
with a few target-specific differences:

| Operation | Routes | Required permission | Additional conditions |
| --- | --- | --- | --- |
| Assign role | `POST /roles/{name}/user`, `POST /roles/{name}/token`, `POST /roles/{name}/group` | Global `role.update.assign` or an ancestor | Role exists; context is valid; administrator holds every static role permission at that context |
| Dissociate role | `DELETE /roles/{name}/user/{email}`, `DELETE /roles/{name}/token/{token_id}`, `DELETE /roles/{name}/group/{group_name}` | Global `role.update.dissociate` or an ancestor | Role exists; administrator holds every static role permission at the supplied context |
| Add permission | `POST /roles/{name}/permissions` | Global `role.update.permission.add` or an ancestor | Role and permission exist; permission supports the role context; static and dynamic permissions are not mixed |
| Remove permission | `DELETE /roles/{name}/permissions/{permission}` | Global `role.update.permission.remove` or an ancestor | Role exists |

For user assignments, the target user must already exist. For team-token
assignments, the token must already exist. Assigning a role to a nonempty group
name creates the stored group record when necessary. Dissociating from a group
that does not exist is a successful no-op.

All these routes require an authenticated token. A missing authentication token
produces HTTP 401; a valid token without the required Tsuru permission produces
HTTP 403.

!!! tip

    Prefer group assignments for access shared by a team of people and direct
    user assignments for exceptions. This keeps audits and removal of access
    easier to reason about.

### Default roles

Default-role events assign roles automatically:

- `user-create` applies global roles when a user is created.
- `team-create` applies team roles to the user who creates a team, with the new
  team name as the context value.

The role's context type must match the event. Manage defaults with:

```bash
tsuru role default add --user-create platform-auditor
tsuru role default add --team-create team-admin
tsuru role default list

tsuru role default remove --user-create platform-auditor
tsuru role default remove --team-create team-admin
```

Default-role configuration affects future creation events; it does not
retroactively add or remove assignments for existing users or teams.

## Contexts

A context determines where all permissions in a role assignment apply. The
role fixes the context type; the assignment provides the value. Context types
are not hierarchical: a `team` context does not automatically contain an `app`
context. Instead, an application authorization check presents all contexts
associated with that application, such as its name, teams, and pool. A grant
matches when its context type and value equal any context presented by the
resource.

| Context type | Assignment value | Typical scope |
| --- | --- | --- |
| `global` | No value | Every resource checked for the role's permissions |
| `app` | Application name | One application |
| `job` | Job name | One job |
| `team` | Team name | Resources associated with that team |
| `user` | User email | One user account |
| `pool` | Pool name | Resources in that pool, where supported |
| `service` | Service name | One service |
| `service-instance` | Service and instance identity; see the warning below | One service instance |
| `volume` | Volume name | One volume |
| `router` | Router name | One dynamic router |

Only use a context type shown for the permission by
`tsuru permission list`. Tsuru rejects adding a permission to a role when that
permission does not support the role's context type.

### How resource contexts combine

Many resources present more than one context during authorization:

- An application presents its application name, every team with access, and
  its pool.
- A job presents its job name, owner team, and pool.
- A volume presents its volume name, owner team, and pool.
- A service presents its service name and teams with access.
- A service instance presents its service-instance identity and teams with
  access.

This lets administrators express the same application permission at different
scopes. Given an application named `payments-api`, owned by `payments`, in the
`production` pool, `app.deploy` may be granted through any compatible role
assignment below:

```text
app context:    payments-api
team context:   payments
pool context:   production
global context: <no value>
```

These assignments are independent grants. Tsuru does not translate one context
type into another and does not require all of them to match.

### Global context

The `global` context is accepted by every permission and matches without a
resource value. Use it for true installation-wide administration:

```bash
tsuru role add platform-auditor global
tsuru role permission add platform-auditor app.read service.read
tsuru role assign platform-auditor auditor@example.com
```

Avoid using global roles merely to work around an incorrect context value. A
global assignment may grant access to current and future resources throughout
the installation.

!!! warning "Service-action context compatibility"

    At authorization time, current Tsuru code identifies a service instance as
    `<service-name>/<instance-name>`. Some server versions validate new
    service-instance role assignments using only the bare instance name. An
    assignment created with the bare name may therefore fail to match runtime
    authorization, while the composite value may be rejected during
    assignment. Verify this behavior on your server version before relying on
    service-instance-scoped roles. Until the server behavior is consistent,
    prefer a compatible `team`, `service`, or `global` scope according to the
    required access boundary.

    Dynamic service-action permissions advertise `service` as an allowed
    context, but current service-instance proxy authorization presents only
    `team` and `service-instance` contexts. A service-scoped dynamic grant may
    therefore not match. Prefer a verified `team` scope until your server
    version presents the service context during proxy authorization.

## Troubleshooting authorization

When an action is unexpectedly denied, check the model in order:

1. Run `tsuru permission list --tree` and confirm the requested permission
   exists and supports the role's context type.
2. Inspect the role with `tsuru role info` and confirm it contains the exact
   permission or one of its ancestors.
3. Inspect the user, group, or team token assignment and confirm the stored
   context value. Context matching is exact.
4. Confirm the target resource is actually associated with that value. For
   example, a team-scoped application role only applies while the team has
   access to the application.
5. For `service-action.*` permissions, confirm the service manifest is enabled
   and still declares the requested action.
6. Check for client/server version differences if a command or context behaves
   differently from the examples in this guide.

A grant never turns into an explicit denial. If multiple roles are assigned,
any matching grant allows the action; unrelated or nonmatching assignments are
simply ignored for that check.

## Next steps

Use `tsuru role --help` and `tsuru permission --help` to discover the commands
available in your client version. The complete command reference is available
under [Tsuru Client](../tsuru_client/tsuru.md).
