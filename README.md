# infra-cli

Opinionated CLI for orchestrating per-project Docker Compose stacks across `infrastructure/`, `applications/`, and `tooling/` layers — with environment-aware secret export via Infisical.

## Install

Add to your project's `docker/package.json`:

```json
{
  "scripts": {
    "dev": "infra start --env dev",
    "dev:down": "infra stop  --env dev",
    "prod": "infra start --env prod",
    "prod:down": "infra stop  --env prod"
  },
  "devDependencies": {
    "@kevincam3/infra-cli": "github:kevincam3/infra-cli"
  }
}
```

Then:

```bash
cd docker
pnpm install
pnpm run dev
```

On install, an example `infra.config.sh`, `.env.infisical-auth.dev`, and `.env.infisical-auth.prod` are dropped into the directory you ran `pnpm install` from (typically `docker/`). Existing files are never overwritten.

Pin to a specific commit or tag if you want opt-in updates:

```json
"@kevincam3/infra-cli": "github:kevincam3/infra-cli#v1.0.0"
```

## Expected project layout

Run `infra` from the directory that contains the stack folders (typically `docker/`):

```
docker/
  package.json                 # scripts call `infra ...`
  infra.config.sh              # optional per-project config (see below)
  .env.infisical-auth.dev      # optional; enables dev secret export
  .env.infisical-auth.prod     # optional; enables prod secret export
  infrastructure/
    docker-compose.base.yml
    docker-compose.dev.yml
    docker-compose.prod.yml
  applications/
    docker-compose.base.yml
    docker-compose.dev.yml
    docker-compose.prod.yml
  tooling/
    docker-compose.base.yml
    docker-compose.dev.yml
    docker-compose.prod.yml
```

A stack is skipped if neither its `base` nor its `<env>` compose file exists.

## Commands

```
infra start --env <dev|prod>
infra stop  --env <dev|prod>
infra help
infra version
```

`--env` also accepts the long aliases `development` / `production`, the
short form `-e`, and `--env=dev` syntax. `help` / `version` can also be
invoked as `-h` / `--help` and `-v` / `--version`.

### Cleanup on `start`

After bringing stacks up, `start` runs three sweeps:

- **Exited containers** — only those labelled with this project's compose
  project name (`<PROJECT_NAME>-<env>-<stack>`).
- **Anonymous volumes** — removed **globally**, not scoped to this
  project. If you run other Docker stacks on the same host outside
  infra-cli, their anonymous volumes will be removed too.
- **Old images** — for every image repo this project's running containers
  reference, older versions are removed. Images **newer** than the
  currently-running version are preserved, since another project may be
  using them.

## Per-project config: `infra.config.sh`

Optional. The example file dropped in by the postinstall hook contains every
supported setting commented out. Uncomment only what you need to override.

| Setting                                                               | Default                                 | Notes                                                                                                    |
| --------------------------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `PROJECT_NAME`                                                        | `name` field from `./package.json`      | Compose project prefix.                                                                                  |
| `STACKS`                                                              | `(infrastructure applications tooling)` | Order matters; each is a directory under the run dir.                                                    |
| `NETWORKS`                                                            | `(proxy "socket-proxy --internal")`     | Ensured on every run. Each entry is a network name optionally followed by `docker network create` flags. |
| `NETWORKS_DEV`                                                        | `(mailpit)`                             | Ensured only on `--env dev`. Same format as `NETWORKS`.                                                  |
| `DEV_SHARED_SERVICES`                                                 | `()` (empty)                            | Services to deduplicate across compose projects in dev.                                                  |
| `BANNER`                                                              | Built-in ASCII art                      | Multi-line string printed as the header.                                                                 |
| `SECRETS_INFRASTRUCTURE` / `SECRETS_APPLICATIONS` / `SECRETS_TOOLING` | `()` (empty)                            | Per-stack Infisical exports; no-op without `.env.infisical-auth.<env>`.                                  |
| `infra_pre_start`                                                     | undefined                               | Optional bash function. Called once on `start`, after networks are ensured and before any stack runs.    |

> **Setting a list replaces the default — it does not append.** If you set
> `NETWORKS=(my-net)` you lose `proxy` and `socket-proxy` unless you list them
> too.

The values shown commented out in the example `infra.config.sh` mirror the
defaults above for `STACKS`, `NETWORKS`, and `NETWORKS_DEV` — uncommenting them
verbatim is a no-op. The `DEV_SHARED_SERVICES`, `BANNER`, and `SECRETS_*`
samples are illustrative; their real defaults are empty / built-in.

`SECRETS_*` entry format:

```
"service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|exclude_keys"
```

### Pre-start hook

Define `infra_pre_start` in `infra.config.sh` to run project-specific bootstrap
before the stack loop. Typical use case: bringing up a secrets backend so that
the `SECRETS_*` export step has somewhere to authenticate against.

The hook runs only on `start`, after networks are ensured and before any stack
is touched. It has access to `PROJECT_DIR`, `PROJECT_NAME`, `ENVIRONMENT`, and
the logging helpers (`section`, `info`, `success`, `error`). Gate on
`$ENVIRONMENT` if the hook should only run in one environment.

```bash
infra_pre_start() {
  [ "$ENVIRONMENT" = "prod" ] || return 0

  section "🔧 Bootstrapping secrets backend"
  docker compose -p "${PROJECT_NAME}-${ENVIRONMENT}-infrastructure" \
    -f infrastructure/docker-compose.base.yml \
    -f "infrastructure/docker-compose.${ENVIRONMENT}.yml" \
    up -d --wait vault
}
```

## Infisical auth files

To enable secret export, fill in `docker/.env.infisical-auth.dev` and/or
`docker/.env.infisical-auth.prod` (both created by the postinstall hook; make
sure they are gitignored). The CLI sources the file that matches the `--env`
flag, so dev and prod machine identities are always kept separate.

Every value in the example files is a placeholder — there are no built-in
defaults, you must supply real credentials:

```bash
# .env.infisical-auth.dev  (dev-scoped machine identities only)
INFISICAL_HOST=https://infisical.example.com
INFISICAL_PROJECT_ID=your-project-id

TRAEFIK_CLIENT_ID=...
TRAEFIK_CLIENT_SECRET=...
# ...one pair per machine identity referenced in SECRETS_* arrays
```

```bash
# .env.infisical-auth.prod  (prod-scoped machine identities only)
INFISICAL_HOST=https://infisical.example.com
INFISICAL_PROJECT_ID=your-project-id

TRAEFIK_CLIENT_ID=...
TRAEFIK_CLIENT_SECRET=...
# ...one pair per machine identity referenced in SECRETS_* arrays
```

Requires the [Infisical CLI](https://infisical.com/docs/cli/overview) on `PATH`.
