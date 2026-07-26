#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALL_DIR="${CODEX_LIMIT_PEEK_INSTALL_DIR:-$HOME/Applications}"
INSTALLED_APP="$INSTALL_DIR/Codex Limit Peek.app"
DEVELOPMENT_APP="$ROOT_DIR/build/Codex Limit Peek.app"
INSTALLED_EXECUTABLE="$INSTALLED_APP/Contents/MacOS/CodexLimitPeek"
DEVELOPMENT_EXECUTABLE="$DEVELOPMENT_APP/Contents/MacOS/CodexLimitPeek"
EXPECTED_BUNDLE_ID="io.github.onlytwokey.CodexLimitPeek.MenuBar"

PRODUCTION_WAS_RUNNING=0
PRODUCTION_PID=""
DEVELOPMENT_PID=""
SWITCHED_PROCESS=0
PREVIEW_RUNTIME_DIR=""
READY_FILE=""

command_line_for_pid() {
  { ps -ww -p "$1" -o command= 2>/dev/null || true; } \
    | sed -e 's/^[[:space:]]*//'
}

single_pid_for_executable() {
  local expected_executable="$1"
  local pid
  local command_line
  local matches=()

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    command_line="$(command_line_for_pid "$pid")"
    if [[ "$command_line" == "$expected_executable" \
      || "$command_line" == "${expected_executable} "* ]]; then
      matches+=("$pid")
    fi
  done < <(pgrep -x CodexLimitPeek 2>/dev/null || true)

  if [[ "${#matches[@]}" -eq 0 ]]; then
    return 1
  fi
  if [[ "${#matches[@]}" -ne 1 ]]; then
    echo "multiple matching Codex Limit Peek processes found for $expected_executable" >&2
    return 2
  fi

  printf '%s\n' "${matches[0]}"
}

wait_for_pid_exit() {
  local pid="$1"
  local attempt

  for ((attempt = 0; attempt < 100; attempt += 1)); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.05
  done

  return 1
}

terminate_exact_process() {
  local pid="$1"
  local expected_executable="$2"
  local command_line

  command_line="$(command_line_for_pid "$pid")"
  if [[ "$command_line" != "$expected_executable" \
    && "$command_line" != "${expected_executable} "* ]]; then
    echo "refusing to stop unexpected process $pid: $command_line" >&2
    return 1
  fi

  if ! kill -TERM "$pid" 2>/dev/null; then
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    echo "failed to stop process: $expected_executable" >&2
    return 1
  fi
  if ! wait_for_pid_exit "$pid"; then
    echo "process did not exit after SIGTERM: $expected_executable" >&2
    return 1
  fi
}

wait_for_exact_process() {
  local expected_executable="$1"
  local attempt
  local pid
  local status

  for ((attempt = 0; attempt < 100; attempt += 1)); do
    if pid="$(single_pid_for_executable "$expected_executable")"; then
      printf '%s\n' "$pid"
      return 0
    else
      status=$?
      if [[ "$status" -eq 2 ]]; then
        return 2
      fi
    fi
    sleep 0.1
  done

  return 1
}

cleanup_preview_runtime() {
  if [[ -n "$READY_FILE" && -e "$READY_FILE" ]]; then
    rm -f -- "$READY_FILE"
  fi
  if [[ -n "$PREVIEW_RUNTIME_DIR" && -d "$PREVIEW_RUNTIME_DIR" ]]; then
    rmdir -- "$PREVIEW_RUNTIME_DIR" 2>/dev/null || true
  fi
}

restore_production() {
  local original_status=$?
  local restore_failed=0
  local restored_pid=""

  trap - EXIT HUP INT TERM

  if [[ "$SWITCHED_PROCESS" == "1" ]]; then
    if [[ -n "$DEVELOPMENT_PID" ]] \
      && kill -0 "$DEVELOPMENT_PID" 2>/dev/null; then
      if ! terminate_exact_process \
        "$DEVELOPMENT_PID" \
        "$DEVELOPMENT_EXECUTABLE"; then
        restore_failed=1
      fi
    fi

    if [[ "$PRODUCTION_WAS_RUNNING" == "1" ]]; then
      if ! open -n "$INSTALLED_APP" >/dev/null 2>&1; then
        echo "failed to relaunch installed Codex Limit Peek" >&2
        restore_failed=1
      elif restored_pid="$(wait_for_exact_process "$INSTALLED_EXECUTABLE")"; then
        echo "Restored installed Codex Limit Peek (pid $restored_pid)."
      else
        echo "installed Codex Limit Peek did not become ready" >&2
        restore_failed=1
      fi
    else
      echo "Installed Codex Limit Peek was not running; left it stopped."
    fi
  fi

  cleanup_preview_runtime

  if [[ "$restore_failed" == "1" ]]; then
    exit 1
  fi
  exit "$original_status"
}

trap restore_production EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ ! -d "$INSTALLED_APP" ]]; then
  echo "installed app not found: $INSTALLED_APP" >&2
  exit 1
fi
if [[ ! -x "$INSTALLED_EXECUTABLE" ]]; then
  echo "installed executable not found: $INSTALLED_EXECUTABLE" >&2
  exit 1
fi

INSTALLED_BUNDLE_ID="$(/usr/libexec/PlistBuddy \
  -c 'Print :CFBundleIdentifier' \
  "$INSTALLED_APP/Contents/Info.plist")"
if [[ "$INSTALLED_BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "unexpected installed bundle identifier: $INSTALLED_BUNDLE_ID" >&2
  exit 1
fi

echo "Building the development preview before stopping the installed app..."
CODEX_LIMIT_PEEK_BUILD_CONFIGURATION=debug \
  "$ROOT_DIR/scripts/build-app.sh" >/dev/null

if [[ ! -x "$DEVELOPMENT_EXECUTABLE" ]]; then
  echo "development executable not found: $DEVELOPMENT_EXECUTABLE" >&2
  exit 1
fi

DEVELOPMENT_BUNDLE_ID="$(/usr/libexec/PlistBuddy \
  -c 'Print :CFBundleIdentifier' \
  "$DEVELOPMENT_APP/Contents/Info.plist")"
if [[ "$DEVELOPMENT_BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "unexpected development bundle identifier: $DEVELOPMENT_BUNDLE_ID" >&2
  exit 1
fi

PREVIEW_RUNTIME_DIR="$(
  mktemp -d /private/tmp/codex-limit-peek-preview.XXXXXX
)"
READY_FILE="$PREVIEW_RUNTIME_DIR/ready"

if PRODUCTION_PID="$(single_pid_for_executable "$INSTALLED_EXECUTABLE")"; then
  PRODUCTION_WAS_RUNNING=1
else
  PROCESS_STATUS=$?
  if [[ "$PROCESS_STATUS" -eq 2 ]]; then
    exit 1
  fi
  PRODUCTION_PID=""
fi

echo "Switching from the installed app to the development preview..."
if [[ "$PRODUCTION_WAS_RUNNING" == "1" ]]; then
  terminate_exact_process "$PRODUCTION_PID" "$INSTALLED_EXECUTABLE"
fi
SWITCHED_PROCESS=1

open -n "$DEVELOPMENT_APP" --args \
  --developer-preview \
  --developer-preview-ready-file "$READY_FILE"
if ! DEVELOPMENT_PID="$(wait_for_exact_process "$DEVELOPMENT_EXECUTABLE")"; then
  echo "development preview did not start" >&2
  exit 1
fi

DEVELOPMENT_COMMAND="$(command_line_for_pid "$DEVELOPMENT_PID")"
if [[ "$DEVELOPMENT_COMMAND" != *" --developer-preview"* ]]; then
  echo "development preview launched without its debug argument" >&2
  exit 1
fi

PREVIEW_READY=0
for ((READY_ATTEMPT = 0; READY_ATTEMPT < 100; READY_ATTEMPT += 1)); do
  if [[ -f "$READY_FILE" ]] \
    && IFS= read -r READY_VALUE < "$READY_FILE" \
    && [[ "$READY_VALUE" == "ready" ]]; then
    PREVIEW_READY=1
    break
  fi
  if ! kill -0 "$DEVELOPMENT_PID" 2>/dev/null; then
    break
  fi
  sleep 0.1
done

if [[ "$PREVIEW_READY" != "1" ]]; then
  echo "development preview window did not become ready" >&2
  exit 1
fi
echo "Development preview is ready (pid $DEVELOPMENT_PID)."

while kill -0 "$DEVELOPMENT_PID" 2>/dev/null; do
  sleep 0.2
done
