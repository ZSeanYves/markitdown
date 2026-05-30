#!/usr/bin/env bash

bench_v2_usage_external_bench_message() {
  cat <<'EOF'
external benchmark corpus is required;
pass --manifest <path> or set MARKITDOWN_BENCH_LAB / MARKITDOWN_QUALITY_LAB;
fetch or prepare markitdown-quality-lab/external_bench first.
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
