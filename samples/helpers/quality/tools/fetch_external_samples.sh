#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
QUALITY_LAB_ROOT="${MARKITDOWN_QUALITY_LAB:-$ROOT/markitdown-quality-lab}"
SOURCES_PATH="$QUALITY_LAB_ROOT/external_quality/_quality_rows_staging/source_catalog.tsv"
LEGACY_CACHE_ROOT="$ROOT/.external/quality_corpus"
DEFAULT_CACHE_ROOT="$QUALITY_LAB_ROOT/external_quality"
CACHE_ROOT="${MARKITDOWN_QUALITY_CORPUS:-$DEFAULT_CACHE_ROOT}"

usage() {
  cat <<'EOF'
usage:
  bash ./samples/helpers/quality/tools/fetch_external_samples.sh --list-sources
  bash ./samples/helpers/quality/tools/fetch_external_samples.sh --prepare-cache
  bash ./samples/helpers/quality/tools/fetch_external_samples.sh --source <id>

Notes:
  * this helper does not auto-download large datasets
  * this helper does not auto-clone repositories
  * it only prints source catalog rows, cache prep actions, and manual guidance
  * source catalog discovery prefers markitdown-quality-lab/external_quality/_quality_rows_staging/source_catalog.tsv
EOF
}

trim_cr() {
  local value="${1-}"
  value="${value%$'\r'}"
  printf '%s' "$value"
}

detect_sources_path() {
  if [[ ! -f "$SOURCES_PATH" ]]; then
    echo "source catalog not found: $SOURCES_PATH" >&2
    echo "clone the quality-lab into markitdown-quality-lab/ or set MARKITDOWN_QUALITY_LAB" >&2
    exit 1
  fi
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
  detect_sources_path
  cat "$SOURCES_PATH"
}

prepare_cache() {
  detect_sources_path
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
    local target_dir=""
    if [[ "$local_cache" == .external/quality_corpus/* ]]; then
      local suffix="${local_cache#.external/quality_corpus/}"
      target_dir="$CACHE_ROOT/$suffix"
    elif [[ "$local_cache" == external_quality/* || "$local_cache" == pdf_model_training/* ]]; then
      target_dir="$QUALITY_LAB_ROOT/$local_cache"
    elif [[ "$local_cache" == /* ]]; then
      target_dir="$local_cache"
    else
      target_dir="$ROOT/$local_cache"
    fi
    mkdir -p "$target_dir"
    created=$((created + 1))
    printf 'prepared %s\n' "$target_dir"
  done < "$SOURCES_PATH"
  printf 'prepared %s external cache directories under %s\n' "$created" "$CACHE_ROOT"
}

print_source_help() {
  detect_sources_path
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
     bash ./samples/helpers/quality/tools/fetch_external_samples.sh --prepare-cache
  3. place only a small manually selected subset under:
     $CACHE_ROOT
  4. register local rows in:
     markitdown-quality-lab/external_quality/_quality_rows_staging/manifest.tsv
  5. prefer canonical external-quality row paths under:
     external_quality/<format>/<source>/...
  6. keep license_review_status as pending_review until your local review is complete
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
