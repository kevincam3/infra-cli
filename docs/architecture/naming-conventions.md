# Naming Conventions

Conventions observed across the codebase. New code should follow these
unless there is a deliberate reason to diverge.

## Files & directories

| Kind                       | Convention                                        | Examples                                                                       |
| -------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------ |
| Bash source files          | `kebab-case.sh` (single-word here, but lowercase) | `logging.sh`, `secrets.sh`, `cleanup.sh`                                       |
| Node scripts               | `kebab-case.mjs`                                  | `release-preflight.mjs`, `postinstall.mjs`                                     |
| Top-level dirs             | lowercase, single-word                            | `bin/`, `lib/`, `scripts/`, `examples/`, `docs/`                               |
| Stack dirs (consumer side) | lowercase, single-word                            | `infrastructure/`, `applications/`, `tooling/`                                 |
| Compose files              | `docker-compose.<layer>.yml`                      | `docker-compose.base.yml`, `docker-compose.dev.yml`, `docker-compose.prod.yml` |
| Generated hook shims       | inside `.vite-hooks/_/` (gitignored)              | `pre-commit`, `commit-msg`                                                     |

`.mjs` is required for the Node scripts because the package has no
`"type": "module"` field; the extension forces ESM parsing.

## Bash

| Kind                      | Convention                         | Examples                                                                  |
| ------------------------- | ---------------------------------- | ------------------------------------------------------------------------- |
| Public functions          | `snake_case`                       | `load_config`, `ensure_network`, `run_stack`, `cleanup_exited_containers` |
| Private/internal helpers  | `_snake_case` (leading underscore) | `_resolve_bin_dir`, `_compute_explicit_services`                          |
| Local variables           | `snake_case`                       | `config_file`, `service_name`, `client_id`                                |
| Globals & exports         | `UPPER_SNAKE_CASE`                 | `PROJECT_NAME`, `PROJECT_DIR`, `ENVIRONMENT`, `COMPOSE_ACTION`            |
| User-facing config arrays | `UPPER_SNAKE_CASE`                 | `STACKS`, `NETWORKS`, `NETWORKS_DEV`, `DEV_SHARED_SERVICES`               |
| Per-stack config arrays   | `SECRETS_<STACK_UPPER>`            | `SECRETS_INFRASTRUCTURE`, `SECRETS_APPLICATIONS`, `SECRETS_TOOLING`       |
| Color/ANSI constants      | `UPPER_SNAKE_CASE`                 | `GREEN`, `YELLOW`, `RED`, `BLUE`, `RESET`                                 |

Every shell file begins with `#!/usr/bin/env bash`. The entrypoint
(`bin/infra.sh`) sets `set -Eeo pipefail`; library files do not, since
they rely on the caller's options.

## JavaScript (Node scripts)

| Kind                | Convention                       | Examples                                                 |
| ------------------- | -------------------------------- | -------------------------------------------------------- |
| Top-level constants | `UPPER_SNAKE_CASE`               | `RELEASE_BRANCH`, `GH_ACCOUNT`                           |
| Variables           | `camelCase`                      | `githubToken`, `targetDir`, `examplesDir`, `lastTag`     |
| Helper functions    | `camelCase` (often arrow consts) | `sh`, `fail`                                             |
| Imports             | Node namespace prefix preferred  | `node:child_process`, `node:fs`, `node:path`, `node:url` |

Strings use double quotes in `release-preflight.mjs` and single quotes in
`postinstall.mjs` — the codebase isn't consistent here yet. Match the
file you're editing.

## Compose project naming

Every `docker compose` invocation is namespaced as:

```
<PROJECT_NAME>-<ENVIRONMENT>-<STACK>
```

For example, `acme-dev-applications` or `acme-prod-tooling`. This pattern
is used both as the `-p` flag and as the value passed to
`label=com.docker.compose.project=...` filters in cleanup logic.

## Environment values

`--env` accepts both short and long forms; both are normalized to two
canonical values used internally and in compose filenames:

| Input                | Canonical |
| -------------------- | --------- |
| `dev`, `development` | `dev`     |
| `prod`, `production` | `prod`    |

## SECRETS entry format

Each entry in `SECRETS_<STACK>` is a single pipe-delimited string:

```
"service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|output_path|exclude_keys"
```

- `service_name` — lowercase, kebab-case (e.g. `traefik`, `tooling-mysql`).
- `CLIENT_ID_VAR` / `CLIENT_SECRET_VAR` — env-var **names** (not values),
  conventionally `<SERVICE>_CLIENT_ID` / `<SERVICE>_CLIENT_SECRET` in
  `UPPER_SNAKE_CASE`.
- `output_path` — relative to the project dir, e.g. `tooling/mysql/.env`.
- `exclude_keys` — space-separated list of keys to strip; may be empty.

## Logging output

The `lib/logging.sh` helpers prefix output with one of these glyphs:

| Helper    | Glyph          | Color  | Stream |
| --------- | -------------- | ------ | ------ |
| `info`    | `ℹ`            | blue   | stdout |
| `success` | `✔`            | green  | stdout |
| `warn`    | `⚠`            | yellow | stdout |
| `error`   | `✖`            | red    | stderr |
| `section` | (rule + title) | blue   | stdout |

Section titles use Title Case and lead with an emoji that signals intent:
`🚀` for stack lifecycle, `🔐` for secrets, `🧹` for cleanup.

## npm package

- Scoped under `@kevincam3/`.
- Single bin entry: `infra` → `./bin/infra.sh`.
- Engines: Node `>=22`.
