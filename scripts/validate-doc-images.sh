#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_FILE_BYTES=$((3 * 1024 * 1024))
MAX_TOTAL_BYTES=$((5 * 1024 * 1024))

case $# in
  0)
    PANEL="$ROOT_DIR/docs/images/panel-preview.png"
    SETTINGS="$ROOT_DIR/docs/images/appearance-settings-loud.png"
    ;;
  1)
    PANEL="$1/panel-preview.png"
    SETTINGS="$1/appearance-settings-loud.png"
    ;;
  2)
    PANEL="$1"
    SETTINGS="$2"
    ;;
  *)
    echo \
      "usage: $0 [image-directory | panel-image settings-image]" \
      >&2
    exit 2
    ;;
esac

fail() {
  echo "$1" >&2
  exit 1
}

check_dpi() {
  local dpi="$1"
  local axis="$2"
  local path="$3"

  awk -v value="$dpi" \
    'BEGIN { exit !(value >= 143.5 && value <= 144.5) }' \
    || fail "unexpected $axis DPI: $path ($dpi)"
}

check_png() {
  local path="$1"
  local width="$2"
  local height="$3"
  local info
  local dpi_width
  local dpi_height
  local bytes

  [[ -f "$path" ]] \
    || fail "missing documentation image: $path"
  file "$path" | grep -q 'PNG image data' \
    || fail "not a PNG image: $path"

  info="$(sips \
    -g pixelWidth \
    -g pixelHeight \
    -g dpiWidth \
    -g dpiHeight \
    -g profile \
    "$path" 2>/dev/null)"
  grep -Eq \
    "^[[:space:]]*pixelWidth: ${width}$" \
    <<<"$info" \
    || fail "unexpected width: $path"
  grep -Eq \
    "^[[:space:]]*pixelHeight: ${height}$" \
    <<<"$info" \
    || fail "unexpected height: $path"
  grep -Eq \
    '^[[:space:]]*profile: sRGB([[:space:]].*)?$' \
    <<<"$info" \
    || fail "image is not tagged sRGB: $path"

  dpi_width="$(
    awk -F': ' '/dpiWidth:/ { print $2; exit }' <<<"$info"
  )"
  dpi_height="$(
    awk -F': ' '/dpiHeight:/ { print $2; exit }' <<<"$info"
  )"
  [[ -n "$dpi_width" ]] \
    || fail "missing horizontal DPI: $path"
  [[ -n "$dpi_height" ]] \
    || fail "missing vertical DPI: $path"
  check_dpi "$dpi_width" "horizontal" "$path"
  check_dpi "$dpi_height" "vertical" "$path"

  bytes="$(stat -f '%z' "$path")"
  (( bytes <= MAX_FILE_BYTES )) \
    || fail "documentation image exceeds 3 MiB: $path"
}

check_png "$PANEL" 2400 900
check_png "$SETTINGS" 1440 1200

panel_bytes="$(stat -f '%z' "$PANEL")"
settings_bytes="$(stat -f '%z' "$SETTINGS")"
(( panel_bytes + settings_bytes <= MAX_TOTAL_BYTES )) \
  || fail "documentation images exceed 5 MiB combined"

echo "documentation image checks passed"
