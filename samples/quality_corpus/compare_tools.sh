#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_ROOT="$TMP_ROOT/quality_corpus"
OUT_PATH="$OUT_ROOT/comparison.tsv"
MANIFEST_PATH="$ROOT/samples/quality_corpus/manifest.tsv"
EXTERNAL_MANIFEST_PATH="$ROOT/samples/quality_corpus/external_manifest.local.tsv"

mkdir -p "$OUT_ROOT"

tool_available() {
  case "$1" in
    markitdown)
      command -v markitdown >/dev/null 2>&1
      ;;
    pandoc)
      command -v pandoc >/dev/null 2>&1
      ;;
    unstructured)
      python3 -m unstructured --help >/dev/null 2>&1
      ;;
    paddleocr)
      command -v paddleocr >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

tool_status() {
  if tool_available "$1"; then
    printf 'available'
  else
    printf 'skipped'
  fi
}

trim_cr() {
  local value="${1-}"
  value="${value%$'\r'}"
  printf '%s' "$value"
}

has_public_rows() {
  local count=0
  if [[ -f "$MANIFEST_PATH" ]]; then
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
      raw_line="$(trim_cr "$raw_line")"
      [[ "$count" -eq 0 ]] && { count=1; continue; }
      [[ -z "$raw_line" ]] && continue
      [[ "${raw_line#\#}" != "$raw_line" ]] && continue
      printf '1'
      return
    done < "$MANIFEST_PATH"
  fi
  printf '0'
}

count_approved_existing_external_rows() {
  local count=0
  if [[ -f "$EXTERNAL_MANIFEST_PATH" ]]; then
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
      raw_line="$(trim_cr "$raw_line")"
      count=$((count + 1))
      [[ "$count" -eq 1 ]] && continue
      [[ -z "$raw_line" ]] && continue
      [[ "${raw_line#\#}" != "$raw_line" ]] && continue
      IFS=$'\t' read -r _ _ path _ _ _ license_review_status _ _ _ _ _ _ _ _ <<< "$raw_line"
      [[ "$license_review_status" == "approved" ]] || continue
      local abs_path="$path"
      if [[ "$abs_path" != /* ]]; then
        abs_path="$ROOT/$abs_path"
      fi
      [[ -f "$abs_path" ]] || continue
      printf '1'
      return
    done < "$EXTERNAL_MANIFEST_PATH"
  fi
  printf '0'
}

public_rows="$(has_public_rows)"
approved_external_rows="$(count_approved_existing_external_rows)"

{
  printf 'tool\tstatus\tnotes\n'
  if [[ "$public_rows" == "0" && "$approved_external_rows" == "0" ]]; then
    printf 'manifest\t%s\tno public rows and no approved existing external rows; reference-only probe skipped\n' "skipped"
  fi
  printf 'markitdown\t%s\toptional reference CLI, not an oracle\n' "$(tool_status markitdown)"
  printf 'pandoc\t%s\toptional reference CLI, not an oracle\n' "$(tool_status pandoc)"
  printf 'unstructured\t%s\toptional python module reference, not an oracle\n' "$(tool_status unstructured)"
  printf 'paddleocr\t%s\toptional OCR/tool probe, not an oracle\n' "$(tool_status paddleocr)"
} > "$OUT_PATH"

echo "wrote comparison availability summary to $OUT_PATH"
