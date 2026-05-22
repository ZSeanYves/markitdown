#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LAB_ROOT="$ROOT/markitdown-quality-lab"
OCR_DIR="$LAB_ROOT/ocr_samples"
MANIFEST="$OCR_DIR/manifest.tsv"
SOURCE_CATALOG="$OCR_DIR/source_catalog.tsv"
IMAGES_DIR="$OCR_DIR/images"
EXPECTED_TEXT_DIR="$OCR_DIR/expected_text"
EXPECTED_MARKDOWN_DIR="$OCR_DIR/expected_markdown"
TSV_DIR="$OCR_DIR/provider_outputs/tesseract_tsv"
PREVIEW_DIR="$OCR_DIR/provider_outputs/layout_preview"
PREVIEW_RESEG_DIR="$OCR_DIR/provider_outputs/layout_preview_resegmented"
IR_HINTS_DIR="$OCR_DIR/provider_outputs/ir_hints"
IR_HINTS_RESEG_DIR="$OCR_DIR/provider_outputs/ir_hints_resegmented"

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

count_tracked_files() {
  local dir="$1"
  local pattern="$2"
  [[ -d "$dir" ]] || fail "missing directory: $dir"
  find "$dir" -maxdepth 1 -type f -name "$pattern" ! -name '.gitkeep' | wc -l | tr -d ' '
}

join_csv_sorted() {
  if [[ $# -eq 0 ]]; then
    printf '(none)\n'
    return 0
  fi
  printf '%s\n' "$@" | LC_ALL=C sort -u | paste -sd',' -
  printf '\n'
}

if [[ ! -d "$OCR_DIR" ]]; then
  echo "QUALITY-LAB OCR SUMMARY SKIPPED: missing $OCR_DIR"
  exit 0
fi

[[ -f "$MANIFEST" ]] || fail "missing manifest: $MANIFEST"
[[ -f "$SOURCE_CATALOG" ]] || fail "missing source catalog: $SOURCE_CATALOG"
[[ -d "$IMAGES_DIR" ]] || fail "missing images dir: $IMAGES_DIR"
[[ -d "$EXPECTED_TEXT_DIR" ]] || fail "missing expected_text dir: $EXPECTED_TEXT_DIR"
[[ -d "$EXPECTED_MARKDOWN_DIR" ]] || fail "missing expected_markdown dir: $EXPECTED_MARKDOWN_DIR"
[[ -d "$TSV_DIR" ]] || fail "missing tesseract_tsv dir: $TSV_DIR"
[[ -d "$PREVIEW_DIR" ]] || fail "missing layout_preview dir: $PREVIEW_DIR"
[[ -d "$PREVIEW_RESEG_DIR" ]] || fail "missing layout_preview_resegmented dir: $PREVIEW_RESEG_DIR"
[[ -d "$IR_HINTS_DIR" ]] || fail "missing ir_hints dir: $IR_HINTS_DIR"
[[ -d "$IR_HINTS_RESEG_DIR" ]] || fail "missing ir_hints_resegmented dir: $IR_HINTS_RESEG_DIR"

manifest_rows=0
line_no=0

default_paragraph=0
default_heading=0
default_listitem=0
default_tablelike=0
default_keyvaluelike=0
default_captionlike=0
default_unknown=0

reseg_paragraph=0
reseg_heading=0
reseg_listitem=0
reseg_tablelike=0
reseg_keyvaluelike=0
reseg_captionlike=0
reseg_unknown=0

default_tablelike_ids=()
default_keyvalue_ids=()
default_caption_ids=()
reseg_tablelike_ids=()
reseg_keyvalue_ids=()
reseg_caption_ids=()

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line_no=$((line_no + 1))
  if [[ "$line_no" -eq 1 ]]; then
    continue
  fi

  [[ -z "$(trim_value "$raw_line")" ]] && continue

  IFS=$'\t' read -r id image_path expected_text_path expected_markdown_path source_id language script document_kind layout_kind provider_required notes <<< "$raw_line"

  id="$(trim_value "$id")"
  image_path="$(trim_value "$image_path")"
  expected_text_path="$(trim_value "$expected_text_path")"
  expected_markdown_path="$(trim_value "$expected_markdown_path")"

  [[ -n "$id" ]] || fail "manifest line $line_no is missing id"

  reject_unsafe_rel_path "image" "$image_path" "$line_no" "$id"
  reject_unsafe_rel_path "expected_text" "$expected_text_path" "$line_no" "$id"
  reject_unsafe_rel_path "expected_markdown" "$expected_markdown_path" "$line_no" "$id"

  image_file="$OCR_DIR/$image_path"
  expected_text_file="$OCR_DIR/$expected_text_path"
  expected_markdown_file="$OCR_DIR/$expected_markdown_path"
  tsv_file="$TSV_DIR/${id}.tsv"
  preview_file="$PREVIEW_DIR/${id}.md"
  preview_reseg_file="$PREVIEW_RESEG_DIR/${id}.md"
  hints_file="$IR_HINTS_DIR/${id}.tsv"
  hints_reseg_file="$IR_HINTS_RESEG_DIR/${id}.tsv"

  [[ -f "$image_file" ]] || fail "manifest line $line_no ($id) missing image: $image_file"
  [[ -f "$expected_text_file" ]] || fail "manifest line $line_no ($id) missing expected_text: $expected_text_file"
  [[ -f "$expected_markdown_file" ]] || fail "manifest line $line_no ($id) missing expected_markdown: $expected_markdown_file"
  [[ -f "$tsv_file" ]] || fail "manifest line $line_no ($id) missing tesseract_tsv: $tsv_file"
  [[ -f "$preview_file" ]] || fail "manifest line $line_no ($id) missing layout_preview: $preview_file"
  [[ -f "$preview_reseg_file" ]] || fail "manifest line $line_no ($id) missing layout_preview_resegmented: $preview_reseg_file"
  [[ -f "$hints_file" ]] || fail "manifest line $line_no ($id) missing ir_hints: $hints_file"
  [[ -f "$hints_reseg_file" ]] || fail "manifest line $line_no ($id) missing ir_hints_resegmented: $hints_reseg_file"

  manifest_rows=$((manifest_rows + 1))

  default_has_tablelike=0
  default_has_keyvalue=0
  default_has_caption=0
  while IFS=$'\t' read -r page_index ir_block_index kind confidence line_start line_end text reasons; do
    [[ "$page_index" == "page_index" ]] && continue
    [[ -z "${kind:-}" ]] && continue
    case "$kind" in
      Paragraph) default_paragraph=$((default_paragraph + 1)) ;;
      Heading) default_heading=$((default_heading + 1)) ;;
      ListItem) default_listitem=$((default_listitem + 1)) ;;
      TableLike) default_tablelike=$((default_tablelike + 1)); default_has_tablelike=1 ;;
      KeyValueLike) default_keyvaluelike=$((default_keyvaluelike + 1)); default_has_keyvalue=1 ;;
      CaptionLike) default_captionlike=$((default_captionlike + 1)); default_has_caption=1 ;;
      Unknown) default_unknown=$((default_unknown + 1)) ;;
      *) fail "unexpected hint kind in $hints_file: $kind" ;;
    esac
  done < "$hints_file"
  (( default_has_tablelike )) && default_tablelike_ids+=("$id")
  (( default_has_keyvalue )) && default_keyvalue_ids+=("$id")
  (( default_has_caption )) && default_caption_ids+=("$id")

  reseg_has_tablelike=0
  reseg_has_keyvalue=0
  reseg_has_caption=0
  while IFS=$'\t' read -r page_index ir_block_index kind confidence line_start line_end text reasons; do
    [[ "$page_index" == "page_index" ]] && continue
    [[ -z "${kind:-}" ]] && continue
    case "$kind" in
      Paragraph) reseg_paragraph=$((reseg_paragraph + 1)) ;;
      Heading) reseg_heading=$((reseg_heading + 1)) ;;
      ListItem) reseg_listitem=$((reseg_listitem + 1)) ;;
      TableLike) reseg_tablelike=$((reseg_tablelike + 1)); reseg_has_tablelike=1 ;;
      KeyValueLike) reseg_keyvaluelike=$((reseg_keyvaluelike + 1)); reseg_has_keyvalue=1 ;;
      CaptionLike) reseg_captionlike=$((reseg_captionlike + 1)); reseg_has_caption=1 ;;
      Unknown) reseg_unknown=$((reseg_unknown + 1)) ;;
      *) fail "unexpected hint kind in $hints_reseg_file: $kind" ;;
    esac
  done < "$hints_reseg_file"
  (( reseg_has_tablelike )) && reseg_tablelike_ids+=("$id")
  (( reseg_has_keyvalue )) && reseg_keyvalue_ids+=("$id")
  (( reseg_has_caption )) && reseg_caption_ids+=("$id")
done < "$MANIFEST"

source_rows=$(( $(wc -l < "$SOURCE_CATALOG") - 1 ))
if (( source_rows < 0 )); then
  source_rows=0
fi

images_count="$(count_tracked_files "$IMAGES_DIR" '*.png')"
expected_text_count="$(count_tracked_files "$EXPECTED_TEXT_DIR" '*.txt')"
expected_markdown_count="$(count_tracked_files "$EXPECTED_MARKDOWN_DIR" '*.md')"
tesseract_tsv_count="$(count_tracked_files "$TSV_DIR" '*.tsv')"
layout_preview_count="$(count_tracked_files "$PREVIEW_DIR" '*.md')"
layout_preview_resegmented_count="$(count_tracked_files "$PREVIEW_RESEG_DIR" '*.md')"
ir_hints_count="$(count_tracked_files "$IR_HINTS_DIR" '*.tsv')"
ir_hints_resegmented_count="$(count_tracked_files "$IR_HINTS_RESEG_DIR" '*.tsv')"

echo "QUALITY-LAB OCR SUMMARY"
echo "manifest_rows=$manifest_rows"
echo "source_rows=$source_rows"
echo "images_count=$images_count"
echo "expected_text_count=$expected_text_count"
echo "expected_markdown_count=$expected_markdown_count"
echo "tesseract_tsv_count=$tesseract_tsv_count"
echo "layout_preview_count=$layout_preview_count"
echo "layout_preview_resegmented_count=$layout_preview_resegmented_count"
echo "ir_hints_count=$ir_hints_count"
echo "ir_hints_resegmented_count=$ir_hints_resegmented_count"
echo "default_hint_rows.Paragraph=$default_paragraph"
echo "default_hint_rows.Heading=$default_heading"
echo "default_hint_rows.ListItem=$default_listitem"
echo "default_hint_rows.TableLike=$default_tablelike"
echo "default_hint_rows.KeyValueLike=$default_keyvaluelike"
echo "default_hint_rows.CaptionLike=$default_captionlike"
echo "default_hint_rows.Unknown=$default_unknown"
echo "resegmented_hint_rows.Paragraph=$reseg_paragraph"
echo "resegmented_hint_rows.Heading=$reseg_heading"
echo "resegmented_hint_rows.ListItem=$reseg_listitem"
echo "resegmented_hint_rows.TableLike=$reseg_tablelike"
echo "resegmented_hint_rows.KeyValueLike=$reseg_keyvaluelike"
echo "resegmented_hint_rows.CaptionLike=$reseg_captionlike"
echo "resegmented_hint_rows.Unknown=$reseg_unknown"
printf 'default_semantic_ids.TableLike='
join_csv_sorted "${default_tablelike_ids[@]:-}"
printf 'default_semantic_ids.KeyValueLike='
join_csv_sorted "${default_keyvalue_ids[@]:-}"
printf 'default_semantic_ids.CaptionLike='
join_csv_sorted "${default_caption_ids[@]:-}"
printf 'resegmented_semantic_ids.TableLike='
join_csv_sorted "${reseg_tablelike_ids[@]:-}"
printf 'resegmented_semantic_ids.KeyValueLike='
join_csv_sorted "${reseg_keyvalue_ids[@]:-}"
printf 'resegmented_semantic_ids.CaptionLike='
join_csv_sorted "${reseg_caption_ids[@]:-}"
