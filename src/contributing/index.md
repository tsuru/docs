# Contributing to tsuru

tsuru is a set of repositories under [github.com/tsuru](https://github.com/tsuru). The ones you
are most likely to touch:

| Repository | What it is |
|---|---|
| [tsuru/tsuru](https://github.com/tsuru/tsuru) | the API server, `tsurud` |
| [tsuru/tsuru-client](https://github.com/tsuru/tsuru-client) | the `tsuru` CLI |
| [tsuru/deploy-agent](https://github.com/tsuru/deploy-agent) | image builds |
| [tsuru/kubernetes-router](https://github.com/tsuru/kubernetes-router) | the router API |
| [tsuru/platforms](https://github.com/tsuru/platforms) | official platform images |
| [tsuru/tsuru-charts](https://github.com/tsuru/tsuru-charts) | Helm charts |
| [tsuru/docs](https://github.com/tsuru/docs) | this site |

All of them are BSD-3 licensed. Every Go file carries the copyright header; CI checks it with
`misc/check-license.sh`.

## Commits and pull requests

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(platform): ...`, `fix(deps): ...`, `chore(kubernetes): ...`, `docs(api): ...`. The scope is
  the package or area touched.
- Open a pull request against `main`. CI must be green; see the checks below so you can run them
  before pushing.
- Add yourself to `CONTRIBUTORS` on your first change to tsuru/tsuru. CI
  (`misc/check-contributors.sh`) fails when a commit author e-mail is missing from that file.
- Releases are git tags. Tagging `vX.Y.Z` on tsuru/tsuru publishes the `tsuru/api:X.Y.Z` image
  and a GitHub release through GoReleaser; tsuru-client releases the same way. The API version
  string in `api/server.go` and `docs/reference/api.yaml` is bumped with `make release version=X.Y.Z`.

## Working on tsuru/tsuru

You need Go (the version in `go.mod`), Docker or Podman, and for integration tests a Kubernetes
cluster such as minikube.

| Command | What it does |
|---|---|
| `make test` | unit tests for every package plus `tsurud api --dry` against `etc/tsuru.conf`, which catches config loading errors |
| `make race` | the unit tests with the race detector, as CI runs them |
| `make lint` | golangci-lint, yamlfmt lint and the contributors check |
| `make yamlfmt` | formats YAML files |
| `make api-doc` | regenerates `docs/handlers.yml`, the list of API handlers, with tsuru-api-docs |
| `make check-api-doc` | fails when a handler lacks its doc comment |
| `make validate-api-spec` | validates `docs/reference/api.yaml` with go-swagger |
| `make run-tsurud-api` (alias `make run`, `make serve`) | builds and starts `tsurud api` with the config at `etc/tsuru.conf` |
| `make run-tsurud-token` | builds `tsurud` and prints a token |
| `make generate-grpc` | regenerates gRPC code |

CI also runs `misc/check-handlers.sh` (every API handler must call a permission check or be on
the allow list), `misc/check-events.sh` (every mutating handler must record an event),
`misc/govulncheck.sh`, `hack/verify-codegen.sh` and the integration suite from `make test-ci-integration`.

### Running tsuru locally

Two scripts set up a development environment:

- **Docker Compose**: `misc/setup-docker-compose.sh` followed by
  `docker compose --profile tsurud-api up -d` runs MongoDB, a registry, deploy-agent and the API in
  containers. The full walkthrough is in
  [Running development environment with Docker Compose](docker-compose.md).
- **`misc/local-dev.sh`**: runs `tsurud` from your checkout on the host. It assigns a fixed loopback
  IP (`100.64.100.100`) so containers and minikube can reach the API at port 8080, renders the config
  templates from `etc/`, and configures the client. Subcommands: `setup-loopback`, `setup-tsuru-user`,
  `setup-tsuru-target`, `setup-tsuru-cluster`, `render-templates`; `-h` prints them.

## Working on this documentation

The site is built with MkDocs. `make serve` previews it; `make build` (`mkdocs build --strict`)
is what CI runs, so broken links fail the build. CLI reference pages under `src/tsuru_client/` are
generated from tsuru-client with `make generate-tsuru-client-docs` and must not be edited by hand.
The API specifications are embedded from the `tsuru/tsuru` repository, so fix them there.
