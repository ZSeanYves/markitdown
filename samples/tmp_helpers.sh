#!/usr/bin/env bash

sample_tmp_keep_enabled() {
  local raw="${SAMPLES_KEEP_TMP:-${KEEP_TMP:-0}}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    1|true|yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sample_make_isolated_tmp_dir() {
  local tmp_root="$1"
  local script_name="$2"
  local parent="$tmp_root/samples"
  mkdir -p "$parent"
  mktemp -d "$parent/${script_name}.XXXXXX"
}

sample_cleanup_tmp_dir() {
  local dir="${1-}"
  [[ -z "$dir" ]] && return 0
  if sample_tmp_keep_enabled; then
    echo "==> preserving temp dir: $dir"
    return 0
  fi
  rm -rf "$dir"
}
