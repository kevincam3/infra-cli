# infra-cli

Opinionated CLI for orchestrating per-project Docker Compose stacks across `infrastructure/`, `applications/`, and `tooling/` layers — with environment-aware secret export via Infisical.

## Install

Add to your project's `docker/package.json`:

```json
{
  "devDependencies": {
    "@kevincam3/infra-cli": "github:kevincam3/infra-cli"
  },
  "scripts": {
    "dev":       "infra start --env dev",
    "dev:down":  "infra stop  --env dev",
    "prod":      "infra start --env prod",
    "prod:down": "infra stop  --env prod"
  }
}
```

Then:

```bash
cd docker
pnpm install
pnpm run dev
```

On install, an example `infra.config.sh` and `.env.infisical-auth` are dropped into the directory you ran `pnpm install` from (typically `docker/`). Existing files are never overwritten.

Pin to a specific commit or tag if you want opt-in updates:

```json
"@kevincam/infra-cli": "github:kevincam/infra-cli#v0.1.0"
```

## Expected project layout

Run `infra` from the directory that contains the stack folders (typically `docker/`):

```
docker/
  package.json                 # scripts call `infra ...`
  infra.config.sh              # optional per-project config (see below)
  .env.infisical-auth          # optional; enables prod secret export
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

`start` also cleans up exited containers, anonymous volumes, and older image versions that your current containers no longer reference.

## Per-project config: `infra.config.sh`

Optional. If absent, `PROJECT_NAME` falls back to the `name` field in `./package.json`.

```bash
# docker/infra.config.sh
PROJECT_NAME="tcmsvc"

# Override the default stack list or order:
# STACKS=(infrastructure applications tooling)

# Override the external networks the CLI ensures before bringing stacks up.
# Each entry may include extra `docker network create` flags after the name:
# NETWORKS=(proxy "socket-proxy --internal")
# NETWORKS_DEV=(mailpit)

# Services that should be deduplicated across compose projects in dev: if any
# one of these is already running in another project, this stack skips its own
# copy and shares the running instance. Useful for host-port-bound services
# like Traefik that ship in every project but can only run once locally.
# DEV_SHARED_SERVICES=(traefik)

# Optional custom banner (otherwise a default one is used):
# BANNER=$'\n  TCM Services\n'

# Infisical machine-identity secret exports (prod only; no-op without
# .env.infisical-auth). Each entry:
#   "service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|output_path|exclude_keys"
SECRETS_INFRASTRUCTURE=(
  "traefik|TRAEFIK_CLIENT_ID|TRAEFIK_CLIENT_SECRET|infrastructure/traefik/.env|"
)

SECRETS_APPLICATIONS=()

SECRETS_TOOLING=(
  "tooling-mysql|TOOLING_MYSQL_CLIENT_ID|TOOLING_MYSQL_CLIENT_SECRET|tooling/mysql/.env|PORT HOST"
  "kanbn|KANBN_CLIENT_ID|KANBN_CLIENT_SECRET|tooling/kanbn/.env|PORT HOST PGPASSWORD POSTGRES_DB POSTGRES_PASSWORD POSTGRES_USER"
)
```

## Infisical auth file

To enable prod secret export, create `docker/.env.infisical-auth` (gitignored):

```bash
INFISICAL_HOST=https://infisical.example.com
INFISICAL_PROJECT_ID=your-project-id

TRAEFIK_CLIENT_ID=...
TRAEFIK_CLIENT_SECRET=...

TOOLING_MYSQL_CLIENT_ID=...
TOOLING_MYSQL_CLIENT_SECRET=...
# ...one pair per machine identity referenced in SECRETS_* arrays
```

Requires the [Infisical CLI](https://infisical.com/docs/cli/overview) on `PATH`.
