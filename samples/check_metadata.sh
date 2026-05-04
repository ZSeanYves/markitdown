#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/samples/scripts/tmp_helpers.sh"
source "$ROOT/samples/scripts/validation_helpers.sh"
META_DIR="$ROOT/samples/metadata"
EXP_DIR="$META_DIR/expected"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "metadata")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_cli
echo "runner: $CLI_RUNNER_KIND"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

FORMATS=("image" "html" "pdf" "pptx" "docx" "xlsx" "csv" "tsv" "txt" "xml" "yaml" "markdown" "zip" "epub")

discover_metadata_samples() {
  local fmt="$1"
  local in_dir="$META_DIR/$fmt"
  case "$fmt" in
    image|html) find "$in_dir" -maxdepth 1 -type f \( -name "*.html" -o -name "*.htm" \) -print ;;
    pdf) find "$in_dir" -maxdepth 1 -type f -name "*.pdf" -print ;;
    pptx) find "$in_dir" -maxdepth 1 -type f -name "*.pptx" -print ;;
    docx) find "$in_dir" -maxdepth 1 -type f -name "*.docx" -print ;;
    xlsx) find "$in_dir" -maxdepth 1 -type f -name "*.xlsx" -print ;;
    csv) find "$in_dir" -maxdepth 1 -type f -name "*.csv" -print ;;
    tsv) find "$in_dir" -maxdepth 1 -type f -name "*.tsv" -print ;;
    txt) find "$in_dir" -maxdepth 1 -type f -name "*.txt" -print ;;
    xml) find "$in_dir" -maxdepth 1 -type f -name "*.xml" -print ;;
    yaml) find "$in_dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) -print ;;
    markdown) find "$in_dir" -maxdepth 1 -type f \( -name "*.md" -o -name "*.markdown" \) -print ;;
    zip) find "$in_dir" -maxdepth 1 -type f -name "*.zip" -print ;;
    epub) find "$in_dir" -maxdepth 1 -type f -name "*.epub" -print ;;
    *) return 0 ;;
  esac
}

SAMPLE_LIST=()
for fmt in "${FORMATS[@]}"; do
  in_dir="$META_DIR/$fmt"
  [[ -d "$in_dir" ]] || continue
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    SAMPLE_LIST+=("$fmt|$f")
  done < <(discover_metadata_samples "$fmt" | sort)
done

if [[ ${#SAMPLE_LIST[@]} -eq 0 ]]; then
  echo "No metadata sample files found under $META_DIR for: ${FORMATS[*]}"
  exit 1
fi

validation_progress_init "metadata" "${#SAMPLE_LIST[@]}"

for entry in "${SAMPLE_LIST[@]}"; do
  IFS='|' read -r fmt f <<< "$entry"
  base="$(basename "$f")"
  name="${base%.*}"
  exp_dir="$EXP_DIR/$fmt"
  out_dir="$OUT_DIR/$fmt"
  sample_out_dir="$out_dir"
  if [[ "$fmt" == "docx" || "$fmt" == "pptx" ]]; then
    sample_out_dir="$out_dir/$name"
  fi

  out="$sample_out_dir/$name.md"
  exp="$exp_dir/$name.md"
  diff_path="$sample_out_dir/$name.diff"

  mkdir -p "$exp_dir" "$sample_out_dir"
  validation_progress_step "$fmt/$base"

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> converting metadata/$fmt/$base"
  fi
  if ! run_markitdown_cli normal "$f" "$out"; then
    validation_record_failure "metadata/$fmt/$name" "$f" "$exp" "$out" "conversion failed"
    continue
  fi

  if [[ ! -f "$exp" ]]; then
    validation_record_failure "metadata/$fmt/$name" "$f" "$exp" "$out" "expected missing"
    continue
  fi

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> diff metadata/$fmt/$name"
  fi
  validation_diff_or_record "metadata/$fmt/$name" "$f" "$exp" "$out" "$diff_path" || true
done

validation_finish "ALL METADATA TESTS PASSED" "FAILED METADATA SAMPLES"
