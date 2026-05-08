#!/bin/sh
set -eu

is_true() {
  case "${1:-}" in
    true|TRUE|1|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

vault_dir="${COLLABMD_GIT_CONTAINER_DIR:-/data}"
interval="${COLLABMD_GIT_META_SYNC_INTERVAL_SEC:-30}"
enabled="${COLLABMD_GIT_META_SYNC_ENABLED:-false}"
track_comments="${COLLABMD_GIT_TRACK_COLLABMD_COMMENTS:-true}"
track_yjs="${COLLABMD_GIT_TRACK_COLLABMD_YJS:-false}"
track_pull_backups="${COLLABMD_GIT_TRACK_COLLABMD_PULL_BACKUPS:-false}"
oneshot="${COLLABMD_GIT_META_SYNC_ONESHOT:-false}"

case "$interval" in
  ''|*[!0-9]*) interval=30 ;;
esac

if [ "$interval" -lt 5 ]; then
  interval=5
fi

if ! is_true "$enabled"; then
  echo "collabmd-git-meta-sync disabled; set COLLABMD_GIT_META_SYNC_ENABLED=true to enable."
  while :; do sleep 3600; done
fi

apply_policy() {
  git_dir="$vault_dir/.git"
  exclude_file="$git_dir/info/exclude"

  if [ ! -d "$git_dir" ]; then
    echo "waiting for git checkout at $vault_dir ..."
    return 1
  fi

  mkdir -p "$git_dir/info"
  touch "$exclude_file"

  tmp_file="$(mktemp)"
  awk '
    $0 == "# collabmd-git-meta-sync begin" { skip = 1; next }
    $0 == "# collabmd-git-meta-sync end" { skip = 0; next }
    skip == 1 { next }
    $0 == ".collabmd" { next }
    $0 == ".collabmd/" { next }
    { print }
  ' "$exclude_file" > "$tmp_file"

  {
    echo "# collabmd-git-meta-sync begin"
    if is_true "$track_comments"; then
      if ! is_true "$track_yjs"; then
        echo ".collabmd/yjs/"
      fi
      if ! is_true "$track_pull_backups"; then
        echo ".collabmd/pull-backups/"
      fi
    else
      echo ".collabmd/"
    fi
    echo "# collabmd-git-meta-sync end"
  } >> "$tmp_file"

  if ! cmp -s "$tmp_file" "$exclude_file"; then
    cat "$tmp_file" > "$exclude_file"
    echo "updated $exclude_file for CollabMD metadata tracking."
  fi

  rm -f "$tmp_file"
  return 0
}

while :; do
  apply_policy || true

  if is_true "$oneshot"; then
    exit 0
  fi

  sleep "$interval"
done
