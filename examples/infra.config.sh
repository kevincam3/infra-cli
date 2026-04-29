#!/usr/bin/env bash
# Per-project infra-cli config. Sourced by `infra` from the directory it is
# run from. Everything below is optional — PROJECT_NAME falls back to the
# "name" field in ./package.json if unset.

# PROJECT_NAME="my-project"

# Override the default stack list or order:
# STACKS=(infrastructure applications tooling)

# External networks ensured before stacks start. Each entry may include extra
# `docker network create` flags after the name (e.g. "socket-proxy --internal").
# NETWORKS=(proxy "socket-proxy --internal")

# External networks ensured only when --env dev:
# NETWORKS_DEV=(mailpit)

# Services to deduplicate across compose projects in dev: if one is already
# running in another project, this stack skips its own copy and shares it.
# Useful for host-port-bound services like Traefik.
# DEV_SHARED_SERVICES=(traefik)

# Optional custom banner — plain text, converted to ASCII art automatically:
# BANNER="My Project"

# Infisical machine-identity secret exports (prod only; no-op without
# .env.infisical-auth.<env>). Each entry:
#   "service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|exclude_keys"
# Secrets are injected into the shell environment at runtime; docker compose
# inherits them. In your compose files, list consumed vars as bare key names
# under `environment:` (no value) and docker compose will resolve them.
# SECRETS_INFRASTRUCTURE=(
#   "traefik|TRAEFIK_CLIENT_ID|TRAEFIK_CLIENT_SECRET|"
# )
# SECRETS_APPLICATIONS=()
# SECRETS_TOOLING=(
#   "tooling-mysql|TOOLING_MYSQL_CLIENT_ID|TOOLING_MYSQL_CLIENT_SECRET|PORT HOST"
# )
