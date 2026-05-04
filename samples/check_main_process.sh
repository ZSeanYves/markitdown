#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/samples/scripts/tmp_helpers.sh"
source "$ROOT/samples/scripts/validation_helpers.sh"
SAMPLES_DIR="$ROOT/samples/main_process"
EXP_DIR="$SAMPLES_DIR/expected"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "main_process")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_cli
echo "runner: $CLI_RUNNER_KIND"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

FORMATS=("docx" "pdf" "xlsx" "html" "pptx" "csv" "tsv" "txt" "xml" "json" "yaml" "markdown" "zip" "epub")

discover_samples() {
  local fmt="$1"
  local in_dir="$SAMPLES_DIR/$fmt"
  case "$fmt" in
    docx) find "$in_dir" -maxdepth 1 -type f -name "*.docx" -print ;;
    pdf) find "$in_dir" -maxdepth 1 -type f -name "*.pdf" -print ;;
    xlsx) find "$in_dir" -maxdepth 1 -type f -name "*.xlsx" -print ;;
    pptx) find "$in_dir" -maxdepth 1 -type f -name "*.pptx" -print ;;
    html) find "$in_dir" -maxdepth 1 -type f \( -name "*.html" -o -name "*.htm" \) -print ;;
    csv) find "$in_dir" -maxdepth 1 -type f -name "*.csv" -print ;;
    tsv) find "$in_dir" -maxdepth 1 -type f -name "*.tsv" -print ;;
    txt) find "$in_dir" -maxdepth 1 -type f -name "*.txt" -print ;;
    xml) find "$in_dir" -maxdepth 1 -type f -name "*.xml" -print ;;
    json) find "$in_dir" -maxdepth 1 -type f -name "*.json" -print ;;
    yaml) find "$in_dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) -print ;;
    markdown) find "$in_dir" -maxdepth 1 -type f \( -name "*.md" -o -name "*.markdown" \) -print ;;
    zip) find "$in_dir" -maxdepth 1 -type f -name "*.zip" -print ;;
    epub) find "$in_dir" -maxdepth 1 -type f -name "*.epub" -print ;;
    *) return 0 ;;
  esac
}

SAMPLE_LIST=()
for fmt in "${FORMATS[@]}"; do
  in_dir="$SAMPLES_DIR/$fmt"
  [[ -d "$in_dir" ]] || continue
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    SAMPLE_LIST+=("$fmt|$f")
  done < <(discover_samples "$fmt" | sort)
done

if [[ ${#SAMPLE_LIST[@]} -eq 0 ]]; then
  echo "No sample files found under $SAMPLES_DIR for: ${FORMATS[*]}"
  exit 1
fi

validation_progress_init "main_process" "${#SAMPLE_LIST[@]}"

for entry in "${SAMPLE_LIST[@]}"; do
  IFS='|' read -r fmt f <<< "$entry"
  base="$(basename "$f")"
  name="${base%.*}"
  exp_dir="$EXP_DIR/$fmt"
  out_dir="$OUT_DIR/$fmt"
  out="$out_dir/$name.md"
  exp="$exp_dir/$name.md"
  diff_path="$out_dir/$name.diff"

  mkdir -p "$exp_dir" "$out_dir"
  validation_progress_step "$fmt/$base"

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> converting main_process/$fmt/$base"
  fi
  if ! run_markitdown_cli normal "$f" "$out"; then
    validation_record_failure "main_process/$fmt/$name" "$f" "$exp" "$out" "conversion failed"
    continue
  fi

  if [[ ! -f "$exp" ]]; then
    validation_record_failure "main_process/$fmt/$name" "$f" "$exp" "$out" "expected missing"
    continue
  fi

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> check main_process/$fmt/$name"
  fi
  validation_diff_or_record "main_process/$fmt/$name" "$f" "$exp" "$out" "$diff_path" || true
done

validation_finish "ALL MAIN PROCESS TESTS PASSED" "FAILED MAIN PROCESS SAMPLES"
