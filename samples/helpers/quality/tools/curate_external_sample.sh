#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
QUALITY_LAB_ROOT="${MARKITDOWN_QUALITY_LAB:-$ROOT/markitdown-quality-lab}"
SOURCES_PATH="$QUALITY_LAB_ROOT/external_quality/_quality_rows_staging/source_catalog.tsv"
HEADER=$'id\tformat\tpath\tsource_type\tsource_id\tlicense_status\tlicense_review_status\tprivacy\tsize_class\tfeatures\texpected_signals\tquality_tier\toriginal_url\tlocal_cache_path\tnotes'

usage() {
  cat <<'EOF'
usage:
  bash ./samples/helpers/quality/tools/curate_external_sample.sh --print-header
  bash ./samples/helpers/quality/tools/curate_external_sample.sh \
    --id <row_id> \
    --format <format> \
    --source-id <catalog_id> \
    --path <local_cache_file> \
    --features <feature;feature> \
    --signals <signal;signal> \
    --tier <gate|reference|stress|known_bad> \
    [--size-class <small|medium|large>] \
    [--privacy <external_cache|private_local|public>] \
    [--license-review-status <pending_review|approved|rejected>] \
    [--notes <text>]

This helper prints one TSV row template to stdout. It does not copy files and
does not modify any manifest automatically.

Canonical row paths should use repo-relative payload paths under
`external_quality/<format>/<source>/...`.
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

lookup_source() {
  detect_sources_path
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

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

row_id=""
format=""
source_id=""
path=""
features=""
signals=""
tier=""
size_class="unknown"
privacy="external_cache"
license_review_status="pending_review"
notes=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-header)
      printf '%s\n' "$HEADER"
      exit 0
      ;;
    --id)
      row_id="${2-}"
      shift 2
      ;;
    --format)
      format="${2-}"
      shift 2
      ;;
    --source-id)
      source_id="${2-}"
      shift 2
      ;;
    --path)
      path="${2-}"
      shift 2
      ;;
    --features)
      features="${2-}"
      shift 2
      ;;
    --signals)
      signals="${2-}"
      shift 2
      ;;
    --tier)
      tier="${2-}"
      shift 2
      ;;
    --size-class)
      size_class="${2-}"
      shift 2
      ;;
    --privacy)
      privacy="${2-}"
      shift 2
      ;;
    --license-review-status)
      license_review_status="${2-}"
      shift 2
      ;;
    --notes)
      notes="${2-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$row_id" || -z "$format" || -z "$source_id" || -z "$path" || -z "$features" || -z "$signals" || -z "$tier" ]]; then
  usage >&2
  exit 1
fi

source_row="$(lookup_source "$source_id" || true)"
if [[ -z "$source_row" ]]; then
  echo "unknown source id: $source_id" >&2
  exit 1
fi

IFS=$'\t' read -r _ _ _ source_type original_url license_status _ _ _ local_cache_path _ _ <<< "$source_row"

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$row_id" \
  "$format" \
  "$path" \
  "$source_type" \
  "$source_id" \
  "$license_status" \
  "$license_review_status" \
  "$privacy" \
  "$size_class" \
  "$features" \
  "$signals" \
  "$tier" \
  "$original_url" \
  "$local_cache_path" \
  "$notes"
