#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_FILE_BYTES=$((3 * 1024 * 1024))
MAX_TOTAL_BYTES=$((5 * 1024 * 1024))
ASSETS=(
  "panel-preview.png"
  "quota-states-loud.png"
  "refresh-states-loud.png"
  "appearance-settings-loud.png"
)
WIDTHS=(2400 1840 1840 1440)
HEIGHTS=(900 720 1350 2400)
PATHS=()
check_repository_contract=0

usage() {
  echo \
    "usage: $0 [image-directory | panel quota refresh settings]" \
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
  4)
    PATHS=("$1" "$2" "$3" "$4")
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
  README="$ROOT_DIR/README.md"
  required_references=(
    '<img src="docs/images/panel-preview.png" alt="LOUD、BOLD、FROST 三套主题的状态栏显示层与额度面板预览" width="860">'
    '<img src="docs/images/quota-states-loud.png" alt="LOUD 主题下正常、警告和危险额度状态的生产菜单栏显示层" width="860">'
    '<img src="docs/images/refresh-states-loud.png" alt="LOUD 主题下双窗口与仅周额度布局的实时、确认中和已确认刷新状态" width="860">'
    '<img src="docs/images/appearance-settings-loud.png" alt="LOUD 主题的基础色板、面板参数、状态栏显示层和高级状态颜色设置" width="720">'
  )

  [[ -f "$README" ]] \
    || fail "missing README: $README"

  for reference in "${required_references[@]}"; do
    grep -Fq "$reference" "$README" \
      || fail "README is missing image reference: $reference"
  done

  if grep -Eq \
    '(quota-states|refresh-states)\.svg' \
    "$README"; then
    fail "README still references an obsolete documentation SVG"
  fi

  for asset in \
    "$ROOT_DIR/docs/images/quota-states.svg" \
    "$ROOT_DIR/docs/images/refresh-states.svg"; do
    [[ ! -e "$asset" ]] \
      || fail "obsolete documentation image is still present: $asset"
  done
fi

echo "documentation image checks passed"
