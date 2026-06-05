#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
LAB_ROOT="$ROOT/markitdown-quality-lab"
OCR_DIR="$LAB_ROOT/external_quality/ocr/_legacy_samples"
MANIFEST="$OCR_DIR/manifest.tsv"
TSV_DIR="$OCR_DIR/provider_outputs/tesseract_tsv"
PREVIEW_DIR="$OCR_DIR/provider_outputs/layout_preview_resegmented"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}/quality/ocr_helpers"
TMP_DIR=""
TSV_PREVIEW_TOOL="${TSV_PREVIEW_TOOL:-}"

pass_count=0
fail_count=0
row_count=0

fail() {
  echo "[fail] $1" >&2
  exit 1
}

cleanup() {
  sample_cleanup_tmp_dir "$TMP_DIR"
}

trap cleanup EXIT

trim_value() {
  local value="${1-}"
  value="${value#"${value%%[!$' \t\r\n']*}"}"
  value="${value%"${value##*[!$' \t\r\n']}"}"
  printf '%s' "$value"
}

normalize_file() {
  python3 - "$1" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = text.replace('\r\n', '\n').replace('\r', '\n')
lines = [line.rstrip(' \t') for line in text.split('\n')]
while lines and lines[-1] == '':
    lines.pop()
if not lines:
    sys.stdout.write('')
else:
    sys.stdout.write('\n'.join(lines) + '\n')
PY
}

print_diff() {
  python3 - "$1" "$2" <<'PY'
from pathlib import Path
import difflib
import sys

def normalize(path: Path) -> str:
    text = path.read_text(encoding='utf-8')
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    lines = [line.rstrip(' \t') for line in text.split('\n')]
    while lines and lines[-1] == '':
        lines.pop()
    if not lines:
        return ''
    return '\n'.join(lines) + '\n'

expected = normalize(Path(sys.argv[1])).splitlines()
actual = normalize(Path(sys.argv[2])).splitlines()
for line in list(difflib.unified_diff(expected, actual, fromfile='expected', tofile='actual', n=2))[:20]:
    print(line)
PY
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

resolve_tsv_preview_tool() {
  if [[ -n "$TSV_PREVIEW_TOOL" ]]; then
    [[ -x "$TSV_PREVIEW_TOOL" ]] || fail "TSV_PREVIEW_TOOL is not executable: $TSV_PREVIEW_TOOL"
    printf '%s\n' "$TSV_PREVIEW_TOOL"
    return 0
  fi

  local candidate
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done <<EOF
$ROOT/_build/native/debug/build/convert/vision/tsv_preview_tool/tsv_preview_tool.exe
$ROOT/_build/native/release/build/convert/vision/tsv_preview_tool/tsv_preview_tool.exe
EOF

  fail $'tsv_preview_tool native executable not found\nRun: moon build convert/vision/tsv_preview_tool --target native\nOr set TSV_PREVIEW_TOOL=/path/to/tsv_preview_tool.exe'
}

if [[ ! -f "$MANIFEST" ]]; then
  echo "QUALITY-LAB OCR RESEGMENTED PREVIEW CHECK SKIPPED: missing $MANIFEST"
  exit 0
fi

if [[ ! -d "$TSV_DIR" ]]; then
  echo "QUALITY-LAB OCR RESEGMENTED PREVIEW CHECK SKIPPED: missing $TSV_DIR"
  exit 0
fi

if [[ ! -d "$PREVIEW_DIR" ]]; then
  echo "QUALITY-LAB OCR RESEGMENTED PREVIEW CHECK SKIPPED: missing $PREVIEW_DIR"
  exit 0
fi

TOOL_BIN="$(resolve_tsv_preview_tool)"
TMP_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "quality_lab_ocr_resegmented_preview")"

line_no=0
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line_no=$((line_no + 1))
  if [[ "$line_no" -eq 1 ]]; then
    continue
  fi

  [[ -z "$(trim_value "$raw_line")" ]] && continue

  IFS=$'\t' read -r id image_path expected_text_path expected_markdown_path source_id language script document_kind layout_kind provider_required notes <<< "$raw_line"

  id="$(trim_value "$id")"
  row_count=$((row_count + 1))

  [[ -n "$id" ]] || fail "manifest line $line_no is missing id"

  reject_unsafe_rel_path "tsv artifact" "provider_outputs/tesseract_tsv/${id}.tsv" "$line_no" "$id"
  reject_unsafe_rel_path "resegmented preview artifact" "provider_outputs/layout_preview_resegmented/${id}.md" "$line_no" "$id"

  tsv_file="$TSV_DIR/${id}.tsv"
  expected_file="$PREVIEW_DIR/${id}.md"
  actual_file="$TMP_DIR/${id}.md"

  [[ -f "$tsv_file" ]] || fail "manifest line $line_no ($id) missing TSV artifact: $tsv_file"
  [[ -f "$expected_file" ]] || fail "manifest line $line_no ($id) missing resegmented preview artifact: $expected_file"

  "$TOOL_BIN" \
    --tsv "$tsv_file" \
    --resegment-lines \
    --output "$actual_file"

  expected_norm="$(normalize_file "$expected_file")"
  actual_norm="$(normalize_file "$actual_file")"

  if [[ "$expected_norm" == "$actual_norm" ]]; then
    echo "[ok] $id"
    pass_count=$((pass_count + 1))
  else
    echo "[mismatch] $id"
    echo "  expected=$expected_file"
    echo "  actual=$actual_file"
    print_diff "$expected_file" "$actual_file"
    fail_count=$((fail_count + 1))
  fi
done < "$MANIFEST"

if (( fail_count > 0 )); then
  echo "QUALITY-LAB OCR RESEGMENTED PREVIEW CHECK FAILED ($row_count rows; $pass_count passed; $fail_count failed)"
  exit 1
fi

echo "QUALITY-LAB OCR RESEGMENTED PREVIEW CHECK PASSED ($row_count rows; $pass_count passed; $fail_count failed)"
