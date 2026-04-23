#!/usr/bin/env bash

# Load per-project config from <project_dir>/infra.config.sh (optional).
# Provides defaults, and derives PROJECT_NAME from package.json if unset.
#
# Variables a config file may set:
#   PROJECT_NAME                  Compose project prefix. Default: package.json "name".
#   STACKS                        Ordered list of stack dirs. Default: (infrastructure applications tooling).
#   NETWORKS                      External networks to ensure on every run. Default: (proxy).
#   NETWORKS_DEV                  External networks to ensure only when --env dev. Default: (mailpit).
#   BANNER                        Multi-line string to print as the header banner. Default: built-in.
#   SECRETS_<STACK>               Per-stack secret export list (see lib/secrets.sh for format).
load_config() {
  local project_dir="${1:-$(pwd)}"
  local config_file="${project_dir}/infra.config.sh"

  STACKS=(infrastructure applications tooling)
  NETWORKS=(proxy socket-proxy)
  NETWORKS_DEV=(mailpit)
  SECRETS_INFRASTRUCTURE=()
  SECRETS_APPLICATIONS=()
  SECRETS_TOOLING=()
  PROJECT_NAME="${PROJECT_NAME:-}"
  BANNER="${BANNER:-}"

  if [ -f "$config_file" ]; then
    # shellcheck disable=SC1090
    source "$config_file"
  fi

  if [ -z "$PROJECT_NAME" ] && [ -f "${project_dir}/package.json" ] && command -v node >/dev/null 2>&1; then
    PROJECT_NAME="$(node -p "require('${project_dir}/package.json').name" 2>/dev/null || echo "")"
  fi

  if [ -z "$PROJECT_NAME" ]; then
    error "PROJECT_NAME is not set. Define it in ${config_file} or in ${project_dir}/package.json."
    exit 1
  fi
}
