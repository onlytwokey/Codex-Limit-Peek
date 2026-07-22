#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${CODEX_LIMIT_PEEK_VERSION:-0.1.0}"
BUILD_NUMBER="${CODEX_LIMIT_PEEK_BUILD_NUMBER:-1}"
BUILD_CONFIGURATION="${CODEX_LIMIT_PEEK_BUILD_CONFIGURATION:-release}"

case "$BUILD_CONFIGURATION" in
  debug|release) ;;
  *)
    echo "CODEX_LIMIT_PEEK_BUILD_CONFIGURATION must be debug or release" >&2
    exit 2
    ;;
esac

SWIFT_BUILD_ARGS=(-c "$BUILD_CONFIGURATION")
BUILD_ROOT="$ROOT_DIR/.build"

if [[ -n "${CODEX_LIMIT_PEEK_SDK_PATH:-}" ]]; then
  if [[ "$CODEX_LIMIT_PEEK_SDK_PATH" != /* ]] \
    || [[ ! -d "$CODEX_LIMIT_PEEK_SDK_PATH" ]]; then
    echo "CODEX_LIMIT_PEEK_SDK_PATH must be an existing absolute directory" >&2
    exit 2
  fi
  SWIFT_BUILD_ARGS+=(--sdk "$CODEX_LIMIT_PEEK_SDK_PATH")
fi

case "${CODEX_LIMIT_PEEK_DISABLE_SWIFTPM_SANDBOX:-0}" in
  0) ;;
  1) SWIFT_BUILD_ARGS+=(--disable-sandbox) ;;
  *)
    echo "CODEX_LIMIT_PEEK_DISABLE_SWIFTPM_SANDBOX must be 0 or 1" >&2
    exit 2
    ;;
esac

if [[ -n "${CODEX_LIMIT_PEEK_SCRATCH_PATH:-}" ]]; then
  if [[ "$CODEX_LIMIT_PEEK_SCRATCH_PATH" != /* ]]; then
    echo "CODEX_LIMIT_PEEK_SCRATCH_PATH must be absolute" >&2
    exit 2
  fi
  SWIFT_BUILD_ARGS+=(--scratch-path "$CODEX_LIMIT_PEEK_SCRATCH_PATH")
  BUILD_ROOT="$CODEX_LIMIT_PEEK_SCRATCH_PATH"
fi

swift build "${SWIFT_BUILD_ARGS[@]}"

EXECUTABLE="$BUILD_ROOT/$BUILD_CONFIGURATION/CodexLimitPeek"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "$BUILD_CONFIGURATION executable not found: $EXECUTABLE" >&2
  exit 1
fi

APP_DIR="$ROOT_DIR/build/Codex Limit Peek.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/CodexLimitPeek"
chmod +x "$APP_DIR/Contents/MacOS/CodexLimitPeek"

/usr/libexec/PlistBuddy -c "Clear dict" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleName string Codex Limit Peek" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Codex Limit Peek" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string io.github.onlytwokey.CodexLimitPeek" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string CodexLimitPeek" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSUserNotificationUsageDescription string Codex Limit Peek uses notifications for low quota alerts." "$APP_DIR/Contents/Info.plist"

echo "$APP_DIR"
