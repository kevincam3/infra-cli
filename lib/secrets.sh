#!/usr/bin/env bash

# Export secrets for a given stack using Infisical machine identities.
#
# Reads SECRETS_<STACK_UPPER> from the loaded config. Each array entry is a
# pipe-delimited string:
#
#   "service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|exclude_keys"
#
#   service_name       Label for logging (and for the Infisical machine identity)
#   CLIENT_ID_VAR      Name of an env var holding the Universal Auth client id
#   CLIENT_SECRET_VAR  Name of an env var holding the Universal Auth client secret
#   exclude_keys       Space-separated keys to strip from the export (may be empty)
#
# Secrets are exported directly into the current shell environment so that
# docker compose inherits them. No .env files are written to disk. Services in
# compose files should declare the vars they consume using bare key names under
# the `environment:` key (docker compose resolves them from the inherited env).
#
# The client id/secret env vars themselves are populated by sourcing
# <project_dir>/.env.infisical-auth. If that file is missing, this function
# is a no-op (secrets export is an opt-in feature for prod).
export_stack_secrets() {
  local stack="$1"
  local project_dir="${2:-$(pwd)}"
  local auth_file="${project_dir}/.env.infisical-auth.${ENVIRONMENT}"

  [ -f "$auth_file" ] || return 0

  local array_name
  array_name="SECRETS_$(echo "$stack" | tr '[:lower:]' '[:upper:]')"

  local -a entries=()
  if [[ -v "$array_name" ]]; then
    eval "entries=(\"\${${array_name}[@]}\")"
  fi

  [ "${#entries[@]}" -eq 0 ] && return 0

  set -a
  # shellcheck disable=SC1090
  source "$auth_file"
  set +a

  if [ -z "${INFISICAL_HOST:-}" ] || [ -z "${INFISICAL_PROJECT_ID:-}" ]; then
    error "INFISICAL_HOST and INFISICAL_PROJECT_ID must be set in ${auth_file}"
    return 1
  fi

  section "🔐 Exporting ${stack^} Secrets"

  local entry service_name client_id_var client_secret_var exclude_keys
  local client_id client_secret token dotenv_content pattern
  for entry in "${entries[@]}"; do
    IFS='|' read -r service_name client_id_var client_secret_var exclude_keys <<<"$entry"

    client_id="${!client_id_var:-}"
    client_secret="${!client_secret_var:-}"

    if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
      error "Missing credentials for ${service_name} (${client_id_var} / ${client_secret_var})"
      continue
    fi

    info "Exporting secrets for ${service_name} -> environment"

    token=$(infisical login \
      --method=universal-auth \
      --client-id="$client_id" \
      --client-secret="$client_secret" \
      --domain="$INFISICAL_HOST" \
      --silent --plain)

    if [ -z "$token" ]; then
      error "Failed to authenticate ${service_name}"
      continue
    fi

    dotenv_content=$(infisical secrets \
      --token="$token" \
      --projectId="$INFISICAL_PROJECT_ID" \
      --env="$ENVIRONMENT" \
      --recursive \
      --domain="$INFISICAL_HOST" \
      --output=dotenv)

    if [ -n "$exclude_keys" ]; then
      pattern=$(echo "$exclude_keys" | tr ' ' '|')
      dotenv_content=$(grep -vE "^(${pattern})=" <<<"$dotenv_content")
      info "Excluded keys from ${service_name}: ${exclude_keys}"
    fi

    set -a
    # shellcheck disable=SC1090
    source <(printf '%s\n' "$dotenv_content")
    set +a

    success "Exported ${service_name}"
  done
}
