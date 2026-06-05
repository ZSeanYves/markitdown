#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/samples/helpers/bench/bench_v2_common.sh"

LAYER=""
declare -a FORWARD_ARGS=()

usage() {
  cat <<'EOF'
Usage:
  ./samples/bench.sh --layer parser|convert|cli|compare [--format fmt[,fmt]] [--manifest PATH] [--iterations N] [--warmup N] [--output PATH|--output-dir DIR] [--profile PROFILE]

Examples:
  MARKITDOWN_QUALITY_LAB=/path/to/markitdown-quality-lab ./samples/bench.sh --layer parser --format html --iterations 1 --warmup 0
  MARKITDOWN_QUALITY_LAB=/path/to/markitdown-quality-lab ./samples/bench.sh --layer convert --format html --iterations 1 --warmup 0
  MARKITDOWN_QUALITY_LAB=/path/to/markitdown-quality-lab ./samples/bench.sh --layer cli --profile normal --format pdf --iterations 1 --warmup 0

Layers:
  parser   parser layer benchmark using bench/parser_layer and quality-lab external_bench
  convert  convert/convert.parse_to_ir benchmark using quality-lab external_bench
  cli      native CLI process benchmark using quality-lab external_bench
  compare  explicit Microsoft MarkItDown comparison layer using quality-lab external_bench

Notes:
  * samples/bench.sh is the only public benchmark entrypoint.
  * Benchmark corpus and manifest rows must come from quality-lab external_bench.
  * Suite-style benchmark entrypoints are retired; use --layer instead.
  * Main-process regression samples are not a performance benchmark corpus.
EOF
}

deprecated_suite() {
  cat >&2 <<'EOF'
--suite is retired for benchmark entrypoints.
Use --layer parser|convert|cli|compare with an external_bench manifest instead.
EOF
}

require_value() {
  local flag="$1"
  local count="$2"
  if [[ "$count" -lt 2 ]]; then
    echo "missing value for $flag" >&2
    usage >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --layer)
      require_value "$1" "$#"
      LAYER="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --format|--manifest|--iterations|--warmup|--output|--output-dir|--profile)
      require_value "$1" "$#"
      if [[ "$1" == "--format" ]]; then
        bench_v2_require_non_empty_token_filter "$1" "$2" || exit 1
      fi
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --corpus)
      echo "corpus now comes from external_bench manifest; use --manifest PATH or MARKITDOWN_BENCH_LAB / MARKITDOWN_QUALITY_LAB" >&2
      exit 1
      ;;
    --suite)
      deprecated_suite
      usage >&2
      exit 1
      ;;
    --runs|--kind|--formats|--counts|--group-sizes|--models|--memory)
      echo "$1 belongs to deprecated suite-specific benchmark entrypoints; use --layer with external_bench" >&2
      exit 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    smoke|compare|batch-profile|cold-start|cold_start|doc-parse|doc_parse|product-path|product_path)
      deprecated_suite
      usage >&2
      exit 1
      ;;
    *)
      echo "unknown benchmark argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$LAYER" ]]; then
  echo "missing required --layer parser|convert|cli|compare" >&2
  usage >&2
  exit 1
fi

case "$LAYER" in
  parser)
    exec "$ROOT/samples/helpers/bench/bench_doc_parse_helper.sh" "${FORWARD_ARGS[@]}"
    ;;
  convert)
    exec "$ROOT/samples/helpers/bench/bench_convert_layer.sh" "${FORWARD_ARGS[@]}"
    ;;
  cli)
    exec "$ROOT/samples/helpers/bench/bench_cli_layer.sh" "${FORWARD_ARGS[@]}"
    ;;
  compare)
    exec "$ROOT/samples/helpers/bench/bench_compare_markitdown.sh" "${FORWARD_ARGS[@]}"
    ;;
  *)
    echo "unknown benchmark layer: $LAYER" >&2
    usage >&2
    exit 1
    ;;
esac
