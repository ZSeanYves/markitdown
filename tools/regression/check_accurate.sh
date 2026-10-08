#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUALITY_CHECK="$ROOT/tools/regression/lib/quality/check.sh"
QUALITY_LAB_ROOT="${MARKITDOWN_QUALITY_LAB:-$ROOT/markitdown-quality-lab}"
ACCURATE_CORPUS_ROOT="$QUALITY_LAB_ROOT/external_accurate"
ACCURATE_MANIFEST_PATH="$ACCURATE_CORPUS_ROOT/MANIFEST.tsv"
ACCURATE_TMP_ROOT="${QUALITY_TMP_ROOT:-$ROOT/.tmp/accurate}"
declare -a ORIGINAL_ARGS=()
if [[ $# -gt 0 ]]; then
  ORIGINAL_ARGS=("$@")
fi

source "$ROOT/tools/env/lib/common.sh"
source "$ROOT/tools/regression/lib/shared/cli_runner.sh"
source "$ROOT/tools/regression/lib/shared/external_signal_suite.sh"

SIGNAL_SUITE_ENTRYPOINT="tools/regression/check_accurate.sh"
SIGNAL_SUITE_USAGE_TITLE="Run the external accurate Office/document validation entrypoint."
SIGNAL_SUITE_CORPUS_LABEL="external accurate"
SIGNAL_SUITE_CORPUS_DIRNAME="external_accurate"
SIGNAL_SUITE_SUPPORTED_FORMATS="docx odp ods odt pdf pptx xlsx"
SIGNAL_SUITE_USAGE_EXTRA=$'  * validates Office/ODF/document accurate semantics through the common text pipeline\n  * OCR and scanned-page recognition rows are retired and fail closed\n'
SIGNAL_SUITE_USAGE_EXAMPLES=$'  ./tools/regression/check_accurate.sh\n  ./tools/regression/check_accurate.sh --pdf\n  ./tools/regression/check_accurate.sh --docx'
SIGNAL_SUITE_TMP_ROOT="$ACCURATE_TMP_ROOT"
SIGNAL_SUITE_RUN_ID_PREFIX="accurate"
SIGNAL_SUITE_RESULT_PREFIX="accurate"
SIGNAL_SUITE_CHECK="$QUALITY_CHECK"
SIGNAL_SUITE_LAB_ROOT="$QUALITY_LAB_ROOT"
SIGNAL_SUITE_CORPUS_ROOT="$ACCURATE_CORPUS_ROOT"
SIGNAL_SUITE_MANIFEST_PATH="$ACCURATE_MANIFEST_PATH"
SIGNAL_SUITE_SUMMARY_INTRO="External accurate rows from ./markitdown-quality-lab. These rows validate Office/ODF/document semantics through the shared text pipeline."
SIGNAL_SUITE_MISSING_TITLE="EXTERNAL ACCURATE CORPUS NOT FOUND"
SIGNAL_SUITE_MISSING_HINTS=$'place markitdown-quality-lab at the official repo-root location\nsync the external lab so ./markitdown-quality-lab/external_accurate exists\nofficial location: ./markitdown-quality-lab'

quality_lab_sha() {
  git -C "$QUALITY_LAB_ROOT" rev-parse HEAD 2>/dev/null || printf 'unavailable'
}

signal_suite_before_run() {
  local run_dir="$1"
  local log_dir="$2"
  local _run_label="$3"
  local preflight_log_path="$log_dir/preflight.log"
  if ! (
    echo "preflight: checking shared CLI runner"
    resolve_markitdown_cli >/dev/null || exit 1
    echo "preflight: ok"
    echo "quality_lab_sha: $(quality_lab_sha)"
    echo "runner: ${CLI_RUNNER_KIND:-none}"
    echo "cli: ${CLI_BIN:-unset}"
    echo "run: $(display_path "$ROOT" "$run_dir")"
  ) >"$preflight_log_path" 2>&1; then
    echo "accurate: preflight failed"
    echo "run: $(display_path "$ROOT" "$run_dir")"
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
  echo "- quality-lab SHA: $(quality_lab_sha)"
  echo "- Common CLI runner: ${CLI_RUNNER_KIND:-none}"
}

signal_suite_run "$@"
