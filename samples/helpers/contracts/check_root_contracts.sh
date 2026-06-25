#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CONTRACTS_DIR="$ROOT/samples/helpers/contracts"

usage() {
  cat <<'EOF'
usage: bash samples/helpers/contracts/check_root_contracts.sh [--help]

Run the retained root contract helper suite from any working directory.

Modes:
  default           run all retained root contract helpers
  --help            show this help

Groups:
  Root main CLI contracts:
    cli, samples, quality, quality grouping, quality signal eval, zip, epub, docx, xlsx, pptx, ocr fail-closed, pdf signal layer
EOF
}

section() {
  printf '\n==> %s\n' "$1"
}

run_contract() {
  local label="$1"
  local script_name="$2"
  printf '[run] %s\n' "$label"
  bash "$CONTRACTS_DIR/$script_name"
}

assert_absent_dir() {
  local path="$1"
  [[ ! -e "$ROOT/$path" ]] || {
    echo "[fail] legacy root must be absent: $path" >&2
    exit 1
  }
}

assert_present_dir() {
  local path="$1"
  [[ -d "$ROOT/$path" ]] || {
    echo "[fail] expected directory missing: $path" >&2
    exit 1
  }
}

run_root_contracts() {
  section "legacy roots retired"
  assert_absent_dir "office"
  assert_absent_dir "office_shared"
  assert_absent_dir "doc_parse"
  assert_present_dir "format_readers"

  section "root main cli and fail-closed contracts"
  run_contract "cli" "check_cli_contract.sh"
  run_contract "samples" "check_samples_check_contract.sh"
  run_contract "quality" "check_quality_contract.sh"
  run_contract "quality-grouping" "check_quality_grouping_contract.sh"
  run_contract "quality-signal-eval" "check_quality_signal_eval_contract.sh"
  run_contract "zip" "check_zip_contract.sh"
  run_contract "epub" "check_epub_contract.sh"
  run_contract "docx" "check_docx_contract.sh"
  run_contract "xlsx" "check_xlsx_contract.sh"
  run_contract "pptx" "check_pptx_contract.sh"
  run_contract "ocr" "check_ocr_contract.sh"
  run_contract "pdf-signal" "check_pdf_signal_contract.sh"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

run_root_contracts

section "summary"
echo "ROOT CONTRACT AGGREGATOR PASSED"
echo "mode: root-only"
