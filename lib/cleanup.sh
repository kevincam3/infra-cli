#!/usr/bin/env bash

cleanup_exited_containers() {
  section "🧹 Removing Exited Containers"

  local removed=false stack containers id name
  for stack in "${STACKS[@]}"; do
    containers=$(docker ps -a \
      --filter "label=com.docker.compose.project=${PROJECT_NAME}-${ENVIRONMENT}-${stack}" \
      --filter "status=exited" \
      --format "{{.ID}} {{.Names}}")

    [ -z "$containers" ] && continue

    while read -r id name; do
      [ -z "$id" ] && continue
      success "Removed $name"
      docker rm "$id" >/dev/null
      removed=true
    done <<<"$containers"
  done

  [ "$removed" = false ] && info "No exited containers to remove"
}

cleanup_anonymous_volumes() {
  section "🧹 Removing Unused Volumes"

  local removed=false v labels
  for v in $(docker volume ls -q); do
    labels=$(docker volume inspect "$v" --format '{{json .Labels}}')
    if [[ $labels == *"com.docker.volume.anonymous"* ]]; then
      success "Removed $v"
      docker volume rm "$v" >/dev/null
      removed=true
    fi
  done

  [ "$removed" = false ] && info "No unused volumes to remove"
}

# Remove older versions of images that this project's running containers reference.
# Preserves images newer than the running version, since another project may be using them.
cleanup_old_images() {
  section "🧹 Removing Unused Images"

  local projects=() stack
  for stack in "${STACKS[@]}"; do
    projects+=("${PROJECT_NAME}-${ENVIRONMENT}-${stack}")
  done

  # Digest-pinned images often have tag=<none>, so inspect containers (which
  # always expose the real image id) rather than image refs.
  local project_repos=() used_ids=() project cid meta image_id image_ref repo
  for project in "${projects[@]}"; do
    while IFS= read -r cid; do
      [ -z "$cid" ] && continue
      meta=$(docker container inspect --format '{{.Image}}|{{.Config.Image}}' "$cid" 2>/dev/null || echo "|")
      image_id=${meta%%|*}
      image_ref=${meta#*|}
      [ -n "$image_id" ] && used_ids+=("$image_id")
      if [ -n "$image_ref" ]; then
        repo=${image_ref%%@*}   # strip digest
        repo=${repo%:*}         # strip tag (shortest match preserves registry:port)
        project_repos+=("$repo")
      fi
    done < <(docker container ls --filter "label=com.docker.compose.project=$project" --format '{{.ID}}')
  done

  local repos=()
  if [ ${#project_repos[@]} -gt 0 ]; then
    mapfile -t repos < <(printf '%s\n' "${project_repos[@]}" | sort -u)
  fi

  if [ ${#repos[@]} -eq 0 ]; then
    info "No unused images to remove"
    return 0
  fi

  local removed_any=false repo images img_id img_meta id created last_tag
  local has_running running_created running_last_tag newer
  for repo in "${repos[@]}"; do
    if ! printf '%s\n' "${used_ids[@]}" | grep -q .; then
      continue
    fi

    has_running=false
    images=""
    while IFS= read -r img_id; do
      [ -z "$img_id" ] && continue
      img_meta=$(docker image inspect --format '{{.Created}}|{{.Metadata.LastTagTime}}' "$img_id" 2>/dev/null || echo "|")
      images+="${img_id}|${img_meta}"$'\n'
    done < <(docker images "$repo" --no-trunc --format '{{.ID}}')

    while IFS='|' read -r id created last_tag; do
      [ -z "$id" ] && continue
      if printf '%s\n' "${used_ids[@]}" | grep -qx "$id"; then
        has_running=true
        break
      fi
    done <<<"$images"

    [ "$has_running" = false ] && continue

    running_created=""
    running_last_tag=""
    while IFS='|' read -r id created last_tag; do
      [ -z "$id" ] && continue
      if printf '%s\n' "${used_ids[@]}" | grep -qx "$id"; then
        running_created="$created"
        running_last_tag="$last_tag"
        break
      fi
    done <<<"$images"

    while IFS='|' read -r id created last_tag; do
      [ -z "$id" ] && continue
      if printf '%s\n' "${used_ids[@]}" | grep -qx "$id"; then
        continue
      fi

      # Skip images newer than the running one — another project may be using them.
      # "Newer" = Created later, or identical Created with LastTagTime later.
      if [ -n "$running_created" ] && [ -n "$created" ]; then
        newer=false
        if [[ "$created" > "$running_created" ]]; then
          newer=true
        elif [[ "$created" == "$running_created" ]] && [ -n "$running_last_tag" ] && [ -n "$last_tag" ] && [[ "$last_tag" > "$running_last_tag" ]]; then
          newer=true
        fi
        if [ "$newer" = true ]; then
          echo "  Keeping ${repo} (newer than running) [${id:0:12}]"
          continue
        fi
      fi

      success "Removed ${repo} (${id:0:12})"
      docker rmi "$id" >/dev/null 2>&1 && removed_any=true
    done <<<"$images"
  done

  [ "$removed_any" = false ] && info "No unused images to remove"
}
