#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LAB_ROOT="$ROOT/markitdown-quality-lab"
OCR_DIR="$LAB_ROOT/ocr_samples"
MANIFEST="$OCR_DIR/manifest.tsv"
SOURCE_CATALOG="$OCR_DIR/source_catalog.tsv"

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

reject_unsafe_rel_path() {
  local kind="$1"
  local value="$2"
  local line_no="$3"
  local row_id="$4"

  case "$value" in
    /*) fail "$kind path on line $line_no ($row_id) must not be absolute: $value" ;;
  esac

  case "$value" in
    *..*) fail "$kind path on line $line_no ($row_id) must not contain '..': $value" ;;
  esac
}

if [[ ! -d "$OCR_DIR" ]]; then
  echo "QUALITY-LAB OCR SCAFFOLD SKIPPED: missing $OCR_DIR"
  exit 0
fi

[[ -f "$MANIFEST" ]] || fail "missing OCR quality-lab manifest: $MANIFEST"
[[ -f "$SOURCE_CATALOG" ]] || fail "missing OCR quality-lab source catalog: $SOURCE_CATALOG"

[[ -d "$OCR_DIR/images" ]] || fail "missing OCR quality-lab images dir: $OCR_DIR/images"
[[ -d "$OCR_DIR/expected_text" ]] || fail "missing OCR quality-lab expected_text dir: $OCR_DIR/expected_text"
[[ -d "$OCR_DIR/expected_markdown" ]] || fail "missing OCR quality-lab expected_markdown dir: $OCR_DIR/expected_markdown"
[[ -d "$OCR_DIR/provider_outputs/tesseract_tsv" ]] || fail "missing OCR quality-lab provider_outputs/tesseract_tsv dir"
[[ -d "$OCR_DIR/provider_outputs/layout_preview" ]] || fail "missing OCR quality-lab provider_outputs/layout_preview dir"

manifest_header=$'id\timage_path\texpected_text_path\texpected_markdown_path\tsource_id\tlanguage\tscript\tdocument_kind\tlayout_kind\tprovider_required\tnotes'
source_header=$'source_id\tsource_url\tlicense\tauthor\tretrieval_date\tredistribution_allowed\tpii_risk\tnotes'

line_no=0
source_row_count=0
source_ids=''

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line_no=$((line_no + 1))
  if [[ "$line_no" -eq 1 ]]; then
    [[ "$raw_line" == "$source_header" ]] || fail "unexpected OCR quality-lab source_catalog header: $raw_line"
    continue
  fi

  if is_blank_value "$raw_line"; then
    continue
  fi

  field_count="$(field_count_for_line "$raw_line")"
  [[ "$field_count" == "8" ]] || fail "source_catalog line $line_no must have exactly 8 tab-separated fields (got $field_count)"

  IFS=$'\t' read -r source_id source_url license author retrieval_date redistribution_allowed pii_risk notes <<< "$raw_line"

  source_id="$(trim_value "$source_id")"
  source_url="$(trim_value "$source_url")"
  license="$(trim_value "$license")"
  author="$(trim_value "$author")"
  retrieval_date="$(trim_value "$retrieval_date")"
  redistribution_allowed="$(trim_value "$redistribution_allowed")"
  pii_risk="$(trim_value "$pii_risk")"
  notes="$(trim_value "$notes")"

  is_blank_value "$source_id" && fail "source_catalog line $line_no is missing source_id"
  is_blank_value "$source_url" && fail "source_catalog line $line_no ($source_id) is missing source_url"
  is_blank_value "$license" && fail "source_catalog line $line_no ($source_id) is missing license"
  is_blank_value "$author" && fail "source_catalog line $line_no ($source_id) is missing author"
  is_blank_value "$retrieval_date" && fail "source_catalog line $line_no ($source_id) is missing retrieval_date"
  is_blank_value "$redistribution_allowed" && fail "source_catalog line $line_no ($source_id) is missing redistribution_allowed"
  is_blank_value "$pii_risk" && fail "source_catalog line $line_no ($source_id) is missing pii_risk"
  is_blank_value "$notes" && fail "source_catalog line $line_no ($source_id) is missing notes"

  case "$redistribution_allowed" in
    true|false) ;;
    *) fail "source_catalog line $line_no ($source_id) has invalid redistribution_allowed: $redistribution_allowed" ;;
  esac

  source_ids+=$'\n'"$source_id"$'\n'
  source_row_count=$((source_row_count + 1))
done < "$SOURCE_CATALOG"

line_no=0
manifest_row_count=0
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line_no=$((line_no + 1))
  if [[ "$line_no" -eq 1 ]]; then
    [[ "$raw_line" == "$manifest_header" ]] || fail "unexpected OCR quality-lab manifest header: $raw_line"
    continue
  fi

  if is_blank_value "$raw_line"; then
    continue
  fi

  field_count="$(field_count_for_line "$raw_line")"
  [[ "$field_count" == "11" ]] || fail "manifest line $line_no must have exactly 11 tab-separated fields (got $field_count)"

  IFS=$'\t' read -r id image_path expected_text_path expected_markdown_path source_id language script document_kind layout_kind provider_required notes <<< "$raw_line"

  id="$(trim_value "$id")"
  image_path="$(trim_value "$image_path")"
  expected_text_path="$(trim_value "$expected_text_path")"
  expected_markdown_path="$(trim_value "$expected_markdown_path")"
  source_id="$(trim_value "$source_id")"
  language="$(trim_value "$language")"
  script="$(trim_value "$script")"
  document_kind="$(trim_value "$document_kind")"
  layout_kind="$(trim_value "$layout_kind")"
  provider_required="$(trim_value "$provider_required")"
  notes="$(trim_value "$notes")"

  is_blank_value "$id" && fail "manifest line $line_no is missing id"
  is_blank_value "$image_path" && fail "manifest line $line_no ($id) is missing image_path"
  is_blank_value "$expected_text_path" && fail "manifest line $line_no ($id) is missing expected_text_path"
  is_blank_value "$expected_markdown_path" && fail "manifest line $line_no ($id) is missing expected_markdown_path"
  is_blank_value "$source_id" && fail "manifest line $line_no ($id) is missing source_id"
  is_blank_value "$language" && fail "manifest line $line_no ($id) is missing language"
  is_blank_value "$script" && fail "manifest line $line_no ($id) is missing script"
  is_blank_value "$document_kind" && fail "manifest line $line_no ($id) is missing document_kind"
  is_blank_value "$layout_kind" && fail "manifest line $line_no ($id) is missing layout_kind"
  is_blank_value "$provider_required" && fail "manifest line $line_no ($id) is missing provider_required"
  is_blank_value "$notes" && fail "manifest line $line_no ($id) is missing notes"

  case "$provider_required" in
    true|false) ;;
    *) fail "manifest line $line_no ($id) has invalid provider_required: $provider_required" ;;
  esac

  reject_unsafe_rel_path "image_path" "$image_path" "$line_no" "$id"
  reject_unsafe_rel_path "expected_text_path" "$expected_text_path" "$line_no" "$id"
  reject_unsafe_rel_path "expected_markdown_path" "$expected_markdown_path" "$line_no" "$id"

  [[ -f "$OCR_DIR/$image_path" ]] || fail "manifest line $line_no ($id) missing image file: $OCR_DIR/$image_path"
  [[ -f "$OCR_DIR/$expected_text_path" ]] || fail "manifest line $line_no ($id) missing expected text file: $OCR_DIR/$expected_text_path"
  [[ -f "$OCR_DIR/$expected_markdown_path" ]] || fail "manifest line $line_no ($id) missing expected markdown file: $OCR_DIR/$expected_markdown_path"

  grep -Fxq "$source_id" <<< "$source_ids" || fail "manifest line $line_no ($id) references unknown source_id: $source_id"

  manifest_row_count=$((manifest_row_count + 1))
done < "$MANIFEST"

echo "QUALITY-LAB OCR SCAFFOLD VALIDATION PASSED (${manifest_row_count} manifest rows; ${source_row_count} source rows)"
