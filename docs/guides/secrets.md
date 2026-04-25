# Configuring Infisical Secret Export

`infra start --env prod` can export secrets from
[Infisical](https://infisical.com) into per-service `.env` files before
bringing each stack up. This is opt-in — nothing happens unless you
provide both `.env.infisical-auth` and a `SECRETS_<STACK>` array.

## How it works

For each entry in `SECRETS_INFRASTRUCTURE`, `SECRETS_APPLICATIONS`, and
`SECRETS_TOOLING`:

1. The CLI authenticates to Infisical using a Universal Auth machine
   identity (one client id + secret pair per service).
2. It fetches all secrets in the project for the `prod` environment.
3. It writes them as a dotenv file at `output_path` (relative to the
   project dir).
4. Optionally strips out keys named in `exclude_keys`.

The `infisical` CLI must be on `PATH` — see
[Infisical CLI install docs](https://infisical.com/docs/cli/overview).

## One-time Infisical setup

Per service that needs secrets:

1. In Infisical, create a **Machine Identity** scoped to the project and
   the `prod` environment with **read** access to the relevant secret
   path(s).
2. Attach **Universal Auth** to the identity and copy the resulting
   client id and client secret.
3. Decide on a stable env-var-name pair for them, e.g.
   `TRAEFIK_CLIENT_ID` / `TRAEFIK_CLIENT_SECRET`.

## Per-project configuration

Two files in the project's `docker/` directory.

### `infra.config.sh`

Declare what to export:

```bash
SECRETS_INFRASTRUCTURE=(
  "traefik|TRAEFIK_CLIENT_ID|TRAEFIK_CLIENT_SECRET|infrastructure/traefik/.env|"
)

SECRETS_TOOLING=(
  "tooling-mysql|TOOLING_MYSQL_CLIENT_ID|TOOLING_MYSQL_CLIENT_SECRET|tooling/mysql/.env|PORT HOST"
)
```

Each entry is a single pipe-delimited string:

```
"service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|output_path|exclude_keys"
```

| Field               | Notes                                                          |
| ------------------- | -------------------------------------------------------------- |
| `service_name`      | Used in log output and as the human label.                     |
| `CLIENT_ID_VAR`     | **Name** of the env var holding the client id (not the value). |
| `CLIENT_SECRET_VAR` | **Name** of the env var holding the client secret.             |
| `output_path`       | Where to write the dotenv, relative to the project dir.        |
| `exclude_keys`      | Space-separated keys to strip from the output. May be empty.   |

### `.env.infisical-auth`

Holds the actual credentials. **Must be gitignored.** The default
`.gitignore` shipped by the postinstall hook covers `.env*`.

```bash
INFISICAL_HOST=https://infisical.example.com
INFISICAL_PROJECT_ID=your-project-id

TRAEFIK_CLIENT_ID=...
TRAEFIK_CLIENT_SECRET=...

TOOLING_MYSQL_CLIENT_ID=...
TOOLING_MYSQL_CLIENT_SECRET=...
```

The CLI sources this file with `set -a` so every variable becomes an
exported env var, then resolves each `*_CLIENT_ID_VAR` indirectly. Both
`INFISICAL_HOST` and `INFISICAL_PROJECT_ID` are required when any
`SECRETS_*` array is non-empty.

## Verifying

```bash
cd docker
infra start --env prod
```

You should see a section per stack:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 Exporting Infrastructure Secrets
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ Exporting secrets for traefik -> infrastructure/traefik/.env
✔ Exported traefik
```

Failure modes the CLI surfaces explicitly:

| Symptom                                               | Cause                                                                 |
| ----------------------------------------------------- | --------------------------------------------------------------------- |
| Section not printed at all                            | `.env.infisical-auth` missing, or `SECRETS_<STACK>` empty.            |
| `INFISICAL_HOST and INFISICAL_PROJECT_ID must be set` | Auth file present but missing those keys.                             |
| `Missing credentials for <service> (X / Y)`           | The `*_CLIENT_ID` / `*_CLIENT_SECRET` vars referenced aren't defined. |
| `Failed to authenticate <service>`                    | Infisical rejected the credentials — check the machine identity.      |

## Dev environments

Secret export is **prod-only by design**. Dev environments are expected
to use checked-in `.env.example` files or local-only `.env` files; the
CLI will not touch them.
