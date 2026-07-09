#!/usr/bin/env bash

markitdown_clear_test_env_vars() {
  local name
  while IFS='=' read -r name _; do
    if [[ "$name" == MARKITDOWN_* ]]; then
      unset "$name"
    fi
  done < <(env)
}

markitdown_reset_managed_test_state() {
  rm -rf env/.venv-markitdown-baseline
  rm -rf env/.venv-markitdown-runtime
  rm -rf env/managed-paths
  rm -f env/*.env.sh
  rm -rf "${HOME}/.cache/markitdown"
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
