#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_FILE_BYTES=$((3 * 1024 * 1024))
MAX_TOTAL_BYTES=$((5 * 1024 * 1024))
ASSETS=(
  "panel-preview.png"
  "quota-states-loud.png"
  "refresh-states-loud.png"
  "appearance-panel-settings-loud.png"
  "appearance-status-settings-loud.png"
)
WIDTHS=(2400 1840 1840 1440 1440)
HEIGHTS=(900 720 1350 2400 2400)
PATHS=()
check_repository_contract=0

usage() {
  echo \
    "usage: $0 [image-directory | panel quota refresh panel-settings status-settings]" \
    >&2
}

case $# in
  0)
    check_repository_contract=1
    for asset in "${ASSETS[@]}"; do
      PATHS[${#PATHS[@]}]="$ROOT_DIR/docs/images/$asset"
    done
    ;;
  1)
    for asset in "${ASSETS[@]}"; do
      PATHS[${#PATHS[@]}]="$1/$asset"
    done
    ;;
  5)
    PATHS=("$1" "$2" "$3" "$4" "$5")
    ;;
  *)
    usage
    exit 2
    ;;
esac

fail() {
  echo "$1" >&2
  exit 1
}

count_literal_occurrences() {
  local needle="$1"
  local path="$2"

  awk -v needle="$needle" '
    BEGIN { count = 0 }
    {
      line = $0
      while ((position = index(line, needle)) > 0) {
        count += 1
        line = substr(line, position + length(needle))
      }
    }
    END { print count }
  ' "$path"
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

check_readme_contract() {
  local readme="$1"
  local language_navigation="$2"
  local navigation_count
  local reference
  local reference_count
  shift 2

  [[ -f "$readme" ]] \
    || fail "missing README: $readme"

  navigation_count="$(
    count_literal_occurrences "$language_navigation" "$readme"
  )"
  [[ "$navigation_count" == "1" ]] \
    || fail \
      "README must contain exactly one language navigation: $readme"

  for reference in "$@"; do
    reference_count="$(
      count_literal_occurrences "$reference" "$readme"
    )"
    [[ "$reference_count" == "1" ]] \
      || fail \
        "README must contain exactly one image reference: $reference"
  done

  if grep -Eq \
    '(appearance-settings-loud\.png|(quota-states|refresh-states)\.svg)' \
    "$readme"; then
    fail "README still references an obsolete documentation image: $readme"
  fi
}

total_bytes=0
for ((index = 0; index < ${#PATHS[@]}; index += 1)); do
  check_png \
    "${PATHS[$index]}" \
    "${WIDTHS[$index]}" \
    "${HEIGHTS[$index]}"
  bytes="$(stat -f '%z' "${PATHS[$index]}")"
  total_bytes=$((total_bytes + bytes))
done

(( total_bytes <= MAX_TOTAL_BYTES )) \
  || fail "documentation images exceed 5 MiB combined"

if (( check_repository_contract )); then
  required_chinese_references=(
    '<img src="docs/images/panel-preview.png" alt="LOUD、BOLD、FROST 三套主题的状态栏与额度面板预览" width="860">'
    '<img src="docs/images/quota-states-loud.png" alt="LOUD 主题下正常、警告和危险额度状态的生产状态栏" width="860">'
    '<img src="docs/images/refresh-states-loud.png" alt="LOUD 主题下双窗口与单窗口的实时、确认中和确认失败状态" width="860">'
    '<img src="docs/images/appearance-panel-settings-loud.png" alt="LOUD 主题面板设置中的颜色、文字、几何和阴影区域" width="720">'
    '<img src="docs/images/appearance-status-settings-loud.png" alt="LOUD 主题状态栏设置中的文字、阴影、几何和状态颜色区域" width="720">'
  )
  required_english_references=(
    '<img src="docs/images/panel-preview.png" alt="LOUD, BOLD, and FROST status items and quota panels" width="860">'
    '<img src="docs/images/quota-states-loud.png" alt="Production status items for normal, warning, and danger quota states in LOUD" width="860">'
    '<img src="docs/images/refresh-states-loud.png" alt="Live, confirming, and confirmed-failure states for dual- and single-window layouts in LOUD" width="860">'
    '<img src="docs/images/appearance-panel-settings-loud.png" alt="Color, text, geometry, and shadow sections of the LOUD panel editor" width="720">'
    '<img src="docs/images/appearance-status-settings-loud.png" alt="Text, shadow, geometry, and state-color sections of the LOUD status-item editor" width="720">'
  )

  check_readme_contract \
    "$ROOT_DIR/README.md" \
    '**简体中文** | [English](README.en.md)' \
    "${required_chinese_references[@]}"
  check_readme_contract \
    "$ROOT_DIR/README.en.md" \
    '[简体中文](README.md) | **English**' \
    "${required_english_references[@]}"

  for asset in \
    "$ROOT_DIR/docs/images/appearance-settings-loud.png" \
    "$ROOT_DIR/docs/images/quota-states.svg" \
    "$ROOT_DIR/docs/images/refresh-states.svg"; do
    [[ ! -e "$asset" ]] \
      || fail "obsolete documentation image is still present: $asset"
  done
fi

echo "documentation image checks passed"
