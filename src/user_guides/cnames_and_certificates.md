# CNAMEs and certificates

Every tsuru app gets an address from its router. This page explains how to find that address, how to attach your own domain names (CNAMEs) to an app, and how to serve them over HTTPS with a certificate you upload or one issued automatically by a certificate issuer.

## App addresses

The router assigned to the app exposes it under a generated address. `tsuru app info` shows every router linked to the app, its addresses and whether the backend is ready:

```bash
$ tsuru app info -a myapp
...
Routers:
+---------+-------------------------+--------+
| Router  | Addresses               | Status |
+---------+-------------------------+--------+
| default | http://myapp.example.io | ready  |
+---------+-------------------------+--------+
```

The `Status` column comes from the router itself: `ready`, or `not ready` with a detail message when the router has no backend for the app yet (for example before the first deploy). `tsuru app list` prints the same addresses in its `Address` column; CNAMEs are listed first, marked with `(cname)`.

## Adding a CNAME

A CNAME is a custom domain you point at the app. tsuru does not touch DNS: create a `CNAME` record on your DNS provider pointing to the router address, then register it on the app so the router accepts requests for that host.

```bash
$ tsuru cname add myapp.mydomain.com -a myapp
```

You can pass several names at once. Wildcards are accepted (`*.mydomain.com`).

```bash
$ tsuru cname add myapp.mydomain.com www.mydomain.com -a myapp
```

tsuru validates each name before saving it (`app/actions.go`, `validateNewCNames`):

| Rule | Error |
|------|-------|
| Must match `^(\*\.)?[a-zA-Z0-9][\w-.]+$` | `Invalid cname` |
| Not already on the same app | `cname <name> already exists for this app` |
| Not used by another app that shares a router with this one | `cname <name> already exists for app <other> using same router` |
| Not used by an app owned by a different team | `cname <name> already exists for another app <other> and belongs to a different team owner` |

The same CNAME can therefore be shared by two apps of the same team as long as they use different routers.

After saving, tsuru rebuilds the app routes so every router linked to the app starts serving the new host. The CNAME then appears in `app info` and `app list`.

## Removing a CNAME

```bash
$ tsuru cname remove myapp.mydomain.com -a myapp
```

Removing a CNAME also drops any certificate issuer configured for it and rebuilds the routes. Certificates you uploaded manually for that name are not removed from the router by this command; use `tsuru certificate unset` first if you want them gone.

See [tsuru cname add](../tsuru_client/tsuru_cname_add.md) and [tsuru cname remove](../tsuru_client/tsuru_cname_remove.md).

## Certificates

Certificates are stored by the router, not by tsuru. Only routers that implement TLS (the `TLSRouter` interface) accept them.

### Uploading a certificate

```bash
$ tsuru certificate set -a myapp -c myapp.mydomain.com ./fullchain.pem ./privkey.pem
```

The command takes the PEM files for the certificate and its private key. Before sending anything to the router, tsuru checks that:

- `-c` is one of the app CNAMEs or one of its router addresses (`invalid name` otherwise);
- the certificate and key are a valid pair;
- the certificate is valid for the hostname given in `-c`.

The certificate is then added to every TLS-capable router linked to the app. If none of the app routers supports TLS the request fails with `no router with tls support`.

### Listing certificates

```bash
$ tsuru certificate list -a myapp
+---------+----------------------+--------------------------+--------------------------------+
| Router  | CName                | Public Key Info          | Certificate Validity           |
+---------+----------------------+--------------------------+--------------------------------+
| default | myapp.mydomain.com   | Algorithm                | Not before                     |
|         |                      | RSA                      | 2026-01-01 00:00:00 +0000 UTC  |
|         |                      | Key size (in bits)       | Not after                      |
|         |                      | 2048                     | 2026-12-31 23:59:59 +0000 UTC  |
+---------+----------------------+--------------------------+--------------------------------+
```

Use `-r/--raw` to print the PEM certificates or `--json` for machine-readable output.

!!! note "404: no router with tls support"
    Since tsuru 1.24.3, `certificate list` returns HTTP 404 with the message `no router with tls support` when no router linked to the app supports TLS, and also when the TLS routers have no certificate or issuer for any of the app names. Add a certificate or an issuer first, or check the app routers with `tsuru app info`.

### Removing a certificate

```bash
$ tsuru certificate unset -a myapp -c myapp.mydomain.com
```

The name goes through the same validation as `certificate set` and the certificate is removed from every TLS-capable router.

See [tsuru certificate set](../tsuru_client/tsuru_certificate_set.md), [tsuru certificate list](../tsuru_client/tsuru_certificate_list.md) and [tsuru certificate unset](../tsuru_client/tsuru_certificate_unset.md).

## Certificate issuers

Since tsuru 1.24.0 you can delegate certificate issuance to an issuer configured in the router (for instance a cert-manager issuer on a Kubernetes router) instead of uploading PEM files. The issuer is set per CNAME:

```bash
$ tsuru certificate issuer set -a myapp -c myapp.mydomain.com letsencrypt
```

The CNAME must already belong to the app. tsuru stores the issuer on the app and rebuilds the routes, passing the issuer to the router, which requests the certificate.

### Pool constraint `cert-issuer`

Which issuers an app may use is controlled by a pool constraint of type `cert-issuer`. When the pool has such a constraint, the issuer must be in its allowed values (or must not be in them, for a deny list); otherwise the command fails with `cert issuer not allowed by constraints of this pool` followed by the allowed or denied values. A pool without a `cert-issuer` constraint accepts any issuer. Pool administrators set it with:

```bash
$ tsuru pool constraint set mypool cert-issuer letsencrypt letsencrypt-staging
```

See [Managing pools](../admin_guides/managing_pools.md).

### Waiting for the certificate

Issuance is asynchronous. Until the issuer delivers the certificate, `certificate list` shows the CNAME with the issuer and no certificate data:

```
| default | myapp.mydomain.com        |  |  |
|         |   managed by: cert-manager |  |  |
|         |   issuer: letsencrypt      |  |  |
|         |   status: not ready        |  |  |
```

Once the router has the certificate the row fills in and `status: not ready` disappears.

### Removing an issuer

```bash
$ tsuru certificate issuer unset -a myapp -c myapp.mydomain.com
```

The command asks for confirmation unless you pass `-y/--assume-yes`. Removing the CNAME itself (`tsuru cname remove`) also removes its issuer.

See [tsuru certificate issuer set](../tsuru_client/tsuru_certificate_issuer_set.md) and [tsuru certificate issuer unset](../tsuru_client/tsuru_certificate_issuer_unset.md).

## Permissions

| Action | Permission |
|--------|------------|
| `cname add` / `cname remove` | `app.update.cname.add` / `app.update.cname.remove` |
| `certificate set` / `certificate unset` | `app.update.certificate.set` / `app.update.certificate.unset` |
| `certificate list` | `app.read.certificate` |
| `certificate issuer set` / `certificate issuer unset` | `certissuer.set` / `certissuer.unset` |

All of them are checked against the app, its teams and its pool. Note that the `certissuer.*` permissions are a separate tree from `app.*`: a role that grants `app.update` does not grant the right to manage issuers. See [Managing roles and permissions](../admin_guides/managing_roles.md).
