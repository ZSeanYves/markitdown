#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_ROOT="$ROOT/samples/pdf_core"
PDF_DIR="$FIXTURE_ROOT/native"
EXP_DIR="$FIXTURE_ROOT/expected"
OUT_ROOT="${1:-$ROOT/.tmp_pdf_regression_out}"
RUN_DIR="$OUT_ROOT/run"
LOG_DIR="$OUT_ROOT/log"
GEN_SCRIPT="$FIXTURE_ROOT/generate_phase7_native_fixtures.py"

mkdir -p "$RUN_DIR" "$LOG_DIR"

if ! command -v moon >/dev/null 2>&1; then
  echo "[env] moon command not found; cannot run pdf regression check."
  exit 2
fi

CASES=(
  "pdf_native_real_en_single_page"
  "pdf_native_real_tounicode_basic"
  "pdf_native_real_normal_multipage_current_boundary"
  "pdf_native_real_xref_stream_simple"
  "pdf_native_real_xref_stream_multipage"
  "pdf_native_real_objstm_simple"
  "pdf_native_real_objstm_multipage"
  "pdf_native_real_xref_objstm_simple_text"
  "pdf_native_real_xref_objstm_multipage"
  "pdf_native_real_simple_font_fallback"
)

passed=0
failed=0

printf '==> pdf mainflow regression check\n'
printf '    pdf dir    : %s\n' "$PDF_DIR"
printf '    expected   : %s\n' "$EXP_DIR"
printf '    output dir : %s\n\n' "$OUT_ROOT"

if [[ -f "$GEN_SCRIPT" ]]; then
  python3 "$GEN_SCRIPT"
fi

for name in "${CASES[@]}"; do
  pdf="$PDF_DIR/$name.pdf"
  exp="$EXP_DIR/$name.expected.md"
  out="$RUN_DIR/$name.md"
  log="$LOG_DIR/$name.log"

  if [[ ! -f "$pdf" || ! -f "$exp" ]]; then
    echo "[FAIL] $name missing fixture or expected file"
    failed=$((failed + 1))
    continue
  fi

  echo "==> running $name"
  if moon run "$ROOT/cli" -- convert "$pdf" -o "$out" --debug extract >"$log" 2>&1; then
    if ! grep -q "selected backend=pdf-native" "$log"; then
      echo "  [FAIL] backend trace missing (expected native marker)"
      failed=$((failed + 1))
      continue
    fi

    if diff -u "$exp" "$out" >"$LOG_DIR/$name.diff"; then
      echo "  [PASS] output matched expected"
      passed=$((passed + 1))
      rm -f "$LOG_DIR/$name.diff"
    else
      echo "  [FAIL] output mismatch"
      echo "         see: $LOG_DIR/$name.diff"
      failed=$((failed + 1))
    fi
  else
    echo "  [FAIL] command failed"
    failed=$((failed + 1))
  fi
  echo
 done

printf '==> summary\n'
printf '    passed: %d\n' "$passed"
printf '    failed: %d\n' "$failed"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
