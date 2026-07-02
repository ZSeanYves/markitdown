#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp.sh"
source "$ROOT/samples/helpers/shared/cli_runner.sh"
source "$ROOT/samples/helpers/validation/check_samples_inventory.sh"
source "$ROOT/samples/helpers/validation/check_samples_lanes.sh"
source "$ROOT/samples/helpers/validation/check_samples_failures.sh"
source "$ROOT/samples/helpers/validation/check_samples_rag_assets.sh"

SAMPLES_DIR="$ROOT/samples/main_process"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
FAILURE_DIFF_DIR="${CHECK_FAILURE_DIFF_DIR:-}"
FAILURE_RAW_DIR="${CHECK_FAILURE_RAW_DIR:-}"
FAILURE_REPORTS_DIR="${CHECK_FAILURE_REPORTS_DIR:-}"
if [[ -n "${CHECK_SAMPLES_OUT_DIR:-}" ]]; then
  OUT_DIR="$CHECK_SAMPLES_OUT_DIR"
  mkdir -p "$OUT_DIR"
  CLEANUP_OUT_DIR=0
else
  OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "main_process")"
  CLEANUP_OUT_DIR=1
fi

MODE="markdown"
FORMAT_FILTER=""
SPECIAL_MODE=""
FORMATS=("csv" "tsv" "txt" "json" "jsonl" "ndjson" "ipynb" "xml" "yaml" "toml" "html" "markdown" "zip" "epub" "docx" "xlsx" "pptx" "pdf" "ocr")

trap 'status=$?; if [[ "$CLEANUP_OUT_DIR" -ne 0 ]]; then sample_cleanup_tmp_dir "$OUT_DIR"; fi; exit "$status"' EXIT

usage() {
  cat <<'EOF'
Internal usage: check_samples_impl.sh [--markdown|--rag|--assets|--ocr] [--format FMT] [--check-inventory] [--list-inventory]
EOF
}

supported_formats() {
  local IFS=","
  echo "${FORMATS[*]}"
}

sample_inventory_formats() {
  printf '%s\n' xlsx html zip epub docx pptx pdf ocr csv tsv json jsonl ndjson ipynb yaml toml xml markdown txt
}

format_is_supported() {
  local target="$1"
  local fmt
  for fmt in "${FORMATS[@]}"; do
    if [[ "$fmt" == "$target" ]]; then
      return 0
    fi
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown)
MODE="markdown"
      ;;
    --rag)
      MODE="rag"
      ;;
    --assets)
      MODE="assets"
      ;;
    --ocr)
      MODE="ocr"
      ;;
    --format)
      shift
      if [[ $# -eq 0 || "${1:-}" == --* ]]; then
        echo "--format requires a value" >&2
        usage >&2
        exit 1
      fi
      FORMAT_FILTER="$1"
      ;;
    --check-inventory)
      SPECIAL_MODE="check-inventory"
      ;;
    --list-inventory)
      SPECIAL_MODE="list-inventory"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -n "$FORMAT_FILTER" ]] && ! format_is_supported "$FORMAT_FILTER"; then
  echo "unsupported format for the main CLI gate in this build: $FORMAT_FILTER" >&2
  echo "supported gate formats: $(supported_formats)" >&2
  echo "unsupported formats fail closed; no alternate product route is available here" >&2
  exit 1
fi

if [[ -n "$SPECIAL_MODE" ]]; then
  if [[ -n "$FORMAT_FILTER" ]]; then
    echo "--format cannot be combined with --$SPECIAL_MODE" >&2
    usage >&2
    exit 1
  fi
  case "$SPECIAL_MODE" in
    check-inventory)
      check_sample_inventory_integrity
      exit 0
      ;;
    list-inventory)
      inventory_list
      exit 0
      ;;
  esac
fi

resolve_markitdown_cli
echo "runner: $CLI_RUNNER_KIND"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

ACTIVE_FORMATS=("${FORMATS[@]}")
if [[ -n "$FORMAT_FILTER" ]]; then
  ACTIVE_FORMATS=("$FORMAT_FILTER")
fi

MODE_UPPER="$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')"

SAMPLE_LIST=()
for fmt in "${ACTIVE_FORMATS[@]}"; do
  in_dir="$(lane_input_dir "$fmt" "$MODE")"
  [[ -d "$in_dir" ]] || continue
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel="${f#$in_dir/}"
    SAMPLE_LIST+=("$fmt|$rel")
  done < <(discover_samples "$fmt" "$MODE" | sort)
done

if [[ ${#SAMPLE_LIST[@]} -eq 0 ]]; then
  echo "No enrolled sample files matched mode=$MODE format=${FORMAT_FILTER:-all} under $SAMPLES_DIR"
  echo "ALL MAIN PROCESS ${MODE_UPPER} TESTS PASSED (0 samples, 0 failures)"
  exit 0
fi

label="main_process_${MODE}"
success_message="ALL MAIN PROCESS ${MODE_UPPER} TESTS PASSED"
failure_message="FAILED MAIN PROCESS ${MODE_UPPER} SAMPLES"
if [[ -n "$FORMAT_FILTER" ]]; then
  label="${label}_${FORMAT_FILTER}"
  success_message="$success_message ($FORMAT_FILTER)"
  failure_message="$failure_message ($FORMAT_FILTER)"
fi

validation_progress_init "$label" "${#SAMPLE_LIST[@]}"

for entry in "${SAMPLE_LIST[@]}"; do
  IFS='|' read -r fmt rel <<< "$entry"
  base="$(basename "$rel")"
  name="${base%.*}"
  rel_no_ext="${rel%.*}"
  input_path="$(lane_input_dir "$fmt" "$MODE")/$rel"
  expected_path="$(resolve_expected_fixture "$fmt" "$MODE" "$rel_no_ext")"
  scope="main_process/$MODE/$fmt/$rel_no_ext"
  sample_out_dir="$OUT_DIR/$fmt/$rel_no_ext"
  run_dir="$sample_out_dir/run"
  cli_dir="$sample_out_dir/cli"
  output_md="$run_dir/$name.md"
  output_rag="$run_dir/$name.rag.json"
  stdout_path="$cli_dir/$name.stdout.log"
  stderr_path="$cli_dir/$name.stderr.log"
  failure_slug="$(sample_failure_slug "$scope")"
  failure_diff="$FAILURE_DIFF_DIR/$failure_slug.diff"
  failure_raw_dir="$FAILURE_RAW_DIR/$failure_slug"
  failure_actual="$failure_raw_dir/actual.out"
  failure_expected="$failure_raw_dir/expected.out"
  failure_stdout="$failure_raw_dir/stdout.log"
  failure_stderr="$failure_raw_dir/stderr.log"
  failure_report="$FAILURE_REPORTS_DIR/$failure_slug.md"
  mkdir -p "$run_dir" "$cli_dir"
  validation_progress_step "$fmt/$rel"

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> converting $scope"
  fi

  cli_args=(normal)
  while IFS= read -r extra_arg; do
    [[ -z "$extra_arg" ]] && continue
    cli_args+=("$extra_arg")
  done < <(sample_lane_cli_args "$fmt" "$MODE" "$rel")
  if [[ "$MODE" == "rag" ]]; then
    cli_args=(--rag)
  fi
  out_path="$output_md"
  if [[ "$MODE" == "rag" ]]; then
    out_path="$output_rag"
  fi

  if ! run_markitdown_cli "${cli_args[@]}" "$input_path" "$out_path" >"$stdout_path" 2>"$stderr_path"; then
    copy_if_exists "$out_path" "$failure_actual"
    copy_if_exists "$expected_path" "$failure_expected"
    copy_if_exists "$stdout_path" "$failure_stdout"
    copy_if_exists "$stderr_path" "$failure_stderr"
    failure_note="conversion failed"
    if [[ -f "$stderr_path" ]]; then
      preview="$(single_line_note "$(sed -n '1,5p' "$stderr_path" 2>/dev/null)")"
      if [[ -n "$preview" ]]; then
        failure_note="$failure_note: $preview"
      fi
    fi
    write_failure_report \
      "$failure_report" \
      "$scope" \
      "$fmt" \
      "$input_path" \
      "${expected_path:-}" \
      "$failure_actual" \
      "" \
      "$failure_stdout" \
      "$failure_stderr" \
      "$failure_note" \
      "conversion_failed"
    validation_record_failure "$scope" "$input_path" "$expected_path" "$failure_actual" "$failure_note" "conversion_failed" "" "$failure_stdout" "$failure_stderr" "$failure_report"
    continue
  fi

  if [[ ! -f "$expected_path" ]]; then
    copy_if_exists "$out_path" "$failure_actual"
    copy_if_exists "$stdout_path" "$failure_stdout"
    copy_if_exists "$stderr_path" "$failure_stderr"
    write_failure_report \
      "$failure_report" \
      "$scope" \
      "$fmt" \
      "$input_path" \
      "${expected_path:-}" \
      "$failure_actual" \
      "" \
      "$failure_stdout" \
      "$failure_stderr" \
      "expected missing" \
      "expected_missing"
    validation_record_failure "$scope" "$input_path" "$expected_path" "$failure_actual" "expected missing" "expected_missing" "" "$failure_stdout" "$failure_stderr" "$failure_report"
    continue
  fi

  case "$MODE" in
    markdown)
      if ! validation_diff_or_record "$scope" "$input_path" "$expected_path" "$output_md" "$failure_diff"; then
        copy_if_exists "$output_md" "$failure_actual"
        copy_if_exists "$expected_path" "$failure_expected"
        copy_if_exists "$stdout_path" "$failure_stdout"
        copy_if_exists "$stderr_path" "$failure_stderr"
        write_failure_report \
          "$failure_report" \
          "$scope" \
          "$fmt" \
          "$input_path" \
          "$failure_expected" \
          "$failure_actual" \
          "$failure_diff" \
          "$failure_stdout" \
          "$failure_stderr" \
          "markdown output differed from expected" \
          "diff_mismatch"
        validation_record_failure "$scope" "$input_path" "$failure_expected" "$failure_actual" "markdown output differed from expected" "diff_mismatch" "$failure_diff" "$failure_stdout" "$failure_stderr" "$failure_report"
      fi
      ;;
    rag)
      set +e
      rag_detail="$(validate_rag_fixture "$output_rag" "$expected_path" "$scope" 2>&1)"
      rag_status=$?
      set -e
      if [[ "$rag_status" -ne 0 ]]; then
        copy_if_exists "$output_rag" "$failure_actual"
        copy_if_exists "$expected_path" "$failure_expected"
        copy_if_exists "$stdout_path" "$failure_stdout"
        copy_if_exists "$stderr_path" "$failure_stderr"
        write_failure_report \
          "$failure_report" \
          "$scope" \
          "$fmt" \
          "$input_path" \
          "$failure_expected" \
          "$failure_actual" \
          "" \
          "$failure_stdout" \
          "$failure_stderr" \
          "${rag_detail:-rag fixture validation failed}" \
          "rag_mismatch"
        validation_record_failure "$scope" "$input_path" "$failure_expected" "$failure_actual" "${rag_detail:-rag fixture validation failed}" "rag_mismatch" "" "$failure_stdout" "$failure_stderr" "$failure_report"
      fi
      ;;
    assets)
      expected_case_dir="$(dirname "$expected_path")"
      actual_assets_dir="$run_dir/assets"
      expected_assets_dir="$expected_case_dir/assets"
      if ! validation_diff_or_record "$scope" "$input_path" "$expected_path" "$output_md" "$failure_diff"; then
        copy_if_exists "$output_md" "$failure_actual"
        copy_if_exists "$expected_path" "$failure_expected"
        copy_if_exists "$stdout_path" "$failure_stdout"
        copy_if_exists "$stderr_path" "$failure_stderr"
        copy_dir_if_exists "$actual_assets_dir" "$failure_raw_dir/assets"
        write_failure_report \
          "$failure_report" \
          "$scope" \
          "$fmt" \
          "$input_path" \
          "$failure_expected" \
          "$failure_actual" \
          "$failure_diff" \
          "$failure_stdout" \
          "$failure_stderr" \
          "assets lane markdown output differed from expected" \
          "diff_mismatch"
        validation_record_failure "$scope" "$input_path" "$failure_expected" "$failure_actual" "assets lane markdown output differed from expected" "diff_mismatch" "$failure_diff" "$failure_stdout" "$failure_stderr" "$failure_report"
        continue
      fi
      if ! check_asset_refs_or_record "$scope" "$run_dir"; then
        copy_if_exists "$output_md" "$failure_actual"
        copy_if_exists "$expected_path" "$failure_expected"
        copy_if_exists "$stdout_path" "$failure_stdout"
        copy_if_exists "$stderr_path" "$failure_stderr"
        copy_dir_if_exists "$actual_assets_dir" "$failure_raw_dir/assets"
        write_failure_report \
          "$failure_report" \
          "$scope" \
          "$fmt" \
          "$input_path" \
          "$expected_path" \
          "$output_md" \
          "" \
          "$failure_stdout" \
          "$failure_stderr" \
          "asset reference points to a missing output asset" \
          "missing_asset"
        validation_record_failure "$scope" "$input_path" "$expected_path" "$output_md" "asset reference points to a missing output asset" "missing_asset" "" "$failure_stdout" "$failure_stderr" "$failure_report"
        continue
      fi
      set +e
      asset_detail="$(assets_dirs_equal "$expected_assets_dir" "$actual_assets_dir" 2>&1)"
      asset_status=$?
      set -e
      if [[ "$asset_status" -ne 0 ]]; then
        copy_if_exists "$output_md" "$failure_actual"
        copy_if_exists "$expected_path" "$failure_expected"
        copy_if_exists "$stdout_path" "$failure_stdout"
        copy_if_exists "$stderr_path" "$failure_stderr"
        copy_dir_if_exists "$actual_assets_dir" "$failure_raw_dir/assets"
        write_failure_report \
          "$failure_report" \
          "$scope" \
          "$fmt" \
          "$input_path" \
          "$expected_path" \
          "$output_md" \
          "" \
          "$failure_stdout" \
          "$failure_stderr" \
          "${asset_detail:-asset output mismatch}" \
          "asset_mismatch"
        validation_record_failure "$scope" "$input_path" "$expected_path" "$output_md" "${asset_detail:-asset output mismatch}" "asset_mismatch" "" "$failure_stdout" "$failure_stderr" "$failure_report"
      fi
      ;;
  esac
done

validation_finish "$success_message" "$failure_message"
