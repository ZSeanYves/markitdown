#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/env/share/install_runtime_deps_common.sh"

usage() {
  cat <<'EOF'
Usage: ./samples/env/install_ocr_balance_deps.sh

Install runtime dependencies for:
  - balanced direct image OCR

This installs:
  - tesseract

This script also records the repo-managed Tesseract path under
`./env/managed-paths/tesseract`.
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
    install_system_packages "$platform_family" tesseract tesseract-lang
    ;;
  apt)
    install_system_packages "$platform_family" tesseract-ocr tesseract-ocr-eng
    ;;
esac
write_managed_command_path_record tesseract tesseract

env_path="$(generated_env_path balance-ocr-pdf.env.sh)"
write_note_env_file "$env_path" "Balanced direct image OCR does not require extra markitdown runtime exports."

log_note "Balanced direct image OCR dependencies are ready."
log_note "Tesseract: $(command -v tesseract)"
log_note "Managed record: $(managed_command_record_path tesseract)"
log_note "Env note written to: $env_path"
