#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING="$(
  mktemp -d \
    "${TMPDIR:-/tmp}/codex-limit-peek-docs.XXXXXX"
)"
IMAGE_DIR="$ROOT_DIR/docs/images"
PANEL="$IMAGE_DIR/panel-preview.png"
SETTINGS="$IMAGE_DIR/appearance-settings-loud.png"
PANEL_NEW=""
SETTINGS_NEW=""
LOCK_FILE="$IMAGE_DIR/.render-doc-previews.lock"
PANEL_BACKUP=""
SETTINGS_BACKUP=""
panel_had_original=0
settings_had_original=0
lock_acquired=0
replacement_started=0
replacement_committed=0

restore_originals() {
  if (( panel_had_original )); then
    if mv "$PANEL_BACKUP" "$PANEL"; then
      PANEL_BACKUP=""
    else
      echo "failed to restore $PANEL" >&2
    fi
  elif [[ -e "$PANEL" ]]; then
    unlink "$PANEL" \
      || echo "failed to remove $PANEL" >&2
  fi

  if (( settings_had_original )); then
    if mv "$SETTINGS_BACKUP" "$SETTINGS"; then
      SETTINGS_BACKUP=""
    else
      echo "failed to restore $SETTINGS" >&2
    fi
  elif [[ -e "$SETTINGS" ]]; then
    unlink "$SETTINGS" \
      || echo "failed to remove $SETTINGS" >&2
  fi
}

cleanup() {
  local status=$?
  trap - EXIT
  trap '' HUP INT TERM
  set +e

  if (( replacement_started && ! replacement_committed )); then
    restore_originals
  fi
  if [[ -n "$PANEL_NEW" && -e "$PANEL_NEW" ]]; then
    unlink "$PANEL_NEW"
  fi
  if [[ -n "$SETTINGS_NEW" && -e "$SETTINGS_NEW" ]]; then
    unlink "$SETTINGS_NEW"
  fi
  if (( ! replacement_started || replacement_committed )); then
    if [[ -n "$PANEL_BACKUP" && -e "$PANEL_BACKUP" ]]; then
      unlink "$PANEL_BACKUP"
    fi
    if [[ -n "$SETTINGS_BACKUP" && -e "$SETTINGS_BACKUP" ]]; then
      unlink "$SETTINGS_BACKUP"
    fi
  else
    if [[ -n "$PANEL_BACKUP" && -e "$PANEL_BACKUP" ]]; then
      echo "original panel retained at $PANEL_BACKUP" >&2
    fi
    if [[ -n "$SETTINGS_BACKUP" && -e "$SETTINGS_BACKUP" ]]; then
      echo "original settings retained at $SETTINGS_BACKUP" >&2
    fi
  fi
  if [[ -d "$STAGING" ]]; then
    /bin/rm -rf "$STAGING"
  fi
  if (( lock_acquired )) && [[ -f "$LOCK_FILE" ]]; then
    unlink "$LOCK_FILE"
  fi

  exit "$status"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$IMAGE_DIR"
cd "$ROOT_DIR"

CODEX_LIMIT_PEEK_DOC_PREVIEW_OUTPUT_DIR="$STAGING" \
  "$ROOT_DIR/scripts/test.sh" \
  --filter DocumentationPreviewRendererTests

"$ROOT_DIR/scripts/validate-doc-images.sh" "$STAGING"

if ! /usr/bin/shlock -f "$LOCK_FILE" -p "$$"; then
  echo "another documentation preview render is installing" >&2
  exit 1
fi
lock_acquired=1

find "$IMAGE_DIR" \
  -maxdepth 1 \
  -type f \
  \( \
    -name '.panel-preview.png.new.*' \
    -o -name '.appearance-settings-loud.png.new.*' \
  \) \
  -exec unlink {} \;

if [[ -f "$PANEL" ]]; then
  PANEL_BACKUP="$(
    mktemp "$IMAGE_DIR/.panel-preview.png.rollback.XXXXXX"
  )"
  /bin/cp -p "$PANEL" "$PANEL_BACKUP"
  panel_had_original=1
elif [[ -e "$PANEL" ]]; then
  echo "documentation image is not a regular file: $PANEL" >&2
  exit 1
fi
if [[ -f "$SETTINGS" ]]; then
  SETTINGS_BACKUP="$(
    mktemp \
      "$IMAGE_DIR/.appearance-settings-loud.png.rollback.XXXXXX"
  )"
  /bin/cp -p "$SETTINGS" "$SETTINGS_BACKUP"
  settings_had_original=1
elif [[ -e "$SETTINGS" ]]; then
  echo "documentation image is not a regular file: $SETTINGS" >&2
  exit 1
fi

PANEL_NEW="$(
  mktemp "$IMAGE_DIR/.panel-preview.png.new.XXXXXX"
)"
SETTINGS_NEW="$(
  mktemp "$IMAGE_DIR/.appearance-settings-loud.png.new.XXXXXX"
)"
install -m 0644 \
  "$STAGING/panel-preview.png" \
  "$PANEL_NEW"
install -m 0644 \
  "$STAGING/appearance-settings-loud.png" \
  "$SETTINGS_NEW"

"$ROOT_DIR/scripts/validate-doc-images.sh" \
  "$PANEL_NEW" \
  "$SETTINGS_NEW"

replacement_started=1
mv "$PANEL_NEW" "$PANEL"
PANEL_NEW=""
mv "$SETTINGS_NEW" "$SETTINGS"
SETTINGS_NEW=""

"$ROOT_DIR/scripts/validate-doc-images.sh"
cmp -s "$STAGING/panel-preview.png" "$PANEL" \
  || {
    echo "installed panel preview differs from staging" >&2
    exit 1
  }
cmp -s "$STAGING/appearance-settings-loud.png" "$SETTINGS" \
  || {
    echo "installed settings preview differs from staging" >&2
    exit 1
  }

replacement_committed=1
