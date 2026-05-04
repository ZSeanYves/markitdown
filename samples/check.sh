#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CONTINUE_ON_FAILURE="${CHECK_CONTINUE:-0}"

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
}

STAGE_RESULTS=()
overall_status=0

run_stage "integrity" env SAMPLES_QUIET_INTEGRITY=1 "$ROOT/samples/scripts/check_samples.sh" || overall_status=$?
if [[ "$overall_status" -ne 0 ]] && ! bool_enabled "$CONTINUE_ON_FAILURE"; then
  print_summary "$overall_status"
  exit "$overall_status"
fi

run_stage "diff" "$ROOT/samples/diff.sh" || overall_status=$?
if [[ "$overall_status" -ne 0 ]] && ! bool_enabled "$CONTINUE_ON_FAILURE"; then
  print_summary "$overall_status"
  exit "$overall_status"
fi

run_stage "metadata" "$ROOT/samples/check_metadata.sh" || overall_status=$?
if [[ "$overall_status" -ne 0 ]] && ! bool_enabled "$CONTINUE_ON_FAILURE"; then
  print_summary "$overall_status"
  exit "$overall_status"
fi

run_stage "assets" "$ROOT/samples/check_assets.sh" || overall_status=$?

print_summary "$overall_status"
exit "$overall_status"
