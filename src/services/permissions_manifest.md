# Service permissions manifest

Service instances expose extra operations through tsuru's **proxy**: a client plugin calls `/services/{service}/resources/{instance}/<path>` on the tsuru API, and tsuru forwards the request to the provider. Until tsuru 1.30 any proxied request, whether it listed backups or dropped the database, required the same permission, `service-instance.update.proxy`. Granting it meant granting everything the provider exposes.

The **permissions manifest** fixes that. The provider declares its proxied operations once, each with a name, and tsuru turns every name into a permission that admins grant per role: `service-action.<service>.<action>`. Available since tsuru 1.31 (API and client).

This manifest is separate from the YAML passed to `tsuru service create`. For the role side see [Dynamic service-action permissions](../admin_guides/managing_roles.md#dynamic-service-action-permissions).

## Format

```yaml
enabled: true
strict_actions: true
legacy_compat: false
operations:
  - method: POST
    path: /backups
    action: backup.create
```

| Field | Meaning |
|-------|---------|
| `enabled` | Turns the manifest on. While `false` (or no manifest is stored) proxied requests behave as before: they need `service-instance.update.proxy`. |
| `strict_actions` | When `true`, a proxied request whose method and path match no operation is refused, whatever the caller's permissions. When `false`, unmatched requests fall back to `service-instance.update.proxy`. |
| `legacy_compat` | When `true`, a request that matches an operation is also accepted from callers that lack the `service-action` permission but hold `service-instance.update.proxy`. Use it while migrating roles; set it to `false` to make the fine-grained permissions the only way in. |
| `operations[].method` | HTTP method in upper case: `GET`, `HEAD`, `POST`, `PUT`, `PATCH`, `DELETE` or `OPTIONS`. |
| `operations[].path` | Path pattern relative to `/resources/<instance>` (see below). A leading `/` is added if missing. |
| `operations[].action` | Name of the operation, matching `^[a-z0-9-]+(\.[a-z0-9-]+)*$`: lower case letters, digits and dashes, with dots as separators. Dots build a hierarchy for granting (`backup` covers `backup.create`). |

### Validation

The server rejects the whole manifest with `400` when any operation has an empty `action`, a duplicate `action`, a method outside the list above (lower case is a different string and fails), an `action` that does not match the regex, a blank `path`, or the same `method` + `path` as another operation. Patterns are also compiled into a Go `http.ServeMux`; patterns Go considers conflicting (two that could match the same request without one being more specific) are rejected with `invalid manifest route`.

### How paths are matched

tsuru matches the request's method and path against the operations with the semantics of Go's `http.ServeMux` (Go 1.22 patterns):

- `/backups` matches exactly `/backups`.
- `/backups/` matches `/backups/` and everything below it.
- `/backups/{id}` matches one path segment in place of `{id}`; `/backups/{id}/restore` works the same way.
- `/files/{rest...}` matches any number of trailing segments.
- `/{$}` matches only the root.
- When several patterns match, the most specific wins (`/backups/latest` beats `/backups/{id}`).

The path is taken relative to the instance: a plugin calling `/services/mydb/resources/orders-db/backups/42/restore` is matched as `POST /backups/42/restore`. Requests sent through the older `/services/{service}/proxy/{instance}?callback=` route are normalized the same way: a `callback` starting with `/resources/<instance>` has that prefix stripped before matching.

## Uploading and reading the manifest

```bash
$ tsuru service manifest set mydb manifest.yaml
Manifest for service "mydb" successfully updated.
$ tsuru service manifest get mydb
$ tsuru service manifest get mydb --yaml
$ tsuru service manifest get mydb -o manifest.json
```

`set` takes a JSON or YAML file and replaces the stored manifest; `get` prints a table, or `--json`/`--yaml` for structured output, or writes to `-o/--output FILE` (format inferred from `.json`, `.yaml`, `.yml`). Both commands need `service.update` on the service, the same permission as `tsuru service update`, so they are meant for the service's owner team. Behind them are `PUT /1.31/services/{service}/manifest` (JSON body) and `GET /1.31/services/{service}/manifest`, which returns `null` when nothing is stored. There is no delete: upload a manifest with `enabled: false` to switch back to the legacy behaviour. See [tsuru service manifest set](../tsuru_client/tsuru_service_manifest_set.md) and [get](../tsuru_client/tsuru_service_manifest_get.md).

## Permissions created

Each action in an **enabled** manifest exists as the dynamic permission `service-action.<service>.<action>`. For the example above: `service-action.mydb.backup.create`. Prefixes work like the rest of tsuru's permission tree: `service-action.mydb.backup` grants every `backup.*` action and `service-action.mydb` grants all actions of the service.

Dynamic permissions accept the `global`, `service`, `service-instance` and `team` contexts (the team is the instance's owner team). `tsuru permission list` shows them while the manifest is enabled; `tsuru role info <role>` lists the ones a role holds.

Admins grant them with the usual commands:

```bash
$ tsuru role add dba-operator team
$ tsuru role permission add dba-operator service-action.mydb.backup.create
$ tsuru role assign dba-operator alice@example.com orders
```

Two rules apply: the action must exist in an enabled manifest at the time of the grant (otherwise `permission named "..." not found`), and one `tsuru role permission add` call cannot mix static and dynamic permission names (`cannot mix static and dynamic permissions in one request`). Remove with `tsuru role permission remove`.

## What happens to a proxied request

| Manifest state | Request matches an operation | Request matches nothing |
|----------------|------------------------------|-------------------------|
| No manifest, or `enabled: false` | needs `service-instance.update.proxy` | needs `service-instance.update.proxy` |
| `enabled`, `legacy_compat: false` | needs `service-action.<service>.<action>` | `strict_actions: true`: refused. `false`: needs `service-instance.update.proxy` |
| `enabled`, `legacy_compat: true` | `service-action.<service>.<action>` **or** `service-instance.update.proxy` | same as above |

For requests other than `GET` and `HEAD` the event tsuru records uses the action's permission as its kind and stores the `action` in its custom data, so `tsuru event list` shows which operation ran rather than a generic `proxy`.

## Removing an action that roles still use

When a new manifest drops (or renames) an action and some role holds a permission that would cover nothing else, the server refuses the upload with `409` and a JSON body:

```json
{
  "service": "mydb",
  "conflicts": [
    {"action": "backup.create", "roles": ["dba-operator"]}
  ]
}
```

A grant counts as orphaned only when none of the remaining actions is under it: removing `backup.create` while `backup.list` stays does not conflict with a role that holds `service-action.mydb.backup`. Remove the permission from the listed roles (`tsuru role permission remove dba-operator service-action.mydb.backup.create`) and upload again, or keep the action.

## Complete example

A database service that offers backups, restores and read replicas through its proxy:

```yaml
enabled: true
strict_actions: true
legacy_compat: false
operations:
  - method: GET
    path: /backups
    action: backup.list
  - method: POST
    path: /backups
    action: backup.create
  - method: POST
    path: /backups/{backupId}/restore
    action: backup.restore
  - method: GET
    path: /replicas
    action: replica.list
  - method: POST
    path: /replicas
    action: replica.create
  - method: DELETE
    path: /replicas/{replicaName}
    action: replica.delete
```

```bash
$ tsuru service manifest set mydb manifest.yaml
```

Roles for it, from least to most powerful:

```bash
# Developers of the owner team: look, and take backups.
$ tsuru role add mydb-developer team
$ tsuru role permission add mydb-developer service-action.mydb.backup.list service-action.mydb.backup.create service-action.mydb.replica.list

# Operators: everything about backups and replicas, on every instance of the service.
$ tsuru role add mydb-operator service
$ tsuru role permission add mydb-operator service-action.mydb.backup service-action.mydb.replica
$ tsuru role assign mydb-operator dba@example.com mydb

# One person, one instance: restore only on orders-db.
$ tsuru role add orders-db-restorer service-instance
$ tsuru role permission add orders-db-restorer service-action.mydb.backup.restore
$ tsuru role assign orders-db-restorer bob@example.com orders-db
```

With `strict_actions: true`, a call to `POST /resources/orders-db/anything-else` is refused for everyone, including users with `service-instance.update.proxy`, so add every operation your plugin uses before enabling it. If you are not sure you listed them all, start with `strict_actions: false` and `legacy_compat: true`, watch the events, then tighten.
