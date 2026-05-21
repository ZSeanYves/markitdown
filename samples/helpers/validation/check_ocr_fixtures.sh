#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIXTURE_DIR="$ROOT/samples/fixtures/ocr"
MANIFEST="$FIXTURE_DIR/manifest.tsv"
MAX_FIXTURE_BYTES=$((500 * 1024))

fail() {
  echo "[fail] $1" >&2
  exit 1
}

trim_value() {
  local value="${1-}"
  value="${value#"${value%%[!$' \t\r\n']*}"}"
  value="${value%"${value##*[!$' \t\r\n']}"}"
  printf '%s' "$value"
}

is_blank_value() {
  [[ -z "$(trim_value "${1-}")" ]]
}

field_count_for_line() {
  printf '%s\n' "${1-}" | awk -F '\t' '{ print NF }'
}

file_size_bytes() {
  wc -c < "$1" | tr -d '[:space:]'
}

reject_unsafe_rel_path() {
  local kind="$1"
  local value="$2"
  local line_no="$3"
  local row_id="$4"

  case "$value" in
    /*) fail "manifest line $line_no ($row_id) uses absolute $kind: $value" ;;
  esac

  case "$value" in
    *..*) fail "manifest line $line_no ($row_id) uses unsafe $kind with '..': $value" ;;
  esac
}

[[ -d "$FIXTURE_DIR" ]] || fail "missing OCR fixture dir: $FIXTURE_DIR"
[[ -f "$MANIFEST" ]] || fail "missing OCR fixture manifest: $MANIFEST"

header_expected=$'id\tpath\texpected_text_path\tsource\tlicense\tpurpose\tprovider_required\tnotes'
line_no=0
row_count=0

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line_no=$((line_no + 1))

  if [[ "$line_no" -eq 1 ]]; then
    [[ "$raw_line" == "$header_expected" ]] || fail "unexpected OCR fixture manifest header: $raw_line"
    continue
  fi

  if is_blank_value "$raw_line"; then
    continue
  fi

  field_count="$(field_count_for_line "$raw_line")"
  [[ "$field_count" == "8" ]] || fail "manifest line $line_no must have exactly 8 tab-separated fields (got $field_count)"

  IFS=$'\t' read -r id rel_path expected_path source license purpose provider_required notes <<< "$raw_line"

  id="$(trim_value "$id")"
  rel_path="$(trim_value "$rel_path")"
  expected_path="$(trim_value "$expected_path")"
  source="$(trim_value "$source")"
  license="$(trim_value "$license")"
  purpose="$(trim_value "$purpose")"
  provider_required="$(trim_value "$provider_required")"
  notes="$(trim_value "$notes")"

  is_blank_value "$id" && fail "manifest line $line_no is missing id"
  is_blank_value "$rel_path" && fail "manifest line $line_no ($id) is missing path"
  is_blank_value "$expected_path" && fail "manifest line $line_no ($id) is missing expected_text_path"
  is_blank_value "$source" && fail "manifest line $line_no ($id) is missing source"
  is_blank_value "$license" && fail "manifest line $line_no ($id) is missing license"
  is_blank_value "$purpose" && fail "manifest line $line_no ($id) is missing purpose"
  is_blank_value "$provider_required" && fail "manifest line $line_no ($id) is missing provider_required"
  is_blank_value "$notes" && fail "manifest line $line_no ($id) is missing notes"

  case "$provider_required" in
    true|false) ;;
    *) fail "manifest line $line_no ($id) has invalid provider_required: $provider_required" ;;
  esac

  reject_unsafe_rel_path "path" "$rel_path" "$line_no" "$id"
  reject_unsafe_rel_path "expected_text_path" "$expected_path" "$line_no" "$id"

  fixture_path="$FIXTURE_DIR/$rel_path"
  expected_text_file="$FIXTURE_DIR/$expected_path"

  [[ -f "$fixture_path" ]] || fail "manifest line $line_no ($id) missing fixture file: $fixture_path"
  [[ -f "$expected_text_file" ]] || fail "manifest line $line_no ($id) missing expected text file: $expected_text_file"

  fixture_bytes="$(file_size_bytes "$fixture_path")"
  [[ "$fixture_bytes" =~ ^[0-9]+$ ]] || fail "manifest line $line_no ($id) returned non-numeric fixture size: $fixture_bytes"
  if (( fixture_bytes > MAX_FIXTURE_BYTES )); then
    fail "manifest line $line_no ($id) exceeds fixture size limit (${MAX_FIXTURE_BYTES} bytes): $fixture_bytes bytes at $fixture_path"
  fi

  [[ -s "$expected_text_file" ]] || fail "manifest line $line_no ($id) has empty expected text file: $expected_text_file"

  if [[ "$license" != "project-license" ]]; then
    fail "manifest line $line_no ($id) must record project-license for main-repo OCR fixtures: $license"
  fi

  if [[ "$source" != "self-generated" ]]; then
    fail "manifest line $line_no ($id) must remain self-generated in the main repo for now: $source"
  fi

  row_count=$((row_count + 1))
done < "$MANIFEST"

[[ "$row_count" -gt 0 ]] || fail "OCR fixture manifest has no data rows"

echo "OCR FIXTURE VALIDATION PASSED ($row_count rows; max fixture size ${MAX_FIXTURE_BYTES} bytes)"
