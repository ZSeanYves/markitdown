#!/usr/bin/env bash
set -euo pipefail

HELPER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HELPER_ROOT/../../.." && pwd)"
GENERATED_ENV_ROOT="$REPO_ROOT/env"
DEFAULT_RUNTIME_VENV_NAME=".venv-markitdown-runtime"

mkdir -p "$GENERATED_ENV_ROOT"

APT_UPDATED=0

log_note() {
  printf '[deps] %s\n' "$*" >&2
}

die() {
  printf '[deps] error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
}

resolve_platform_family() {
  if command -v brew >/dev/null 2>&1; then
    printf 'brew'
    return
  fi
  if command -v apt-get >/dev/null 2>&1; then
    printf 'apt'
    return
  fi
  die "unsupported platform; expected Homebrew or apt-get"
}

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi
  die "root privileges are required to run: $*"
}

brew_package_installed() {
  local package="$1"
  brew list --versions "$package" >/dev/null 2>&1
}

apt_package_installed() {
  local package="$1"
  dpkg -s "$package" >/dev/null 2>&1
}

install_system_packages() {
  local family="$1"
  shift
  local requested_packages_text="$*"
  local packages=()
  local package
  for package in "$@"; do
    case "$family" in
      brew)
        if ! brew_package_installed "$package"; then
          packages+=("$package")
        fi
        ;;
      apt)
        if ! apt_package_installed "$package"; then
          packages+=("$package")
        fi
        ;;
      *)
        die "unknown platform family: $family"
        ;;
    esac
  done
  if [[ "${#packages[@]}" -eq 0 ]]; then
    if [[ -n "$requested_packages_text" ]]; then
      log_note "System packages already installed for $family: $requested_packages_text"
    else
      log_note "No additional system packages required for $family"
    fi
    return
  fi
  case "$family" in
    brew)
      log_note "Installing Homebrew packages: ${packages[*]}"
      brew install "${packages[@]}"
      ;;
    apt)
      if [[ "$APT_UPDATED" -eq 0 ]]; then
        log_note "Updating apt package index"
        run_as_root apt-get update
        APT_UPDATED=1
      fi
      log_note "Installing apt packages: ${packages[*]}"
      run_as_root apt-get install -y "${packages[@]}"
      ;;
    *)
      die "unknown platform family: $family"
      ;;
  esac
}

resolve_python_cmd() {
  if command -v python3 >/dev/null 2>&1; then
    printf 'python3'
    return
  fi
  if command -v python >/dev/null 2>&1; then
    printf 'python'
    return
  fi
  die "python3 is unavailable after dependency installation"
}

python_command_available() {
  command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1
}

python_supports_venv() {
  if ! python_command_available; then
    return 1
  fi
  local python_cmd
  python_cmd="$(resolve_python_cmd)"
  "$python_cmd" -m venv --help >/dev/null 2>&1
}

resolve_python_bin() {
  local python_cmd
  python_cmd="$(resolve_python_cmd)"
  command -v "$python_cmd"
}

runtime_venv_path() {
  venv_path_for_name "$DEFAULT_RUNTIME_VENV_NAME"
}

runtime_venv_python_bin() {
  venv_python_bin_for_name "$DEFAULT_RUNTIME_VENV_NAME"
}

venv_path_for_name() {
  local name="$1"
  printf '%s/%s' "$GENERATED_ENV_ROOT" "$name"
}

venv_python_bin_for_name() {
  local name="$1"
  printf '%s/bin/python' "$(venv_path_for_name "$name")"
}

venv_executable_path() {
  local name="$1"
  local executable="$2"
  printf '%s/bin/%s' "$(venv_path_for_name "$name")" "$executable"
}

ensure_named_venv() {
  local name="$1"
  local python_cmd
  python_cmd="$(resolve_python_cmd)"
  local venv_path
  venv_path="$(venv_path_for_name "$name")"
  local venv_python
  venv_python="$(venv_python_bin_for_name "$name")"
  if [[ ! -x "$venv_python" ]]; then
    log_note "Creating repo-local Python virtualenv at $venv_path"
    "$python_cmd" -m venv "$venv_path"
  fi
  if ! "$venv_python" -m pip --version >/dev/null 2>&1; then
    log_note "Bootstrapping pip into repo-local virtualenv"
    "$venv_python" -m ensurepip --upgrade >/dev/null 2>&1 || die "repo-local virtualenv is missing pip support; install Python with venv/ensurepip enabled"
  fi
  log_note "Upgrading repo-local virtualenv tooling"
  "$venv_python" -m pip install --upgrade pip setuptools wheel
}

resolve_named_venv_python_bin() {
  local name="$1"
  ensure_named_venv "$name" >&2
  venv_python_bin_for_name "$name"
}

named_venv_pip_install_packages() {
  local name="$1"
  shift
  local venv_python
  venv_python="$(resolve_named_venv_python_bin "$name")"
  log_note "Installing Python packages into repo-local virtualenv with $venv_python -m pip: $*"
  "$venv_python" -m pip install --upgrade "$@"
}

ensure_runtime_venv() {
  ensure_named_venv "$DEFAULT_RUNTIME_VENV_NAME"
}

resolve_runtime_python_bin() {
  resolve_named_venv_python_bin "$DEFAULT_RUNTIME_VENV_NAME"
}

venv_pip_install_packages() {
  named_venv_pip_install_packages "$DEFAULT_RUNTIME_VENV_NAME" "$@"
}

mark_executable() {
  local path="$1"
  chmod +x "$path"
}

default_cache_root() {
  if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
    printf '%s' "$XDG_CACHE_HOME"
    return
  fi
  if [[ -n "${HOME:-}" ]]; then
    printf '%s/.cache' "$HOME"
    return
  fi
  printf '%s/.cache' "$REPO_ROOT"
}

default_audio_model_path() {
  printf '%s/markitdown/vosk/model' "$(default_cache_root)"
}

generated_env_path() {
  local name="$1"
  printf '%s/%s' "$GENERATED_ENV_ROOT" "$name"
}

managed_command_root() {
  printf '%s/managed-paths' "$GENERATED_ENV_ROOT"
}

managed_command_record_path() {
  local name="$1"
  printf '%s/%s' "$(managed_command_root)" "$name"
}

absolute_existing_path() {
  local path="$1"
  [[ -e "$path" ]] || die "path does not exist: $path"
  local dir base
  dir="$(cd "$(dirname "$path")" && pwd -P)"
  base="$(basename "$path")"
  printf '%s/%s' "$dir" "$base"
}

resolve_absolute_command_path() {
  local command_name="$1"
  local resolved
  resolved="$(type -P "$command_name" || true)"
  [[ -n "$resolved" ]] || die "command is unavailable after dependency installation: $command_name"
  [[ -x "$resolved" ]] || die "command is not executable after dependency installation: $resolved"
  absolute_existing_path "$resolved"
}

write_managed_command_path_record() {
  local record_name="$1"
  local command_name="$2"
  local record_path resolved
  record_path="$(managed_command_record_path "$record_name")"
  resolved="$(resolve_absolute_command_path "$command_name")"
  mkdir -p "$(dirname "$record_path")"
  printf '%s\n' "$resolved" > "$record_path"
  log_note "Repo-managed path recorded: $record_name -> $resolved"
}

write_export_env_file() {
  local path="$1"
  shift
  local parent
  parent="$(dirname "$path")"
  mkdir -p "$parent"
  {
    printf '# Generated by %s on %s\n' "$(basename "$0")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '# shellcheck shell=bash\n'
    while [[ $# -gt 1 ]]; do
      local var_name="$1"
      local var_value="$2"
      shift 2
      printf 'export %s=%q\n' "$var_name" "$var_value"
    done
  } > "$path"
}

shell_quote_arg() {
  local escaped="${1//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  printf '"%s"' "$escaped"
}

join_shell_command() {
  local first=1
  local arg
  for arg in "$@"; do
    if [[ "$first" -eq 0 ]]; then
      printf ' '
    fi
    first=0
    shell_quote_arg "$arg"
  done
}

write_note_env_file() {
  local path="$1"
  local note="$2"
  local parent
  parent="$(dirname "$path")"
  mkdir -p "$parent"
  {
    printf '# Generated by %s on %s\n' "$(basename "$0")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '# %s\n' "$note"
  } > "$path"
}

print_source_hint() {
  local path="$1"
  printf 'source %q\n' "$path"
}
