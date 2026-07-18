#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_DIR="$ROOT_DIR/docs/images"
LOCK_FILE="$IMAGE_DIR/.render-doc-previews.lock"
ASSETS=(
  "panel-preview.png"
  "quota-states-loud.png"
  "refresh-states-loud.png"
  "appearance-settings-loud.png"
)

STAGING=""
CHECK_STAGING=""
NEW_PATHS=()
BACKUP_PATHS=()
HAD_ORIGINAL=()
lock_acquired=0
replacement_started=0
replacement_committed=0
check_only=0

usage() {
  echo "usage: $0 [--check]" >&2
}

restore_originals() {
  local index
  local asset
  local target
  local backup

  for ((index = 0; index < ${#ASSETS[@]}; index += 1)); do
    asset="${ASSETS[$index]}"
    target="$IMAGE_DIR/$asset"
    backup="${BACKUP_PATHS[$index]:-}"

    if [[ "${HAD_ORIGINAL[$index]:-0}" == "1" ]]; then
      if [[ -n "$backup" && -e "$backup" ]]; then
        if /bin/mv -f "$backup" "$target"; then
          BACKUP_PATHS[$index]=""
        else
          echo "failed to restore $target" >&2
        fi
      else
        echo "missing rollback copy for $target" >&2
      fi
    elif [[ -e "$target" ]]; then
      unlink "$target" \
        || echo "failed to remove newly installed $target" >&2
    fi
  done
}

cleanup() {
  local status=$?
  local path

  trap - EXIT
  trap '' HUP INT TERM
  set +e

  if (( replacement_started && ! replacement_committed )); then
    restore_originals
  fi

  for path in "${NEW_PATHS[@]:-}"; do
    if [[ -n "$path" && -e "$path" ]]; then
      unlink "$path"
    fi
  done

  if (( ! replacement_started || replacement_committed )); then
    for path in "${BACKUP_PATHS[@]:-}"; do
      if [[ -n "$path" && -e "$path" ]]; then
        unlink "$path"
      fi
    done
  else
    for path in "${BACKUP_PATHS[@]:-}"; do
      if [[ -n "$path" && -e "$path" ]]; then
        echo "original documentation image retained at $path" >&2
      fi
    done
  fi

  if [[ -n "$STAGING" && -d "$STAGING" ]]; then
    /bin/rm -rf "$STAGING"
  fi
  if [[ -n "$CHECK_STAGING" && -d "$CHECK_STAGING" ]]; then
    /bin/rm -rf "$CHECK_STAGING"
  fi
  if (( lock_acquired )) && [[ -f "$LOCK_FILE" ]]; then
    unlink "$LOCK_FILE"
  fi

  exit "$status"
}

render_into() {
  local output_dir="$1"

  CODEX_LIMIT_PEEK_DOC_PREVIEW_OUTPUT_DIR="$output_dir" \
    "$ROOT_DIR/scripts/test.sh" \
    --filter DocumentationPreviewRendererTests
}

validate_directory() {
  "$ROOT_DIR/scripts/validate-doc-images.sh" "$1"
}

compare_directories() {
  local left="$1"
  local right="$2"
  local asset

  for asset in "${ASSETS[@]}"; do
    cmp -s "$left/$asset" "$right/$asset" \
      || {
        echo "documentation render is not deterministic: $asset" >&2
        return 1
      }
  done
}

case $# in
  0)
    ;;
  1)
    if [[ "$1" == "--check" ]]; then
      check_only=1
    else
      usage
      exit 2
    fi
    ;;
  *)
    usage
    exit 2
    ;;
esac

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

STAGING="$(
  mktemp -d \
    "${TMPDIR:-/tmp}/codex-limit-peek-docs.XXXXXX"
)"
mkdir -p "$IMAGE_DIR"
cd "$ROOT_DIR"

render_into "$STAGING"
validate_directory "$STAGING"

if (( check_only )); then
  CHECK_STAGING="$(
    mktemp -d \
      "${TMPDIR:-/tmp}/codex-limit-peek-docs-check.XXXXXX"
  )"
  render_into "$CHECK_STAGING"
  validate_directory "$CHECK_STAGING"
  compare_directories "$STAGING" "$CHECK_STAGING"
  echo "documentation preview determinism checks passed"
  exit 0
fi

if ! /usr/bin/shlock -f "$LOCK_FILE" -p "$$"; then
  echo "another documentation preview render is installing" >&2
  exit 1
fi
lock_acquired=1

for asset in "${ASSETS[@]}"; do
  find "$IMAGE_DIR" \
    -maxdepth 1 \
    -type f \
    -name ".$asset.new.*" \
    -exec unlink {} \;
done

for asset in "${ASSETS[@]}"; do
  target="$IMAGE_DIR/$asset"

  if [[ -f "$target" ]]; then
    backup="$(
      mktemp "$IMAGE_DIR/.$asset.rollback.XXXXXX"
    )"
    BACKUP_PATHS[${#BACKUP_PATHS[@]}]="$backup"
    /bin/cp -p "$target" "$backup"
    HAD_ORIGINAL[${#HAD_ORIGINAL[@]}]=1
  elif [[ -e "$target" ]]; then
    echo "documentation image is not a regular file: $target" >&2
    exit 1
  else
    BACKUP_PATHS[${#BACKUP_PATHS[@]}]=""
    HAD_ORIGINAL[${#HAD_ORIGINAL[@]}]=0
  fi
done

for asset in "${ASSETS[@]}"; do
  new_path="$(
    mktemp "$IMAGE_DIR/.$asset.new.XXXXXX"
  )"
  NEW_PATHS[${#NEW_PATHS[@]}]="$new_path"
  install -m 0644 "$STAGING/$asset" "$new_path"
done

"$ROOT_DIR/scripts/validate-doc-images.sh" \
  "${NEW_PATHS[0]}" \
  "${NEW_PATHS[1]}" \
  "${NEW_PATHS[2]}" \
  "${NEW_PATHS[3]}"

replacement_started=1
for ((index = 0; index < ${#ASSETS[@]}; index += 1)); do
  /bin/mv -f \
    "${NEW_PATHS[$index]}" \
    "$IMAGE_DIR/${ASSETS[$index]}"
  NEW_PATHS[$index]=""
done

"$ROOT_DIR/scripts/validate-doc-images.sh"

for asset in "${ASSETS[@]}"; do
  cmp -s "$STAGING/$asset" "$IMAGE_DIR/$asset" \
    || {
      echo "installed documentation image differs from staging: $asset" >&2
      exit 1
    }
done

replacement_committed=1
for asset in "${ASSETS[@]}"; do
  find "$IMAGE_DIR" \
    -maxdepth 1 \
    -type f \
    -name ".$asset.rollback.*" \
    -exec unlink {} \;
done
echo "documentation previews installed"
