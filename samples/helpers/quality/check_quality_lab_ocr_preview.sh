#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LAB_ROOT="$ROOT/markitdown-quality-lab"
OCR_DIR="$LAB_ROOT/ocr_samples"
MANIFEST="$OCR_DIR/manifest.tsv"
PREVIEW_DIR="$OCR_DIR/provider_outputs/layout_preview"

pass_count=0
fail_count=0
row_count=0

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

if [[ ! -f "$MANIFEST" ]]; then
  echo "QUALITY-LAB OCR PREVIEW CHECK SKIPPED: missing $MANIFEST"
  exit 0
fi

if [[ ! -d "$PREVIEW_DIR" ]]; then
  echo "QUALITY-LAB OCR PREVIEW CHECK SKIPPED: missing $PREVIEW_DIR"
  exit 0
fi

line_no=0
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line_no=$((line_no + 1))
  if [[ "$line_no" -eq 1 ]]; then
    continue
  fi

  [[ -z "$(trim_value "$raw_line")" ]] && continue

  IFS=$'\t' read -r id image_path expected_text_path expected_markdown_path source_id language script document_kind layout_kind provider_required notes <<< "$raw_line"

  id="$(trim_value "$id")"
  expected_markdown_path="$(trim_value "$expected_markdown_path")"
  row_count=$((row_count + 1))

  [[ -n "$id" ]] || fail "manifest line $line_no is missing id"
  [[ -n "$expected_markdown_path" ]] || fail "manifest line $line_no ($id) is missing expected_markdown_path"

  reject_unsafe_rel_path "expected_markdown_path" "$expected_markdown_path" "$line_no" "$id"

  expected_file="$OCR_DIR/$expected_markdown_path"
  actual_file="$PREVIEW_DIR/${id}.md"

  [[ -f "$expected_file" ]] || fail "manifest line $line_no ($id) missing expected markdown: $expected_file"
  [[ -f "$actual_file" ]] || fail "manifest line $line_no ($id) missing preview markdown: $actual_file"

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
  echo "QUALITY-LAB OCR PREVIEW CHECK FAILED ($row_count rows; $pass_count passed; $fail_count failed)"
  exit 1
fi

echo "QUALITY-LAB OCR PREVIEW CHECK PASSED ($row_count rows; $pass_count passed; $fail_count failed)"
