# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A CLI tool (`infra`) consumed by other projects as an npm package (`github:kevincam3/infra-cli`). It orchestrates Docker Compose stacks across three layers (`infrastructure/`, `applications/`, `tooling/`) with environment-aware secret injection via Infisical. The CLI is pure bash; the only Node.js pieces are the banner renderer and postinstall scaffolding.

## Commands

```bash
pnpm install          # install dev dependencies
pnpm run prepare      # configure vite-plus (runs vp config — sets up git hooks)
pnpm verify           # everything CI runs: typecheck, shellcheck, test (if present)
```

There are no tests and no build step — the bash scripts run directly.

`pnpm verify` is the single script the CI workflow runs, and the `pre-merge-commit` and `pre-push` hooks in `.vite-hooks/` run it as well. Add new checks to `verify` in `package.json` rather than as workflow steps, so CI and local merges stay identical. `shellcheck` needs Docker running.

## Commits

All commit messages must follow the [Conventional Commits](https://www.conventionalcommits.org/) spec:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`.

Breaking changes must be indicated either with a `!` after the type/scope (`feat!:`) or with a `BREAKING CHANGE:` footer — or both.

## Releasing

Releases are automated: every push to `main` runs `.github/workflows/ci.yml`, whose `release` job runs `pnpm exec semantic-release` once the `check` job (`pnpm verify`) has passed. There is no local release command. Releases are driven entirely by conventional commits — `feat:` bumps minor, `fix:` bumps patch, `feat!:` / `BREAKING CHANGE:` footer bumps major; other types (`chore:`, `docs:`, …) publish nothing.

When a release is due, semantic-release (configured under `release` in `package.json`) updates `CHANGELOG.md` and the `package.json` version, publishes `@kevincam3/infra-cli` to GitHub Packages, commits both files as `chore(release): X.Y.Z [skip ci]`, and creates the tag and GitHub Release.

Commits must pass commitlint (`@commitlint/config-conventional`), enforced via the `commit-msg` git hook installed by vite-plus.

## Architecture

`bin/infra.sh` is the entry point. It sources all four `lib/` modules, parses CLI args, then orchestrates the run:

1. `lib/config.sh` — `load_config()` sets defaults and sources `infra.config.sh` from the consumer's project dir (the `docker/` dir where `infra` is run from, not this repo).
2. Networks are ensured (`lib/stacks.sh:ensure_network`).
3. `infra_pre_start` hook fires if defined in the consumer's config.
4. For each stack: `lib/stacks.sh:run_stack()` calls `lib/secrets.sh:export_stack_secrets()` then `docker compose up/down`.
5. After `start`: `lib/cleanup.sh` sweeps exited containers, anonymous volumes, and old images.

## Secret export (`lib/secrets.sh`)

Secrets are fetched from Infisical using per-service machine identities and exported directly into the shell environment (no `.env` files written). Key behaviours:

- **Auto-prefix**: every exported key is prefixed with the uppercased service name (`tooling-postgres` → `TOOLING_POSTGRES_`). Non-alphanumeric chars become underscores.
- **No double-prefix**: if a key already starts with the derived prefix it is exported as-is.
- **Dotenv parser**: values are parsed directly (not `source`d) so embedded double quotes are preserved.
- **`exclude_keys`**: strips keys by their original unprefixed name, before prefixing. Used to suppress keys that Infisical pulls in transitively via secret references.

Because secrets land in the environment prefixed, docker compose files in consumer projects must map them explicitly:

```yaml
environment:
  DB_PASSWORD: ${TOOLING_POSTGRES_DB_PASSWORD}
```

## `SECRETS_*` entry format

```
"service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|exclude_keys"
```

`CLIENT_ID_VAR` and `CLIENT_SECRET_VAR` are the _names_ of env vars (not the values) that hold the Infisical Universal Auth credentials. They are read from `.env.infisical-auth.<env>` sourced at runtime.

## Postinstall scaffolding

`scripts/postinstall.mjs` runs when a consumer installs the package. It copies `examples/infra.config.sh`, `examples/env.infisical-auth.dev`, and `examples/env.infisical-auth.prod` into the consumer's directory (skipping files that already exist). In pnpm workspaces it detects the correct sub-package via `pnpm-workspace.yaml`.

## Plane

Work for this repo is tracked in Plane: workspace `kev-services` (MCP server `plane-kev-services`), project `INFRACLI` — Infra cli (project id `d3464f7b-408e-4b86-b6ae-f44c6b25ba24`). Use that workspace and project for any Plane read or update from this repo without asking which one.
