#!/usr/bin/env bash
set -euo pipefail

DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
TESTING_FRAMEWORKS="$DEVELOPER_DIR/Library/Developer/Frameworks"
TESTING_MACROS="$DEVELOPER_DIR/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
TESTING_INTEROP="$DEVELOPER_DIR/Library/Developer/usr/lib"

if [[ -d "$TESTING_FRAMEWORKS/Testing.framework" && -f "$TESTING_MACROS" ]]; then
  export DYLD_FRAMEWORK_PATH="$TESTING_FRAMEWORKS${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
  exec swift test \
    -Xswiftc -F \
    -Xswiftc "$TESTING_FRAMEWORKS" \
    -Xswiftc -load-plugin-library \
    -Xswiftc "$TESTING_MACROS" \
    -Xlinker -rpath \
    -Xlinker "$TESTING_FRAMEWORKS" \
    -Xlinker -rpath \
    -Xlinker "$TESTING_INTEROP" \
    "$@"
fi

exec swift test "$@"
