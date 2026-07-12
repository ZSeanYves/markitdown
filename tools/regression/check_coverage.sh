#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT_DIR="${MARKITDOWN_COVERAGE_OUTPUT_DIR:-$ROOT/.tmp/coverage}"
ENFORCE=()
if [[ "${1:-}" == "--enforce" ]]; then
  ENFORCE=(--enforce)
elif [[ $# -gt 0 ]]; then
  echo "usage: ./tools/regression/check_coverage.sh [--enforce]" >&2
  exit 2
fi

moon coverage clean
mkdir -p "$OUTPUT_DIR"
if ! moon test --enable-coverage >"$OUTPUT_DIR/coverage-test.log" 2>&1; then
  cat "$OUTPUT_DIR/coverage-test.log" >&2
  exit 1
fi
moon coverage analyze >"$OUTPUT_DIR.uncovered.log" 2>&1
mv "$OUTPUT_DIR.uncovered.log" "$OUTPUT_DIR/uncovered.log"
moon coverage report -f cobertura -o "$OUTPUT_DIR/cobertura.xml"
COMMAND=(
  python3 "$ROOT/tools/regression/lib/coverage_gate.py"
  --cobertura "$OUTPUT_DIR/cobertura.xml"
  --output-dir "$OUTPUT_DIR"
)
if [[ ${#ENFORCE[@]} -gt 0 ]]; then
  COMMAND+=("${ENFORCE[@]}")
fi
"${COMMAND[@]}"
