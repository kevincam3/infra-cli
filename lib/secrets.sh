#!/usr/bin/env bash

# Export secrets for a given stack using Infisical machine identities.
#
# Reads SECRETS_<STACK_UPPER> from the loaded config. Each array entry is a
# pipe-delimited string:
#
#   "service_name|CLIENT_ID_VAR|CLIENT_SECRET_VAR|output_path|exclude_keys"
#
#   service_name       Label for logging (and for the Infisical machine identity)
#   CLIENT_ID_VAR      Name of an env var holding the Universal Auth client id
#   CLIENT_SECRET_VAR  Name of an env var holding the Universal Auth client secret
#   output_path        .env path to write, relative to the project dir
#   exclude_keys       Space-separated keys to strip from the export (may be empty)
#
# The client id/secret env vars themselves are populated by sourcing
# <project_dir>/.env.infisical-auth. If that file is missing, this function
# is a no-op (secrets export is an opt-in feature for prod).
export_stack_secrets() {
  local stack="$1"
  local project_dir="${2:-$(pwd)}"
  local auth_file="${project_dir}/.env.infisical-auth"

  [ -f "$auth_file" ] || return 0

  local array_name
  array_name="SECRETS_$(echo "$stack" | tr '[:lower:]' '[:upper:]')"

  local -a entries=()
  if declare -p "$array_name" >/dev/null 2>&1; then
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

  local entry service_name client_id_var client_secret_var output_path exclude_keys
  local client_id client_secret abs_output token pattern tmp
  for entry in "${entries[@]}"; do
    IFS='|' read -r service_name client_id_var client_secret_var output_path exclude_keys <<<"$entry"

    client_id="${!client_id_var:-}"
    client_secret="${!client_secret_var:-}"
    abs_output="${project_dir}/${output_path}"

    if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
      error "Missing credentials for ${service_name} (${client_id_var} / ${client_secret_var})"
      continue
    fi

    info "Exporting secrets for ${service_name} -> ${output_path}"

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

    mkdir -p "$(dirname "$abs_output")"
    infisical secrets \
      --token="$token" \
      --projectId="$INFISICAL_PROJECT_ID" \
      --env="prod" \
      --recursive \
      --domain="$INFISICAL_HOST" \
      --output=dotenv >"$abs_output"

    if [ -n "$exclude_keys" ]; then
      pattern=$(echo "$exclude_keys" | tr ' ' '|')
      tmp=$(mktemp)
      grep -vE "^(${pattern})=" "$abs_output" >"$tmp" && mv "$tmp" "$abs_output"
      info "Excluded keys from ${service_name}: ${exclude_keys}"
    fi

    success "Exported ${service_name}"
  done
}
