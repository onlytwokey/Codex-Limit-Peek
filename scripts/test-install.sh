#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/codex-limit-peek-install-tests.XXXXXX")"
TEST_TMP="$SANDBOX/tmp"
TEST_APPS="$SANDBOX/Applications"

cleanup() {
  if [[ -d "$SANDBOX" ]]; then
    /bin/rm -rf "$SANDBOX"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$TEST_TMP" "$TEST_APPS"

TMPDIR="$TEST_TMP" \
CODEX_LIMIT_PEEK_INSTALL_DIR="$TEST_APPS" \
CODEX_LIMIT_PEEK_SKIP_LAUNCH=1 \
"$ROOT_DIR/scripts/install.sh"

APP_PATH="$TEST_APPS/Codex Limit Peek.app"
test -x "$APP_PATH/Contents/MacOS/CodexLimitPeek"
codesign --verify --deep --strict "$APP_PATH"

if find "$TEST_TMP" -maxdepth 1 -name 'codex-limit-peek-build.*' -print -quit | grep -q .; then
  echo "install scratch directory was not removed" >&2
  exit 1
fi
if find "$TEST_APPS" -maxdepth 1 -name '.codex-limit-peek-install.*' -print -quit | grep -q .; then
  echo "install staging directory was not removed" >&2
  exit 1
fi

mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/swift" <<'EOF'
#!/usr/bin/env bash
exit 42
EOF
chmod +x "$SANDBOX/bin/swift"

if PATH="$SANDBOX/bin:$PATH" \
  TMPDIR="$TEST_TMP" \
  CODEX_LIMIT_PEEK_INSTALL_DIR="$TEST_APPS" \
  CODEX_LIMIT_PEEK_SKIP_LAUNCH=1 \
  "$ROOT_DIR/scripts/install.sh"; then
  echo "expected the stubbed build to fail" >&2
  exit 1
fi

if find "$TEST_TMP" -maxdepth 1 -name 'codex-limit-peek-build.*' -print -quit | grep -q .; then
  echo "failed install scratch directory was not removed" >&2
  exit 1
fi
test -x "$APP_PATH/Contents/MacOS/CodexLimitPeek"

echo "source installation checks passed"
