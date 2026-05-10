#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
CORPUS_PATH="$ROOT/samples/benchmark/corpus.tsv"
OUTPUT_DIR="$TMP_ROOT/bench/product_path_plan"
FORMATS="txt,json,yaml,csv,xlsx,html,docx,pptx"
MODE=""

usage() {
  cat <<'EOF'
Usage: ./samples/bench_product_path.sh --help
   or: ./samples/bench_product_path.sh --smoke [--corpus PATH] [--output-dir PATH] [--formats txt,json,...]

Notes:
  * This is a planning-only skeleton for the next product-path attribution round.
  * It does not benchmark the converter yet and does not change samples/bench.sh.
  * --smoke writes planning artifacts only:
      - stage-plan.tsv
      - sample-plan.tsv
  * The intended future stage model is:
      startup_probe, file_read, dispatch, parse, convert, emit, metadata, assets, total
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --smoke)
      MODE="smoke"
      shift
      ;;
    --corpus)
      [[ $# -ge 2 ]] || { echo "missing value for --corpus" >&2; exit 1; }
      CORPUS_PATH="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || { echo "missing value for --output-dir" >&2; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --formats)
      [[ $# -ge 2 ]] || { echo "missing value for --formats" >&2; exit 1; }
      FORMATS="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  usage >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

STAGE_PLAN="$OUTPUT_DIR/stage-plan.tsv"
SAMPLE_PLAN="$OUTPUT_DIR/sample-plan.tsv"

cat > "$STAGE_PLAN" <<'EOF'
stage	owner_layer	planned_instrumentation	notes
startup_probe	cli	process launch and empty command baseline	separate fixed startup from format-local work
file_read	cli	before format dispatch	local file I/O only; keep network out of scope
dispatch	cli	format detection and option routing	split dispatcher overhead from parse/convert
parse	doc_parse-or-convert	format parser/open/scan entry	use doc_parse where integrated; keep current converter-local parse where not switched
convert	convert	model to IR or product block lowering	do not move product policy into doc_parse
emit	emitter	Markdown/string emission	track separately from convert lowering
metadata	metadata	sidecar build only	measure only when metadata mode is enabled
assets	assets	asset scan/export/copy only	measure only when asset mode is enabled
total	product	full normal path	end-to-end same-process row
EOF

awk -F '\t' -v formats=",$FORMATS," '
BEGIN {
  print "run_kind\tformat\tsample\tinput_path\tmetadata_enabled\tproposed_stages\tnotes"
}
/^#/ { next }
NR == 1 { next }
{
  if (index(formats, "," $2 ",") == 0) {
    next
  }
  if ($1 == "smoke") {
    print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\tstartup_probe,file_read,dispatch,parse,convert,emit,total\tbaseline normal-path candidate"
  } else if ($1 == "metadata") {
    print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\tstartup_probe,file_read,dispatch,parse,convert,emit,metadata,total\tmetadata sidecar attribution candidate"
  } else if ($1 == "image") {
    print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\tstartup_probe,file_read,dispatch,parse,convert,emit,assets,total\tasset export attribution candidate"
  }
}
' "$CORPUS_PATH" > "$SAMPLE_PLAN"

echo "PRODUCT PATH ATTRIBUTION PLAN READY"
echo "- corpus: $CORPUS_PATH"
echo "- output_dir: $OUTPUT_DIR"
echo "- stage_plan: $STAGE_PLAN"
echo "- sample_plan: $SAMPLE_PLAN"
