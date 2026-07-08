#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/tests/check}"
mkdir -p "$TMP_ROOT"
OUT_DIR="$(mktemp -d "$TMP_ROOT/quality_override_contract.XXXXXX")"

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

QUALITY_ROOT="$OUT_DIR/external_quality"
mkdir -p "$QUALITY_ROOT/shared"
printf 'Alpha\nBeta\n' > "$QUALITY_ROOT/shared/shared.txt"

BASE_MANIFEST="$OUT_DIR/base.MANIFEST.tsv"
cat >"$BASE_MANIFEST" <<'EOF'
id	format	path	source_type	source_id	license_status	license_review_status	privacy	size_class	features	expected_signals	quality_tier	original_url	local_cache_path	notes
override_row	txt	external_quality/shared/shared.txt	file	contract_source	Apache-2.0	approved	public	small	txt	contains:Gamma	gate			base manifest row should fail without override
EOF

OVERRIDE_MANIFEST="$OUT_DIR/override.MANIFEST.tsv"
cat >"$OVERRIDE_MANIFEST" <<'EOF'
id	format	path	source_type	source_id	license_status	license_review_status	privacy	size_class	features	expected_signals	quality_tier	original_url	local_cache_path	notes
override_row	txt	external_quality/shared/shared.txt	file	contract_source	Apache-2.0	approved	public	small	txt	contains:Alpha;order:Alpha|Beta	gate			override manifest row should replace base manifest signals
EOF

RUN_DIR_REL="test-quality-override-$$"
RUN_DIR="$ROOT/.tmp/tests/quality/runs/$RUN_DIR_REL"
RUN_LOG="$OUT_DIR/run.log"

(
  cd "$ROOT"
  QUALITY_RUN_ID="$RUN_DIR_REL" \
  QUALITY_TMP_ROOT="$ROOT/.tmp/tests/quality" \
  MARKITDOWN_TMP_DIR="$ROOT/.tmp/tests/quality" \
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  MARKITDOWN_QUALITY_OVERRIDE_MANIFEST="$OVERRIDE_MANIFEST" \
  bash samples/helpers/quality/check.sh \
    --require-lab \
    --corpus-root "$QUALITY_ROOT" \
    --lab-manifest "$BASE_MANIFEST"
) >"$RUN_LOG" 2>&1

assert_contains "$RUN_LOG" "QUALITY CHECK PASSED"
assert_contains "$RUN_LOG" "quality_rows_manifest: $BASE_MANIFEST"
assert_contains "$RUN_LOG" "failed: 0"

SUMMARY_TSV="$RUN_DIR/summary.tsv"
[[ -f "$SUMMARY_TSV" ]] || fail "missing summary.tsv"
assert_contains "$SUMMARY_TSV" $'override_row\ttxt\texternal\tgate\tpass\t2\t2\tall signals passed'
assert_contains "$SUMMARY_TSV" $'QUALITY_OVERRIDE_MANIFEST\t-\t-\t-\t-\t0\t0\t'"$OVERRIDE_MANIFEST"

echo "QUALITY OVERRIDE CONTRACT PASSED"
