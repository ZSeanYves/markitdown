#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/tests/check}"
mkdir -p "$TMP_ROOT"
OUT_DIR="$(mktemp -d "$TMP_ROOT/quality_signal_eval.XXXXXX")"

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

ARTIFACT_DIR="$OUT_DIR/artifact"
mkdir -p "$ARTIFACT_DIR/assets" "$ARTIFACT_DIR/metadata"
MARKDOWN="$ARTIFACT_DIR/result.md"
METADATA="$ARTIFACT_DIR/metadata/result.metadata.json"
ROWS_TSV="$ARTIFACT_DIR/rows.tsv"
RESULTS_TSV="$ARTIFACT_DIR/results.tsv"

cat >"$MARKDOWN" <<'EOF'
# Alpha Heading
Alpha Beta
Alpha Gamma
| H | V |
| --- | --- |
| a | b |
![img](assets/pic.png)
[link](https://example.com)
tiny
this_has_a_really_really_long_token_that_should_fail
EOF

printf '{}' > "$METADATA"
printf 'fake' > "$ARTIFACT_DIR/assets/pic.png"

cat >"$ROWS_TSV" <<'EOF'
row_id	format	source_scope	source_id	quality_tier	expected_signals
row_exact	txt	external	source	gate	exact_count:Alpha=3;min_count:Beta=1;max_count:Gamma=1;contains_all:Alpha|Beta;order:Alpha|Gamma
row_negative	txt	external	source	gate	not_contains:Delta;table_marker;image_ref;link_ref;asset_count_min:1;line_fragmentation_max:10
row_long_token	txt	external	source	gate	max_long_token_len:20
EOF

python3 "$ROOT/samples/helpers/quality/evaluate_signals.py" \
  --markdown "$MARKDOWN" \
  --artifact-dir "$ARTIFACT_DIR" \
  --rows-tsv "$ROWS_TSV" \
  --results-tsv "$RESULTS_TSV"

[[ -f "$RESULTS_TSV" ]] || fail "missing results.tsv"
assert_contains "$RESULTS_TSV" $'row_exact\ttxt\texternal\tsource\tgate\t5\t5\t\t'
assert_contains "$RESULTS_TSV" $'row_negative\ttxt\texternal\tsource\tgate\t6\t6\t\t'
assert_contains "$RESULTS_TSV" $'row_long_token\ttxt\texternal\tsource\tgate\t0\t1\tmax_long_token_len:20\t'

echo "QUALITY SIGNAL EVAL PASSED"
