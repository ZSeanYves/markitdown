#!/usr/bin/env bash
set -euo pipefail

markitdown_clear_test_env_vars() {
  local name
  while IFS='=' read -r name _; do
    if [[ "$name" == MARKITDOWN_* ]]; then
      unset "$name"
    fi
  done < <(env)
}

markitdown_reset_managed_test_state() {
  rm -rf env/.venv-markitdown-audio
  rm -rf env/.venv-markitdown-accurate
  rm -rf env/.venv-markitdown-bench
  rm -rf env/downloads
  rm -rf env/fingerprints
  rm -rf env/managed-metadata
  rm -rf env/managed-paths
  rm -rf env/managed-tools
  rm -rf env/models
  rm -f env/*.env.sh
}

markitdown_print_ambient_product_commands() {
  local cmd
  for cmd in ffmpeg tesseract pdftoppm markitdown; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%s=%s\n' "$cmd" "$(command -v "$cmd")"
    else
      printf '%s=<missing>\n' "$cmd"
    fi
  done
}

markitdown_reset_test_env_main() {
  markitdown_clear_test_env_vars
  markitdown_reset_managed_test_state
  markitdown_print_ambient_product_commands
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  markitdown_reset_test_env_main
fi
