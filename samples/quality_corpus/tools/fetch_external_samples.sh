#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SOURCES_PATH="$ROOT/samples/quality_corpus/external_sources.tsv"
CACHE_ROOT="$ROOT/.external/quality_corpus"

usage() {
  cat <<'EOF'
usage:
  bash ./samples/quality_corpus/tools/fetch_external_samples.sh --list-sources
  bash ./samples/quality_corpus/tools/fetch_external_samples.sh --prepare-cache
  bash ./samples/quality_corpus/tools/fetch_external_samples.sh --source <id>

Notes:
  * this helper does not auto-download large datasets
  * this helper does not auto-clone repositories
  * it only prints source catalog rows, cache prep actions, and manual guidance
EOF
}

trim_cr() {
  local value="${1-}"
  value="${value%$'\r'}"
  printf '%s' "$value"
}

source_row_by_id() {
  local wanted_id="$1"
  local line_no=0
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    raw_line="$(trim_cr "$raw_line")"
    line_no=$((line_no + 1))
    [[ "$line_no" -eq 1 ]] && continue
    [[ -z "$raw_line" ]] && continue
    [[ "${raw_line#\#}" != "$raw_line" ]] && continue
    IFS=$'\t' read -r id _ <<< "$raw_line"
    if [[ "$id" == "$wanted_id" ]]; then
      printf '%s\n' "$raw_line"
      return 0
    fi
  done < "$SOURCES_PATH"
  return 1
}

list_sources() {
  cat "$SOURCES_PATH"
}

prepare_cache() {
  local created=0
  local line_no=0
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    raw_line="$(trim_cr "$raw_line")"
    line_no=$((line_no + 1))
    [[ "$line_no" -eq 1 ]] && continue
    [[ -z "$raw_line" ]] && continue
    [[ "${raw_line#\#}" != "$raw_line" ]] && continue
    IFS=$'\t' read -r _ _ _ _ _ _ _ _ _ local_cache _ _ <<< "$raw_line"
    [[ -z "$local_cache" ]] && continue
    mkdir -p "$ROOT/$local_cache"
    created=$((created + 1))
    printf 'prepared %s\n' "$local_cache"
  done < "$SOURCES_PATH"
  printf 'prepared %s external cache directories under %s\n' "$created" "$CACHE_ROOT"
}

print_source_help() {
  local source_id="$1"
  local row
  if ! row="$(source_row_by_id "$source_id")"; then
    echo "unknown source id: $source_id" >&2
    exit 1
  fi

  IFS=$'\t' read -r id source_name formats source_type url license_status redistributable recommended_use download_mode local_cache priority notes <<< "$row"

  cat <<EOF
source_id: $id
source_name: $source_name
formats: $formats
source_type: $source_type
url: $url
license_status: $license_status
redistributable: $redistributable
recommended_use: $recommended_use
download_mode: $download_mode
local_cache: $local_cache
priority: $priority
notes: $notes

manual guidance:
  1. review the upstream repository or dataset terms first
  2. prepare the cache root with:
     bash ./samples/quality_corpus/tools/fetch_external_samples.sh --prepare-cache
  3. place only a small manually selected subset under:
     $local_cache
  4. register local rows in:
     samples/quality_corpus/external_manifest.local.tsv
  5. keep license_review_status as pending_review until your local review is complete
EOF

  case "$id" in
    microsoft_markitdown_tests|pandoc_tests)
      cat <<'EOF'

optional sparse-checkout idea (not executed by this script):
  git clone --filter=blob:none --no-checkout <repo-url> <local-dir>
  git -C <local-dir> sparse-checkout init --cone
  git -C <local-dir> sparse-checkout set <subdir>
EOF
      ;;
  esac
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

case "$1" in
  --list-sources)
    list_sources
    ;;
  --prepare-cache)
    prepare_cache
    ;;
  --source)
    [[ $# -ge 2 ]] || { usage >&2; exit 1; }
    print_source_help "$2"
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "unknown argument: $1" >&2
    usage >&2
    exit 1
    ;;
esac
