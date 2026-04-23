#!/usr/bin/env bash

ensure_network() {
  local name="$1"
  if ! docker network inspect "$name" >/dev/null 2>&1; then
    docker network create "$name" >/dev/null
    echo
    success "Created network '$name'"
  fi
}

# Bring a single stack up or down. Silently skips stacks with no compose files.
# Relies on these globals from bin/infra:
#   COMMAND          start|stop
#   COMPOSE_ACTION   e.g. "up -d --wait" or "down"
#   ENVIRONMENT      dev|prod
#   PROJECT_NAME     compose project prefix
#   PROJECT_DIR      absolute path to the project's docker dir
run_stack() {
  local stack="$1"
  local base="${stack}/docker-compose.base.yml"
  local env_file="${stack}/docker-compose.${ENVIRONMENT}.yml"

  if [ ! -f "$base" ] && [ ! -f "$env_file" ]; then
    return 0
  fi

  if [ "$COMMAND" = "start" ] && [ "$ENVIRONMENT" = "prod" ]; then
    export_stack_secrets "$stack" "$PROJECT_DIR"
  fi

  section "🚀  ${COMMAND^}ing ${ENVIRONMENT^^} ${stack^}"
  echo

  local compose_args=(-p "${PROJECT_NAME}-${ENVIRONMENT}-${stack}")
  [ -f "$base" ]     && compose_args+=(-f "$base")
  [ -f "$env_file" ] && compose_args+=(-f "$env_file")

  docker compose "${compose_args[@]}" $COMPOSE_ACTION
}
