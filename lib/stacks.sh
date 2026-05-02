#!/usr/bin/env bash

# Create the network if it doesn't exist. Any extra args after the name are passed
# through to `docker network create` (e.g. `ensure_network socket-proxy --internal`).
ensure_network() {
  local name="$1"
  shift || true
  if ! docker network inspect "$name" >/dev/null 2>&1; then
    docker network create "$@" "$name" >/dev/null
    echo
    success "Created network '$name'"
  fi
}

# Bring a single stack up or down. Silently skips stacks with no compose files.
# Relies on these globals from bin/infra.sh:
#   COMMAND               start|stop
#   COMPOSE_ACTION        e.g. "up -d --wait" or "down"
#   ENVIRONMENT           dev|prod
#   PROJECT_NAME          compose project prefix
#   PROJECT_DIR           absolute path to the project's docker dir
#   DEV_SHARED_SERVICES   (dev only) services to skip if already running in another compose project
run_stack() {
  local stack="$1"
  local base="${stack}/docker-compose.base.yml"
  local env_file="${stack}/docker-compose.${ENVIRONMENT}.yml"

  if [ ! -f "$base" ] && [ ! -f "$env_file" ]; then
    return 0
  fi

  section "🚀  ${COMMAND^}ing ${ENVIRONMENT^^} ${stack^}"
  echo

  local compose_args=(-p "${PROJECT_NAME}-${ENVIRONMENT}-${stack}")
  if [ "$COMMAND" = "start" ]; then
    [ -f "$base" ]     && compose_args+=(-f "$base")
    [ -f "$env_file" ] && compose_args+=(-f "$env_file")
  fi

  local explicit_services=()
  _compute_explicit_services "$stack" explicit_services "${compose_args[@]}"

  if [ "$COMMAND" = "start" ]; then
    (
      export_stack_secrets "$stack" "$PROJECT_DIR"
      docker compose "${compose_args[@]}" $COMPOSE_ACTION "${explicit_services[@]}"
    )
  else
    docker compose "${compose_args[@]}" $COMPOSE_ACTION "${explicit_services[@]}"
  fi
}

# In dev, every project ships its own Traefik (etc.) because each runs on a separate
# VPS in prod. Locally that collides on shared host ports, so if a service listed in
# DEV_SHARED_SERVICES is already running in another compose project we skip it here
# and let both stacks share the running instance.
#
# Sets the named array (arg 2) to the explicit service list for `docker compose up`,
# or leaves it empty when no filtering is needed (compose then defaults to all services).
_compute_explicit_services() {
  local stack="$1"
  local out_var="$2"
  shift 2
  local -a compose_args=("$@")

  [ "$COMMAND" != "start" ] && return 0
  [ "$ENVIRONMENT" != "dev" ] && return 0
  [ "${#DEV_SHARED_SERVICES[@]}" -eq 0 ] && return 0

  local our_project="${PROJECT_NAME}-${ENVIRONMENT}-${stack}"
  local stack_services
  stack_services=$(docker compose "${compose_args[@]}" config --services 2>/dev/null || true)
  [ -z "$stack_services" ] && return 0

  local skip=() service external
  for service in "${DEV_SHARED_SERVICES[@]}"; do
    grep -qx "$service" <<<"$stack_services" || continue

    external=$(docker ps \
      --filter "label=com.docker.compose.service=${service}" \
      --format '{{.Label "com.docker.compose.project"}}' \
      | (grep -v "^${our_project}$" || true) \
      | head -n1)

    if [ -n "$external" ]; then
      info "${service^} already running (project '${external}') — skipping it in this stack"
      echo
      skip+=("$service")
    fi
  done

  [ ${#skip[@]} -eq 0 ] && return 0

  local pattern
  pattern=$(IFS='|'; echo "${skip[*]}")
  mapfile -t "$out_var" < <(grep -vE "^(${pattern})$" <<<"$stack_services" || true)
}
