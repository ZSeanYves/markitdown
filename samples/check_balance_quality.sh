#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/samples/helpers/shared/cli_runner.sh"
source "$ROOT/samples/helpers/shared/external_signal_suite.sh"

QUALITY_CHECK="$ROOT/samples/helpers/quality/check.sh"
QUALITY_LAB_ROOT="${MARKITDOWN_QUALITY_LAB:-$ROOT/markitdown-quality-lab}"
QUALITY_CORPUS_ROOT="$QUALITY_LAB_ROOT/external_quality"
QUALITY_MANIFEST_PATH="$QUALITY_CORPUS_ROOT/MANIFEST.tsv"
QUALITY_TMP_ROOT="${QUALITY_TMP_ROOT:-$ROOT/.tmp/quality}"
declare -a ORIGINAL_ARGS=()
if [[ $# -gt 0 ]]; then
  ORIGINAL_ARGS=("$@")
fi

SIGNAL_SUITE_ENTRYPOINT="samples/check_balance_quality.sh"
SIGNAL_SUITE_USAGE_TITLE="Run the external balance-quality validation entrypoint."
SIGNAL_SUITE_CORPUS_LABEL="external balance-quality"
SIGNAL_SUITE_CORPUS_DIRNAME="external_quality"
SIGNAL_SUITE_SUPPORTED_FORMATS="asciidoc docx eml epub html ipynb json jsonl m4a markdown mp3 ndjson ocr odp ods odt pdf pptx rst srt tex toml tsv txt vtt wav xlsx xml yaml zip"
SIGNAL_SUITE_USAGE_EXTRA=$'  * unsupported formats fail closed and print the supported balance-quality format list\n'
SIGNAL_SUITE_USAGE_EXAMPLES=$'  ./samples/check_balance_quality.sh\n  ./samples/check_balance_quality.sh --pdf\n  ./samples/check_balance_quality.sh --txt\n  ./samples/check_balance_quality.sh --docx --source markitdown_repo_pdf_samples'
SIGNAL_SUITE_TMP_ROOT="$QUALITY_TMP_ROOT"
SIGNAL_SUITE_RUN_ID_PREFIX="quality"
SIGNAL_SUITE_RESULT_PREFIX="balance-quality"
SIGNAL_SUITE_CHECK="$QUALITY_CHECK"
SIGNAL_SUITE_LAB_ROOT="$QUALITY_LAB_ROOT"
SIGNAL_SUITE_CORPUS_ROOT="$QUALITY_CORPUS_ROOT"
SIGNAL_SUITE_MANIFEST_PATH="$QUALITY_MANIFEST_PATH"
SIGNAL_SUITE_SUMMARY_INTRO="External balance-quality rows from ./markitdown-quality-lab. This suite validates the balance product surface only; accurate-tagged rows must live in ./markitdown-quality-lab/external_accurate."
SIGNAL_SUITE_MISSING_TITLE="EXTERNAL BALANCE-QUALITY CORPUS NOT FOUND"
SIGNAL_SUITE_MISSING_HINTS=$'place markitdown-quality-lab at the official repo-root location\nclone: git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab\nofficial location: ./markitdown-quality-lab\nlocal-only validation: bash samples/check_balance.sh'
SIGNAL_SUITE_FORBID_FEATURE="accurate"

signal_suite_before_run() {
  local _run_dir="$1"
  local log_dir="$2"
  local _run_label="$3"
  local preflight_log_path="$log_dir/preflight.log"
  if ! (
    echo "preflight: checking CLI runner"
    resolve_markitdown_cli >/dev/null || exit 1
    echo "preflight: ok"
    echo "runner: ${CLI_RUNNER_KIND:-none}"
    echo "cli: ${CLI_BIN:-unset}"
  ) >"$preflight_log_path" 2>&1; then
    echo "balance-quality: preflight failed"
    echo "run: $(display_path "$ROOT" "$_run_dir")"
    echo "preflight-log: $(display_path "$ROOT" "$preflight_log_path")"
    sed -n '1,40p' "$preflight_log_path" >&2 || true
    exit 1
  fi
}

signal_suite_write_summary_extra() {
  local preflight_log_path="$LOG_DIR/preflight.log"
  echo
  echo "## Preflight"
  echo
  echo "- Log: $(display_path "$ROOT" "$preflight_log_path")"
}

signal_suite_run "$@"
