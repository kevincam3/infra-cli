# Configuring Infisical Secret Export

`infra start --env <dev|prod>` can export secrets from
[Infisical](https://infisical.com) and inject them directly into the shell
environment before bringing each stack up. Docker Compose inherits this
environment, and services receive the vars via `environment:` key declarations
in their compose files. No `.env` files are written to disk.

This is opt-in — nothing happens unless you provide both an
`.env.infisical-auth.<env>` file and a `SECRETS_<STACK>` array.

## How it works

For each entry in `SECRETS_INFRASTRUCTURE`, `SECRETS_APPLICATIONS`, and
`SECRETS_TOOLING`:

1. The CLI authenticates to Infisical using a Universal Auth machine
   identity (one client id + secret pair per service).
2. It fetches all secrets in the project for the current environment (`dev`
   or `prod`).
3. Optionally strips out keys named in `exclude_keys`.
4. Exports the remaining secrets as environment variables in the current
   shell process — no files are written.
5. `docker compose up` inherits those vars and passes them to any service
   that lists the key names under its `environment:` section.

The `infisical` CLI must be on `PATH` — see
[Infisical CLI install docs](https://infisical.com/docs/cli/overview).

## One-time Infisical setup

Per service that needs secrets:

1. In Infisical, create a **Machine Identity** scoped to the project and
   the target environment (`dev` or `prod`) with **read** access to the
   relevant secret path(s). Create a separate identity per environment.
2. Attach **Universal Auth** to each identity and copy the resulting
   client id and client secret.
3. Decide on a stable env-var-name pair for them, e.g.
   `TRAEFIK_CLIENT_ID` / `TRAEFIK_CLIENT_SECRET`.

## Per-project configuration

Three files in the project's `docker/` directory.

### `infra.config.sh`

Declare what to export (same config for both environments — the CLI picks
the right auth file and Infisical environment automatically):

```bash
SECRETS_INFRASTRUCTURE=(
  "traefik|TRAEFIK_CLIENT_ID|TRAEFIK_CLIENT_SECRET|"
)

SECRETS_TOOLING=(
  "tooling-mysql|TOOLING_MYSQL_CLIENT_ID|TOOLING_MYSQL_CLIENT_SECRET|PORT HOST"
)
```

Each entry is a single pipe-delimited string:

```
"service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|exclude_keys"
```

| Field               | Notes                                                          |
| ------------------- | -------------------------------------------------------------- |
| `service_name`      | Used in log output and as the human label.                     |
| `CLIENT_ID_VAR`     | **Name** of the env var holding the client id (not the value). |
| `CLIENT_SECRET_VAR` | **Name** of the env var holding the client secret.             |
| `exclude_keys`      | Space-separated keys to strip from the export. May be empty.   |

### `.env.infisical-auth.dev` and `.env.infisical-auth.prod`

One file per environment. Each holds credentials for machine identities
scoped to that environment only. **Both must be gitignored.** The default
`.gitignore` shipped by the postinstall hook covers `.env*`.

```bash
# .env.infisical-auth.dev — dev-scoped identities only
INFISICAL_HOST=https://infisical.example.com
INFISICAL_PROJECT_ID=your-project-id

TRAEFIK_CLIENT_ID=<dev machine identity client id>
TRAEFIK_CLIENT_SECRET=<dev machine identity client secret>

TOOLING_MYSQL_CLIENT_ID=<dev machine identity client id>
TOOLING_MYSQL_CLIENT_SECRET=<dev machine identity client secret>
```

```bash
# .env.infisical-auth.prod — prod-scoped identities only
INFISICAL_HOST=https://infisical.example.com
INFISICAL_PROJECT_ID=your-project-id

TRAEFIK_CLIENT_ID=<prod machine identity client id>
TRAEFIK_CLIENT_SECRET=<prod machine identity client secret>

TOOLING_MYSQL_CLIENT_ID=<prod machine identity client id>
TOOLING_MYSQL_CLIENT_SECRET=<prod machine identity client secret>
```

The CLI sources the appropriate file (`auth.dev` or `auth.prod`) based on
the `--env` flag, then resolves each `*_CLIENT_ID_VAR` indirectly. Both
`INFISICAL_HOST` and `INFISICAL_PROJECT_ID` are required when any
`SECRETS_*` array is non-empty.

## Compose file changes

Services must declare which environment variables they consume using bare
key names (no value) under the `environment:` key. Docker Compose resolves
these from the inherited shell environment at startup.

```yaml
# Before (file-based — no longer needed)
services:
  traefik:
    env_file: ./traefik/.env

# After (runtime injection)
services:
  traefik:
    environment:
      - DATABASE_URL
      - API_SECRET_KEY
      - SOME_OTHER_SECRET
```

Remove any `env_file:` references that pointed to generated `.env` files,
and delete those generated files from disk.

## Verifying

```bash
cd docker
infra start --env dev
```

You should see a section per stack:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 Exporting Infrastructure Secrets
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ Exporting secrets for traefik -> environment
✔ Exported traefik
```

Failure modes the CLI surfaces explicitly:

| Symptom                                               | Cause                                                                         |
| ----------------------------------------------------- | ----------------------------------------------------------------------------- |
| Section not printed at all                            | `.env.infisical-auth.<env>` missing, or `SECRETS_<STACK>` empty.              |
| `INFISICAL_HOST and INFISICAL_PROJECT_ID must be set` | Auth file present but missing those keys.                                     |
| `Missing credentials for <service> (X / Y)`           | The `*_CLIENT_ID` / `*_CLIENT_SECRET` vars referenced aren't defined.         |
| `Failed to authenticate <service>`                    | Infisical rejected the credentials — check the machine identity for that env. |

## Migrating from v1 (file-based, prod-only export)

1. **Update `infra.config.sh`** — remove the `output_path` field (4th
   pipe-separated value) from every `SECRETS_*` entry:

   ```bash
   # v1
   "traefik|TRAEFIK_CLIENT_ID|TRAEFIK_CLIENT_SECRET|infrastructure/traefik/.env|"

   # v2
   "traefik|TRAEFIK_CLIENT_ID|TRAEFIK_CLIENT_SECRET|"
   ```

2. **Rename your auth file** and create an env-specific counterpart:

   ```bash
   mv .env.infisical-auth .env.infisical-auth.prod
   cp .env.infisical-auth.prod .env.infisical-auth.dev
   # Fill in dev-scoped machine identity credentials in the .dev file
   ```

3. **Update compose files** — replace `env_file:` with `environment:` bare
   key names as shown above.

4. **Delete old generated `.env` files** from your project directory.
