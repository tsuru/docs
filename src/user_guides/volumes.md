# Volumes

Volumes let an app use external storage mounted on the filesystem of its units. A volume is created once, from a *volume plan* defined by the tsuru administrator, and then bound to one or more apps at a mount point. The app units see the volume as a regular directory.

On the Kubernetes provisioner a volume becomes a `PersistentVolumeClaim` (and, for plans that name a plugin, a `PersistentVolume`) that tsuru creates in the namespace of the apps bound to it and mounts into every pod of the app (`provision/kubernetes/volume.go`).

## Administrator setup

### Volume plans

Volume plans live in the tsuru API configuration under `volume-plans:<plan>:<provisioner>`. Each plan is a set of options interpreted by the provisioner. For `kubernetes` the recognized keys are:

| Key | Description |
|-----|-------------|
| `plugin` | Name of a Kubernetes volume plugin (`nfs`, `emptyDir`, `ephemeral`, ...). tsuru creates a `PersistentVolume` whose spec is `{<plugin>: <volume opts>}`, so the `-o` options given on `volume create` are passed straight to the plugin. |
| `storage-class` | Name of a `StorageClass` for dynamic provisioning. tsuru creates only a `PersistentVolumeClaim`. |
| `capacity` | Requested storage, as a Kubernetes quantity (`10Gi`). |
| `access-modes` | Comma-separated access modes (`ReadWriteOnce`, `ReadWriteMany`, ...). |

Rules enforced when a volume is created or mounted:

- At least one of `plugin` or `storage-class` must be set. Setting both is only allowed for the non-persistent plugins `emptyDir` and `ephemeral` (`ephemeral` uses the storage class for its claim template).
- `capacity` and `access-modes` are mandatory. Each can come from the plan or be given by the user with `-o capacity=...` / `-o access-modes=...`; a value passed by the user wins. The `emptyDir` plugin needs neither.
- `emptyDir` and `ephemeral` volumes are not persistent: no `PersistentVolume` is created and the data lives with the pod.

Example configuration:

```yaml
volume-plans:
  nfs:
    kubernetes:
      plugin: nfs
      access-modes: ReadWriteMany
  ssd:
    kubernetes:
      storage-class: fast-ssd
      capacity: 20Gi
      access-modes: ReadWriteOnce
```

With the `nfs` plan above a user must supply the plugin fields and the capacity: `-o server=10.0.0.5 -o path=/exports -o capacity=50Gi`. With `ssd` nothing else is needed. See the [configuration reference](../reference/config.md).

### Pool constraint `volume-plan`

A pool only accepts volumes from plans listed in its `volume-plan` constraint. Without the constraint, `volume create` fails with `no volume-plan found for pool`; with a plan that is not allowed it fails with `volume-plan not present in pool constraint`.

```bash
$ tsuru pool constraint set mypool volume-plan nfs ssd
```

See [Managing pools](../admin_guides/managing_pools.md).

## Using volumes

### Listing plans

```bash
$ tsuru volume plan list
```

Shows a table with `Plan`, `Provisioner` and `Opts` columns.

### Creating a volume

```bash
$ tsuru volume create shared-data nfs -p mypool -t myteam -o server=10.0.0.5 -o path=/exports -o capacity=50Gi
```

| Argument / flag | Description |
|-----------------|-------------|
| `<volume-name>` | At most 40 characters, lower case letters, numbers or dashes, starting with a letter. Names are global: a second volume with the same name is refused with `volume already exists`. |
| `<plan-name>` | One of the plans allowed by the pool constraint. |
| `-p, --pool` | Pool that owns the volume. Mandatory if you have access to more than one pool. |
| `-t, --team` | Team that owns the volume. Mandatory if you have access to more than one team. |
| `-o, --opt key=value` | Backend-specific options, repeatable. Plugin fields plus `capacity` and `access-modes` when the plan does not define them. |

Creating the volume only validates it and records it in tsuru. Nothing is created in the cluster until the volume is bound to an app and the app is restarted or deployed.

### Binding to an app

```bash
$ tsuru volume bind shared-data /mnt/data -a myapp
```

A bind is identified by volume, app and mount point, so the same volume can be mounted at several paths or in several apps (subject to its access modes). Binding the same volume twice at the same mount point fails with `volume already bound in mountpoint`.

| Flag | Description |
|------|-------------|
| `-r, --readonly` | Mount the volume read-only in this app. |
| `--no-restart` | Record the bind without restarting the app. The volume is mounted on the next deploy or restart. |

By default the app is restarted right away; the PV/PVC are created during that restart, when tsuru builds the pod spec with the app volumes. The command streams the restart output.

### Unbinding

```bash
$ tsuru volume unbind shared-data /mnt/data -a myapp
```

Removes the bind for that mount point and restarts the app unless `--no-restart` is given. An unknown bind returns `volume bind not found`.

### Inspecting volumes

```bash
$ tsuru volume list
+-------------+------+--------+--------+
| Name        | Plan | Pool   | Team   |
+-------------+------+--------+--------+
| shared-data | nfs  | mypool | myteam |
+-------------+------+--------+--------+
```

`volume list` accepts filters: `-n/--name`, `-p/--plan`, `-o/--pool`, `-t/--team`, plus `-q/--only-name` and `--json`.

```bash
$ tsuru volume info shared-data
```

Prints name, plan, pool and team, the current binds (app, mount point, read-only or read-write), the plan options and the options given at creation. `--json` prints the raw volume.

### Updating a volume

```bash
$ tsuru volume update shared-data nfs -p mypool -t myteam -o capacity=100Gi
```

`volume update` takes the same arguments as `volume create` and replaces the volume definition. It is only possible while the volume has not yet been created in the cluster:

!!! note "Volumes are immutable once provisioned"
    If tsuru already created the `PersistentVolume` for this volume, `volume update` fails with `updating a volume already provisioned is not supported, a new volume must be created and the old one deleted if necessary`. Resize or reconfigure by creating a new volume, binding it, and deleting the old one.

### Deleting a volume

```bash
$ tsuru volume delete shared-data
```

The volume must have no binds (`cannot delete volume with existing binds`): unbind it from every app first. tsuru then deletes the `PersistentVolume` and every `PersistentVolumeClaim` it created for the volume and removes the volume record.

## Permissions

| Action | Permission |
|--------|------------|
| `volume plan list` | `volume.create` (any context) |
| `volume create` | `volume.create` on the target team and pool |
| `volume list` / `volume info` | `volume.read` |
| `volume update` | `volume.update` |
| `volume bind` | `volume.update.bind` on the volume **and** `app.update.bind-volume` on the app |
| `volume unbind` | `volume.update.unbind` on the volume **and** `app.update.unbind-volume` on the app |
| `volume delete` | `volume.delete` |

Volume permissions are checked against the volume name, its team and its pool. See [Managing roles and permissions](../admin_guides/managing_roles.md).

For the exact flags see the [tsuru volume](../tsuru_client/tsuru_volume.md) command reference.
