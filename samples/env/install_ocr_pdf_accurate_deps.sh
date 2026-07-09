#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/env/share/install_runtime_deps_common.sh"

usage() {
  cat <<'EOF'
Usage: ./samples/env/install_ocr_pdf_accurate_deps.sh

Install runtime dependencies for:
  - accurate direct image OCR
  - accurate PDF OCR

This installs:
  - tesseract
  - poppler / pdftoppm
  - repo-local Python virtualenv packages: paddlepaddle, paddleocr, pillow

Python packages are installed into a repo-local virtualenv under `./env/`.
If Python with `venv` support is missing, the script installs that runtime first.
This script also records repo-managed `tesseract` and `pdftoppm` paths under
`./env/managed-paths/`, and writes a stable env file that exports
MARKITDOWN_PADDLE_OCR_CMD.
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
system_packages=()
case "$platform_family" in
  brew)
    system_packages+=(poppler tesseract tesseract-lang)
    if ! python_command_available; then
      system_packages+=(python)
    fi
    ;;
  apt)
    system_packages+=(poppler-utils tesseract-ocr tesseract-ocr-eng)
    if ! python_command_available; then
      system_packages+=(python3 python3-venv)
    elif ! python_supports_venv; then
      system_packages+=(python3-venv)
    fi
    ;;
esac
if [[ "${#system_packages[@]}" -eq 0 ]]; then
  install_system_packages "$platform_family"
else
  install_system_packages "$platform_family" "${system_packages[@]}"
fi
write_managed_command_path_record tesseract tesseract
write_managed_command_path_record pdftoppm pdftoppm

venv_pip_install_packages paddlepaddle paddleocr pillow
mark_executable "$ROOT/samples/env/ocr/paddle_ocr_wrapper.py"

python_bin="$(resolve_runtime_python_bin)"
wrapper_path="$ROOT/samples/env/ocr/paddle_ocr_wrapper.py"
wrapper_cmd="$(join_shell_command "$python_bin" "$wrapper_path")"
env_path="$(generated_env_path accurate-ocr-pdf.env.sh)"
write_export_env_file \
  "$env_path" \
  MARKITDOWN_MODULE_ROOT "$ROOT" \
  MARKITDOWN_RUNTIME_VENV "$(runtime_venv_path)" \
  MARKITDOWN_RUNTIME_PYTHON "$python_bin" \
  MARKITDOWN_PADDLE_OCR_CMD "$wrapper_cmd"

log_note "Accurate OCR/PDF OCR dependencies are ready."
log_note "Tesseract: $(command -v tesseract)"
log_note "pdftoppm: $(command -v pdftoppm)"
log_note "Managed tesseract record: $(managed_command_record_path tesseract)"
log_note "Managed pdftoppm record: $(managed_command_record_path pdftoppm)"
log_note "Repo-local Python: $python_bin"
log_note "Repo-local virtualenv: $(runtime_venv_path)"
log_note "Wrapper: $wrapper_path"
log_note "Env file written to: $env_path"
log_note "Load it in your shell with:"
print_source_hint "$env_path"
