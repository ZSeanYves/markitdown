#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="$ROOT/samples/pdf_core"
OUT_ROOT="${1:-$ROOT/.tmp_pdf_native_gate_out}"
RUN_DIR="$OUT_ROOT/run"
LOG_DIR="$OUT_ROOT/log"
GEN_SCRIPT="$FIXTURE_DIR/generate_phase7_native_fixtures.py"

mkdir -p "$RUN_DIR" "$LOG_DIR"

if ! command -v moon >/dev/null 2>&1; then
  echo "[env] moon command not found; cannot run native gate check."
  exit 2
fi

CASES=(
  "gated_should_use_native_en_single_page|$FIXTURE_DIR/pdf_native_real_en_single_page.pdf|pdf-native|ACCEPT_"
  "gated_should_use_native_tounicode_basic|$FIXTURE_DIR/pdf_native_real_tounicode_basic.pdf|pdf-native|ACCEPT_"
  "gated_should_use_native_xref_stream_simple|$FIXTURE_DIR/pdf_native_real_xref_stream_simple.pdf|pdf-native|ACCEPT_"
  "gated_should_use_native_objstm_simple|$FIXTURE_DIR/pdf_native_real_objstm_simple.pdf|pdf-native|ACCEPT_"
  "gated_should_use_native_xref_objstm_simple_text|$FIXTURE_DIR/pdf_native_real_xref_objstm_simple_text.pdf|pdf-native|ACCEPT_"
  "gated_should_use_native_simple_font_fallback|$FIXTURE_DIR/pdf_native_real_simple_font_fallback.pdf|pdf-native|ACCEPT_"
  "gated_should_use_external_encrypted_marker|$FIXTURE_DIR/gated_should_use_external_encrypted_marker.pdf|external|REJECT_"
)

passed=0
failed=0

printf '==> pdf-native gate decision check\n'
printf '    fixture dir: %s\n' "$FIXTURE_DIR"
printf '    output dir : %s\n\n' "$OUT_ROOT"

if [[ -f "$GEN_SCRIPT" ]]; then
  python3 "$GEN_SCRIPT"
fi

for item in "${CASES[@]}"; do
  IFS='|' read -r name pdf expect_backend expect_reason_prefix <<<"$item"
  out="$RUN_DIR/$name.md"
  log="$LOG_DIR/$name.log"

  if [[ ! -f "$pdf" ]]; then
    echo "[FAIL] $name missing fixture: $pdf"
    failed=$((failed + 1))
    continue
  fi

  echo "==> running $name"
  moon run "$ROOT/src/cli" -- convert "$pdf" -o "$out" \
    --pdf-backend-policy native-gated \
    --pdf-extract-debug true >"$log" 2>&1 || true

  if ! grep -q "policy=native-gated selected=$expect_backend reason=$expect_reason_prefix" "$log"; then
    echo "  [FAIL] unexpected gate decision (expect selected=$expect_backend reason=$expect_reason_prefix*)"
    echo "         see: $log"
    failed=$((failed + 1))
    continue
  fi

  echo "  [PASS] gate decision matched"
  passed=$((passed + 1))
  echo
done

printf '==> summary\n'
printf '    passed: %d\n' "$passed"
printf '    failed: %d\n' "$failed"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
