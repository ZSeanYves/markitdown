#!/usr/bin/env bash

if [[ -n "${ROOT:-}" && -f "$ROOT/samples/helpers/shared/progress_helpers.sh" ]]; then
  source "$ROOT/samples/helpers/shared/progress_helpers.sh"
fi

bench_v2_usage_external_bench_message() {
  cat <<'EOF'
external benchmark corpus is required;
pass --manifest <path> or set MARKITDOWN_BENCH_LAB / MARKITDOWN_QUALITY_LAB;
expected: markitdown-quality-lab/external_bench/MANIFEST.tsv;
clone/place the external lab with:
  git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
EOF
}

bench_v2_fail_missing_manifest() {
  bench_v2_usage_external_bench_message >&2
  return 1
}

bench_v2_resolve_manifest() {
  local root="$1"
  local candidate

  if [[ -n "${MARKITDOWN_BENCH_LAB:-}" ]]; then
    candidate="${MARKITDOWN_BENCH_LAB%/}/external_bench/MANIFEST.tsv"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  if [[ -n "${MARKITDOWN_QUALITY_LAB:-}" ]]; then
    candidate="${MARKITDOWN_QUALITY_LAB%/}/external_bench/MANIFEST.tsv"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  candidate="$root/markitdown-quality-lab/external_bench/MANIFEST.tsv"
  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

bench_v2_manifest_dir() {
  local manifest="$1"
  local parent
  if [[ "$manifest" == */* ]]; then
    parent="${manifest%/*}"
  else
    parent="."
  fi
  (cd "$parent" && pwd)
}

bench_v2_resolve_rel_path() {
  local manifest_dir="$1"
  local rel_path="$2"
  if [[ "$rel_path" == /* ]]; then
    printf '%s\n' "$rel_path"
  else
    printf '%s/%s\n' "$manifest_dir" "$rel_path"
  fi
}

bench_v2_reject_forbidden_path() {
  local root="$1"
  local path="$2"
  local normalized="${path//\\//}"
  local root_normalized="${root//\\//}"

  case "$normalized" in
    samples/main_process|samples/main_process/*|*/samples/main_process|*/samples/main_process/*|samples/benchmark|samples/benchmark/*|*/samples/benchmark|*/samples/benchmark/*)
      echo "benchmark rows must not use repo-local samples/main_process or samples/benchmark paths: $path" >&2
      return 1
      ;;
  esac

  case "$normalized" in
    "$root_normalized/samples/main_process"|"$root_normalized/samples/main_process/"*|"$root_normalized/samples/benchmark"|"$root_normalized/samples/benchmark/"*)
      echo "benchmark rows must not use repo-local samples/main_process or samples/benchmark paths: $path" >&2
      return 1
      ;;
  esac

  return 0
}

bench_v2_enabled_tier_action() {
  local value
  value="$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]')"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  case "$value" in
    smoke|full|manual)
      printf 'run\n'
      ;;
    disabled|pending_review|unknown|"")
      printf 'skip\n'
      ;;
    *)
      printf 'error\n'
      ;;
  esac
}

bench_v2_list_contains_token() {
  local list token wanted
  list="$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]')"
  wanted="$(printf '%s' "${2-}" | tr '[:upper:]' '[:lower:]')"
  wanted="${wanted#"${wanted%%[![:space:]]*}"}"
  wanted="${wanted%"${wanted##*[![:space:]]}"}"
  [[ "$wanted" == "text" ]] && wanted="txt"
  [[ -z "$wanted" ]] && return 1
  list="${list//;/,}"
  IFS=',' read -r -a _bench_v2_parts <<< "$list"
  for token in "${_bench_v2_parts[@]}"; do
    token="${token#"${token%%[![:space:]]*}"}"
    token="${token%"${token##*[![:space:]]}"}"
    [[ "$token" == "text" ]] && token="txt"
    if [[ -n "$token" && "$token" == "$wanted" ]]; then
      return 0
    fi
  done
  return 1
}

bench_v2_require_non_empty_token_filter() {
  local flag="$1"
  local raw="${2-}"
  local token
  local normalized
  normalized="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  normalized="${normalized//;/,}"
  IFS=',' read -r -a _bench_v2_filter_parts <<< "$normalized"
  for token in "${_bench_v2_filter_parts[@]}"; do
    token="${token#"${token%%[![:space:]]*}"}"
    token="${token%"${token##*[![:space:]]}"}"
    if [[ -n "$token" && "$token" != "all" ]]; then
      return 0
    fi
  done
  echo "$flag has no non-empty tokens" >&2
  return 1
}

bench_v2_selected_row_labels() {
  local manifest="$1"
  local layer="$2"
  local format_filter="${3-}"
  python3 - "$manifest" "$layer" "$format_filter" <<'PY'
import csv
import sys

manifest, wanted_layer, format_filter = sys.argv[1:]

def tokens(value):
    out = []
    for part in value.replace(";", ",").split(","):
        part = part.strip().lower()
        if part == "text":
            part = "txt"
        if part and part != "all":
            out.append(part)
    return out

wanted_formats = set(tokens(format_filter))
run_tiers = {"smoke", "full", "manual"}

with open(manifest, newline="", encoding="utf-8") as f:
    lines = [line for line in f if line.strip() and not line.lstrip().startswith("#")]

reader = csv.DictReader(lines, delimiter="\t")
for row in reader:
    fmt = (row.get("format") or "").strip().lower()
    if fmt == "text":
        fmt = "txt"
    if wanted_formats and fmt not in wanted_formats:
        continue
    enabled_tier = (row.get("enabled_tier") or "").strip().lower()
    if enabled_tier not in run_tiers:
        continue
    layers = set(tokens(row.get("bench_layers") or ""))
    if wanted_layer not in layers:
        continue
    bench_id = (row.get("bench_id") or "").strip()
    rel_path = (row.get("rel_path") or "").strip()
    print(f"{bench_id} {rel_path}".strip())
PY
}

bench_v2_summary_row_count() {
  local summary="$1"
  if [[ ! -f "$summary" ]]; then
    printf '0'
    return
  fi
  awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$summary"
}

bench_v2_progress_label_at() {
  local labels_file="$1"
  local index="$2"
  if [[ "$index" -le 0 || ! -f "$labels_file" ]]; then
    return 0
  fi
  sed -n "${index}p" "$labels_file"
}

bench_v2_progress_monitor() {
  local pid="$1"
  local summary="$2"
  local labels_file="$3"
  local total="$4"
  local last_done=0
  local done label

  if [[ "$total" -le 0 ]]; then
    sample_progress_zero "no matching rows"
    return 0
  fi

  label="$(bench_v2_progress_label_at "$labels_file" 1)"
  sample_progress_update 0 "$total" "running" "$label"
  while kill -0 "$pid" 2>/dev/null; do
    done="$(bench_v2_summary_row_count "$summary")"
    if [[ "$done" != "$last_done" ]]; then
      last_done="$done"
      label="$(bench_v2_progress_label_at "$labels_file" "$done")"
      sample_progress_update "$done" "$total" "running" "$label"
    fi
    sleep 0.2
  done
}

bench_v2_run_with_progress() {
  local root="$1"
  local runner="$2"
  local output_path="$3"
  local labels_file="$4"
  local total="$5"
  shift 5
  local runner_pid status done

  set +e
  (cd "$root" && "$runner" "$@") &
  runner_pid=$!
  bench_v2_progress_monitor "$runner_pid" "$output_path" "$labels_file" "$total"
  wait "$runner_pid"
  status=$?
  set -e

  done="$(bench_v2_summary_row_count "$output_path")"
  if [[ "$status" -eq 0 ]]; then
    sample_progress_finish "$done" "$total" "done"
  else
    sample_progress_finish "$done" "$total" "failed"
  fi
  return "$status"
}

bench_v2_find_native_runner() {
  local root="$1"
  local pattern="$2"
  local preferred="${3-}"
  local candidate

  if [[ -n "$preferred" && -x "$preferred" ]]; then
    printf '%s\n' "$preferred"
    return 0
  fi

  while IFS= read -r candidate; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done < <(find "$root/_build/native" -path "$pattern" -type f 2>/dev/null | sort)

  return 1
}

bench_v2_resolve_native_runner() {
  local root="$1"
  local package="$2"
  local pattern="$3"
  local label="$4"
  local preferred="${5-}"
  local runner=""
  local build_log="${BENCH_BUILD_LOG:-}"

  if runner="$(bench_v2_find_native_runner "$root" "$pattern" "$preferred")"; then
    echo "runner: prebuilt ($runner)" >&2
    printf '%s\n' "$runner"
    return 0
  fi

  echo "runner: building missing native runner ($label)" >&2
  local build_status=0
  set +e
  if [[ -n "$build_log" ]]; then
    mkdir -p "$(dirname "$build_log")"
    {
      echo "reason: native runner missing"
      echo "command: moon build $package --target native"
      (cd "$root" && moon build "$package" --target native)
    } >> "$build_log" 2>&1
    build_status=$?
  else
    (cd "$root" && moon build "$package" --target native)
    build_status=$?
  fi
  set -e
  if [[ "$build_status" -ne 0 ]]; then
    echo "runner: build failed ($label); see ${build_log:-layer log}" >&2
    return "$build_status"
  fi

  if runner="$(bench_v2_find_native_runner "$root" "$pattern" "$preferred")"; then
    echo "runner: built ($runner)" >&2
    printf '%s\n' "$runner"
    return 0
  fi

  echo "runner: build finished but native runner is still missing ($label)" >&2
  return 1
}

bench_v2_require_external_bench_header() {
  local manifest="$1"
  local raw_line line
  local header=""
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line//$'\r'/}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "${line#\#}" != "$line" ]] && continue
    header="$raw_line"
    break
  done < "$manifest"

  if [[ -z "$header" ]]; then
    echo "external_bench manifest is empty: $manifest" >&2
    return 1
  fi

  local -a fields=()
  local key
  local found
  IFS=$'\t' read -r -a fields <<< "$header"
  if [[ "$(printf '%s' "${fields[0]-}" | tr '[:upper:]' '[:lower:]')" != "bench_id" ]]; then
    echo "manifest must use external_bench header schema" >&2
    return 1
  fi

  for required in bench_id format rel_path size_class bench_layers enabled_tier; do
    found=0
    for key in "${fields[@]}"; do
      key="$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')"
      key="${key#"${key%%[![:space:]]*}"}"
      key="${key%"${key##*[![:space:]]}"}"
      if [[ "$key" == "$required" ]]; then
        found=1
        break
      fi
    done
    if [[ "$found" -eq 0 ]]; then
      echo "external_bench manifest missing required field: $required" >&2
      return 1
    fi
  done
}
