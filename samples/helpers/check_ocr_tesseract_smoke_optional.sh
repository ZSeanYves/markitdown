#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "ocr_tesseract_smoke")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_cli
if [[ "$CLI_RUNNER_KIND" == "prebuilt-native" ]]; then
  probe_out="$OUT_DIR/ocr_runner_probe.txt"
  "$CLI_BIN" ocr --provider tesseract-cli --lang eng "$ROOT/samples/main_process/txt/txt_plain.txt" >"$probe_out" 2>&1 || true
  if grep -Fq 'usage: ocr [--with-metadata] <input> [output]' "$probe_out"; then
    CLI_RUNNER_KIND="moon-run"
    CLI_RUNNER_NOTE="prebuilt native OCR CLI probe failed; using moon run for OCR smoke"
    CLI_BIN=""
  fi
fi
echo "runner: $CLI_RUNNER_KIND"
echo "runner_class: $(runner_class_for_kind "$CLI_RUNNER_KIND")"
echo "runner_command: $(markitdown_runner_command_prefix)"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

if ! command -v tesseract >/dev/null 2>&1; then
  echo "OCR TESSERACT SMOKE SKIPPED: tesseract not installed"
  exit 0
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "OCR TESSERACT SMOKE SKIPPED: sips not installed"
  exit 0
fi

fail() {
  echo "[fail] $1" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file missing: $path"
}

BMP_INPUT="$OUT_DIR/ocr_smoke.bmp"
PPM_INPUT="$OUT_DIR/ocr_smoke.ppm"
TXT_OUTPUT="$OUT_DIR/ocr_smoke.txt"

generate_tiny_ocr_ppm() {
  local out="$1"
  local scale=24
  local rows=(
    '01110 11110 11110'
    '10001 10001 10001'
    '10000 10001 10001'
    '10000 11110 11110'
    '10000 10100 10100'
    '10001 10010 10010'
    '01110 10001 10001'
  )
  local height=$(( ${#rows[@]} * scale + 40 ))
  local width=$(( 17 * scale + 40 ))

  {
    echo P3
    echo "$width $height"
    echo 255
    for ((y=0; y<height; y++)); do
      local glyph_y=$(( (y - 20) / scale ))
      for ((x=0; x<width; x++)); do
        local bit=0
        if (( y >= 20 && y < 20 + 7*scale && x >= 20 && x < 20 + 17*scale )); then
          local glyph_x=$(( (x - 20) / scale ))
          local row="${rows[$glyph_y]}"
          local ch="${row:$glyph_x:1}"
          if [[ "$ch" == "1" ]]; then
            bit=1
          fi
        fi
        if (( bit == 1 )); then
          printf '0 0 0 '
        else
          printf '255 255 255 '
        fi
      done
      printf '\n'
    done
  } > "$out"
}

generate_tiny_ocr_ppm "$PPM_INPUT"
sips -s format bmp "$PPM_INPUT" --out "$BMP_INPUT" >/dev/null

echo "==> optional explicit ocr smoke"
run_markitdown_cli ocr --provider tesseract-cli "$BMP_INPUT" "$TXT_OUTPUT"
assert_file_exists "$TXT_OUTPUT"

if [[ ! -s "$TXT_OUTPUT" ]]; then
  fail "expected OCR smoke output to be non-empty"
fi

echo "OCR TESSERACT SMOKE PASSED"
