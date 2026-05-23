#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
STRICT=0
FAILED=0
SKIPPED=0

usage() {
  cat <<'EOF'
usage: bash samples/helpers/release/summarize_release_readiness.sh [--strict] [--help]

Print a local release-readiness dry-run snapshot from the repo root.

Default behavior:
  * run required quick checks
  * run optional diagnostics when their prebuilt tools are already available
  * skip optional diagnostics when a required prebuilt tool is missing
  * fail when a required check fails
  * fail when an optional diagnostic runs and fails

Strict behavior:
  * treat missing optional prebuilt tools as failures

This helper:
  * does not build tools automatically
  * does not run full quality by default
  * does not run OCR or `tesseract`
  * does not probe providers
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
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

cd "$ROOT"

pass() {
  printf 'PASS %s\n' "$1"
}

skip() {
  SKIPPED=1
  printf 'SKIP %s %s\n' "$1" "$2"
}

fail_line() {
  FAILED=1
  printf 'FAIL %s\n' "$1"
}

run_required() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$name"
  else
    fail_line "$name"
  fi
}

run_optional() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$name"
  else
    fail_line "$name"
  fi
}

run_optional_with_tool() {
  local name="$1"
  local tool_path="$2"
  local build_hint="$3"
  shift 3
  if [[ ! -x "$tool_path" ]]; then
    if [[ "$STRICT" -eq 1 ]]; then
      fail_line "$name"
    else
      skip "$name" "missing tool; run: $build_hint"
    fi
    return
  fi
  run_optional "$name" "$@"
}

run_optional_quality_lab() {
  local name="$1"
  shift
  if [[ ! -d "$ROOT/markitdown-quality-lab" ]]; then
    if [[ "$STRICT" -eq 1 ]]; then
      fail_line "$name"
    else
      skip "$name" "markitdown-quality-lab not present"
    fi
    return
  fi
  run_optional "$name" "$@"
}

tsv_preview_tool_path() {
  local candidate
  for candidate in \
    "$ROOT/_build/native/debug/build/convert/vision/tsv_preview_tool/tsv_preview_tool.exe" \
    "$ROOT/_build/native/release/build/convert/vision/tsv_preview_tool/tsv_preview_tool.exe"
  do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

printf 'REQUIRED\n'
run_required "moon-check" moon check
run_required "samples-check" bash samples/check.sh
run_required "samples-quality" bash samples/check_quality.sh
run_required "bench-default" bash samples/bench.sh

printf '\nOPTIONAL QUALITY-LAB\n'
run_optional_quality_lab \
  "ocr-quality-summary" \
  bash samples/helpers/quality/summarize_quality_lab_ocr.sh
run_optional_quality_lab \
  "ocr-scaffold" \
  bash samples/helpers/validation/check_quality_lab_ocr_scaffold.sh
run_optional_quality_lab \
  "ocr-default-preview" \
  bash samples/helpers/quality/check_quality_lab_ocr_preview.sh

if [[ -d "$ROOT/markitdown-quality-lab" ]]; then
  TSV_PREVIEW_TOOL_BIN="$(tsv_preview_tool_path || true)"
  run_optional_with_tool \
    "ocr-resegmented-preview" \
    "${TSV_PREVIEW_TOOL_BIN:-}" \
    "moon build convert/vision/tsv_preview_tool --target native" \
    bash samples/helpers/quality/check_quality_lab_ocr_resegmented_preview.sh
  run_optional_with_tool \
    "ocr-ir-hints" \
    "${TSV_PREVIEW_TOOL_BIN:-}" \
    "moon build convert/vision/tsv_preview_tool --target native" \
    bash samples/helpers/quality/check_quality_lab_ocr_ir_hints.sh
fi

printf '\nOPTIONAL PDF DIAGNOSTICS\n'
run_optional_with_tool \
  "pdf-scan-summary" \
  "$ROOT/_build/native/debug/build/debug/debug.exe" \
  "moon build debug --target native" \
  bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh
run_optional_with_tool \
  "pdf-scan-contract" \
  "$ROOT/_build/native/debug/build/debug/debug.exe" \
  "moon build debug --target native" \
  bash samples/helpers/contracts/check_pdf_scan_diagnostics.sh

printf '\nOPTIONAL PRODUCT PATH ATTRIBUTION\n'
run_optional_with_tool \
  "product-path-attribution-smoke" \
  "$ROOT/_build/native/debug/build/cli/cli.exe" \
  "moon build cli --target native" \
  bash samples/helpers/bench/check_product_path_attribution_smoke.sh

printf '\nSUMMARY\n'
if [[ "$FAILED" -eq 0 ]]; then
  echo "RELEASE READINESS SNAPSHOT PASSED"
else
  echo "RELEASE READINESS SNAPSHOT FAILED"
fi
if [[ "$STRICT" -eq 1 ]]; then
  echo "mode: strict"
else
  echo "mode: default"
fi
if [[ "$SKIPPED" -eq 1 ]]; then
  echo "optional_skips: yes"
else
  echo "optional_skips: no"
fi

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi
