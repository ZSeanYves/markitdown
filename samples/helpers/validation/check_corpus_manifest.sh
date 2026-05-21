#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DEFAULT_MANIFEST="$ROOT/samples/benchmark/corpus_manifest.example.tsv"
EXPECTED_HEADER=$'id\tformat\ttier\tpath_or_uri\tsize_bytes\tlicense\tprovenance\tinclude_daily\tinclude_pre_release\tnotes'

trim_field() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

usage() {
  cat <<EOF
usage: ./samples/helpers/validation/check_corpus_manifest.sh [MANIFEST.tsv]

Default manifest:
  samples/benchmark/corpus_manifest.example.tsv

Validation scope:
  * exact header match
  * required field presence
  * id uniqueness and format
  * format / tier / boolean validation
  * size_bytes numeric validation when present
  * tier-aware path_or_uri safety checks

Exit codes:
  0  manifest ok
  1  manifest validation failed
  2  bad invocation, missing file, or malformed header
EOF
}

is_valid_id() {
  [[ "${1-}" =~ ^[A-Za-z0-9_.-]+$ ]]
}

is_valid_bool() {
  case "${1-}" in
    true|false)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_non_negative_int() {
  [[ "${1-}" =~ ^[0-9]+$ ]]
}

is_valid_format() {
  case "${1-}" in
    txt|markdown|csv|tsv|json|yaml|xml|html|xlsx|zip|epub|docx|pptx|pdf|mixed)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

normalize_tier() {
  case "${1-}" in
    regression|smoke|synthetic|public|private|manual)
      printf '%s' "$1"
      ;;
    tier0)
      printf 'regression'
      ;;
    tier1)
      printf 'smoke'
      ;;
    tier2)
      printf 'synthetic'
      ;;
    tier3)
      printf 'public'
      ;;
    tier4)
      printf 'private'
      ;;
    *)
      return 1
      ;;
  esac
}

looks_like_url() {
  [[ "${1-}" =~ ^[A-Za-z][A-Za-z0-9+.-]*:// ]]
}

is_repo_relative_path() {
  [[ "${1-}" != /* ]]
}

validate_repo_path_exists() {
  local rel_path="${1-}"
  [[ -e "$ROOT/$rel_path" ]]
}

report_error() {
  local row_label="${1-}"
  shift
  printf 'manifest validation error [%s]: %s\n' "$row_label" "$*" >&2
  FAILED=1
}

if [[ "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

MANIFEST_PATH="${1:-$DEFAULT_MANIFEST}"
if [[ "$MANIFEST_PATH" != /* ]]; then
  MANIFEST_PATH="$ROOT/$MANIFEST_PATH"
fi

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "manifest not found: $MANIFEST_PATH" >&2
  exit 2
fi

FAILED=0
DATA_ROWS=0
LINE_NO=0
HEADER_SEEN=0
SEEN_IDS=$'\n'

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  LINE_NO=$((LINE_NO + 1))
  line="$(trim_field "$raw_line")"
  [[ -z "$line" ]] && continue

  if [[ "${line#\#}" != "$line" ]]; then
    continue
  fi

  if [[ $HEADER_SEEN -eq 0 ]]; then
    HEADER_SEEN=1
    if [[ "$line" != "$EXPECTED_HEADER" ]]; then
      echo "manifest header mismatch: $MANIFEST_PATH" >&2
      echo "expected: $EXPECTED_HEADER" >&2
      echo "actual:   $line" >&2
      exit 2
    fi
    continue
  fi

  IFS=$'\t' read -r id format tier path_or_uri size_bytes license provenance include_daily include_pre_release notes extra <<< "$raw_line"
  id="$(trim_field "${id-}")"
  format="$(trim_field "${format-}")"
  tier="$(trim_field "${tier-}")"
  path_or_uri="$(trim_field "${path_or_uri-}")"
  size_bytes="$(trim_field "${size_bytes-}")"
  license="$(trim_field "${license-}")"
  provenance="$(trim_field "${provenance-}")"
  include_daily="$(trim_field "${include_daily-}")"
  include_pre_release="$(trim_field "${include_pre_release-}")"
  notes="$(trim_field "${notes-}")"

  row_label="line $LINE_NO"
  if [[ -n "${id-}" ]]; then
    row_label="id=$id"
  fi

  if [[ -n "${extra-}" ]]; then
    report_error "$row_label" "expected 10 tab-separated columns"
    continue
  fi

  if [[ -z "$id" || -z "$format" || -z "$tier" || -z "$path_or_uri" || -z "$license" || -z "$provenance" || -z "$include_daily" || -z "$include_pre_release" ]]; then
    report_error "$row_label" "missing required field"
    continue
  fi

  if ! is_valid_id "$id"; then
    report_error "$row_label" "id must match [A-Za-z0-9_.-]+"
  fi

  if [[ "$SEEN_IDS" == *$'\n'"$id"$'\n'* ]]; then
    report_error "$row_label" "duplicate id"
  else
    SEEN_IDS+="$id"$'\n'
  fi

  if ! is_valid_format "$format"; then
    report_error "$row_label" "unsupported format '$format'"
  fi

  if ! normalized_tier="$(normalize_tier "$tier")"; then
    report_error "$row_label" "unsupported tier '$tier'"
    normalized_tier=""
  fi

  if ! is_valid_bool "$include_daily"; then
    report_error "$row_label" "include_daily must be true or false"
  fi

  if ! is_valid_bool "$include_pre_release"; then
    report_error "$row_label" "include_pre_release must be true or false"
  fi

  if [[ -n "$size_bytes" ]] && ! is_non_negative_int "$size_bytes"; then
    report_error "$row_label" "size_bytes must be empty or a non-negative integer"
  fi

  case "$normalized_tier" in
    regression|smoke|synthetic)
      if ! is_repo_relative_path "$path_or_uri"; then
        report_error "$row_label" "checked-in tiers must use repo-relative paths"
      elif [[ "$path_or_uri" != samples/* ]]; then
        report_error "$row_label" "checked-in tiers should use paths under samples/"
      elif ! validate_repo_path_exists "$path_or_uri"; then
        report_error "$row_label" "checked-in path does not exist"
      fi
      ;;
    public)
      if [[ "$license" == "unknown" || "$provenance" == "unknown" ]]; then
        report_error "$row_label" "public tier must use explicit non-unknown license/provenance"
      fi
      if ! looks_like_url "$path_or_uri"; then
        if is_repo_relative_path "$path_or_uri"; then
          if ! validate_repo_path_exists "$path_or_uri"; then
            report_error "$row_label" "public relative path does not exist"
          fi
        fi
      fi
      ;;
    private|manual)
      if [[ "$include_daily" != "false" ]]; then
        report_error "$row_label" "private/manual entries must not be included in daily suite"
      fi
      if [[ "$include_pre_release" != "false" ]]; then
        report_error "$row_label" "private/manual entries must not be included in pre-release suite"
      fi
      if is_repo_relative_path "$path_or_uri" && [[ "$path_or_uri" == samples/* ]] && validate_repo_path_exists "$path_or_uri"; then
        report_error "$row_label" "private/manual entries should not point at checked-in repo samples"
      fi
      ;;
  esac

  DATA_ROWS=$((DATA_ROWS + 1))
done < "$MANIFEST_PATH"

if [[ $HEADER_SEEN -eq 0 ]]; then
  echo "manifest is empty or missing header: $MANIFEST_PATH" >&2
  exit 2
fi

if [[ $FAILED -ne 0 ]]; then
  exit 1
fi

echo "CORPUS MANIFEST OK ($DATA_ROWS rows): $MANIFEST_PATH"
