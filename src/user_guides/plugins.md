# Client plugins and configuration

The `tsuru` command-line client can be extended with plugins and tuned through a few files and environment variables. This page covers both.

## Plugins

A plugin is any executable file placed under `~/.tsuru/plugins`. When you run `tsuru <name> ...` and `<name>` is not a built-in command, the client looks for an executable called `<name>` (with or without extension) in that directory, either directly or inside a `<name>/` subdirectory, and runs it with the remaining arguments.

A plugin wins a name conflict with the built-in shorthands (`deploy`, `rollback`, `log`, `info`, `shell`), but a user-defined [alias](#command-aliases) is expanded before any lookup, so it wins over both. Public plugins are tagged [`tsuru-plugin`](https://github.com/topics/tsuru-plugin) on GitHub.

### Installing, listing and removing

```bash
$ tsuru plugin install <plugin-name> <plugin-url>
$ tsuru plugin list
$ tsuru plugin remove <plugin-name>
```

`plugin install` downloads the URL into `~/.tsuru/plugins`. The download may be:

| Content | Behaviour |
|---------|-----------|
| A single script or binary | Saved as `~/.tsuru/plugins/<plugin-name>` and made executable. The remote file name does not matter. |
| A `.tar.gz` or `.zip` archive | Extracted to `~/.tsuru/plugins/<plugin-name>/`. It must contain an executable named `<plugin-name>` (extension optional). |
| A `manifest.json` | tsuru picks the archive for the current `GOOS/GOARCH` from `UrlPerPlatform` and installs it as above. |

Reinstalling replaces the previous copy.

### Installing a bundle

```bash
$ tsuru plugin bundle --url <bundle-url>
```

The URL must serve a JSON document listing plugins to install in one go:

```json
{"plugins": [{"name": "rpaasv2", "url": "https://example.com/rpaasv2/manifest.json"}]}
```

Each entry goes through the same logic as `plugin install`. The command prints which plugins succeeded and fails if any did not.

### What a plugin receives

The plugin inherits your whole environment plus these variables:

| Variable | Value |
|----------|-------|
| `TSURU_TARGET` | The current target URL. |
| `TSURU_TOKEN` | Your authentication token. |
| `TSURU_PLUGIN_NAME` | The name the plugin was called by. |
| `TSURU_VERBOSITY` | Set when `--verbosity` was passed or the variable was already set. |
| `TSURU_TABLE_COLOR`, `TSURU_TABLE_UTF8` | The table border colour and UTF-8 setting in effect, so plugin tables match. |
| `NO_COLOR` | Set to `1` when colours are disabled. |
| `TSURU_PAGER` | Set when a pager is configured (see below). |

The global flags `--target`, `--verbosity` and `--config` are parsed before the plugin runs and exported as `TSURU_TARGET`, `TSURU_VERBOSITY` and `TSURU_CONFIG_FILE`; everything else goes to the plugin untouched. A plugin that runs `tsuru` itself does not recurse: a plugin cannot invoke a plugin of its own name.

### Writing a plugin

Any language works. A minimal shell plugin:

```bash
$ cat > ~/.tsuru/plugins/hello <<"EOF"
#!/bin/sh
echo "Hello from ${TSURU_PLUGIN_NAME}, target ${TSURU_TARGET}, args: $@"
EOF
$ chmod +x ~/.tsuru/plugins/hello
$ tsuru hello world
```

To talk to the API, send `Authorization: bearer $TSURU_TOKEN` to `$TSURU_TARGET`. To distribute a compiled plugin for several platforms, publish a `manifest.json`:

```json
{
  "SchemaVersion": "1.0",
  "Metadata": {"Name": "myplugin", "Version": "1.0.0"},
  "UrlPerPlatform": {
    "linux/amd64": "https://example.com/myplugin_linux_amd64.tar.gz",
    "darwin/arm64": "https://example.com/myplugin_darwin_arm64.tar.gz"
  }
}
```

The full guide lives in the client repository: [Developing Tsuru Plugins](https://github.com/tsuru/tsuru-client/blob/main/plugins.md).

## Targets

A target is a tsuru API endpoint with a label. Targets live in `~/.tsuru/targets`; the current one is in `~/.tsuru/target` and its token in `~/.tsuru/token.d/<label>`.

```bash
$ tsuru target add <label> <url> [-s]
$ tsuru target list
$ tsuru target set <label>
$ tsuru target update <label> <url> [-s]
$ tsuru target remove <label>
```

`-s/--set-current` makes the new or updated target the current one. `TSURU_TARGET` and `TSURU_TOKEN`, when set, take precedence over the files, which is how CI jobs and plugins run without a `tsuru login`.

## Command aliases

Since client 1.38.1 you can define shortcuts for commands:

```bash
$ tsuru config alias "app deploy" "deploy"
$ tsuru deploy myapp
$ tsuru config alias "app info" "ai"
$ tsuru ai myapp
$ tsuru config alias "app info" -d   # remove the alias
```

The first argument is the real command, the second the alias; both may contain spaces. An alias is expanded before anything else, so it can override a built-in command or a plugin of the same name. Aliases are stored as JSON in `$HOME/.config/tsuru/config.json`. Point the client at another file with the global `--config <path>` flag or the `TSURU_CONFIG_FILE` environment variable.

!!! note
    `tsuru config --help` mentions a `TSURU_CONFIG_PATH` variable; the client actually reads `TSURU_CONFIG_FILE`.

## Output settings

Output options are read from `~/.tsuru/client.yaml` or from environment variables named `TSURU_<KEY>` with dashes turned into underscores (`pager` becomes `TSURU_PAGER`).

| Key | Effect |
|-----|--------|
| `disable-colors` | Turn colours off. The standard `NO_COLOR` variable, a dumb terminal or a non-terminal stdout do the same. |
| `color-stream` | Colour streamed output such as deploy logs. Defaults to on in a modern terminal. |
| `pager` | `false` disables paging; a string such as `less -R` sets the pager command. Default: `less -RFX`, used only when stdout is a terminal and the output is taller than it. |
| `table-utf8` | Use UTF-8 box-drawing borders in tables. Defaults to on in a modern terminal. |
| `table-color` | Colour of table borders, e.g. `hi-black`, `blue`. |
| `tab-writer`, `tab-writer-padding`, `tab-writer-truncate`, `break-any`, `force-wrap` | Table layout tweaks (tab-aligned columns instead of borders, padding, truncation, wrapping). |

```yaml
# ~/.tsuru/client.yaml
pager: false
disable-colors: true
```

Commands that support machine-readable output take `--json`; check each command's [reference page](../tsuru_client/tsuru.md). `--verbosity 1` prints the HTTP requests the client makes and `--verbosity 2` also prints the responses.

## Self-update checks

| Variable | Effect |
|----------|--------|
| `TSURU_CLIENT_FORCE_CHECK_UPDATES` | `true` forces the version check even when it was done recently. It blocks if the release server does not answer. |
| `TSURU_CLIENT_SELF_UPDATE_SNOOZE_DURATION` | Suppress the update check for a duration such as `72h`. |
| `TSURU_CLIENT_IGNORE_OUTDATED_PCLOUD_REPO` | `true` silences the warning about an outdated packagecloud repository on deb/rpm installs. |

## Shell completion

```bash
$ tsuru completion bash > /etc/bash_completion.d/tsuru
$ tsuru completion zsh > "${fpath[1]}/_tsuru"
$ tsuru completion fish > ~/.config/fish/completions/tsuru.fish
$ tsuru completion powershell | Out-String | Invoke-Expression
```

`--no-descriptions` drops the help text from the generated script. Completion scripts for the four shells are documented under [tsuru completion](../tsuru_client/tsuru_completion.md).
