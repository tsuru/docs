# Jobs and cronjobs

A job is a program that runs to completion instead of serving requests: a database migration, a nightly report, a cleanup task. tsuru runs jobs on Kubernetes as a [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/), either on a schedule or only when you trigger it. Jobs are available since tsuru 1.15.

Jobs share most concepts with apps: they belong to a team, live in a pool, use a plan, have environment variables, can be bound to service instances and emit events. They do not have routers, processes or versions.

## Scheduled vs manual

| Kind | How it runs | Create with |
|------|-------------|-------------|
| Scheduled (cronjob) | Kubernetes starts an execution at each tick of the cron expression. You can also trigger it by hand. | `--schedule "<cron expression>"` |
| Manual | Never runs on its own. tsuru creates a *suspended* CronJob and only `tsuru job trigger` starts an execution. | `--manual` |

Exactly one of `--schedule` or `--manual` is required; passing both is rejected.

## Creating a job

```bash
$ tsuru job create nightly-report --schedule "0 3 * * *" --pool mypool --team myteam
$ tsuru job create db-migrate --manual --plan small --description "Run pending migrations"
```

| Option | Description |
|--------|-------------|
| `-s`, `--schedule` | Standard five-field cron expression (`minute hour day-of-month month day-of-week`); descriptors such as `@hourly` are accepted too. Test expressions at <https://crontab.guru/>. tsuru does not set a time zone on the CronJob, so the cluster's time zone applies (usually UTC). |
| `--manual` | Create a manual job. |
| `-o`, `--pool` | Pool where the job runs. Required when your teams have access to more than one pool. The pool cannot be changed later. |
| `-t`, `--team` | Owner team. Required when you belong to more than one team. The team must have access to the pool. |
| `-p`, `--plan` | Resource plan (CPU and memory for each execution). Defaults to the pool's default plan; must be allowed in the pool. |
| `-m`, `--max-running-time` | Seconds an execution may run before Kubernetes kills it (`activeDeadlineSeconds`). Default **3600**. Passing `0` resets to the default. |
| `-d`, `--description` | Free-text description shown in `tsuru job info`. |
| `-g`, `--tag` | Tag; repeat the flag for several tags. See [Metadata and tags](#metadata-and-tags). |

Job names must match `^[a-z][a-z0-9-]{0,39}$` (lower case letters, digits and dashes, starting with a letter, at most 40 characters) and are unique across the whole tsuru installation, not just inside a team or pool.

!!! note
    `tsuru job create` still accepts an image and a command as positional arguments, but the client prints a deprecation warning. Create the job without them and use `tsuru job deploy` (below) instead.

See [tsuru job create](../tsuru_client/tsuru_job_create.md) for the full reference.

## Deploying the image

A job created without an image exists only in tsuru's database. Nothing is created in the cluster and nothing runs, scheduled or triggered, until the first deploy.

Deploy a container image you already built:

```bash
$ tsuru job deploy -j nightly-report --image registry.example.com/reports/nightly:v3
```

Or let tsuru build it from a Dockerfile, sending the build context as positional arguments (the same mechanics as [deploying an app with a Dockerfile](deploy_using_dockerfile.md)):

```bash
$ tsuru job deploy -j nightly-report --dockerfile .
$ tsuru job deploy -j nightly-report --dockerfile ./Dockerfile.report ./report/
```

`--image` and `--dockerfile` are mutually exclusive, and you cannot send files together with `--image`. `.tsuruignore` and `.dockerignore` are honoured. Use `-m` to attach a message to the deploy event. `tsuru job deploy` requires tsuru 1.23.

The deploy pushes the image to tsuru's registry, records it on the job and creates (or updates) the CronJob in the pool's namespace. Every execution uses the plan's resource limits, restarts its pod on failure (`restartPolicy: OnFailure`) and is kept for one day after it finishes so you can inspect it.

### The command

By default an execution runs the image's own entrypoint and `CMD`. To override it, pass the command after `--` in `tsuru job update`:

```bash
$ tsuru job update nightly-report -- python report.py --format pdf
```

A single quoted argument is also accepted: it is parsed as a JSON array if it looks like one (`'["python", "report.py"]'`), otherwise split like a shell would.

## Running a job manually

```bash
$ tsuru job trigger db-migrate
```

This works for both manual and scheduled jobs and creates one execution immediately, named `<job>-manual-job-<timestamp>` where the timestamp has one-minute resolution.

!!! warning "Once per minute"
    Because of that naming, a job can be triggered at most once per minute. A second trigger inside the same minute fails with `manual job "..." already exists (cronjobs can only be triggered once per minute)`.

Triggering requires the `job.run` permission on the job.

## Inspecting jobs

```bash
$ tsuru job list
$ tsuru job list --pool mypool --team myteam
$ tsuru job list -q           # names only
$ tsuru job info nightly-report
```

`tsuru job list` shows name, schedule (`manual` for manual jobs), image and command, and filters by `--name`, `--pool`, `--plan` and `--team`.

`tsuru job info` shows the job's teams, owner, cluster, pool, plan, schedule (scheduled jobs only), image, command, max running time and concurrency policy, followed by:

- **Units**: one row per execution kept in the cluster (up to one day after it finished) with name, status, restarts and age. Status is `started`, `succeeded` or `error`; on error the Kubernetes failure reason (for example `DeadlineExceeded` or `BackoffLimitExceeded`) is shown.
- **Service instances** bound to the job.
- **Dashboard**: a link to an external dashboard, when the administrator configured `jobs:dashboard-url:template` in `tsuru.conf`.

Both commands accept `--json`.

## Logs

```bash
$ tsuru job log nightly-report
$ tsuru job log nightly-report -f
```

Logs are served by tsuru's log service rather than read from the finished pods, so they are not tied to the one-day retention of the executions. `-f` keeps streaming new lines. Reading logs requires the `job.read.logs` permission.

## Environment variables

Jobs have their own environment variables, managed with the same commands as apps using `-j` instead of `-a`:

```bash
$ tsuru env set -j nightly-report REPORT_BUCKET=reports TZ=America/Sao_Paulo
$ tsuru env set -j nightly-report API_TOKEN=secret -p
$ tsuru env get -j nightly-report
$ tsuru env unset -j nightly-report TZ
```

Private variables (`-p`) are hidden in `tsuru env get` and delivered to the pod through a Kubernetes Secret named `tsuru-job-<job>` (unless the pool disables secrets). Changes take effect on the next execution; running executions are not affected. If the job has no image yet, variables are stored and applied on the first deploy.

Every execution also receives `TSURU_SERVICES` describing the bound service instances; see [TSURU_SERVICES environment variable](../services/environment_variables.md).

## Binding service instances

```bash
$ tsuru service instance bind mysql reports-db -j nightly-report
$ tsuru service instance unbind mysql reports-db -j nightly-report
```

Binding calls the service API and injects the variables it returns as private environment variables, then updates the CronJob so the next execution sees them. The service must be available in the job's pool, otherwise the bind fails with HTTP 400. `--no-restart` has no effect on jobs. `tsuru job info` lists the current binds.

## Metadata and tags

Labels and annotations are added to the CronJob, to every execution and to its pods:

```bash
$ tsuru metadata set -j nightly-report team-cost-center=finance -t label
$ tsuru metadata set -j nightly-report alerts.example.com/channel=reports -t annotation
$ tsuru metadata get -j nightly-report
$ tsuru metadata unset -j nightly-report team-cost-center -t label
```

The `tsuru.io/` prefix is reserved and rejected. tsuru itself sets `tsuru.io/job-name`, `tsuru.io/job-team`, `tsuru.io/job-pool`, `tsuru.io/is-job` and `tsuru.io/job-manual` on every object; custom labels can never override them.

Tags (`--tag` on create and update) are free strings stored on the job. A tag written as `key=value` is also applied as the label `tsuru.io/custom-tag-key=value`, as long as `custom-tag-key` is a valid label name; other tags are stored but not turned into labels.

## Updating a job

```bash
$ tsuru job update nightly-report --schedule "30 2 * * *" --max-running-time 1800
$ tsuru job update nightly-report --manual           # stop scheduling, keep it triggerable
$ tsuru job update db-migrate --schedule "@daily"    # turn a manual job into a scheduled one
$ tsuru job update nightly-report --plan medium --description "Nightly PDF report"
```

Updates are a merge: only the fields you pass change, everything else keeps its current value. Consequently you cannot clear a description or the tags through the CLI, only replace them.

- Switching between scheduled and manual is allowed, but `--schedule` and `--manual` cannot be given together.
- Changing the schedule replaces the Kubernetes CronJob object (its name embeds a hash of the schedule), so previous executions disappear from `tsuru job info`. Logs are kept.
- `--pool` is rejected with `Update pool is not implemented yet`. Create a new job to move pools.
- `--plan` is validated against the plans allowed in the pool.
- The concurrency policy (`Allow`, `Forbid` or `Replace`, same meaning as in Kubernetes) can only be set through the API field `concurrencyPolicy` on `PUT /1.13/jobs/{name}`; the CLI has no flag for it. `tsuru job info` shows it when set.

See [tsuru job update](../tsuru_client/tsuru_job_update.md).

## Killing a running execution

Each row in the **Units** table of `tsuru job info` is a Kubernetes Job. Stop one with:

```bash
$ tsuru unit kill -j nightly-report nightly-report-manual-job-29876543
$ tsuru unit kill -j nightly-report -f nightly-report-29876600
```

This deletes the Kubernetes Job and its pods. `-f` shortens the termination grace period to one second. The unit must belong to the given job, otherwise tsuru answers 404.

## Deleting a job

```bash
$ tsuru job delete nightly-report
$ tsuru job delete nightly-report -y
```

tsuru removes the CronJob, the job's Secret and service account, then deletes the job record and releases the quota slot. Executions still in the cluster are garbage-collected with the CronJob.

## Events

Every operation is recorded as an event with target type `job`:

| Kind | Emitted by |
|------|------------|
| `job.create`, `job.update`, `job.delete` | `tsuru job create/update/delete`; `job.update` is also used for `env set/unset`, `metadata set/unset` and service `bind/unbind` |
| `job.deploy` | `tsuru job deploy` (cancelable while running) |
| `job.trigger` | `tsuru job trigger` |
| `job.unit.kill` | `tsuru unit kill -j` |
| `job.run` | tsuru itself, each time an execution completes or fails (`BackoffLimitExceeded`). These events carry the Kubernetes reason and message and expire automatically (after at most one day). |

```bash
$ tsuru event list -t job -v nightly-report
$ tsuru event list -t job -v nightly-report -k job.run
```

Reading events requires `job.read.events`.

## Quotas and permissions

Jobs count against the same quotas as apps: each job uses one slot of the owner team's quota and one of the creating user's quota (team tokens have no user quota). See [team quota](../admin_guides/managing_teams.md#team-quota).

The job permissions are `job.create`, `job.read`, `job.read.logs`, `job.read.events`, `job.run`, `job.trigger`, `job.deploy`, `job.update`, `job.update.events`, `job.delete`, `job.unit` and `job.unit.kill`. Except for `job.create`, which is granted per team or globally, they can be scoped to a team, a pool, a single job or globally. See [Managing permissions and roles](../admin_guides/managing_roles.md).
