PIP_BIN ?= pip3
POETRY_BIN ?= poetry

.PHONY: build
build: install/package-deps
	$(POETRY_BIN) run mkdocs build --strict

.PHONY: clean
clean:
	rm -rfv ./site

.PHONY: serve
serve: install/package-deps
	$(POETRY_BIN) run mkdocs serve

.PHONY: install/package-deps
install/package-deps: install/system-deps
	@ echo "Installing package dependecies..."
	$(POETRY_BIN) install --no-root

TSURU_CLIENT_VERSION ?= main

# Installs the pinned client into ./.bin and runs it under an empty HOME, so the
# plugins installed in ~/.tsuru/plugins never leak into the generated pages.
.PHONY: generate-tsuru-client-docs
generate-tsuru-client-docs:
	GOBIN=$(CURDIR)/.bin go install github.com/tsuru/tsuru-client/tsuru@$(TSURU_CLIENT_VERSION)
	rm -Rf src/tsuru_client
	mkdir -p src/tsuru_client
	cd src/tsuru_client && HOME=$$(mktemp -d) $(CURDIR)/.bin/tsuru generate-doc

.PHONY: install/system-deps
install/system-deps:
	@ $(POETRY_BIN) --version || \
		{ echo "Installing poetry using pip"; $(PIP_BIN) install poetry; }
