#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/bench/bench_v2_common.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
RESULT_ROOT="$TMP_ROOT/bench/parser_layer"
DEFAULT_OUTPUT="$RESULT_ROOT/summary.tsv"

usage() {
  cat <<'EOF'
Usage: ./samples/helpers/bench/bench_doc_parse_helper.sh [--manifest PATH] [--layer parser] [--iterations N] [--warmup N] [--format csv,json,...] [--stage parse,inspect,validate] [--output PATH]
       ./samples/helpers/bench/bench_doc_parse_helper.sh --format text --profile text --iterations 10 --warmup 2
       ./samples/helpers/bench/bench_doc_parse_helper.sh --format json --profile json --iterations 10 --warmup 2
       ./samples/helpers/bench/bench_doc_parse_helper.sh --format markdown --profile markdown --iterations 10 --warmup 2
       ./samples/helpers/bench/bench_doc_parse_helper.sh --format xlsx --profile xlsx --iterations 10 --warmup 2
       ./samples/helpers/bench/bench_doc_parse_helper.sh --format docx --profile docx --iterations 10 --warmup 2
       ./samples/helpers/bench/bench_doc_parse_helper.sh --format yaml --profile yaml --iterations 10 --warmup 2

Notes:
  * Recommended public entrypoint:
      ./samples/bench.sh --layer parser ...
  * This is the parser layer benchmark runner for doc_parse APIs.
  * Internal MoonBit harness: bench/parser_layer.
  * BENCH_LAYER: parser; it is a benchmark harness, not parser runtime.
  * The real benchmark corpus lives in markitdown-quality-lab/external_bench.
  * Pass --manifest PATH, or set MARKITDOWN_BENCH_LAB / MARKITDOWN_QUALITY_LAB.
  * This harness measures doc_parse APIs directly inside one benchmark process.
  * It does not call convert/* or the normal CLI conversion path.
  * File I/O is intentionally excluded from measured parse/inspect/validate loops
    unless a package's public API surface is itself byte/package-open oriented.
  * --profile text/json/markdown adds internal lightweight parser or scanner
    sub-stages for hotspot attribution while leaving the default summary layout
    intact.
  * --profile xlsx adds internal SpreadsheetML parse sub-stages for hotspot
    attribution while leaving the default summary layout intact.
  * --profile docx adds internal WordprocessingML parse sub-stages for hotspot
    attribution while leaving the default summary layout intact.
  * --profile yaml adds internal YAML-subset parse sub-stages for hotspot
    attribution while leaving the default summary layout intact.
EOF
}

declare -a FORWARD_ARGS=()
OUTPUT_PATH="$DEFAULT_OUTPUT"
MANIFEST_PATH=""

resolve_default_manifest() {
  bench_v2_resolve_manifest "$ROOT"
}

fail_missing_manifest() {
  bench_v2_fail_missing_manifest
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      [[ $# -ge 2 ]] || { echo "missing value for --manifest" >&2; exit 1; }
      MANIFEST_PATH="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --layer)
      [[ $# -ge 2 ]] || { echo "missing value for --layer" >&2; exit 1; }
      if [[ "$2" != "parser" ]]; then
        echo "doc_parse helper only supports --layer parser; use samples/bench.sh for convert/cli/compare layers" >&2
        exit 1
      fi
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "missing value for --output" >&2; exit 1; }
      OUTPUT_PATH="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --format)
      [[ $# -ge 2 ]] || { echo "missing value for --format" >&2; exit 1; }
      bench_v2_require_non_empty_token_filter "$1" "$2" || exit 1
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      FORWARD_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ! " ${FORWARD_ARGS[*]} " =~ " --manifest " ]]; then
  MANIFEST_PATH="$(resolve_default_manifest)" || fail_missing_manifest
  FORWARD_ARGS=(--manifest "$MANIFEST_PATH" "${FORWARD_ARGS[@]}")
fi
if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "external_bench manifest missing: $MANIFEST_PATH" >&2
  fail_missing_manifest
fi
bench_v2_require_external_bench_header "$MANIFEST_PATH"
if [[ ! " ${FORWARD_ARGS[*]} " =~ " --layer " ]]; then
  FORWARD_ARGS=(--layer parser "${FORWARD_ARGS[@]}")
fi
if [[ ! " ${FORWARD_ARGS[*]} " =~ " --output " ]]; then
  FORWARD_ARGS=(--output "$OUTPUT_PATH" "${FORWARD_ARGS[@]}")
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

echo "==> parser layer benchmark"
echo "manifest: $MANIFEST_PATH"
echo "output: $OUTPUT_PATH"
echo "==> warming Moon build"
(cd "$ROOT" && moon build bench/parser_layer --target native)

RUNNER=""
while IFS= read -r candidate; do
  [[ -n "$candidate" ]] || continue
  RUNNER="$candidate"
  break
done < <(find "$ROOT/_build/native" -path "*/bench/parser_layer/*.exe" -type f 2>/dev/null | sort)

if [[ -n "$RUNNER" && -x "$RUNNER" ]]; then
  echo "runner: prebuilt-native ($RUNNER)"
  (cd "$ROOT" && "$RUNNER" "${FORWARD_ARGS[@]}")
else
  echo "runner: moon run fallback"
  (cd "$ROOT" && moon run "$ROOT/bench/parser_layer" -- "${FORWARD_ARGS[@]}")
fi

echo "BENCHMARK SUITE COMPLETED"
echo "- layer: parser"
echo "- result_root: $(dirname "$OUTPUT_PATH")"
echo "- summary_tsv: $OUTPUT_PATH"
if [[ "$OUTPUT_PATH" == *.tsv ]]; then
  echo "- raw_runs_tsv: ${OUTPUT_PATH%.tsv}.runs.tsv"
else
  echo "- raw_runs_tsv: ${OUTPUT_PATH}.runs.tsv"
fi
