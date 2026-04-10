#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="$ROOT/samples/pdf_core"
OUT_ROOT="${1:-$ROOT/.tmp_pdf_native_out}"
RUN_DIR="$OUT_ROOT/run"
LOG_DIR="$OUT_ROOT/log"
EXP_DIR="$FIXTURE_DIR"

mkdir -p "$RUN_DIR" "$LOG_DIR"

if ! command -v moon >/dev/null 2>&1; then
  echo "[env] moon command not found; cannot run native acceptance."
  exit 2
fi

# 第一批 native acceptance: phase-5 真实简单样例
CASES=(
  "pdf_native_real_en_single_page"
  "pdf_native_real_zh_single_page"
  "pdf_native_real_text_multipage"
  "pdf_native_real_tounicode_basic"
  "pdf_native_real_header_footer_simple"
)

# 允许 unsupported 的样例（当前批次默认空，全部必须通过）
ALLOW_UNSUPPORTED=()

is_allowed_unsupported() {
  local name="$1"
  for x in "${ALLOW_UNSUPPORTED[@]}"; do
    if [[ "$x" == "$name" ]]; then
      return 0
    fi
  done
  return 1
}

passed=0
unsupported=0
tolerated_unsupported=0
parser_error=0
decode_error=0
unexpected_crash=0
failed=0

printf '==> pdf-native acceptance check\n'
printf '    fixture dir: %s\n' "$FIXTURE_DIR"
printf '    output dir : %s\n\n' "$OUT_ROOT"

for name in "${CASES[@]}"; do
  pdf="$FIXTURE_DIR/$name.pdf"
  exp="$EXP_DIR/$name.expected.md"
  out="$RUN_DIR/$name.md"
  log="$LOG_DIR/$name.log"

  if [[ ! -f "$pdf" || ! -f "$exp" ]]; then
    echo "[FAIL] $name missing fixture or expected file"
    failed=$((failed + 1))
    continue
  fi

  echo "==> running $name"
  if moon run "$ROOT/src/cli" -- convert "$pdf" -o "$out" --pdf-backend pdf-native --pdf-extract-debug true >"$log" 2>&1; then
    if ! grep -q "selected backend=pdf-native" "$log"; then
      echo "  [FAIL] backend trace missing (expected forced native marker)"
      failed=$((failed + 1))
      continue
    fi

    if diff -u "$exp" "$out" >"$LOG_DIR/$name.diff"; then
      echo "  [PASS] output matched expected"
      passed=$((passed + 1))
      rm -f "$LOG_DIR/$name.diff"
    else
      echo "  [FAIL] output mismatch (silent wrong output risk)"
      echo "         see: $LOG_DIR/$name.diff"
      failed=$((failed + 1))
    fi
  else
    if grep -Eqi "pdf native unsupported|pdf-native unsupported" "$log"; then
      unsupported=$((unsupported + 1))
      if is_allowed_unsupported "$name"; then
        echo "  [UNSUPPORTED-ALLOWED] $name"
        tolerated_unsupported=$((tolerated_unsupported + 1))
      else
        echo "  [FAIL] unsupported not allowed for required case"
        failed=$((failed + 1))
      fi
    elif grep -Eqi "pdf-native parser_error|invalid pdf|invalid structure|unexpected eof|type mismatch|object not found" "$log"; then
      parser_error=$((parser_error + 1))
      echo "  [FAIL] parser_error"
      failed=$((failed + 1))
    elif grep -Eqi "pdf-native decode_error|decode failed|tounicode|cmap decode" "$log"; then
      decode_error=$((decode_error + 1))
      echo "  [FAIL] decode_error"
      failed=$((failed + 1))
    elif grep -Eqi "pdf-native unexpected_crash|pdf native extraction failed|panic|stack trace" "$log"; then
      unexpected_crash=$((unexpected_crash + 1))
      echo "  [FAIL] unexpected_crash"
      failed=$((failed + 1))
    else
      unexpected_crash=$((unexpected_crash + 1))
      echo "  [FAIL] unexpected_crash (unclassified)"
      failed=$((failed + 1))
    fi
  fi
  echo
 done

printf '==> summary\n'
printf '    passed: %d\n' "$passed"
printf '    unsupported: %d\n' "$unsupported"
printf '    unsupported(allowed): %d\n' "$tolerated_unsupported"
printf '    parser_error: %d\n' "$parser_error"
printf '    decode_error: %d\n' "$decode_error"
printf '    unexpected_crash: %d\n' "$unexpected_crash"
printf '    failed: %d\n' "$failed"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
