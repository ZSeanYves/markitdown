#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/env/share/install_runtime_deps_common.sh"

usage() {
  cat <<'EOF'
Usage: ./samples/env/install_ocr_pdf_balance_deps.sh

Install runtime dependencies for:
  - balanced direct image OCR
  - balanced PDF OCR

This installs:
  - tesseract
  - pdftoppm / poppler

No environment variables are required after this script finishes.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 0 ]]; then
  usage >&2
  exit 2
fi

platform_family="$(resolve_platform_family)"

case "$platform_family" in
  brew)
    install_system_packages "$platform_family" poppler tesseract tesseract-lang
    ;;
  apt)
    install_system_packages "$platform_family" poppler-utils tesseract-ocr tesseract-ocr-eng
    ;;
esac

env_path="$(generated_env_path balance-ocr-pdf.env.sh)"
write_note_env_file "$env_path" "Balanced OCR/PDF OCR does not require extra markitdown runtime exports."

log_note "Balanced OCR/PDF OCR dependencies are ready."
log_note "Tesseract: $(command -v tesseract)"
log_note "pdftoppm: $(command -v pdftoppm)"
log_note "Env note written to: $env_path"
