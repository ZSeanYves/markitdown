#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/env/share/install_runtime_deps_common.sh"

BASELINE_VENV_NAME=".venv-markitdown-baseline"

usage() {
  cat <<'EOF'
Usage: ./samples/env/install_bench_baseline_deps.sh

Install the repo-local benchmark baseline CLI used by `official-compare`.

This installs:
  - repo-local Python virtualenv package: markitdown[all]

Python packages are installed into a dedicated repo-local virtualenv under `./env/`.
If Python with `venv` support is missing, the script installs that runtime first.
If you run the benchmark runner from the repo root, `official-compare` auto-detects this baseline CLI.
This script also writes a stable env file that exports MARKITDOWN_BIN.
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
    if ! python_command_available; then
      system_packages+=(python)
    fi
    ;;
  apt)
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

named_venv_pip_install_packages "$BASELINE_VENV_NAME" "markitdown[all]"

python_bin="$(resolve_named_venv_python_bin "$BASELINE_VENV_NAME")"
baseline_venv_path="$(venv_path_for_name "$BASELINE_VENV_NAME")"
markitdown_bin="$(venv_executable_path "$BASELINE_VENV_NAME" markitdown)"
[[ -x "$markitdown_bin" ]] || die "markitdown binary missing after install: $markitdown_bin"

env_path="$(generated_env_path bench-baseline.env.sh)"
write_export_env_file \
  "$env_path" \
  MARKITDOWN_BASELINE_VENV "$baseline_venv_path" \
  MARKITDOWN_BASELINE_PYTHON "$python_bin" \
  MARKITDOWN_BIN "$markitdown_bin"

log_note "Benchmark baseline dependencies are ready."
log_note "Repo-local Python: $python_bin"
log_note "Repo-local baseline virtualenv: $baseline_venv_path"
log_note "Repo-local baseline CLI: $markitdown_bin"
log_note "Env file written to: $env_path"
log_note "Load it in your shell with:"
print_source_hint "$env_path"
