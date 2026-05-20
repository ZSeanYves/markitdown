#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

MODE="default"
RUN_BENCH=1
OCR_OPTIONAL_STATUS="not-run"

usage() {
  cat <<'EOF'
usage: bash samples/helpers/check_release_candidate.sh [--full] [--skip-bench] [--help]

Run the maintainer-oriented release-candidate readiness checks from the repo root.

Modes:
  --full        additionally run `moon test`
  --skip-bench  skip `./samples/bench.sh --suite smoke --kind smoke`
  --help        show this help

Default behavior:
  * fail fast
  * require a clean git status
  * require prohibited paths to stay clean
  * run `moon check`
  * run `./samples/check.sh`
  * run `bash samples/check_quality.sh`
  * run bench smoke unless `--skip-bench` is set
  * run release-facing contract helpers, including the optional OCR smoke

Notes:
  * this helper does not publish, tag, or push
  * local-only external corpus files remain uncommitted and are not treated as
    release artifacts
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

check_prohibited_paths() {
  section "prohibited paths"
  local status
  status="$(git status --short -- .external .external/layout_model samples/quality_corpus/external_manifest.local.tsv _build .mooncakes .tmp)"
  if [[ -n "$status" ]]; then
    echo "$status"
    echo "[fail] prohibited paths are not clean" >&2
    exit 1
  fi
  echo "prohibited paths clean"
}

run_optional_ocr_smoke() {
  local output status_line
  output="$(bash samples/helpers/check_ocr_tesseract_smoke_optional.sh 2>&1)"
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
check_prohibited_paths

section "moon check"
run moon check

if [[ "$MODE" == "full" ]]; then
  section "moon test"
  run moon test
fi

section "samples check"
run ./samples/check.sh

section "quality corpus"
run bash samples/check_quality.sh

if [[ "$RUN_BENCH" -eq 1 ]]; then
  section "bench smoke"
  run ./samples/bench.sh --suite smoke --kind smoke
else
  section "bench smoke"
  echo "skipped (--skip-bench)"
fi

section "contracts"
run bash samples/helpers/check_cli_contract.sh
run bash samples/helpers/check_pdf_contract.sh
run bash samples/helpers/check_zip_contract.sh
run bash samples/helpers/check_batch_contract.sh
run bash samples/helpers/check_debug_contract.sh
run bash samples/helpers/check_ocr_contract.sh
run_optional_ocr_smoke

section "summary"
echo "RELEASE CANDIDATE CHECK PASSED"
echo "mode: $MODE"
if [[ "$RUN_BENCH" -eq 1 ]]; then
  echo "bench: run"
else
  echo "bench: skipped"
fi
echo "optional_ocr: $OCR_OPTIONAL_STATUS"
