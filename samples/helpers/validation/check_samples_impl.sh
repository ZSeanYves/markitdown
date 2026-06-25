#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"

SAMPLES_DIR="$ROOT/samples/main_process"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
FAILURE_DIFF_DIR="${CHECK_FAILURE_DIFF_DIR:-}"
FAILURE_RAW_DIR="${CHECK_FAILURE_RAW_DIR:-}"
FAILURE_REPORTS_DIR="${CHECK_FAILURE_REPORTS_DIR:-}"
RAG_CHECKER="$ROOT/samples/helpers/validation/check_rag_fixture.py"
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
FORMATS=("csv" "tsv" "txt" "json" "jsonl" "ndjson" "xml" "yaml" "html" "markdown" "zip" "epub" "docx" "xlsx" "pptx" "pdf")

trap 'status=$?; if [[ "$CLEANUP_OUT_DIR" -ne 0 ]]; then sample_cleanup_tmp_dir "$OUT_DIR"; fi; exit "$status"' EXIT

usage() {
  cat <<'EOF'
Internal usage: check_samples_impl.sh [--markdown|--rag|--assets] [--format FMT] [--check-inventory] [--list-inventory]
EOF
}

supported_formats() {
  local IFS=","
  echo "${FORMATS[*]}"
}

sample_inventory_formats() {
  printf '%s\n' xlsx html zip epub docx pptx pdf csv tsv json yaml xml markdown txt jsonl ndjson
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
  echo "unsupported format for current main CLI gate: $FORMAT_FILTER is not migrated to the current main CLI yet" >&2
  echo "supported gate formats: $(supported_formats)" >&2
  echo "supported format restoration is currently limited to the root pipeline set; no legacy fallback is used here" >&2
  exit 1
fi

count_non_hidden_files() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -maxdepth 1 -type f ! -name '.*' | wc -l | tr -d '[:space:]'
}

count_expected_markdown_cases() {
  local fmt="$1"
  local dir="$SAMPLES_DIR/$fmt/expected/markdown"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -type f -name '*.md' | wc -l | tr -d '[:space:]'
}

count_expected_rag_cases() {
  local fmt="$1"
  local dir="$SAMPLES_DIR/$fmt/expected/rag"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -type f -name '*.rag.json' | wc -l | tr -d '[:space:]'
}

count_expected_assets_cases() {
  local fmt="$1"
  local dir="$SAMPLES_DIR/$fmt/expected/assets"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]'
}

count_quality_manifest_rows() {
  local fmt="$1"
  local manifest="$ROOT/samples/helpers/quality/manifest.tsv"
  if [[ ! -f "$manifest" ]]; then
    printf '0'
    return
  fi
  awk -F '\t' -v fmt="$fmt" '
    NR == 1 { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    $2 == fmt { count++ }
    END { print count + 0 }
  ' "$manifest"
}

count_quality_comparison_reports() {
  local fmt="$1"
  local dir="$ROOT/docs/quality-comparisons"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -maxdepth 1 -type f -name "${fmt}*.md" | wc -l | tr -d '[:space:]'
}

inventory_list() {
  local fmt
  printf 'format\tmain_markdown\tmain_rag\tmain_assets\texpected_markdown\texpected_rag\texpected_assets\tfixtures\tquality_records\tquality_intake_public\n'
  while IFS= read -r fmt; do
    [[ -z "$fmt" ]] && continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$fmt" \
      "$(count_non_hidden_files "$SAMPLES_DIR/$fmt/markdown")" \
      "$(count_non_hidden_files "$SAMPLES_DIR/$fmt/rag")" \
      "$(count_non_hidden_files "$SAMPLES_DIR/$fmt/assets")" \
      "$(count_expected_markdown_cases "$fmt")" \
      "$(count_expected_rag_cases "$fmt")" \
      "$(count_expected_assets_cases "$fmt")" \
      "$(count_non_hidden_files "$ROOT/samples/fixtures/$fmt")" \
      "$(count_quality_comparison_reports "$fmt")" \
      "$(count_quality_manifest_rows "$fmt")"
  done < <(sample_inventory_formats)
}

sample_integrity_is_noise_file() {
  local base="$1"
  [[ "$base" == .* ]] && return 0
  [[ "$base" == *~ ]] && return 0
  [[ "$base" == *.swp ]] && return 0
  [[ "$base" == *.tmp ]] && return 0
  return 1
}

sample_integrity_discover_inputs() {
  local fmt="$1"
  local lane="$2"
  local in_dir="$SAMPLES_DIR/$fmt/$lane"
  if [[ ! -d "$in_dir" ]]; then
    return 0
  fi
  find "$in_dir" -type f ! -name '.*' ! -path '*/img/*' | sort
}

sample_integrity_expected_bases() {
  local fmt="$1"
  local lane="$2"
  local exp_dir="$SAMPLES_DIR/$fmt/expected/$lane"
  if [[ ! -d "$exp_dir" ]]; then
    return 0
  fi
  case "$lane" in
    markdown)
      find "$exp_dir" -type f -name '*.md' -print | sort | while read -r path; do
        rel="${path#$exp_dir/}"
        echo "${rel%.md}"
      done | sort -u
      ;;
    rag)
      find "$exp_dir" -type f -name '*.rag.json' -print | sort | while read -r path; do
        rel="${path#$exp_dir/}"
        echo "${rel%.rag.json}"
      done | sort -u
      ;;
    assets)
      find "$exp_dir" -mindepth 1 -maxdepth 1 -type d -print | sort | while read -r path; do
        rel="${path#$exp_dir/}"
        echo "$rel"
      done | sort -u
      ;;
  esac
}

check_sample_inventory_integrity() {
  local formats=("docx" "pdf" "xlsx" "html" "pptx" "csv" "tsv" "txt" "xml" "json" "jsonl" "ndjson" "yaml" "markdown" "zip" "epub")
  local lanes=("markdown" "rag" "assets")
  local fail=0 quiet_integrity=0 fmt lane in_dir exp_dir input_bases expected_bases missing_input missing_expected

  if validation_bool_enabled "${SAMPLES_QUIET_INTEGRITY:-0}"; then
    quiet_integrity=1
  fi

  if [[ "$quiet_integrity" -eq 0 ]]; then
    echo "==> sample integrity check"
  fi

  for fmt in "${formats[@]}"; do
    for lane in "${lanes[@]}"; do
      in_dir="$SAMPLES_DIR/$fmt/$lane"
      exp_dir="$SAMPLES_DIR/$fmt/expected/$lane"

      if [[ ! -d "$in_dir" && ! -d "$exp_dir" ]]; then
        continue
      fi

      input_bases="$(sample_integrity_discover_inputs "$fmt" "$lane" | while read -r path; do
        [[ -z "$path" ]] && continue
        rel="${path#$in_dir/}"
        base="$(basename "$rel")"
        if sample_integrity_is_noise_file "$base"; then
          continue
        fi
        case "$lane" in
          assets) echo "${rel%.*}" ;;
          rag) echo "${rel%.*}" ;;
          markdown) echo "${rel%.*}" ;;
        esac
      done | sort -u)"

      expected_bases="$(sample_integrity_expected_bases "$fmt" "$lane")"

      missing_input="$(comm -23 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"
      missing_expected="$(comm -13 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"

      if [[ -n "$missing_input" || -n "$missing_expected" ]]; then
        if [[ "$quiet_integrity" -eq 1 ]]; then
          printf '[%s/%s]\n' "$fmt" "$lane"
        else
          printf '\n[%s/%s]\n' "$fmt" "$lane"
        fi
      fi

      if [[ -n "$missing_input" ]]; then
        while IFS= read -r base; do
          [[ -z "$base" ]] && continue
          echo "  [error] expected exists but input missing:"
          echo "    - $base"
          fail=1
        done <<< "$missing_input"
      fi

      if [[ -n "$missing_expected" ]]; then
        echo "  [error] input exists but expected missing:"
        while IFS= read -r base; do
          [[ -z "$base" ]] && continue
          echo "    - $base"
        done <<< "$missing_expected"
        fail=1
      fi
    done
  done

  if [[ "$fail" -ne 0 ]]; then
    printf '\nSAMPLE INTEGRITY CHECK FAILED\n'
    exit 1
  fi

  printf 'SAMPLE INTEGRITY CHECK PASSED\n'
}

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

lane_input_dir() {
  local fmt="$1"
  local lane="$2"
  printf '%s/%s/%s' "$SAMPLES_DIR" "$fmt" "$lane"
}

lane_expected_dir() {
  local fmt="$1"
  local lane="$2"
  printf '%s/%s/expected/%s' "$SAMPLES_DIR" "$fmt" "$lane"
}

discover_samples() {
  local fmt="$1"
  local lane="$2"
  local in_dir
  in_dir="$(lane_input_dir "$fmt" "$lane")"
  if [[ ! -d "$in_dir" ]]; then
    return 0
  fi
  case "$fmt" in
    docx) find "$in_dir" -type f -name "*.docx" -print ;;
    pdf) find "$in_dir" -type f -name "*.pdf" -print ;;
    xlsx) find "$in_dir" -type f -name "*.xlsx" -print ;;
    pptx) find "$in_dir" -type f -name "*.pptx" -print ;;
    html) find "$in_dir" -type f \( -name "*.html" -o -name "*.htm" \) -print ;;
    csv) find "$in_dir" -type f -name "*.csv" -print ;;
    tsv) find "$in_dir" -type f -name "*.tsv" -print ;;
    txt) find "$in_dir" -type f -name "*.txt" -print ;;
    xml) find "$in_dir" -type f -name "*.xml" -print ;;
    json) find "$in_dir" -type f -name "*.json" -print ;;
    jsonl) find "$in_dir" -type f -name "*.jsonl" -print ;;
    ndjson) find "$in_dir" -type f -name "*.ndjson" -print ;;
    yaml) find "$in_dir" -type f \( -name "*.yaml" -o -name "*.yml" \) -print ;;
    markdown) find "$in_dir" -type f \( -name "*.md" -o -name "*.markdown" \) -print ;;
    zip) find "$in_dir" -type f -name "*.zip" -print ;;
    epub) find "$in_dir" -type f -name "*.epub" -print ;;
    *) return 0 ;;
  esac
}

resolve_expected_fixture() {
  local fmt="$1"
  local lane="$2"
  local rel_no_ext="$3"
  case "$lane" in
    markdown)
      printf '%s/%s.md\n' "$(lane_expected_dir "$fmt" "$lane")" "$rel_no_ext"
      ;;
    rag)
      printf '%s/%s.rag.json\n' "$(lane_expected_dir "$fmt" "$lane")" "$rel_no_ext"
      ;;
    assets)
      printf '%s/%s/result.md\n' "$(lane_expected_dir "$fmt" "$lane")" "$rel_no_ext"
      ;;
  esac
}

sample_failure_slug() {
  local scope="$1"
  local slug
  slug="$(printf '%s' "$scope" | tr '/: ' '___')"
  printf '%s' "$slug"
}

copy_if_exists() {
  local from="$1"
  local to="$2"
  if [[ -f "$from" ]]; then
    mkdir -p "$(dirname "$to")"
    cp "$from" "$to"
  fi
}

copy_dir_if_exists() {
  local from="$1"
  local to="$2"
  if [[ -d "$from" ]]; then
    mkdir -p "$(dirname "$to")"
    rm -rf "$to"
    cp -R "$from" "$to"
  fi
}

single_line_note() {
  local raw="${1-}"
  raw="${raw//$'\r'/ }"
  raw="${raw//$'\n'/ }"
  raw="$(printf '%s' "$raw" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  printf '%s' "$raw"
}

write_failure_report() {
  local report_path="$1"
  local scope="$2"
  local fmt="$3"
  local input_path="$4"
  local expected_path="$5"
  local actual_path="$6"
  local diff_path="$7"
  local stdout_path="$8"
  local stderr_path="$9"
  local note="${10}"
  local status_label="${11}"

  mkdir -p "$(dirname "$report_path")"
  {
    echo "# Failure Report"
    echo
    echo "- Scope: $scope"
    echo "- Format: $fmt"
    echo "- Status: $status_label"
    echo "- Input: $input_path"
    if [[ -n "$expected_path" ]]; then
      echo "- Expected: $expected_path"
    fi
    if [[ -n "$actual_path" ]]; then
      echo "- Actual: $actual_path"
    fi
    if [[ -n "$diff_path" ]]; then
      echo "- Diff: $diff_path"
    fi
    if [[ -n "$stdout_path" ]]; then
      echo "- Stdout: $stdout_path"
    fi
    if [[ -n "$stderr_path" ]]; then
      echo "- Stderr: $stderr_path"
      if [[ -f "$stderr_path" ]]; then
        local stderr_preview
        stderr_preview="$(sed -n '1,5p' "$stderr_path" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
        if [[ -n "$stderr_preview" ]]; then
          echo "- Stderr preview: $stderr_preview"
        fi
      fi
    fi
    echo "- Note: $note"
  } > "$report_path"
}

extract_asset_refs() {
  local dir="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -o --no-filename "assets/[A-Za-z0-9_./-]+" "$dir" -g '*.md' | sort -u || true
    return
  fi
  find "$dir" -type f -name '*.md' -print0 \
    | xargs -0 grep -hoE "assets/[A-Za-z0-9_./-]+" \
    | sort -u || true
}

check_asset_refs_or_record() {
  local scope="$1"
  local out_dir="$2"
  local refs ref missing=0
  refs="$(extract_asset_refs "$out_dir")"
  if [[ -z "${refs//[$'\t\r\n ']}" ]]; then
    return 0
  fi
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -f "$out_dir/$ref" ]]; then
      validation_record_failure "$scope" "$scope" "" "$out_dir/$ref" "missing asset"
      missing=1
    fi
  done <<< "$refs"
  return "$missing"
}

assets_dirs_equal() {
  local expected_dir="$1"
  local actual_dir="$2"
  python3 - "$expected_dir" "$actual_dir" <<'PY'
import filecmp
import sys
from pathlib import Path

expected = Path(sys.argv[1])
actual = Path(sys.argv[2])

def walk(root: Path):
    if not root.exists():
        return {}
    out = {}
    for path in sorted(root.rglob("*")):
        if path.is_file():
            out[path.relative_to(root).as_posix()] = path.read_bytes()
    return out

left = walk(expected)
right = walk(actual)
if left.keys() != right.keys():
    print("asset file set mismatch")
    sys.exit(1)
for key in left:
    if left[key] != right[key]:
        print(f"asset bytes mismatch: {key}")
        sys.exit(1)
print("ok")
PY
}

validate_rag_fixture() {
  local actual_json="$1"
  local expected_json="$2"
  local scope="$3"
  python3 "$RAG_CHECKER" "$actual_json" "$expected_json" "$scope"
}

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
