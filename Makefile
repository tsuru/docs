PIP_BIN ?= pip3
POETRY_BIN ?= poetry

.PHONY: build
build: install/package-deps
	$(POETRY_BIN) run mkdocs build

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

generate-tsuru-client-docs:
	rm -Rf src/tsuru_client
	mkdir -p src/tsuru_client
	cd src/tsuru_client && \
		tsuru generate-doc

.PHONY: install/system-deps
install/system-deps:
	@ $(POETRY_BIN) --version || \
		{ echo "Installing poetry using pip"; $(PIP_BIN) install poetry; }
