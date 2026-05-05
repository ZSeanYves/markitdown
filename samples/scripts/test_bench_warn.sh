#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/scripts/tmp_helpers.sh"

TMP_DIR="$(sample_make_isolated_tmp_dir "$ROOT/.tmp" "test_bench_warn")"
trap 'sample_cleanup_tmp_dir "$TMP_DIR"' EXIT

thresholds_ok="$TMP_DIR/perf_thresholds_ok.tsv"
thresholds_bad_metric="$TMP_DIR/perf_thresholds_bad_metric.tsv"
batch_input_ok="$TMP_DIR/batch_profile_summary.tsv"
smoke_input_warn="$TMP_DIR/smoke_summary.tsv"

cat > "$thresholds_ok" <<'EOF'
suite	key	metric	direction	warn_value	notes
batch_profile	pdf:16:false	speedup	min	5.0	PDF batch should remain faster than process-per-file
batch_profile	pdf:16:false	peak_rss_kb_batch	max	65536	Warn if PDF batch RSS exceeds 64 MB
EOF

cat > "$thresholds_bad_metric" <<'EOF'
suite	key	metric	direction	warn_value	notes
batch_profile	pdf:16:false	unknown_metric	min	1	Should fail on unsupported metric
EOF

cat > "$batch_input_ok" <<'EOF'
format	group_size	metadata_enabled	metadata_mode	process_per_file_ms	single_process_batch_ms	speedup	total_input_bytes	total_output_bytes	avg_ms_per_file_process	avg_ms_per_file_batch	peak_rss_kb_process	peak_rss_kb_batch	rss_delta_kb	failure_count
pdf	16	false	without-metadata	481	54	8.91	169638	4862	30.06	3.38	6176	6576	400	0
docx	16	false	without-metadata	610	184	3.32	794822	9087	38.12	11.50	6992	7840	848	0
EOF

cat > "$smoke_input_warn" <<'EOF'
format	sample	runs	failed	min_ms	median_ms	max_ms	avg_ms	output_bytes_last	asset_count_last	runner_kind	runner_label
docx	golden	1	0	10075	10075	10075	10075	3870	1	moon-run	moon-run fallback
EOF

echo "==> bench_warn ok case"
"$ROOT/samples/scripts/bench_warn.sh" --suite batch_profile --input "$batch_input_ok" --thresholds "$thresholds_ok"

echo "==> bench_warn warn case"
warn_output="$TMP_DIR/warn.out"
"$ROOT/samples/scripts/bench_warn.sh" --suite batch_profile --input "$batch_input_ok" --thresholds "$thresholds_ok" >"$warn_output"
if ! grep -q '\[ok\]' "$warn_output"; then
  echo "expected ok output in default run" >&2
  exit 1
fi

cat > "$batch_input_ok" <<'EOF'
format	group_size	metadata_enabled	metadata_mode	process_per_file_ms	single_process_batch_ms	speedup	total_input_bytes	total_output_bytes	avg_ms_per_file_process	avg_ms_per_file_batch	peak_rss_kb_process	peak_rss_kb_batch	rss_delta_kb	failure_count
pdf	16	false	without-metadata	481	54	1.40	169638	4862	30.06	3.38	6176	70000	400	0
EOF

"$ROOT/samples/scripts/bench_warn.sh" --suite batch_profile --input "$batch_input_ok" --thresholds "$thresholds_ok" >"$warn_output"
if ! grep -q '\[warn\]' "$warn_output"; then
  echo "expected warning output for degraded batch profile values" >&2
  exit 1
fi

echo "==> bench_warn strict mode"
set +e
"$ROOT/samples/scripts/bench_warn.sh" --strict --suite batch_profile --input "$batch_input_ok" --thresholds "$thresholds_ok" >/dev/null 2>&1
strict_status=$?
set -e
if [[ $strict_status -eq 0 ]]; then
  echo "expected strict mode to exit 1 on warning" >&2
  exit 1
fi
if [[ $strict_status -ne 1 ]]; then
  echo "expected strict mode exit status 1, got $strict_status" >&2
  exit 1
fi

echo "==> bench_warn missing input"
set +e
"$ROOT/samples/scripts/bench_warn.sh" --suite batch_profile --input "$TMP_DIR/missing.tsv" --thresholds "$thresholds_ok" >/dev/null 2>&1
missing_status=$?
set -e
if [[ $missing_status -eq 0 ]]; then
  echo "expected missing input to fail" >&2
  exit 1
fi
if [[ $missing_status -ne 2 ]]; then
  echo "expected missing input exit status 2, got $missing_status" >&2
  exit 1
fi

echo "==> bench_warn unknown metric"
set +e
"$ROOT/samples/scripts/bench_warn.sh" --suite batch_profile --input "$batch_input_ok" --thresholds "$thresholds_bad_metric" >/dev/null 2>&1
bad_metric_status=$?
set -e
if [[ $bad_metric_status -eq 0 ]]; then
  echo "expected unknown metric policy to fail" >&2
  exit 1
fi
if [[ $bad_metric_status -ne 2 ]]; then
  echo "expected unknown metric exit status 2, got $bad_metric_status" >&2
  exit 1
fi

echo "==> bench_warn smoke runner-aware warning"
smoke_warn_output="$TMP_DIR/smoke_warn.out"
"$ROOT/samples/scripts/bench_warn.sh" --suite smoke --input "$smoke_input_warn" >"$smoke_warn_output"
if ! grep -q 'runner=moon-run; includes Moon wrapper overhead' "$smoke_warn_output"; then
  echo "expected smoke warning to mention runner overhead" >&2
  exit 1
fi

echo "BENCH WARN TESTS PASSED"
