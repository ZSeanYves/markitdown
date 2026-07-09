#!/usr/bin/env bash

display_path() {
  local root="$1"
  local path="$2"
  if [[ "$path" == "$root" ]]; then
    printf '.'
  elif [[ "$path" == "$root/"* ]]; then
    printf '%s' "${path#$root/}"
  else
    printf '%s' "$path"
  fi
}

append_command_args() {
  local arg
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
}

summary_value_col() {
  local label="$1"
  local summary_path="$2"
  local column="$3"
  python3 - "$label" "$summary_path" "$column" <<'PY'
import csv
import sys

label, path, column_raw = sys.argv[1:]
column = int(column_raw)
with open(path, newline="", encoding="utf-8") as f:
    reader = csv.reader(f, delimiter="\t")
    next(reader, None)
    for row in reader:
        if row and row[0] == label:
            value = row[column] if len(row) > column else ""
            print(value if value else "0")
            break
    else:
        print("0")
PY
}

summary_value() {
  summary_value_col "$1" "$2" 5
}

summary_total_value() {
  summary_value_col "$1" "$2" 6
}

summary_note_value() {
  summary_value_col "$1" "$2" 7
}

runner_from_log() {
  local log_path="$1"
  if grep -q "runner: prebuilt\\|runner: override" "$log_path" 2>/dev/null; then
    printf 'prebuilt'
  else
    printf 'none'
  fi
}
