#!/usr/bin/env bash

sample_failure_slug() {
  local scope="$1"
  local slug
  slug="$(printf '%s' "$scope" | tr '/: ' '___')"
  printf '%s' "$slug"
}

copy_if_exists() {
  local from="$1"
  local to="$2"
  if [[ -f "$from" ]]; then
    mkdir -p "$(dirname "$to")"
    cp "$from" "$to"
  fi
}

copy_dir_if_exists() {
  local from="$1"
  local to="$2"
  if [[ -d "$from" ]]; then
    mkdir -p "$(dirname "$to")"
    rm -rf "$to"
    cp -R "$from" "$to"
  fi
}

single_line_note() {
  local raw="${1-}"
  raw="${raw//$'\r'/ }"
  raw="${raw//$'\n'/ }"
  raw="$(printf '%s' "$raw" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  printf '%s' "$raw"
}

write_failure_report() {
  local report_path="$1"
  local scope="$2"
  local fmt="$3"
  local input_path="$4"
  local expected_path="$5"
  local actual_path="$6"
  local diff_path="$7"
  local stdout_path="$8"
  local stderr_path="$9"
  local note="${10}"
  local status_label="${11}"

  mkdir -p "$(dirname "$report_path")"
  {
    echo "# Failure Report"
    echo
    echo "- Scope: $scope"
    echo "- Format: $fmt"
    echo "- Status: $status_label"
    echo "- Input: $input_path"
    if [[ -n "$expected_path" ]]; then
      echo "- Expected: $expected_path"
    fi
    if [[ -n "$actual_path" ]]; then
      echo "- Actual: $actual_path"
    fi
    if [[ -n "$diff_path" ]]; then
      echo "- Diff: $diff_path"
    fi
    if [[ -n "$stdout_path" ]]; then
      echo "- Stdout: $stdout_path"
    fi
    if [[ -n "$stderr_path" ]]; then
      echo "- Stderr: $stderr_path"
      if [[ -f "$stderr_path" ]]; then
        local stderr_preview
        stderr_preview="$(sed -n '1,5p' "$stderr_path" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
        if [[ -n "$stderr_preview" ]]; then
          echo "- Stderr preview: $stderr_preview"
        fi
      fi
    fi
    echo "- Note: $note"
  } > "$report_path"
}
