#!/usr/bin/env bash

# `infra hosts` — generate the repo's hostname → server map.
#
# Answers "which server serves this hostname?" without grepping Traefik labels
# across every host directory. Hostnames come from the prod router rules read
# through `docker compose config`, so an include, an extends or a variable
# cannot hide one. Dev `.localhost` names are skipped: they are not DNS and not
# served by any of these servers.
#
# A hostname claimed by two hosts is a hard error. Both servers' Traefik would
# request a certificate for it and whichever one DNS pointed at would win,
# which is not a thing to discover during an outage.
#
# Unlike `start` and `stop`, this command is repo-wide: it runs from anywhere in
# the repository and reads every host directory, so it needs no `--env`.

# Finds host directories: a directory holding an infra.config.sh, at the repo
# root or one level below it.
_hosts_discover_dirs() {
  local root="$1"
  find "$root" -mindepth 1 -maxdepth 2 -name infra.config.sh \
    -not -path '*/node_modules/*' -printf '%h\n' 2>/dev/null | sort
}

# The server a host deploys to is the Docker context in its own prod script, so
# this command never becomes a second place to record it.
_hosts_server_of() {
  local host_dir="$1" server=""
  if [ -f "${host_dir}/package.json" ]; then
    server="$(
      jq -r '.scripts.prod // ""' "${host_dir}/package.json" 2>/dev/null |
        grep -oE 'DOCKER_CONTEXT=[^ ]+' | head -1 | cut -d= -f2
    )" || server=""
  fi
  printf '%s' "${server:-(unset)}"
}

# STACKS from the host's own config. Sourced in a subshell: these files define
# functions and may source shared libraries, none of which should leak here.
_hosts_stacks_of() {
  local host_dir="$1"
  (
    # shellcheck source=/dev/null
    source "${host_dir}/infra.config.sh" >/dev/null 2>&1 || true
    local -a stacks=("${STACKS[@]:-infrastructure applications tooling}")
    printf '%s\n' "${stacks[@]}"
  )
}

# Every hostname a stack's prod compose files route, as "<service>\t<hostname>".
_hosts_routed_in_stack() {
  local host_dir="$1" stack="$2"
  local -a args=()

  [ -f "${host_dir}/${stack}/docker-compose.base.yml" ] &&
    args+=(-f "${stack}/docker-compose.base.yml")
  [ -f "${host_dir}/${stack}/docker-compose.prod.yml" ] &&
    args+=(-f "${stack}/docker-compose.prod.yml")
  [ ${#args[@]} -eq 0 ] && return 0

  # Unresolved ${VAR} substitutions only warn on stderr, and no secret appears
  # in a router rule, so a blank one cannot hide a hostname.
  (
    cd "$host_dir" || exit 0
    # The backticks below are Traefik's Host(`name`) syntax inside a jq program.
    # shellcheck disable=SC2016
    docker compose "${args[@]}" config --format json 2>/dev/null |
      jq -r '
        .services | to_entries[] |
        .key as $service |
        (.value.labels // {}) |
        (if type == "array" then
           map(split("=") | {key: .[0], value: (.[1:] | join("="))}) | from_entries
         else . end) |
        to_entries[] |
        select(.key | test("^traefik\\.http\\.routers\\..*\\.rule$")) |
        .value | scan("Host\\(`([^`]+)`\\)") | .[0] as $hostname |
        "\($service)\t\($hostname)"
      '
  )
}

# Renders the rows as a Markdown table with every column padded, which is what
# prettier-style formatters produce — so a formatter will not rewrite the file
# the next time someone commits.
_hosts_render() {
  {
    printf 'Hostname|Server|Host directory|Stack|Service\n'
    printf -- '-|-|-|-|-\n'
    local hostname server host_dir stack service
    while IFS='|' read -r hostname server host_dir stack service; do
      [ -n "$hostname" ] || continue
      # The backticks are Markdown code spans in the output, not shell.
      # shellcheck disable=SC2016
      printf '`%s`|`%s`|`%s/`|%s|`%s`\n' \
        "$hostname" "$server" "$host_dir" "$stack" "$service"
    done
  } | awk -F'|' '
      { for (i = 1; i <= NF; i++) {
          cell[NR, i] = $i
          if (length($i) > width[i]) width[i] = length($i)
        }
        columns = NF; rows = NR }
      END {
        for (r = 1; r <= rows; r++) {
          line = ""
          for (i = 1; i <= columns; i++) {
            value = cell[r, i]
            if (r == 2) { value = sprintf("%-*s", width[i], ""); gsub(/ /, "-", value) }
            line = line "| " sprintf("%-*s", width[i], value) " "
          }
          print line "|"
        }
      }'
}

cmd_hosts() {
  local check=0 output="" root rows duplicates generated tool
  while [ $# -gt 0 ]; do
    case "$1" in
      --check) check=1; shift ;;
      -o | --output) output="$2"; shift 2 ;;
      --output=*) output="${1#--output=}"; shift ;;
      *)
        error "Unknown argument for hosts: $1"
        return 2
        ;;
    esac
  done

  for tool in docker jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      error "infra hosts requires ${tool}."
      return 1
    fi
  done

  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root="$(pwd)"
  [ -n "$root" ] || root="$(pwd)"
  [ -n "$output" ] || output="${root}/HOSTS.md"

  local host_dir server stack service hostname
  rows=""
  while IFS= read -r host_dir; do
    [ -n "$host_dir" ] || continue
    server="$(_hosts_server_of "$host_dir")"

    while IFS= read -r stack; do
      [ -n "$stack" ] || continue
      while IFS=$'\t' read -r service hostname; do
        [ -n "$hostname" ] || continue
        case "$hostname" in *.localhost) continue ;; esac
        rows+="${hostname}|${server}|$(realpath --relative-to="$root" "$host_dir")|${stack}|${service}"$'\n'
      done < <(_hosts_routed_in_stack "$host_dir" "$stack")
    done < <(_hosts_stacks_of "$host_dir")
  done < <(_hosts_discover_dirs "$root")

  rows="$(printf '%s' "$rows" | sed '/^$/d' | sort -u)"

  if [ -z "$rows" ]; then
    error "No routed hostnames found — is this a repo with host directories?"
    return 1
  fi

  # A misconfiguration, not a formatting problem, so nothing is written.
  duplicates="$(
    printf '%s\n' "$rows" | awk -F'|' '{print $1 "\t" $3}' | sort -u |
      awk -F'\t' '{ count[$1]++; where[$1] = where[$1] " " $2 }
                  END { for (h in count) if (count[h] > 1) print h ":" where[h] }'
  )"
  if [ -n "$duplicates" ]; then
    error "Hostname claimed by more than one host:"
    printf '  %s\n' "$duplicates" >&2
    return 1
  fi

  generated="$(
    cat <<'MARKDOWN_HEADER'
# Hosts

Every public hostname this repo routes, and the server that serves it.

<!-- Generated by `infra hosts`. Do not edit. -->

MARKDOWN_HEADER
    printf '%s\n' "$rows" | _hosts_render
    cat <<'MARKDOWN_FOOTER'

Dev `.localhost` hostnames are deliberately absent: they are not DNS and
not served by any of these servers.

Each server runs its own Traefik and its own certificate store, so a
hostname belongs to exactly one of them. `infra hosts` fails if two hosts
claim the same one.
MARKDOWN_FOOTER
  )"

  local count
  count="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"

  if [ "$check" -eq 1 ]; then
    if [ ! -f "$output" ]; then
      error "${output#"$root"/} is missing — run \`infra hosts\`."
      return 1
    fi
    if ! diff -u "$output" - <<<"$generated"; then
      echo >&2
      error "${output#"$root"/} is stale — run \`infra hosts\` and commit it."
      return 1
    fi
    success "${output#"$root"/} is up to date (${count} hostnames)."
    return 0
  fi

  printf '%s\n' "$generated" >"$output"
  success "Wrote ${output#"$root"/} (${count} hostnames)."
}
