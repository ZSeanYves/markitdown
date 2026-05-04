#!/usr/bin/env bash

SAMPLES_VERBOSE="${SAMPLES_VERBOSE:-${VERBOSE:-0}}"
CLI_RUNNER_KIND=""
CLI_RUNNER_NOTE=""
CLI_BIN=""

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
  if [[ -n "${MARKITDOWN_CLI:-}" ]]; then
    if [[ ! -x "$MARKITDOWN_CLI" ]]; then
      echo "MARKITDOWN_CLI is set but not executable: $MARKITDOWN_CLI" >&2
      return 1
    fi
    CLI_RUNNER_KIND="override"
    CLI_BIN="$MARKITDOWN_CLI"
    return 0
  fi

  local candidates=(
    "$ROOT/_build/native/debug/build/cli/cli.exe"
    "$ROOT/_build/native/release/build/cli/cli.exe"
    "$ROOT/target/native/debug/build/cli/cli"
    "$ROOT/target/native/release/build/cli/cli"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -x "$candidate" ]] || continue
    if probe_markitdown_cli "$candidate"; then
      CLI_RUNNER_KIND="prebuilt-native"
      CLI_BIN="$candidate"
      return 0
    fi
    CLI_RUNNER_NOTE="native probe failed; falling back to moon run"
  done

  CLI_RUNNER_KIND="moon-run"
  CLI_BIN=""
  return 0
}

run_markitdown_cli() {
  if [[ "${CLI_RUNNER_KIND:-moon-run}" == "prebuilt-native" || "${CLI_RUNNER_KIND:-moon-run}" == "override" ]]; then
    "$CLI_BIN" "$@"
  else
    moon run "$ROOT/cli" -- "$@"
  fi
}

validation_probe_cases() {
  cat <<'EOF'
samples/main_process/docx/docx_comment_basic.docx|samples/main_process/expected/docx/docx_comment_basic.md
samples/main_process/pptx/pptx_hidden_slide_basic.pptx|samples/main_process/expected/pptx/pptx_hidden_slide_basic.md
samples/main_process/pdf/pdf_page_noise_cleanup.pdf|samples/main_process/expected/pdf/pdf_page_noise_cleanup.md
EOF
}

probe_markitdown_cli() {
  local cli_bin="$1"
  local tmp_root="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
  local probe_dir
  probe_dir="$(sample_make_isolated_tmp_dir "$tmp_root" "cli_probe")"
  local status=0
  local input_rel expected_rel input_abs expected_abs out

  while IFS='|' read -r input_rel expected_rel; do
    [[ -n "$input_rel" ]] || continue
    input_abs="$ROOT/$input_rel"
    expected_abs="$ROOT/$expected_rel"
    out="$probe_dir/$(basename "${input_rel%.*}").md"
    if ! "$cli_bin" normal "$input_abs" "$out" >/dev/null 2>&1; then
      status=1
      break
    fi
    if ! diff -u "$expected_abs" "$out" >/dev/null 2>&1; then
      status=1
      break
    fi
  done < <(validation_probe_cases)

  rm -rf "$probe_dir"
  return "$status"
}

validation_progress_init() {
  VALIDATION_LABEL="${1-}"
  VALIDATION_TOTAL="${2-0}"
  VALIDATION_CURRENT=0
  VALIDATION_HAS_FAILURES=0
  VALIDATION_FAILURES=()
  VALIDATION_TTY=0
  if [[ -t 1 ]]; then
    VALIDATION_TTY=1
  fi
}

validation_progress_render() {
  local current="$1"
  local total="$2"
  local item="$3"
  local percent="100"
  if [[ "$total" -gt 0 ]]; then
    percent=$(( current * 100 / total ))
  fi
  local line="[$VALIDATION_LABEL] $current/$total ${percent}% $item"

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "$line"
    return
  fi

  if [[ "$VALIDATION_TTY" -eq 1 ]]; then
    printf '\r%-120s' "$line"
  else
    if (( current == 1 || current == total || current % 25 == 0 )); then
      echo "$line"
    fi
  fi
}

validation_progress_step() {
  VALIDATION_CURRENT=$((VALIDATION_CURRENT + 1))
  validation_progress_render "$VALIDATION_CURRENT" "$VALIDATION_TOTAL" "$1"
}

validation_progress_done() {
  if ! validation_bool_enabled "$SAMPLES_VERBOSE" && [[ "$VALIDATION_TTY" -eq 1 ]]; then
    printf '\n'
  fi
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
