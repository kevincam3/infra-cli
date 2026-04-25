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
    "dev": "infra start --env dev",
    "dev:down": "infra stop  --env dev",
    "prod": "infra start --env prod",
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
| `SECRETS_INFRASTRUCTURE` / `SECRETS_APPLICATIONS` / `SECRETS_TOOLING` | `()` (empty)                            | Per-stack Infisical exports; prod only, no-op without `.env.infisical-auth`.                             |

> **Setting a list replaces the default — it does not append.** If you set
> `NETWORKS=(my-net)` you lose `proxy` and `socket-proxy` unless you list them
> too.

The values shown commented out in the example `infra.config.sh` mirror the
defaults above for `STACKS`, `NETWORKS`, and `NETWORKS_DEV` — uncommenting them
verbatim is a no-op. The `DEV_SHARED_SERVICES`, `BANNER`, and `SECRETS_*`
samples are illustrative; their real defaults are empty / built-in.

`SECRETS_*` entry format:

```
"service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|output_path|exclude_keys"
```

## Infisical auth file

To enable prod secret export, fill in `docker/.env.infisical-auth` (created by
the postinstall hook; make sure it is gitignored). Every value in the example
file is a placeholder — there are no built-in defaults, you must supply real
credentials:

```bash
INFISICAL_HOST=https://infisical.example.com   # placeholder
INFISICAL_PROJECT_ID=your-project-id           # placeholder

TRAEFIK_CLIENT_ID=...
TRAEFIK_CLIENT_SECRET=...

TOOLING_MYSQL_CLIENT_ID=...
TOOLING_MYSQL_CLIENT_SECRET=...
# ...one pair per machine identity referenced in SECRETS_* arrays
```

Requires the [Infisical CLI](https://infisical.com/docs/cli/overview) on `PATH`.
