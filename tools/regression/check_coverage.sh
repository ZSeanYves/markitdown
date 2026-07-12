#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/tools/regression/lib/shared/progress.sh"

OUTPUT_DIR="${MARKITDOWN_COVERAGE_OUTPUT_DIR:-$ROOT/.tmp/coverage}"
PROGRESS_TOTAL=5
PROGRESS_CURRENT=0
CURRENT_STAGE="startup"
CURRENT_LOG=""
CHILD_PID=""
ENFORCE=()
if [[ "${1:-}" == "--enforce" ]]; then
  ENFORCE=(--enforce)
elif [[ $# -gt 0 ]]; then
  echo "usage: ./tools/regression/check_coverage.sh [--enforce]" >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"

coverage_progress() {
  local status="$1"
  local label="$2"
  if sample_progress_is_tty; then
    sample_progress_update "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "$status" "$label"
  elif [[ "$status" == "running" ]]; then
    echo "coverage: [$((PROGRESS_CURRENT + 1))/$PROGRESS_TOTAL] $label"
  fi
}

interrupt_coverage() {
  local signal="$1"
  local status="$2"
  trap - INT TERM
  if [[ -n "$CHILD_PID" ]]; then
    kill -"$signal" "$CHILD_PID" 2>/dev/null || true
    wait "$CHILD_PID" 2>/dev/null || true
  fi
  sample_progress_finish "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "interrupted" "$CURRENT_STAGE"
  echo "coverage: interrupted by $signal while $CURRENT_STAGE" >&2
  if [[ -n "$CURRENT_LOG" ]]; then
    echo "coverage: log: $CURRENT_LOG" >&2
  fi
  exit "$status"
}

trap 'interrupt_coverage INT 130' INT
trap 'interrupt_coverage TERM 143' TERM

run_coverage_step() {
  local label="$1"
  local log_path="$2"
  shift 2
  local started_at status elapsed last_elapsed=-1
  CURRENT_STAGE="$label"
  CURRENT_LOG="$log_path"
  coverage_progress "running" "$label"
  started_at="$(date +%s)"
  "$@" >"$log_path" 2>&1 &
  CHILD_PID=$!
  while kill -0 "$CHILD_PID" 2>/dev/null; do
    if sample_progress_is_tty; then
      elapsed=$(($(date +%s) - started_at))
      if [[ "$elapsed" -ne "$last_elapsed" ]]; then
        sample_progress_update "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "running" "$label (${elapsed}s)"
        last_elapsed="$elapsed"
      fi
    fi
    sleep 0.2
  done
  set +e
  wait "$CHILD_PID"
  status=$?
  set -e
  CHILD_PID=""
  if [[ "$status" -ne 0 ]]; then
    sample_progress_finish "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "failed" "$label (exit=$status)"
    echo "coverage: failed while $label (exit=$status)" >&2
    echo "coverage: log: $log_path" >&2
    cat "$log_path" >&2
    if [[ "$label" == "checking coverage thresholds" && -f "$OUTPUT_DIR/coverage.md" ]]; then
      cat "$OUTPUT_DIR/coverage.md" >&2
    fi
    exit "$status"
  fi
  PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
  coverage_progress "done" "$label"
}

run_coverage_step "cleaning coverage data" "$OUTPUT_DIR/coverage-clean.log" \
  moon coverage clean
run_coverage_step "running tests with coverage" "$OUTPUT_DIR/coverage-test.log" \
  moon test --enable-coverage
run_coverage_step "analyzing uncovered code" "$OUTPUT_DIR/uncovered.log" \
  moon coverage analyze
run_coverage_step "generating Cobertura report" "$OUTPUT_DIR/coverage-report.log" \
  moon coverage report -f cobertura -o "$OUTPUT_DIR/cobertura.xml"
COMMAND=(
  python3 "$ROOT/tools/regression/lib/coverage_gate.py"
  --cobertura "$OUTPUT_DIR/cobertura.xml"
  --output-dir "$OUTPUT_DIR"
)
if [[ ${#ENFORCE[@]} -gt 0 ]]; then
  COMMAND+=("${ENFORCE[@]}")
fi
run_coverage_step "checking coverage thresholds" "$OUTPUT_DIR/coverage-gate.log" \
  "${COMMAND[@]}"
sample_progress_finish "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "done" "coverage gate passed"
cat "$OUTPUT_DIR/coverage.md"
