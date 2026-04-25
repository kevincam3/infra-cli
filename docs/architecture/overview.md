# Architecture Overview

`infra-cli` is a Bash-based CLI distributed as an npm package
(`@kevincam3/infra-cli`). It orchestrates per-project Docker Compose stacks
across three layers — `infrastructure/`, `applications/`, `tooling/` — for
two environments (`dev`, `prod`), with optional Infisical-backed secret
export for prod.

## Components

```
bin/
  infra.sh                # entrypoint; argument parsing, top-level flow
lib/
  logging.sh              # info / success / error / warn / section helpers
  config.sh               # loads ./infra.config.sh + applies defaults
  secrets.sh              # Infisical secret export (prod only)
  stacks.sh               # ensure_network, run_stack, dev shared-service dedup
  cleanup.sh              # exited containers, anonymous volumes, old images
scripts/
  postinstall.mjs         # scaffolds example config files into INIT_CWD
  release-preflight.mjs   # gates `pnpm release` and execs semantic-release
examples/
  infra.config.sh         # template copied to the consumer on install
  env.infisical-auth      # template copied to the consumer on install
```

`bin/infra.sh` `source`s every file in `lib/` at startup; library files
expose functions only and read globals set by the entrypoint
(`PROJECT_NAME`, `ENVIRONMENT`, `STACKS`, `PROJECT_DIR`, etc.).

## Runtime flow

1. **Resolve install dir** — `bin/infra.sh` follows symlinks (pnpm/npm bin
   shims) to find the package root and load `lib/*.sh`.
2. **Parse args** — `start | stop | help | version`, plus `--env dev|prod`.
3. **Load config** — `load_config` sources `./infra.config.sh` if present,
   then fills in defaults; `PROJECT_NAME` falls back to the `name` field of
   `./package.json`.
4. **Ensure networks** — every entry in `NETWORKS` (and `NETWORKS_DEV` when
   `--env dev`) is created if missing. Each entry is a network name plus
   optional `docker network create` flags.
5. **Iterate stacks** — for each entry in `STACKS`, `run_stack` skips
   silently if neither `<stack>/docker-compose.base.yml` nor
   `<stack>/docker-compose.<env>.yml` exists. Otherwise:
   - **Prod only:** `export_stack_secrets` writes a `.env` per Infisical
     machine identity listed in `SECRETS_<STACK>`.
   - **Dev only:** `_compute_explicit_services` filters out
     `DEV_SHARED_SERVICES` already running under another compose project,
     so multiple projects share a single host-port-bound instance.
   - `docker compose -p <PROJECT_NAME>-<env>-<stack> ... <up|down>` runs.
6. **Cleanup (start only)** — exited containers labelled with this
   project's compose project name, anonymous volumes globally, and old
   images older than the currently-running version per repo.

## Distribution & install

- Published as a GitHub-installable package; consumers add
  `@kevincam3/infra-cli` to a `docker/package.json` and pin to a tag.
- `scripts/postinstall.mjs` copies `examples/infra.config.sh` and
  `examples/env.infisical-auth` (renamed `.env.infisical-auth`) into
  `INIT_CWD` if absent. It is idempotent and never fails the install.

## Releases

- `pnpm release` runs `scripts/release-preflight.mjs`, which:
  1. Resolves `GITHUB_TOKEN` from env or `gh auth token --user kevincam3`.
  2. Verifies branch (`main`), clean tree, and parity with `origin/main`.
  3. Lists commits since the last tag and prompts for confirmation.
  4. Execs `pnpm exec semantic-release --no-ci` with `GITHUB_TOKEN` injected.
- Conventional Commits drive version bumps via
  `@semantic-release/commit-analyzer`; `@semantic-release/git` commits
  `package.json` + `CHANGELOG.md`; `@semantic-release/github` cuts the
  release. npm publish is disabled (`npmPublish: false`).

## Tooling

- **vite-plus** (`vp`) provides the staged-files check and generates git
  hook shims into `.vite-hooks/_/` via the `prepare` script.
- **commitlint** (`@commitlint/config-conventional`) runs from the
  `commit-msg` hook to enforce Conventional Commit subjects.
