#!/usr/bin/env bash
set -euo pipefail

ENV_LIB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKITDOWN_REPO_ROOT="$(cd "$ENV_LIB_ROOT/../../.." && pwd)"
ENV_MANAGER_PY="$MARKITDOWN_REPO_ROOT/tools/env/lib/manage.py"

env_log_note() {
  printf '[deps] %s\n' "$*" >&2
}

env_die() {
  printf '[deps] error: %s\n' "$*" >&2
  exit 1
}

source_env_file_if_present() {
  local path="$1"
  if [[ -f "$path" ]]; then
    # shellcheck source=/dev/null
    source "$path"
  fi
}

resolve_env_manager_python() {
  local override=""
  local expect_value=0
  local arg
  for arg in "$@"; do
    if [[ "$expect_value" -eq 1 ]]; then
      override="$arg"
      break
    fi
    case "$arg" in
      --python)
        expect_value=1
        ;;
      --python=*)
        override="${arg#--python=}"
        break
        ;;
    esac
  done
  if [[ -n "$override" ]]; then
    [[ -x "$override" ]] || env_die "requested python is not executable: $override"
    printf '%s' "$override"
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    command -v python3
    return
  fi
  if command -v python >/dev/null 2>&1; then
    command -v python
    return
  fi
  env_die "python3 is required to run the tools/env manager"
}

run_env_manager() {
  local python_bin
  python_bin="$(resolve_env_manager_python "$@")"
  "$python_bin" "$ENV_MANAGER_PY" "$@"
}

install_env_profile() {
  local profile="$1"
  shift
  run_env_manager install --profile "$profile" "$@"
}

sync_env_model() {
  run_env_manager sync-model "$@"
}
