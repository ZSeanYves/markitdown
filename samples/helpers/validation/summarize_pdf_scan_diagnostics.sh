#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

fail() {
  echo "[fail] $1" >&2
  exit 1
}

resolve_debug_cli() {
  if [[ -n "${MARKITDOWN_DEBUG:-}" ]]; then
    if [[ ! -x "${MARKITDOWN_DEBUG}" ]]; then
      fail "MARKITDOWN_DEBUG is set but not executable: ${MARKITDOWN_DEBUG}"
    fi
    DEBUG_RUNNER_KIND="override"
    DEBUG_BIN="${MARKITDOWN_DEBUG}"
    return 0
  fi

  local candidate
  for candidate in \
    "$ROOT/_build/native/debug/build/debug/debug.exe" \
    "$ROOT/_build/native/release/build/debug/debug.exe"
  do
    if [[ -x "$candidate" ]]; then
      DEBUG_RUNNER_KIND="prebuilt-native"
      DEBUG_BIN="$candidate"
      return 0
    fi
  done

  echo "failed to locate a prebuilt debug runner." >&2
  echo "Run: moon build debug --target native" >&2
  echo "Or set MARKITDOWN_DEBUG=/path/to/debug.exe" >&2
  exit 1
}

extract_backend_field() {
  local path="$1"
  local key="$2"
  python3 - "$path" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

backend = None
for section in data.get("sections", []):
    if section.get("name") == "pdf_backend":
        backend = section.get("data", {})
        break

if backend is None:
    raise SystemExit("missing pdf_backend section")

value = backend.get(key)
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
PY
}

derive_reasons() {
  local native_text_char_count="$1"
  local page_image_count="$2"
  local text_signal_level="$3"
  local ocr_recommended="$4"

  local reasons=()
  if [[ "$text_signal_level" == "normal" ]]; then
    reasons+=("normal_text_signal")
  fi
  if [[ "$native_text_char_count" == "0" ]]; then
    reasons+=("empty_extracted_text")
  elif [[ "$text_signal_level" == "low" ]]; then
    reasons+=("low_text_signal")
  fi
  if [[ "$page_image_count" != "0" ]]; then
    reasons+=("page_images_present")
  fi
  if [[ "$ocr_recommended" == "true" ]]; then
    reasons+=("ocr_recommended_report_only")
  fi

  if [[ "${#reasons[@]}" -eq 0 ]]; then
    reasons+=("no_special_signal")
  fi

  local joined=""
  local item
  for item in "${reasons[@]}"; do
    if [[ -n "$joined" ]]; then
      joined="${joined};${item}"
    else
      joined="${item}"
    fi
  done
  printf '%s\n' "$joined"
}

emit_row() {
  local case_id="$1"
  local input_path="$2"
  local json_path="$3"

  local page_count native_text_char_count page_image_count has_embedded_text
  local has_page_images image_only text_signal_level ocr_recommended ocr_mode
  local ocr_used reasons

  page_count="$(extract_backend_field "$json_path" "page_count")"
  native_text_char_count="$(extract_backend_field "$json_path" "native_text_char_count")"
  page_image_count="$(extract_backend_field "$json_path" "page_image_count")"
  has_embedded_text="$(extract_backend_field "$json_path" "has_embedded_text")"
  has_page_images="$(extract_backend_field "$json_path" "has_page_images")"
  image_only="$(extract_backend_field "$json_path" "image_only")"
  text_signal_level="$(extract_backend_field "$json_path" "text_signal_level")"
  ocr_recommended="$(extract_backend_field "$json_path" "ocr_recommended")"
  ocr_mode="$(extract_backend_field "$json_path" "ocr_mode")"
  ocr_used="$(extract_backend_field "$json_path" "ocr_used")"
  reasons="$(derive_reasons "$native_text_char_count" "$page_image_count" "$text_signal_level" "$ocr_recommended")"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$case_id" \
    "$input_path" \
    "$page_count" \
    "$native_text_char_count" \
    "$page_image_count" \
    "$has_embedded_text" \
    "$has_page_images" \
    "$image_only" \
    "$text_signal_level" \
    "$ocr_recommended" \
    "$ocr_mode" \
    "$ocr_used" \
    "$reasons"
}

resolve_debug_cli

declare -a CASES=(
  "text_simple|$ROOT/samples/main_process/pdf/text_simple.pdf"
  "image_xobject|$ROOT/samples/main_process/pdf/assets/pdf_image_xobject.pdf"
)

TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
mkdir -p "$TMP_ROOT/helpers"
WORK_DIR="$(mktemp -d "$TMP_ROOT/helpers/pdf_scan_summary.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

printf 'case\tinput\tpage_count\tnative_text_char_count\tpage_image_count\thas_embedded_text\thas_page_images\timage_only\ttext_signal_level\tocr_recommended\tocr_mode\tocr_used\treasons\n'

entry=""
for entry in "${CASES[@]}"; do
  case_id="${entry%%|*}"
  input_path="${entry#*|}"
  [[ -f "$input_path" ]] || fail "missing sample input: $input_path"
  json_path="$WORK_DIR/${case_id}.json"
  "$DEBUG_BIN" --json "$input_path" > "$json_path"
  emit_row "$case_id" "$input_path" "$json_path"
done
