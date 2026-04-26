#!/usr/bin/env bash
set -Eeo pipefail

# Resolve this script's real directory (follow symlinks from pnpm/npm bin shims).
_resolve_bin_dir() {
  local src="${BASH_SOURCE[0]}"
  local dir
  while [ -L "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ $src != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

BIN_DIR="$(_resolve_bin_dir)"
CLI_ROOT="$(cd -P "$BIN_DIR/.." && pwd)"
LIB_DIR="$CLI_ROOT/lib"

# shellcheck source=../lib/logging.sh
source "$LIB_DIR/logging.sh"
# shellcheck source=../lib/config.sh
source "$LIB_DIR/config.sh"
# shellcheck source=../lib/secrets.sh
source "$LIB_DIR/secrets.sh"
# shellcheck source=../lib/stacks.sh
source "$LIB_DIR/stacks.sh"
# shellcheck source=../lib/cleanup.sh
source "$LIB_DIR/cleanup.sh"

VERSION="$(node -p "require('${CLI_ROOT}/package.json').version" 2>/dev/null || echo "unknown")"

usage() {
  cat <<EOF
Usage: infra <command> [options]

Commands:
  start --env <dev|prod>    Start infrastructure, applications, and tooling stacks
  stop  --env <dev|prod>    Stop all stacks
  help                      Show this help
  version                   Show version

Options:
  -e, --env <dev|prod>      Environment to target (required for start/stop)
  -h, --help                Show help
  -v, --version             Show version

Configuration (optional ./infra.config.sh in CWD):
  PROJECT_NAME              Compose project prefix (defaults to package.json "name")
  STACKS                    Ordered list of stack dirs (default: infrastructure applications tooling)
  NETWORKS                  External networks to ensure on every run; each entry may include
                            docker-network-create flags (default: proxy "socket-proxy --internal")
  NETWORKS_DEV              External networks to ensure only in dev (default: mailpit)
  DEV_SHARED_SERVICES       Services skipped in dev when already running in another compose project
  BANNER                    Plain text converted to ASCII art banner
  SECRETS_<STACK>           Per-stack Infisical secret exports (prod only)

Run from the directory containing the stack folders (typically your project's docker/).
EOF
}

COMMAND=""
ENV_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    start|stop|help|version)
      [ -z "$COMMAND" ] && COMMAND="$1"
      shift
      ;;
    -h|--help)    COMMAND="help";    shift ;;
    -v|--version) COMMAND="version"; shift ;;
    -e|--env)     ENV_ARG="$2";      shift 2 ;;
    --env=*)      ENV_ARG="${1#--env=}"; shift ;;
    *)
      error "Unknown argument: $1"
      echo
      usage
      exit 2
      ;;
  esac
done

case "$COMMAND" in
  ""|help) usage; exit 0 ;;
  version) echo "infra-cli v${VERSION}"; exit 0 ;;
esac

if [ -z "$ENV_ARG" ]; then
  error "Missing required --env flag (dev or prod)"
  echo
  usage
  exit 2
fi

case "$ENV_ARG" in
  dev|development) ENVIRONMENT="dev" ;;
  prod|production) ENVIRONMENT="prod" ;;
  *)
    error "Invalid --env: '${ENV_ARG}'. Expected 'dev' or 'prod'."
    exit 2
    ;;
esac

PROJECT_DIR="$(pwd)"
load_config "$PROJECT_DIR"

[ -t 1 ] && clear

echo -e "\033[0;34m"
if [ -n "${BANNER:-}" ]; then
  node "$CLI_ROOT/lib/banner.mjs" "$BANNER" || printf '%s\n' "$BANNER"
else
  cat <<'EOF'
   _        __
  (_)__  __/ _|_ __ __ _
  | / _ \| |_| '__/ _` |
  | | | | |  _| | | (_| |
  |_|_| |_|_| |_|  \__,_|

EOF
fi
echo -e "\033[0m"

case "$COMMAND" in
  start) COMPOSE_ACTION="up -d --wait" ;;
  stop)  COMPOSE_ACTION="down" ;;
esac

# Each NETWORKS entry is "<name> [docker-network-create flags...]" — split on whitespace
# so flags like --internal reach `docker network create`.
for net in "${NETWORKS[@]}"; do
  read -ra net_args <<<"$net"
  ensure_network "${net_args[@]}"
done
if [ "$ENVIRONMENT" = "dev" ]; then
  for net in "${NETWORKS_DEV[@]}"; do
    read -ra net_args <<<"$net"
    ensure_network "${net_args[@]}"
  done
fi

# Optional pre-start hook for project-specific bootstrap (e.g. bringing up a
# secrets backend before secret export runs). Define `infra_pre_start` in
# infra.config.sh; it has access to PROJECT_DIR, PROJECT_NAME, ENVIRONMENT
# and the logging helpers.
if [ "$COMMAND" = "start" ] && declare -F infra_pre_start >/dev/null 2>&1; then
  infra_pre_start
fi

for stack in "${STACKS[@]}"; do
  run_stack "$stack"
done

if [ "$COMMAND" = "start" ]; then
  cleanup_exited_containers
  cleanup_anonymous_volumes
  cleanup_old_images
fi

echo
success "Done"
echo
