#!/usr/bin/env bash

source "$ROOT/samples/helpers/shared/progress_helpers.sh"

SAMPLES_VERBOSE="${SAMPLES_VERBOSE:-${VERBOSE:-0}}"
CLI_RUNNER_KIND=""
CLI_RUNNER_NOTE=""
CLI_BIN=""
CLI_PACKAGE="cli"
CLI_NATIVE_BUILD_ATTEMPTED=0
CLI_NATIVE_BUILD_ATTEMPTED_PACKAGE=""
PDF_CLI_RUNNER_KIND=""
PDF_CLI_RUNNER_NOTE=""
PDF_CLI_BIN=""
ZIP_CLI_RUNNER_KIND=""
ZIP_CLI_RUNNER_NOTE=""
ZIP_CLI_BIN=""

runner_class_for_kind() {
  case "${1-}" in
    prebuilt-native)
      printf 'native-binary'
      ;;
    moon-run)
      printf 'moon-run-fallback'
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
  resolve_markitdown_pdf_cli || return 1
  PDF_CLI_RUNNER_KIND="$CLI_RUNNER_KIND"
  PDF_CLI_RUNNER_NOTE="$CLI_RUNNER_NOTE"
  PDF_CLI_BIN="$CLI_BIN"
  resolve_markitdown_zip_cli || return 1
  ZIP_CLI_RUNNER_KIND="$CLI_RUNNER_KIND"
  ZIP_CLI_RUNNER_NOTE="$CLI_RUNNER_NOTE"
  ZIP_CLI_BIN="$CLI_BIN"
  resolve_markitdown_package_cli "cli" "MARKITDOWN_CLI" || return 1
  if [[ -n "${PDF_CLI_BIN:-}" ]]; then
    if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
      CLI_RUNNER_NOTE="$CLI_RUNNER_NOTE; bundled pdf component: $PDF_CLI_BIN"
    else
      CLI_RUNNER_NOTE="bundled pdf component: $PDF_CLI_BIN"
    fi
  fi
  if [[ -n "${ZIP_CLI_BIN:-}" ]]; then
    if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
      CLI_RUNNER_NOTE="$CLI_RUNNER_NOTE; bundled zip component: $ZIP_CLI_BIN"
    else
      CLI_RUNNER_NOTE="bundled zip component: $ZIP_CLI_BIN"
    fi
  fi
}

resolve_markitdown_pdf_cli() {
  resolve_markitdown_package_cli "pdf" "MARKITDOWN_PDF_CLI"
}

resolve_markitdown_zip_cli() {
  resolve_markitdown_package_cli "zip" "MARKITDOWN_ZIP_CLI"
}

resolve_markitdown_debug_cli() {
  resolve_markitdown_package_cli "debug" "MARKITDOWN_DEBUG_CLI"
}

resolve_markitdown_bench_cli() {
  resolve_markitdown_package_cli "bench" "MARKITDOWN_BENCH_CLI"
}

resolve_markitdown_package_cli() {
  local package="${1-}"
  local override_env="${2-}"
  local override_bin=""

  CLI_PACKAGE="$package"
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

  if build_markitdown_cli_native_once "$package"; then
    if resolve_probe_validated_native_cli_with_retries "$package" 25; then
      CLI_RUNNER_NOTE="built native CLI once via moon build $package --target native"
      return 0
    fi
  fi

  if validation_bool_enabled "${MARKITDOWN_ALLOW_MOON_RUN:-0}"; then
    CLI_RUNNER_KIND="moon-run"
    CLI_RUNNER_NOTE="manual moon run fallback enabled via MARKITDOWN_ALLOW_MOON_RUN=1; timings are not native product-path"
    CLI_BIN=""
    return 0
  fi

  echo "failed to locate a working native runner for $package; run 'moon build $package --target native' and retry" >&2
  return 1
}

validation_cli_tmp_root() {
  local base="${MARKITDOWN_CLI_TMP_DIR:-${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}}"
  printf '%s' "$base"
}

run_markitdown_cli() {
  local cli_tmp_root
  cli_tmp_root="$(validation_cli_tmp_root)"
  if [[ "${CLI_RUNNER_KIND:-moon-run}" == "prebuilt-native" || "${CLI_RUNNER_KIND:-moon-run}" == "override" ]]; then
    if [[ "${CLI_PACKAGE:-cli}" == "cli" && -n "${PDF_CLI_BIN:-}" ]]; then
      MARKITDOWN_TMP_DIR="$cli_tmp_root" MARKITDOWN_PDF_CLI="$PDF_CLI_BIN" MARKITDOWN_ZIP_CLI="${ZIP_CLI_BIN:-${MARKITDOWN_ZIP_CLI:-}}" "$CLI_BIN" "$@"
    else
      MARKITDOWN_TMP_DIR="$cli_tmp_root" "$CLI_BIN" "$@"
    fi
  else
    if [[ "${CLI_PACKAGE:-cli}" == "cli" && -n "${PDF_CLI_BIN:-}" ]]; then
      MARKITDOWN_TMP_DIR="$cli_tmp_root" MARKITDOWN_PDF_CLI="$PDF_CLI_BIN" MARKITDOWN_ZIP_CLI="${ZIP_CLI_BIN:-${MARKITDOWN_ZIP_CLI:-}}" moon run "$ROOT/$CLI_PACKAGE" -- "$@"
    else
      MARKITDOWN_TMP_DIR="$cli_tmp_root" moon run "$ROOT/$CLI_PACKAGE" -- "$@"
    fi
  fi
}

run_markitdown_pdf_cli() {
  run_markitdown_cli "$@"
}

run_markitdown_zip_cli() {
  run_markitdown_cli "$@"
}

run_markitdown_debug_cli() {
  run_markitdown_cli "$@"
}

run_markitdown_bench_cli() {
  run_markitdown_cli "$@"
}

markitdown_cli_candidates() {
  local package="${1-}"
  cat <<EOF
$ROOT/_build/native/debug/build/$package/$package.exe
$ROOT/_build/native/release/build/$package/$package.exe
$ROOT/target/native/debug/build/$package/$package
$ROOT/target/native/release/build/$package/$package
EOF
}

resolve_probe_validated_native_cli() {
  local package="${1-}"
  local candidate
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    [[ -x "$candidate" ]] || continue
    if probe_markitdown_cli "$package" "$candidate"; then
      CLI_RUNNER_KIND="prebuilt-native"
      CLI_BIN="$candidate"
      return 0
    fi
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

build_markitdown_cli_native_once() {
  local package="${1-}"
  if [[ "$CLI_NATIVE_BUILD_ATTEMPTED" -ne 0 && "$CLI_NATIVE_BUILD_ATTEMPTED_PACKAGE" == "$package" ]]; then
    return 1
  fi

  CLI_NATIVE_BUILD_ATTEMPTED=1
  CLI_NATIVE_BUILD_ATTEMPTED_PACKAGE="$package"
  echo "[markitdown-cli] building native runner once: moon build $package --target native" >&2
  (cd "$ROOT" && moon build "$package" --target native)
}

markitdown_runner_command_prefix() {
  if [[ "${CLI_RUNNER_KIND:-moon-run}" == "prebuilt-native" || "${CLI_RUNNER_KIND:-moon-run}" == "override" ]]; then
    printf '%s' "$CLI_BIN"
  else
    printf 'moon run %s/%s --' "$ROOT" "$CLI_PACKAGE"
  fi
}

validation_probe_cases() {
  cat <<'EOF'
samples/main_process/docx/docx_comment_basic.docx|samples/main_process/docx/expected/docx_comment_basic.md
samples/main_process/pptx/pptx_hidden_slide_basic.pptx|samples/main_process/pptx/expected/pptx_hidden_slide_basic.md
samples/main_process/pdf/pdf_page_noise_cleanup.pdf|samples/main_process/pdf/expected/pdf_page_noise_cleanup.md
samples/main_process/zip/zip_basic_structured.zip|samples/main_process/zip/expected/zip_basic_structured.md
EOF
}

probe_markitdown_cli() {
  local package="$1"
  local cli_bin="$2"
  local probe_tmp_root
  probe_tmp_root="$(validation_cli_tmp_root)"
  if [[ "$package" == "bench" ]]; then
    MARKITDOWN_TMP_DIR="$probe_tmp_root" "$cli_bin" _bench-noop >/dev/null 2>&1
    return $?
  fi
  if [[ "$package" == "pdf" ]]; then
    local pdf_input="$ROOT/samples/main_process/pdf/text_simple.pdf"
    local pdf_expected="$ROOT/samples/main_process/pdf/expected/text_simple.md"
    local pdf_tmp_root="$probe_tmp_root"
    local pdf_probe_dir
    pdf_probe_dir="$(sample_make_isolated_tmp_dir "$pdf_tmp_root" "pdf_probe")"
    local pdf_out="$pdf_probe_dir/text_simple.md"
    local status=0
    if ! MARKITDOWN_TMP_DIR="$probe_tmp_root" "$cli_bin" "$pdf_input" "$pdf_out" >/dev/null 2>&1; then
      status=1
    elif ! diff -u "$pdf_expected" "$pdf_out" >/dev/null 2>&1; then
      status=1
    fi
    rm -rf "$pdf_probe_dir"
    return "$status"
  fi
  if [[ "$package" == "zip" ]]; then
    local zip_input="$ROOT/samples/main_process/zip/zip_basic_structured.zip"
    local zip_expected="$ROOT/samples/main_process/zip/expected/zip_basic_structured.md"
    local zip_tmp_root="$probe_tmp_root"
    local zip_probe_dir
    zip_probe_dir="$(sample_make_isolated_tmp_dir "$zip_tmp_root" "zip_probe")"
    local zip_out="$zip_probe_dir/zip_basic_structured.md"
    local status=0
    if ! MARKITDOWN_TMP_DIR="$probe_tmp_root" "$cli_bin" "$zip_input" "$zip_out" >/dev/null 2>&1; then
      status=1
    elif ! diff -u "$zip_expected" "$zip_out" >/dev/null 2>&1; then
      status=1
    fi
    rm -rf "$zip_probe_dir"
    return "$status"
  fi
  if [[ "$package" != "cli" ]]; then
    MARKITDOWN_TMP_DIR="$probe_tmp_root" "$cli_bin" --help >/dev/null 2>&1
    return $?
  fi
  local tmp_root="$probe_tmp_root"
  local probe_dir
  probe_dir="$(sample_make_isolated_tmp_dir "$tmp_root" "cli_probe")"
  local status=0
  local input_rel expected_rel input_abs expected_abs out

  while IFS='|' read -r input_rel expected_rel; do
    [[ -n "$input_rel" ]] || continue
    input_abs="$ROOT/$input_rel"
    expected_abs="$ROOT/$expected_rel"
    out="$probe_dir/$(basename "${input_rel%.*}").md"
    if ! MARKITDOWN_TMP_DIR="$probe_tmp_root" MARKITDOWN_PDF_CLI="${PDF_CLI_BIN:-${MARKITDOWN_PDF_CLI:-}}" MARKITDOWN_ZIP_CLI="${ZIP_CLI_BIN:-${MARKITDOWN_ZIP_CLI:-}}" "$cli_bin" normal "$input_abs" "$out" >/dev/null 2>&1; then
      status=1
      break
    fi
    if ! diff -u "$expected_abs" "$out" >/dev/null 2>&1; then
      status=1
      break
    fi
  done < <(validation_probe_cases)

  if [[ "$status" -eq 0 ]]; then
    local help_out
    help_out="$(MARKITDOWN_TMP_DIR="$probe_tmp_root" "$cli_bin" --help 2>&1)" || status=1
    if [[ "$status" -eq 0 ]] && ! grep -Fq -- '[--ocr-lang LANG]' <<<"$help_out"; then
      status=1
    fi
  fi

  if [[ "$status" -eq 0 ]]; then
    local contract_dir="$probe_dir/contract"
    local contract_input="$ROOT/samples/main_process/txt/txt_plain.txt"
    local contract_output="$contract_dir/txt_plain.md"
    mkdir -p "$contract_dir"
    if ! MARKITDOWN_TMP_DIR="$probe_tmp_root" MARKITDOWN_PDF_CLI="${PDF_CLI_BIN:-${MARKITDOWN_PDF_CLI:-}}" MARKITDOWN_ZIP_CLI="${ZIP_CLI_BIN:-${MARKITDOWN_ZIP_CLI:-}}" "$cli_bin" normal "$contract_input" "$contract_output" >/dev/null 2>&1; then
      status=1
    elif [[ -e "$contract_dir/metadata/txt_plain.metadata.json" ]]; then
      status=1
    fi
  fi

  rm -rf "$probe_dir"
  return "$status"
}

validation_progress_init() {
  VALIDATION_LABEL="${1-}"
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
  if [[ "${VALIDATION_TOTAL:-0}" -eq 0 ]]; then
    return
  fi
  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "progress: $VALIDATION_CURRENT/$VALIDATION_TOTAL done"
    return
  fi
  sample_progress_finish "$VALIDATION_CURRENT" "$VALIDATION_TOTAL" "done"
}

validation_record_failure() {
  local scope="$1"
  local input="$2"
  local expected="$3"
  local actual="$4"
  local note="${5-}"
  VALIDATION_HAS_FAILURES=1
  VALIDATION_FAILURES+=("$scope|$input|$expected|$actual|$note")
}

validation_print_failures() {
  local idx=0
  local record scope input expected actual note
  for record in "${VALIDATION_FAILURES[@]}"; do
    idx=$((idx + 1))
    IFS='|' read -r scope input expected actual note <<< "$record"
    echo "$idx. $scope"
    [[ -n "$input" ]] && echo "   input: $input"
    [[ -n "$expected" ]] && echo "   expected: $expected"
    [[ -n "$actual" ]] && echo "   actual: $actual"
    [[ -n "$note" ]] && echo "   note: $note"
  done
}

validation_finish() {
  local success_message="$1"
  local failure_message="$2"
  validation_progress_done
  if [[ "$VALIDATION_HAS_FAILURES" -ne 0 ]]; then
    echo "$failure_message (${#VALIDATION_FAILURES[@]} failures)"
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
  if diff -u "$expected" "$actual" > "$diff_path"; then
    return 0
  fi
  validation_record_failure "$scope" "$input" "$expected" "$actual" "diff: $diff_path"
  return 1
}
