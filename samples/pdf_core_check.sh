#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

run_group() {
  local group="$1"
  echo "==> pdf_core check group: $group"
  moon run "$ROOT/cli" -- check-pdf-core-set "$group"
  echo
}

run_group smoke
run_group decode
run_group signal

echo "pdf_core grouped checks passed"
