#!/usr/bin/env bash

source "$ROOT/tools/regression/lib/shared/progress.sh"
source "$ROOT/tools/regression/lib/shared/tmp.sh"

SAMPLES_VERBOSE="${SAMPLES_VERBOSE:-${VERBOSE:-0}}"
CLI_RUNNER_KIND=""
CLI_RUNNER_NOTE=""
CLI_BIN=""
CLI_PACKAGE="cli"
CLI_MODULE_ROOT=""
CLI_STALENESS_SENTINEL=""

runner_class_for_kind() {
  case "${1-}" in
    prebuilt)
      printf 'native-binary'
      ;;
    override)
      printf 'user-override'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

validation_bool_enabled() {
  local raw="${1-}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    1|true|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_markitdown_cli() {
  resolve_markitdown_package_cli "cli" "MARKITDOWN_CLI" || return 1
}

resolve_markitdown_package_cli() {
  local package="${1-}"
  local override_env="${2-}"
  local override_bin=""

  CLI_PACKAGE="$package"
  CLI_MODULE_ROOT="$(markitdown_package_module_root "$package")"
  CLI_RUNNER_KIND=""
  CLI_RUNNER_NOTE=""
  CLI_BIN=""

  if [[ -n "$override_env" ]]; then
    override_bin="${!override_env:-}"
  fi

  if [[ -n "$override_bin" ]]; then
    if [[ ! -x "$override_bin" ]]; then
      echo "$override_env is set but not executable: $override_bin" >&2
      return 1
    fi
    CLI_RUNNER_KIND="override"
    CLI_BIN="$override_bin"
    return 0
  fi

  if resolve_probe_validated_native_cli_with_retries "$package" 1; then
    return 0
  fi

  if [[ -n "$CLI_STALENESS_SENTINEL" ]]; then
    echo "native runner for $package is missing or stale; newer source detected at $(basename "$CLI_STALENESS_SENTINEL")" >&2
  elif [[ -n "$CLI_RUNNER_NOTE" ]]; then
    echo "$CLI_RUNNER_NOTE" >&2
  else
    echo "failed to locate a working native runner for $package" >&2
  fi
  echo "run 'moon build $package --target native' and retry" >&2
  return 1
}

validation_cli_tmp_root() {
  local base="${MARKITDOWN_CLI_TMP_DIR:-${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}}"
  printf '%s' "$base"
}

markitdown_runner_cwd() {
  local base="${MARKITDOWN_RUNNER_CWD:-}"
  if [[ -z "$base" ]]; then
    return 1
  fi
  printf '%s' "$base"
}

markitdown_package_module_root() {
  printf '%s' "$ROOT"
}

run_markitdown_cli() {
  local cli_tmp_root
  cli_tmp_root="$(validation_cli_tmp_root)"
  local module_root="${MARKITDOWN_MODULE_ROOT:-$CLI_MODULE_ROOT}"
  if [[ "${CLI_RUNNER_KIND:-}" == "prebuilt" || "${CLI_RUNNER_KIND:-}" == "override" ]]; then
    local runner_cwd=""
    runner_cwd="$(markitdown_runner_cwd 2>/dev/null || true)"
    if [[ -n "$runner_cwd" ]]; then
      mkdir -p "$runner_cwd"
      (
        cd "$runner_cwd" || exit 1
        MARKITDOWN_MODULE_ROOT="$module_root" MARKITDOWN_TMP_DIR="$cli_tmp_root" "$CLI_BIN" "$@"
      )
      return $?
    fi
    MARKITDOWN_MODULE_ROOT="$module_root" MARKITDOWN_TMP_DIR="$cli_tmp_root" "$CLI_BIN" "$@"
    return $?
  fi
  echo "CLI runner is not configured. Run 'moon build $CLI_PACKAGE --target native' or set MARKITDOWN_CLI." >&2
  return 1
}

markitdown_cli_candidates() {
  local package="${1-}"
  cat <<EOF
$CLI_MODULE_ROOT/_build/native/debug/build/$package/$package.exe
$CLI_MODULE_ROOT/_build/native/release/build/$package/$package.exe
$CLI_MODULE_ROOT/target/native/debug/build/$package/$package
$CLI_MODULE_ROOT/target/native/release/build/$package/$package
EOF
}

native_cli_staleness_sentinel() {
  local package="${1-}"
  case "$package" in
    cli)
      printf '%s' "$ROOT/cli/cli.mbt"
      ;;
    *)
      return 1
      ;;
  esac
}

native_cli_source_roots() {
  local package="${1-}"
  case "$package" in
    cli)
      cat <<EOF
$ROOT/cli
$ROOT/container
$ROOT/convert
$ROOT/core
$ROOT/format_readers
$ROOT/formats
$ROOT/input
$ROOT/parser
$ROOT/pipeline
$ROOT/product
$ROOT/rag
$ROOT/render
$ROOT/runtime
$ROOT/moon.mod.json
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

native_cli_has_newer_source() {
  local candidate="${1-}"
  local package="${2-}"
  local root_path
  while IFS= read -r root_path; do
    [[ -n "$root_path" ]] || continue
    if [[ -f "$root_path" ]]; then
      if [[ "$root_path" -nt "$candidate" ]]; then
        CLI_STALENESS_SENTINEL="$root_path"
        return 0
      fi
      continue
    fi
    [[ -d "$root_path" ]] || continue
    local newer_file=""
    newer_file="$(find "$root_path" -type f \
      \( -name '*.mbt' -o -name 'moon.pkg' -o -name 'moon.pkg.json' -o -name '*.c' \) \
      ! -name '*_test.mbt' \
      ! -name '*_wbtest.mbt' \
      -newer "$candidate" -print -quit 2>/dev/null || true)"
    if [[ -n "$newer_file" ]]; then
      CLI_STALENESS_SENTINEL="$newer_file"
      return 0
    fi
  done < <(native_cli_source_roots "$package")
  return 1
}

native_cli_is_fresh_enough() {
  local candidate="${1-}"
  local package="${2-}"
  local sentinel=""
  sentinel="$(native_cli_staleness_sentinel "$package" 2>/dev/null || true)"
  [[ -f "$candidate" ]] || return 1
  if [[ -n "$sentinel" && -f "$sentinel" && "$candidate" -nt "$sentinel" ]] && \
    ! native_cli_has_newer_source "$candidate" "$package"; then
    CLI_STALENESS_SENTINEL=""
    return 0
  fi
  if [[ -z "$CLI_STALENESS_SENTINEL" && -n "$sentinel" ]]; then
    CLI_STALENESS_SENTINEL="$sentinel"
  fi
  return 1
}

resolve_probe_validated_native_cli() {
  local package="${1-}"
  local candidate
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    [[ -x "$candidate" ]] || continue
    if ! native_cli_is_fresh_enough "$candidate" "$package"; then
      continue
    fi
    if probe_markitdown_cli "$package" "$candidate"; then
      CLI_RUNNER_KIND="prebuilt"
      CLI_BIN="$candidate"
      CLI_RUNNER_NOTE=""
      return 0
    fi
    CLI_RUNNER_NOTE="native runner for $package exists at $candidate but failed the validation probe"
  done < <(markitdown_cli_candidates "$package")
  return 1
}

resolve_probe_validated_native_cli_with_retries() {
  local package="${1-}"
  local attempts="${2:-1}"
  local attempt=1

  while (( attempt <= attempts )); do
    if resolve_probe_validated_native_cli "$package"; then
      return 0
    fi
    if (( attempt < attempts )); then
      sleep 0.2
    fi
    attempt=$((attempt + 1))
  done

  return 1
}

markitdown_runner_command_prefix() {
  if [[ "${CLI_RUNNER_KIND:-}" == "prebuilt" || "${CLI_RUNNER_KIND:-}" == "override" ]]; then
    printf '%s' "$CLI_BIN"
    return 0
  fi
  printf '<missing-native-cli:%s>' "$CLI_PACKAGE"
}

validation_probe_cases() {
  cat <<'EOF'
samples/fixtures/contracts/txt/txt_plain.txt|txt_plain
samples/fixtures/contracts/csv/csv_markdown_pipes.csv|csv_markdown_pipes
samples/fixtures/contracts/tsv/tsv_markdown_pipes.tsv|tsv_markdown_pipes
samples/fixtures/contracts/json/json_object_basic.json|json_object_basic
samples/fixtures/contracts/jsonl/jsonl_records_basic.jsonl|jsonl_records_basic
samples/fixtures/contracts/ndjson/ndjson_records_basic.ndjson|ndjson_records_basic
EOF
}

probe_markitdown_cli() {
  local package="$1"
  local cli_bin="$2"
  local probe_tmp_root
  probe_tmp_root="$(validation_cli_tmp_root)"
  if [[ "$package" != "cli" ]]; then
    return 1
  fi
  local tmp_root="$probe_tmp_root"
  local probe_dir
  probe_dir="$(sample_make_isolated_tmp_dir "$tmp_root" "cli_probe")"
  local status=0
  local input_rel stem input_abs out

  while IFS='|' read -r input_rel stem; do
    [[ -n "$input_rel" ]] || continue
    input_abs="$ROOT/$input_rel"
    out="$probe_dir/$stem.md"
    if ! MARKITDOWN_TMP_DIR="$probe_tmp_root" "$cli_bin" balance "$input_abs" "$out" >/dev/null 2>&1; then
      status=1
      break
    fi
    if [[ ! -s "$out" ]]; then
      status=1
      break
    fi
  done < <(validation_probe_cases)

  if [[ "$status" -eq 0 ]]; then
    local help_out
    help_out="$(MARKITDOWN_TMP_DIR="$probe_tmp_root" "$cli_bin" --help 2>&1)" || status=1
    if [[ "$status" -eq 0 ]]; then
      if ! grep -Fq -- 'markitdown-mb [balance|accurate|stream] [--format <format>]' <<<"$help_out"; then
        status=1
      elif ! grep -Fq -- 'Capability groups: Core, Office, Containers, Media, PdfOcr.' <<<"$help_out"; then
        status=1
      elif ! grep -Fq -- 'All other formats fail closed in this build.' <<<"$help_out"; then
        status=1
      elif ! grep -Fq -- 'Direct image input uses local OCR by default;' <<<"$help_out"; then
        status=1
      fi
    fi
  fi

  if [[ "$status" -eq 0 ]]; then
    local accurate_input="$ROOT/samples/fixtures/contracts/txt/txt_plain.txt"
    local accurate_output="$probe_dir/accurate/txt_plain.md"
    local accurate_error="$probe_dir/accurate/txt_plain.stderr"
    mkdir -p "$probe_dir/accurate"
    if MARKITDOWN_TMP_DIR="$probe_tmp_root" "$cli_bin" accurate "$accurate_input" "$accurate_output" >/dev/null 2>"$accurate_error"; then
      status=1
    elif [[ -e "$accurate_output" ]]; then
      status=1
    elif ! grep -Fq -- $'accurate mode is unsupported for `txt`' "$accurate_error"; then
      status=1
    fi
  fi

  if [[ "$status" -eq 0 ]]; then
    local contract_dir="$probe_dir/contract"
    local contract_input="$ROOT/samples/fixtures/contracts/txt/txt_plain.txt"
    local contract_output="$contract_dir/txt_plain.md"
    mkdir -p "$contract_dir"
    if ! MARKITDOWN_TMP_DIR="$probe_tmp_root" "$cli_bin" balance "$contract_input" "$contract_output" >/dev/null 2>&1; then
      status=1
    elif [[ -e "$contract_dir/metadata/txt_plain.metadata.json" ]]; then
      status=1
    fi
  fi

  rm -rf "$probe_dir"
  return "$status"
}

validation_progress_init() {
  : "${1-}"
  VALIDATION_TOTAL="${2-0}"
  VALIDATION_CURRENT=0
  VALIDATION_HAS_FAILURES=0
  VALIDATION_FAILURES=()
}

validation_progress_render() {
  local current="$1"
  local total="$2"
  local status="$3"
  local item="$4"

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "progress: $current/$total $status $item"
    return
  fi

  sample_progress_update "$current" "$total" "$status" "$item"
}

validation_progress_step() {
  VALIDATION_CURRENT=$((VALIDATION_CURRENT + 1))
  validation_progress_render "$VALIDATION_CURRENT" "$VALIDATION_TOTAL" "running" "$1"
}

validation_progress_step_status() {
  local status="$1"
  local item="${2-}"
  VALIDATION_CURRENT=$((VALIDATION_CURRENT + 1))
  validation_progress_render "$VALIDATION_CURRENT" "$VALIDATION_TOTAL" "$status" "$item"
}

validation_progress_zero() {
  local status="${1:-no matching rows}"
  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "progress: 0/0 $status"
    return
  fi
  sample_progress_zero "$status"
}

validation_progress_done() {
  local status="${1:-done}"
  if [[ "${VALIDATION_TOTAL:-0}" -eq 0 ]]; then
    return
  fi
  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "progress: $VALIDATION_CURRENT/$VALIDATION_TOTAL $status"
    return
  fi
  sample_progress_finish "$VALIDATION_CURRENT" "$VALIDATION_TOTAL" "$status"
}

validation_record_failure() {
  local scope="$1"
  local input="$2"
  local expected="$3"
  local actual="$4"
  local note="${5-}"
  local kind="${6-}"
  local diff_path="${7-}"
  local stdout_path="${8-}"
  local stderr_path="${9-}"
  local report_path="${10-}"
  VALIDATION_HAS_FAILURES=1
  VALIDATION_FAILURES+=("$scope|$input|$expected|$actual|$note|$kind|$diff_path|$stdout_path|$stderr_path|$report_path")
}

validation_print_failures() {
  local idx=0
  local record scope input expected actual note kind diff_path stdout_path stderr_path report_path
  for record in "${VALIDATION_FAILURES[@]}"; do
    idx=$((idx + 1))
    IFS='|' read -r scope input expected actual note kind diff_path stdout_path stderr_path report_path <<< "$record"
    echo "$idx. $scope"
    [[ -n "$input" ]] && echo "   input: $input"
    [[ -n "$expected" ]] && echo "   expected: $expected"
    [[ -n "$actual" ]] && echo "   actual: $actual"
    [[ -n "$note" ]] && echo "   note: $note"
    [[ -n "$diff_path" ]] && echo "   diff: $diff_path"
    [[ -n "$stdout_path" ]] && echo "   stdout: $stdout_path"
    [[ -n "$stderr_path" ]] && echo "   stderr: $stderr_path"
    [[ -n "$report_path" ]] && echo "   report: $report_path"
  done
}

validation_finish() {
  local success_message="$1"
  local failure_message="$2"
  validation_progress_done
  if [[ "$VALIDATION_HAS_FAILURES" -ne 0 ]]; then
    echo "$failure_message ($VALIDATION_TOTAL samples, ${#VALIDATION_FAILURES[@]} failures)"
    validation_print_failures
    return 1
  fi
  echo "$success_message ($VALIDATION_TOTAL samples, 0 failures)"
  return 0
}

validation_diff_or_record() {
  local scope="$1"
  local input="$2"
  local expected="$3"
  local actual="$4"
  local diff_path="$5"
  : "$scope" "$input"
  local diff_dir
  diff_dir="$(dirname "$diff_path")"
  mkdir -p "$diff_dir"
  local tmp_diff="$diff_path.tmp"
  if diff -u "$expected" "$actual" > "$tmp_diff"; then
    rm -f "$tmp_diff"
    return 0
  fi
  mv "$tmp_diff" "$diff_path"
  return 1
}
