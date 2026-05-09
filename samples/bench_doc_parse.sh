#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
RESULT_ROOT="$TMP_ROOT/bench/doc_parse"
DEFAULT_MANIFEST="$ROOT/samples/doc_parse_bench/manifest.tsv"
DEFAULT_OUTPUT="$RESULT_ROOT/summary.tsv"

usage() {
  cat <<'EOF'
Usage: ./samples/bench_doc_parse.sh [--manifest PATH] [--iterations N] [--warmup N] [--format csv,json,...] [--stage parse,inspect,validate] [--output PATH]
       ./samples/bench_doc_parse.sh --format text --profile text --iterations 10 --warmup 2
       ./samples/bench_doc_parse.sh --format json --profile json --iterations 10 --warmup 2
       ./samples/bench_doc_parse.sh --format markdown --profile markdown --iterations 10 --warmup 2
       ./samples/bench_doc_parse.sh --format xlsx --profile xlsx --iterations 10 --warmup 2
       ./samples/bench_doc_parse.sh --format docx --profile docx --iterations 10 --warmup 2
       ./samples/bench_doc_parse.sh --format yaml --profile yaml --iterations 10 --warmup 2

Notes:
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
MANIFEST_PATH="$DEFAULT_MANIFEST"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      [[ $# -ge 2 ]] || { echo "missing value for --manifest" >&2; exit 1; }
      MANIFEST_PATH="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "missing value for --output" >&2; exit 1; }
      OUTPUT_PATH="$2"
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

mkdir -p "$(dirname "$OUTPUT_PATH")"

if [[ ! " ${FORWARD_ARGS[*]} " =~ " --manifest " ]]; then
  FORWARD_ARGS=(--manifest "$MANIFEST_PATH" "${FORWARD_ARGS[@]}")
fi
if [[ ! " ${FORWARD_ARGS[*]} " =~ " --output " ]]; then
  FORWARD_ARGS=(--output "$OUTPUT_PATH" "${FORWARD_ARGS[@]}")
fi

echo "==> doc_parse library benchmark"
echo "manifest: $MANIFEST_PATH"
echo "output: $OUTPUT_PATH"
echo "==> warming Moon build"
(cd "$ROOT" && moon build --target native)

RUNNER=""
while IFS= read -r candidate; do
  [[ -n "$candidate" ]] || continue
  RUNNER="$candidate"
  break
done < <(find "$ROOT/_build/native" -path "*/bench/doc_parse/*.exe" -type f 2>/dev/null | sort)

if [[ -n "$RUNNER" && -x "$RUNNER" ]]; then
  echo "runner: prebuilt-native ($RUNNER)"
  (cd "$ROOT" && "$RUNNER" "${FORWARD_ARGS[@]}")
else
  echo "runner: moon run fallback"
  (cd "$ROOT" && moon run "$ROOT/bench/doc_parse" -- "${FORWARD_ARGS[@]}")
fi

echo "BENCHMARK SUITE COMPLETED"
echo "- suite: doc-parse-library"
echo "- result_root: $(dirname "$OUTPUT_PATH")"
echo "- summary_tsv: $OUTPUT_PATH"
if [[ "$OUTPUT_PATH" == *.tsv ]]; then
  echo "- raw_runs_tsv: ${OUTPUT_PATH%.tsv}.runs.tsv"
else
  echo "- raw_runs_tsv: ${OUTPUT_PATH}.runs.tsv"
fi
