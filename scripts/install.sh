#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${TMPDIR:-/tmp}"
INSTALL_DIR="${CODEX_LIMIT_PEEK_INSTALL_DIR:-$HOME/Applications}"
DEST_APP="$INSTALL_DIR/Codex Limit Peek.app"
SCRATCH_DIR=""
STAGE_ROOT=""

cleanup() {
  if [[ -n "$STAGE_ROOT" && -d "$STAGE_ROOT" ]]; then
    /bin/rm -rf "$STAGE_ROOT"
  fi
  if [[ -n "$SCRATCH_DIR" && -d "$SCRATCH_DIR" ]]; then
    /bin/rm -rf "$SCRATCH_DIR"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$TMP_BASE" "$INSTALL_DIR"
SCRATCH_DIR="$(mktemp -d "$TMP_BASE/codex-limit-peek-build.XXXXXX")"

echo "Building Codex Limit Peek..."
CODEX_LIMIT_PEEK_SCRATCH_PATH="$SCRATCH_DIR" \
  "$ROOT_DIR/scripts/build-app.sh" >/dev/null

STAGE_ROOT="$(mktemp -d "$INSTALL_DIR/.codex-limit-peek-install.XXXXXX")"
STAGED_APP="$STAGE_ROOT/Codex Limit Peek.app"
ditto "$ROOT_DIR/build/Codex Limit Peek.app" "$STAGED_APP"

codesign --force --deep --sign - "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

if [[ "${CODEX_LIMIT_PEEK_SKIP_STOP:-0}" != "1" ]]; then
  pkill -x CodexLimitPeek 2>/dev/null || true
fi

BACKUP_APP="$STAGE_ROOT/previous.app"
if [[ -e "$DEST_APP" ]]; then
  mv "$DEST_APP" "$BACKUP_APP"
fi
if ! mv "$STAGED_APP" "$DEST_APP"; then
  if [[ -e "$BACKUP_APP" ]]; then
    mv "$BACKUP_APP" "$DEST_APP"
  fi
  echo "failed to install Codex Limit Peek" >&2
  exit 1
fi

if [[ "${CODEX_LIMIT_PEEK_SKIP_LAUNCH:-0}" != "1" ]]; then
  open -n "$DEST_APP"
fi

echo "$DEST_APP"
