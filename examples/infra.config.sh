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

# Optional custom banner (otherwise a default one is used):
# BANNER=$'\n  My Project\n'

# Infisical machine-identity secret exports (prod only; no-op without
# .env.infisical-auth). Each entry:
#   "service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|output_path|exclude_keys"
# SECRETS_INFRASTRUCTURE=(
#   "traefik|TRAEFIK_CLIENT_ID|TRAEFIK_CLIENT_SECRET|infrastructure/traefik/.env|"
# )
# SECRETS_APPLICATIONS=()
# SECRETS_TOOLING=(
#   "tooling-mysql|TOOLING_MYSQL_CLIENT_ID|TOOLING_MYSQL_CLIENT_SECRET|tooling/mysql/.env|PORT HOST"
# )
