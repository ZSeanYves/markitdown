#!/usr/bin/env bash

sample_progress_bool_enabled() {
  local raw="${1-}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    1|true|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sample_progress_fd() {
  printf '%s' "${MARKITDOWN_PROGRESS_FD:-1}"
}

sample_progress_is_tty() {
  local fd
  fd="$(sample_progress_fd)"
  [[ -t "$fd" ]] || return 1
  sample_progress_bool_enabled "${NO_PROGRESS:-0}" && return 1
  sample_progress_bool_enabled "${CI:-0}" && return 1
  return 0
}

sample_progress_truncate() {
  local value="${1-}"
  local max="${2:-88}"
  if (( ${#value} > max )); then
    printf '%s...' "${value:0:$((max - 3))}"
  else
    printf '%s' "$value"
  fi
}

sample_progress_emit() {
  local text="$1"
  local fd
  fd="$(sample_progress_fd)"
  printf '%s' "$text" >&"$fd"
}

sample_progress_update() {
  local done="$1"
  local total="$2"
  local status="$3"
  local label="${4-}"
  local fd
  local line
  if ! sample_progress_is_tty; then
    return 0
  fi
  fd="$(sample_progress_fd)"
  label="$(sample_progress_truncate "$label")"
  if [[ -n "$label" ]]; then
    line="progress: $done/$total $status $label"
  else
    line="progress: $done/$total $status"
  fi
  printf '\r%-120s' "$line" >&"$fd"
}

sample_progress_finish() {
  local done="$1"
  local total="$2"
  local status="${3:-done}"
  local label="${4-}"
  local fd
  local line
  if ! sample_progress_is_tty; then
    return 0
  fi
  fd="$(sample_progress_fd)"
  label="$(sample_progress_truncate "$label")"
  if [[ -n "$label" ]]; then
    line="progress: $done/$total $status $label"
  else
    line="progress: $done/$total $status"
  fi
  printf '\r%-120s\n' "$line" >&"$fd"
}

sample_progress_zero() {
  local label="${1:-no matching rows}"
  sample_progress_finish 0 0 "$label"
}
