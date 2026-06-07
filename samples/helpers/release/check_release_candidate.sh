#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

MODE="default"
RUN_BENCH=1
OCR_OPTIONAL_STATUS="not-run"
QUALITY_SIGNAL_STATUS="not-run"

usage() {
  cat <<'EOF'
usage: bash samples/helpers/release/check_release_candidate.sh [--full] [--skip-bench] [--help]

Run the maintainer-oriented release-candidate readiness checks from the repo root.

Modes:
  --full        additionally run `moon test`
  --skip-bench  accepted for compatibility; benchmarks are manual by default
  --help        show this help

Default behavior:
  * fail fast
  * require a clean git status
  * require generated local paths to stay clean
  * run `moon check`
  * run `./samples/check.sh`
  * run `bash samples/check_quality.sh` when the external quality manifest exists
  * do not run benchmark smoke by default
  * run release-facing contract helpers, including the optional OCR smoke

Notes:
  * this helper does not publish, tag, or push
  * the external quality lab is an optional signal and is not a main-repo
    release artifact
EOF
}

section() {
  printf '\n==> %s\n' "$1"
}

run() {
  "$@"
}

check_clean_status() {
  section "git status cleanliness"
  local status
  status="$(git status --short --untracked-files=all)"
  if [[ -n "$status" ]]; then
    echo "$status"
    echo "[fail] working tree is not clean" >&2
    exit 1
  fi
  echo "git status clean"
}

check_generated_paths() {
  section "generated local paths"
  local status
  status="$(git status --short -- _build .mooncakes .tmp)"
  if [[ -n "$status" ]]; then
    echo "$status"
    echo "[fail] generated local paths are not clean" >&2
    exit 1
  fi
  echo "generated local paths clean"
}

external_quality_manifest_path() {
  local quality_lab_root="${MARKITDOWN_QUALITY_LAB:-$ROOT/markitdown-quality-lab}"
  printf '%s/external_quality/MANIFEST.tsv' "${quality_lab_root%/}"
}

run_external_quality_signal() {
  section "external quality signal"
  local manifest_path
  manifest_path="$(external_quality_manifest_path)"
  if [[ ! -f "$manifest_path" ]]; then
    QUALITY_SIGNAL_STATUS="skip"
    echo "external quality signal skipped"
    echo "manifest missing: $manifest_path"
    echo "external quality is optional for this release helper and is not a main-repo public gate"
    return 0
  fi
  if bash samples/check_quality.sh; then
    QUALITY_SIGNAL_STATUS="pass"
  else
    QUALITY_SIGNAL_STATUS="fail"
    return 1
  fi
}

run_optional_ocr_smoke() {
  local output status_line
  output="$(bash samples/helpers/contracts/check_ocr_tesseract_smoke_optional.sh 2>&1)"
  printf '%s\n' "$output"
  status_line="$(printf '%s\n' "$output" | tail -n 1)"
  case "$status_line" in
    *"SKIPPED"*)
      OCR_OPTIONAL_STATUS="skip"
      ;;
    *"PASSED"*)
      OCR_OPTIONAL_STATUS="pass"
      ;;
    *)
      OCR_OPTIONAL_STATUS="fail"
      return 1
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)
      MODE="full"
      ;;
    --skip-bench)
      RUN_BENCH=0
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

check_clean_status
check_generated_paths

section "moon check"
run moon check

if [[ "$MODE" == "full" ]]; then
  section "moon test"
  run moon test
fi

section "samples check"
run ./samples/check.sh

run_external_quality_signal

section "bench smoke"
echo "manual only; --skip-bench is accepted for compatibility"
echo "see docs/performance.md for external_bench commands"

section "contracts"
run bash samples/helpers/contracts/check_cli_contract.sh
run bash samples/helpers/contracts/check_pdf_contract.sh
run bash samples/helpers/contracts/check_zip_contract.sh
run bash samples/helpers/contracts/check_batch_contract.sh
run bash samples/helpers/contracts/check_debug_contract.sh
run bash samples/helpers/contracts/check_ocr_contract.sh
run_optional_ocr_smoke

section "summary"
echo "RELEASE CANDIDATE CHECK PASSED"
echo "mode: $MODE"
echo "bench: manual"
echo "external_quality: $QUALITY_SIGNAL_STATUS"
echo "optional_ocr: $OCR_OPTIONAL_STATUS"
