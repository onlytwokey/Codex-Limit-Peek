#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/build/Codex Limit Peek.app"

stop_running_instances() {
  pkill -x CodexLimitPeek 2>/dev/null || true
  for ((attempt = 0; attempt < 50; attempt++)); do
    if ! pgrep -x CodexLimitPeek >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  echo "CodexLimitPeek did not exit in time" >&2
  return 1
}

if [ ! -d "$APP_PATH" ]; then
  "$ROOT_DIR/scripts/build-app.sh" >/dev/null
fi

stop_running_instances
open "$APP_PATH"
