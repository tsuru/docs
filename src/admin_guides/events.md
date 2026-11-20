# Events, blocks and webhooks

Every action performed through the tsuru API (a deploy, an env change, a pool update, a team creation, a job trigger...) is recorded as an *event*. Events are the audit trail of a tsuru installation and also drive two administrative features: **event blocks**, which refuse actions while a block is active, and **event webhooks**, which notify external systems when an event finishes.

## What an event is

An event is a document stored in the `events` collection of tsuru's database. Its main fields are:

| Field | Description |
|-------|-------------|
| `UniqueID` | The ID shown by `tsuru event list` and used by `event info` and `event cancel`. |
| `Target` | What the action acts on, as a `Type` and a `Value`: `app(myapp)`, `pool(prod)`, `team(backend)`, `job(nightly-report)`. Target types include `global`, `app`, `job`, `pool`, `service`, `service-instance`, `team`, `user`, `role`, `platform`, `plan`, `cluster`, `volume`, `router`, `webhook`, `event-block` and `gc`. An event may carry `ExtraTargets` too (a service bind, for example, targets the app and the service instance). |
| `Kind` | The action. The kind has a `Type` (`permission` or `internal`) and a `Name`, see [Event kinds](#event-kinds). |
| `Owner` | Who did it: a `user` (email), a `token` (team token name), an `app` or `internal` for actions started by tsuru itself. |
| `SourceIP` | IP address of the API client. |
| `StartTime`, `EndTime`, `Running` | An event is created when the action starts and marked done when it finishes. `Running` is `true` in between. |
| `Error` | Empty on success; otherwise the error message that ended the action. |
| `Cancelable`, `CancelInfo` | Whether the action can be cancelled while running, and who asked for cancellation, when and why. See [Cancelling an event](#cancelling-an-event). |
| `StartCustomData`, `EndCustomData`, `OtherCustomData` | Free-form data recorded by the action: the form fields of the request at start (for example `name`, `pool`, `platform` of an `app.create`), the result at the end. |
| `Log` | Output produced while the action ran, for example the deploy log. |
| `Allowed`, `AllowedCancel` | The permission (and contexts) a user must hold to see this event, or to cancel it. |

### One running event per target

When an event is created with a lock (the default) it holds an exclusive lock on its target. If another action tries to start on the same target while the first is still running, it is rejected immediately with:

```
event locked: app(myapp) running "app.deploy" start by user john@example.com at 2026-11-20T14:03:11Z
```

This is why two deploys of the same app cannot run concurrently, and why a deploy fails with `event locked` while an `app update` is in progress. Wait for the running event to finish (or [cancel it](#cancelling-an-event)) and retry. Running events whose lock has not been refreshed for 5 minutes (for example because the tsuru API instance running them died) are closed by a background cleaner with the error `event expired, no update for <duration>`, which releases the lock. See [Server configuration](#server-configuration).

Two other reasons make tsuru refuse to start an event: an active [event block](#event-blocks) (`error running "app.deploy" on app(myapp): block app.deploy by all users on all targets: <reason>`) and [throttling](#server-configuration) (`event throttled, limit for app.deploy on app "myapp" is 3 every 10m0s`). Blocked events are recorded with that error, so they show up in `tsuru event list`; locked and throttled attempts are not recorded.

## Listing events

```bash
$ tsuru event list
$ tsuru event list -t app -v myapp
$ tsuru event list -k app.deploy -k app.update.env.set -o john@example.com
$ tsuru event list -r
```

| Flag | Description |
|------|-------------|
| `-t`, `--target-type` | Only events whose target (or extra target) has this type, for example `app`, `pool`, `team`. |
| `-v`, `--target-value` | Only events whose target (or extra target) has this value, for example the app name. |
| `-k`, `--kind` | Only events of this kind. Repeat the flag to match several kinds. |
| `-o`, `--owner` | Only events started by this owner (user email or token name). |
| `-r`, `--running` | Only events still running. |
| `--json` | Print the raw events as JSON. |

The output has one row per event with its ID, start time and duration, success, owner, kind and target. Events are sorted by start time, most recent first, and the API returns at most 100 events per request. The API (`GET /events`) accepts additional filters that the client does not expose: `since` and `until` (RFC 3339 timestamps), `errorOnly=true`, `ownerType`, `kindType`, `limit`, `skip` and `sort`. See the [API reference](../reference/api.md).

You only see the events you are allowed to see: tsuru filters the list by the `*.read.events` permissions you hold (`app.read.events`, `job.read.events`, `team.read.events`, `pool.read.events`, `service-instance.read.events`...), each inside its context. A user with `app.read.events` on team `backend` sees events of the apps owned by that team and nothing else. A role with `event-block.read.events`, `webhook.read.events` or `platform.read.events` is needed to see events on those targets, and a global `*.read.events` is the usual choice for administrators. See [Managing roles](managing_roles.md).

## Inspecting an event

```bash
$ tsuru event info 6740a1c2e5f9b3a1d4c8e9f0
```

`event info` prints the ID, start and end time, duration, targets, kind, owner, source IP, success flag (and the error, when there is one), cancelable/canceled flags with the cancellation reason and author, followed by the **Start Custom Data**, **End Custom Data** and **Other Custom Data** sections (as YAML-like text) and the **Log** of the action when the event has one. Use `--json` to get the same information as JSON.

Deploy events (`app.deploy`) record the full app, including environment variables, in their start data. With `events:suppress-sensitive-envs: true` in the server configuration, private environment variables (those set with `env set --private`, plus private variables injected by service bindings) are replaced by a placeholder in `event list` and `event info` responses.

## Cancelling an event

```bash
$ tsuru event cancel 6740a1c2e5f9b3a1d4c8e9f0 "wrong image, redeploying"
```

Only running events marked as cancelable can be cancelled; for any other event the API answers `400 event is not cancelable`. Cancelable kinds are:

| Kind | Action |
|------|--------|
| `app.deploy`, `app.build` | App deploy and build. |
| `app.update` | Only the `app version delete` (`DELETE /apps/{app}/versions/{version}`) variant. |
| `job.deploy`, `job.create` | Job deploy and job creation. |
| `platform.create`, `platform.update` | Platform image builds. |

Cancellation is cooperative: `event cancel` records the request (the client prints `Cancellation successfully requested.`) and the action running the event checks for it at its next safe point, aborts, and marks the event as canceled. A second `cancel` on the same event fails with `event cancel already requested`. The reason is mandatory and is shown by `event info`.

Cancelling needs the `*.update.events` permission for the target (`app.update.events`, `job.update.events`, `platform.update.events`) in the right context, while seeing the event needs `*.read.events`.

## Event kinds

Kind names follow the permission that guards the action, `<target>.<action>[.<sub-action>]`: `app.create`, `app.deploy`, `app.update.env.set`, `app.update.unit.add`, `job.trigger`, `pool.update.constraints.set`, `team.create`, `role.update.assign`, `service-instance.update.bind`. These have kind type `permission`. A few actions started by tsuru itself have kind type `internal` and a free-form name, such as `gc`, `version gc`, `bootstrap deploy` and `team rename`.

Because kinds mirror permissions, the complete list is the list of permissions, see `tsuru permission list`. `GET /events/kinds` returns the kinds that have actually been recorded in your installation (the distinct `kind` values of the `events` collection), which is handy to discover what to filter by:

```bash
$ curl -H "Authorization: bearer $TOKEN" https://tsuru.example.com/1.1/events/kinds
```

## Event blocks

An event block makes tsuru refuse to start the events that match it, until the block is removed. Use blocks to freeze changes during an incident or a maintenance window, for example to stop all deploys while a cluster is being migrated, or to stop a single team from touching production.

```bash
$ tsuru event block add "cluster migration in progress" -k app.deploy
$ tsuru event block add "freeze on prod pool" -t pool -v prod
$ tsuru event block add "no new apps on the prod pool" -k app.create -c pool=prod
$ tsuru event block add "revoked until further notice" -o john@example.com
```

| Flag | Description |
|------|-------------|
| `-k`, `--kind` | Block events whose kind name **starts with** this value. `-k app.update` blocks `app.update.env.set`, `app.update.unit.add` and every other `app.update.*` kind. Empty blocks all kinds. |
| `-o`, `--owner` | Block events started by this owner (user email or token name). Empty blocks every owner. |
| `-t`, `--type` | Block events with this target type. Alone (without `-v`) it blocks every target of that type, for example every pool. |
| `-v`, `--value` | Together with `-t`, block only this target, for example `-t app -v myapp`. |
| `-c`, `--conditions` | `name=value` pairs matched against the event's start custom data; repeat for several pairs. All pairs must match for the event to be blocked. |

All filters of a block are ANDed. A block with no filters at all blocks every action on the installation, except `event block` commands themselves (they are never blocked, so you can always remove a block). The reason is mandatory and is part of the error shown to the user whose action was refused:

```
error running "app.deploy" on app(myapp): block app.deploy by all users on all targets: cluster migration in progress
```

Conditions compare `name=value` against the form fields the API received when the event started, so they only work for kinds whose start data is a list of fields (`app.create`, `app.update`, `app.update.env.set`, `pool.update` and most other CRUD-style kinds), not for `app.deploy`, whose start data is a structure. In the `app.create -c pool=prod` example above, apps can still be created on other pools.

```bash
$ tsuru event block list            # all blocks, active or not, most recent first
$ tsuru event block list --active   # only blocks currently in effect
$ tsuru event block remove 6740a1c2e5f9b3a1d4c8e9f1
```

Blocks are never deleted: `block remove` deactivates the block and records its end time, so `block list` keeps the history. Adding or removing a block is itself an event (kinds `event-block.add` and `event-block.remove`, target type `event-block`).

Managing blocks needs the global permissions `event-block.add`, `event-block.read` and `event-block.remove`.

## Event webhooks

A webhook is an HTTP request that tsuru makes every time an event matching the webhook's filter **finishes**. Webhooks belong to a team and are a simple way to feed deploys and other changes into chat tools, incident timelines or your own automation.

```bash
$ tsuru event webhook create deploy-notify https://hooks.example.com/tsuru \
    -d "Notify #deploys about app deploys" -t backend \
    --kind-name app.deploy --target-type app \
    -H Content-Type=application/json \
    -b '{"text": "{{.Kind}} on {{.Target}} by {{.Owner.Name}}: {{if .Error}}failed: {{js .Error}}{{else}}done{{end}}"}'
```

| Flag | Description |
|------|-------------|
| `<name>`, `-u`/`--url` | Unique webhook name and the URL to call. The URL is positional on `create` and `-u` on `update`. |
| `-d`, `--description` | What the webhook is for. |
| `-t`, `--team` | Owner team. Defaults to your team when you belong to one team with `webhook.create`. |
| `-m`, `--method` | HTTP method; `POST` when unset. |
| `-H`, `--header` | `name=value` header; repeat for several headers. tsuru sets a `User-Agent` when you do not. |
| `-b`, `--body` | Request body, parsed as a Go `text/template` with the event as context (see below). When unset and the method is `POST`, `PUT` or `PATCH`, the body is the event serialized as JSON with `Content-Type: application/json`. If the body cannot be parsed as a template it is sent as-is. |
| `--proxy` | Proxy for the request; `http(s)` and `socks5` schemes are supported. Without it, the server-wide `proxy:<host>` configuration applies. |
| `--insecure` | Skip TLS certificate verification. |
| `--target-type`, `--target-value` | Match events whose target or extra target has one of these types or values. Repeat the flags for several. |
| `--kind-type`, `--kind-name` | Match events with one of these kind types (`permission`, `internal`) or kind names. Kind names must match exactly: `app.update` does not match `app.update.env.set`. |
| `--error-only`, `--success-only` | Only events that failed, or only events that succeeded. |

Filters are ANDed; an empty filter matches every event in the installation. `tsuru event webhook update <name>` takes the same flags plus `--no-<flag>` variants (`--no-body`, `--no-header`, `--no-insecure`, `--no-target-type`, `--no-target-value`, `--no-kind-type`, `--no-kind-name`, `--no-error-only`, `--no-success-only`) that clear a setting. `webhook list` shows the webhooks of your teams, `webhook info <name>` the full definition and `webhook delete <name>` removes one.

### Body templates

The template context is the finished event, so any field from [What an event is](#what-an-event-is) is available: `{{.UniqueID.Hex}}`, `{{.Target.Type}}`, `{{.Target.Value}}` (or `{{.Target}}` for `app(myapp)`), `{{.Kind.Name}}` (or `{{.Kind}}`), `{{.Owner.Type}}`, `{{.Owner.Name}}`, `{{.StartTime}}`, `{{.EndTime}}`, `{{.Error}}`, `{{.SourceIP}}`, `{{.CancelInfo.Canceled}}` and `{{.Log}}` (the action's log as a single string). Only the built-in template functions (`if`, `printf`, `js`, `html`, ...) are available; use `{{js .Error}}` or `{{printf "%q" .Error}}` to keep error messages from breaking JSON quoting. Custom data is stored in raw BSON and is not usable from the template.

A Slack-style notification with per-app detail:

```bash
$ tsuru event webhook create deploy-slack https://hooks.slack.com/services/T000/B000/XXXX \
    -t backend --kind-name app.deploy --target-type app -H Content-Type=application/json \
    -b '{"text": "{{if .Error}}:x: deploy of *{{.Target.Value}}* by {{.Owner.Name}} failed: {{js .Error}}{{else}}:white_check_mark: *{{.Target.Value}}* deployed by {{.Owner.Name}} ({{.StartTime.Format "15:04:05"}} - {{.EndTime.Format "15:04:05"}}){{end}}"}'
```

A webhook call is considered successful when the endpoint answers with a 2xx or 3xx status; other statuses and connection errors are logged by the API server (`[webhooks] error calling webhook ...`) and counted in the `tsuru_webhooks_*` Prometheus metrics. There are no retries.

Webhooks are checked against the `webhook.create`, `webhook.read`, `webhook.update` and `webhook.delete` permissions in the context of the owner team. Creating, updating or deleting a webhook is itself an event with target type `webhook`.

### Terraform

The same webhook can be declared with the [terraform provider](https://registry.terraform.io/providers/tsuru/tsuru/latest/docs/resources/webhook):

```hcl
resource "tsuru_webhook" "deploy_notify" {
  name        = "deploy-notify"
  description = "Notify #deploys about app deploys"
  team_owner  = "backend"
  url         = "https://hooks.example.com/tsuru"
  method      = "POST"
  headers = {
    "Content-Type" = "application/json"
  }
  body = "{\"text\": \"{{.Kind}} on {{.Target}} by {{.Owner.Name}}\"}"

  event_filter {
    kind_names   = ["app.deploy"]
    target_types = ["app"]
    success_only = true
  }
}
```

`name`, `description`, `team_owner` and `url` are required; `proxy_url`, `insecure` and `event_filter.{target_types,target_values,kind_types,kind_names,error_only,success_only}` map to the CLI flags above. Import an existing webhook with `terraform import tsuru_webhook.deploy_notify deploy-notify`.

## Server configuration

These keys live in the `tsurud` configuration file (see the [configuration reference](../reference/config.md)).

**`event:throttling`** limits how many events of a given kind may start on a target within a time window. It is a list of specs:

```yaml
event:
  throttling:
    - target-type: app
      kind-name: app.deploy
      limit: 3
      window: 600
    - target-type: app
      limit: 100
      window: 60
      all-targets: true
      wait-finish: true
```

| Key | Description |
|-----|-------------|
| `target-type` | Target type the spec applies to (`app`, `pool`, `job`...). Required. |
| `kind-name` | Kind name the spec applies to. When omitted the spec applies to every kind on that target type; a spec with a kind name takes precedence over one without. |
| `limit` | Maximum number of events in the window. `0` disables the spec. |
| `window` | Window length in **seconds**. |
| `all-targets` | When `true`, count events across all targets of the type (for example all apps) instead of per target. |
| `wait-finish` | When `true`, events still running also count towards the limit even if they started before the window. |

An attempt beyond the limit is refused with `event throttled, limit for app.deploy on app "myapp" is 3 every 10m0s`.

**`events:suppress-sensitive-envs`** (`true`/`false`, default `false`) hides private environment variable values in `app.deploy` events returned by the API, as described in [Inspecting an event](#inspecting-an-event).

**Expired event cleaner.** Every running event refreshes its lock every 30 seconds. A background worker in each API instance runs every 5 minutes and closes running events whose lock has not been refreshed for 5 minutes, recording the error `event expired, no update for <duration>` and incrementing the `tsuru_events_expired_total` metric. This is what frees a target after an API instance crashes mid-deploy; these intervals are not configurable.

Event creation also exposes the `tsuru_events_current`, `tsuru_events_duration_seconds` and `tsuru_events_rejected_total` (labelled by kind and by reason `locked`, `blocked`, `throttled` or `other`) metrics on `/metrics`.
