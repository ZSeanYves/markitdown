#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLE_IMPL="$ROOT/samples/helpers/validation/check_samples_impl.sh"
CORPUS_MANIFEST_CHECK="$ROOT/samples/helpers/validation/check_corpus_manifest.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"

CONTINUE_ON_FAILURE="${CHECK_CONTINUE:-0}"
MODE="full"

bool_enabled() {
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

usage() {
  cat <<'EOF'
Usage: ./samples/check.sh [MODE]

Public modes:
  --full            Run the default release-style validation chain.
  --markdown-only   Run only checked Markdown regression for enrolled samples.
  --metadata-only   Run only metadata-focused sample validation.
  --assets-only     Run only asset-focused sample validation.
  --contracts-only  Run CLI, debug, and batch contract checks only.
  --manifest-only   Run sample enrollment plus benchmark manifest checks.

Notes:
  * The default mode is --full and covers checked regression and contract gates.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)
      MODE="full"
      ;;
    --main-process)
      MODE="main-process"
      ;;
    --markdown-only)
      MODE="markdown-only"
      ;;
    --metadata-only)
      MODE="metadata-only"
      ;;
    --assets-only)
      MODE="assets-only"
      ;;
    --contracts-only)
      MODE="contracts-only"
      ;;
    --manifest-only)
      MODE="manifest-only"
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

run_stage() {
  local stage="$1"
  shift
  local start end elapsed status
  start="$(date +%s 2>/dev/null || printf '0')"
  echo "==> $stage"
  set +e
  "$@"
  status=$?
  set -e
  end="$(date +%s 2>/dev/null || printf '0')"
  elapsed=$((end - start))
  if [[ "$status" -eq 0 ]]; then
    STAGE_RESULTS+=("$stage|passed|${elapsed}s")
    echo "[ok] $stage (${elapsed}s)"
    return 0
  fi
  STAGE_RESULTS+=("$stage|failed|${elapsed}s")
  echo "[fail] $stage (${elapsed}s)"
  return "$status"
}

print_summary() {
  local overall="$1"
  local record stage status elapsed
  if [[ "$overall" -eq 0 ]]; then
    echo "ALL SAMPLE VALIDATION PASSED"
  else
    echo "SAMPLE VALIDATION FAILED"
  fi
  for record in "${STAGE_RESULTS[@]}"; do
    IFS='|' read -r stage status elapsed <<< "$record"
    echo "- $stage: $status ($elapsed)"
  done
  echo "- temp_root: $TMP_ROOT"
}

run_stage_or_stop() {
  local stage="$1"
  shift
  run_stage "$stage" "$@" || overall_status=$?
  if [[ "$overall_status" -ne 0 ]] && ! bool_enabled "$CONTINUE_ON_FAILURE"; then
    print_summary "$overall_status"
    exit "$overall_status"
  fi
}

run_manifest_chain() {
  run_stage_or_stop "integrity" env SAMPLES_QUIET_INTEGRITY=1 "$ROOT/samples/helpers/validation/check_samples.sh"
  run_stage_or_stop "benchmark_manifest" "$CORPUS_MANIFEST_CHECK"
}

run_contract_chain() {
  run_stage_or_stop "cli_contract" "$ROOT/samples/helpers/contracts/check_cli_contract.sh"
  run_stage_or_stop "debug_contract" "$ROOT/samples/helpers/contracts/check_debug_contract.sh"
  run_stage_or_stop "batch_contract" "$ROOT/samples/helpers/contracts/check_batch_contract.sh"
  run_stage_or_stop "ocr_contract" "$ROOT/samples/helpers/contracts/check_ocr_contract.sh"
}

STAGE_RESULTS=()
overall_status=0

case "$MODE" in
  main-process)
    exec "$SAMPLE_IMPL"
    ;;
  markdown-only)
    exec "$SAMPLE_IMPL" --markdown-only
    ;;
  metadata-only)
    exec "$SAMPLE_IMPL" --metadata-only
    ;;
  assets-only)
    exec "$SAMPLE_IMPL" --assets-only
    ;;
  contracts-only)
    run_contract_chain
    print_summary "$overall_status"
    exit "$overall_status"
    ;;
  manifest-only)
    run_manifest_chain
    print_summary "$overall_status"
    exit "$overall_status"
    ;;
esac

run_manifest_chain
run_stage_or_stop "markdown" "$SAMPLE_IMPL" --markdown-only
run_stage_or_stop "metadata" "$SAMPLE_IMPL" --metadata-only
run_stage_or_stop "assets" "$SAMPLE_IMPL" --assets-only
run_contract_chain

print_summary "$overall_status"
exit "$overall_status"
