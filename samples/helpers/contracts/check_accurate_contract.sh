#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/tests/accurate}"
mkdir -p "$TMP_ROOT"
OUT_DIR="$(mktemp -d "$TMP_ROOT/accurate_contract.XXXXXX")"

trap 'status=$?; rm -rf "$OUT_DIR"; exit "$status"' EXIT

fail() {
  echo "[fail] $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}

LAB_ROOT="$OUT_DIR/markitdown-quality-lab"
ACCURATE_ROOT="$LAB_ROOT/external_accurate"
mkdir -p \
  "$ACCURATE_ROOT/ocr/self_synthetic/samples/layout" \
  "$ACCURATE_ROOT/ocr/commons/samples/layout"

printf 'pngish\n' > "$ACCURATE_ROOT/ocr/self_synthetic/samples/layout/ocr_layout_self_heading_paragraph_0001.png"
printf 'pngish\n' > "$ACCURATE_ROOT/ocr/commons/samples/layout/accurate_contract_layout.png"

cat >"$ACCURATE_ROOT/MANIFEST.tsv" <<'EOF'
id	format	path	source_type	source_id	license_status	license_review_status	privacy	size_class	features	expected_signals	quality_tier	original_url	local_cache_path	notes	validation_view
accurate_debug_row	ocr	external_accurate/ocr/commons/samples/layout/accurate_contract_layout.png	file	contract_source	ok	approved	public	small	accurate;contract	contains:DebugAlpha;contains:paddle_ocr	gate			accurate debug contract row	debug
EOF

STUB_WRAPPER="$OUT_DIR/stub_wrapper.py"
cat >"$STUB_WRAPPER" <<'EOF'
#!/usr/bin/env python3
import json
import sys

payload = {
    "provider_name": "paddle_ocr",
    "provider_version": "contract",
    "pages": [
        {
            "page_index": 0,
            "blocks": [
                {
                    "block_index": 0,
                    "lines": [
                        {
                            "line_index": 0,
                            "text": "Contract OCR",
                            "words": [{"word_index": 0, "text": "Contract"}],
                        }
                    ],
                }
            ],
        }
    ],
}
json.dump(payload, sys.stdout)
sys.stdout.write("\n")
EOF
chmod +x "$STUB_WRAPPER"

STUB_CLI="$OUT_DIR/stub_cli.sh"
cat >"$STUB_CLI" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode="${1-}"
shift || true
if [[ "$mode" == "--help" ]]; then
  cat <<'HELP'
Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml
balance|accurate|stream
HELP
  exit 0
fi
debug_mode=0
while [[ $# -gt 0 ]]; do
  case "${1-}" in
    --format)
      shift 2
      ;;
    --debug)
      debug_mode=1
      shift
      ;;
    --provenance-out)
      shift 2
      ;;
    *)
      break
      ;;
  esac
done
input="${1-}"
output="${2-}"
mkdir -p "$(dirname "$output")"
if [[ "$debug_mode" == "1" ]]; then
  printf '{\"marker\":\"DebugAlpha\",\"provider\":\"paddle_ocr\"}\n' >"$output"
else
  printf 'Alpha\n' >"$output"
fi
EOF
chmod +x "$STUB_CLI"

RUN_LOG="$OUT_DIR/run.log"

(
  cd "$ROOT"
  QUALITY_RUN_ID="contract-accurate-$$" \
  QUALITY_TMP_ROOT="$ROOT/.tmp/tests/accurate" \
  MARKITDOWN_TMP_DIR="$ROOT/.tmp/tests/accurate" \
  MARKITDOWN_CLI="$STUB_CLI" \
  MARKITDOWN_QUALITY_LAB="$LAB_ROOT" \
  MARKITDOWN_PADDLE_OCR_CMD="$STUB_WRAPPER" \
  MARKITDOWN_ACCURATE_TESSERACT_CMD=true \
  MARKITDOWN_ACCURATE_PDFTOPPM_CMD=true \
  MARKITDOWN_ACCURATE_SKIP_PADDLE_IMPORT_CHECK=1 \
  ./samples/check_accurate.sh --formats ocr
) >"$RUN_LOG" 2>&1

assert_contains "$RUN_LOG" "result: pass"

RUN_DIR="$(sed -n 's/^run: //p' "$RUN_LOG" | tail -1)"
[[ -n "$RUN_DIR" ]] || fail "missing accurate run directory in output"

SUMMARY_MD="$ROOT/$RUN_DIR/summary.md"
PREFLIGHT_LOG="$ROOT/$RUN_DIR/logs/preflight.log"
RUN_HELPER_LOG="$ROOT/$RUN_DIR/logs/entrypoint.log"

[[ -f "$SUMMARY_MD" ]] || fail "missing accurate summary.md"
[[ -f "$PREFLIGHT_LOG" ]] || fail "missing accurate preflight log"
[[ -f "$RUN_HELPER_LOG" ]] || fail "missing accurate helper log"

assert_contains "$SUMMARY_MD" "## Preflight"
assert_contains "$SUMMARY_MD" "Paddle wrapper"
assert_contains "$PREFLIGHT_LOG" "preflight: ok"
assert_contains "$RUN_HELPER_LOG" "QUALITY CHECK PASSED"

echo "ACCURATE CONTRACT PASSED"
