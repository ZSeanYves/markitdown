#!/usr/bin/env bash

lane_input_dir() {
  local fmt="$1"
  local lane="$2"
  printf '%s/%s/%s' "$MAIN_CORPUS_ROOT" "$fmt" "$lane"
}

sample_lane_cli_args() {
  local fmt="$1"
  local lane="$2"
  local _rel="$3"
  if [[ "$fmt" == "pdf" && "$lane" == "ocr" ]]; then
    printf '%s\n' "--ocr"
    return 0
  fi
  return 0
}

lane_expected_dir() {
  local fmt="$1"
  local lane="$2"
  printf '%s/%s/expected/%s' "$MAIN_CORPUS_ROOT" "$fmt" "$lane"
}

expected_output_path() {
  local lane="$1"
  local expected_rel="$2"
  case "$lane" in
    assets)
      printf '%s/%s' "$MAIN_CORPUS_ROOT" "$expected_rel"
      ;;
    *)
      printf '%s/%s' "$MAIN_CORPUS_ROOT" "$expected_rel"
      ;;
  esac
}
