#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"

MANIFEST_PATH="$ROOT/samples/quality_corpus/manifest.tsv"
LEGACY_EXTERNAL_MANIFEST_PATH="$ROOT/samples/quality_corpus/external_manifest.local.tsv"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_ROOT="$TMP_ROOT/quality_corpus"
OUTPUT_DIR="$OUT_ROOT/outputs"
SUMMARY_TSV="$OUT_ROOT/summary.tsv"
SUMMARY_MD="$OUT_ROOT/summary.md"
ROWS_TSV="$OUT_ROOT/rows.tsv"
SUMMARY_BY_FORMAT_TSV="$OUT_ROOT/summary.by_format.tsv"
SUMMARY_BY_SOURCE_TSV="$OUT_ROOT/summary.by_source.tsv"
SUMMARY_BY_TIER_TSV="$OUT_ROOT/summary.by_tier.tsv"
KNOWN_BAD_TSV="$OUT_ROOT/known_bad.tsv"
UNEXPECTED_PASS_TSV="$OUT_ROOT/unexpected_pass.tsv"
SKIPPED_LICENSE_TSV="$OUT_ROOT/skipped_license.tsv"
MODE="all"
FILTER_ID=""
FILTER_SOURCE=""
FILTER_FORMAT=""
LIST_ONLY=0
METADATA_ENABLED=1
PROFILE_ENABLED=0
PROFILE_TSV="$OUT_ROOT/profile.tsv"
CORPUS_ROOT_OVERRIDE=""
LAB_MANIFEST_OVERRIDE=""
REQUIRE_LAB=0
CORPUS_ROOT=""
CORPUS_ROOT_SOURCE=""
CORPUS_ROOT_CANDIDATES=()
CORPUS_ROOT_CANDIDATE_LABELS=()
QUALITY_ROWS_MANIFEST=""
QUALITY_ROWS_MANIFEST_SOURCE=""
QUALITY_ROWS_MANIFEST_CANDIDATES=()
QUALITY_ROWS_MANIFEST_CANDIDATE_LABELS=()
RESOLVED_EXTERNAL_PATH=""
TRIED_EXTERNAL_PATHS=()

PUBLIC_HEADER=$'id\tformat\tpath\tsource_type\tlicense_status\tprivacy\tsize_class\tfeatures\texpected_signals\tquality_tier\tnotes'
EXTERNAL_HEADER=$'id\tformat\tpath\tsource_type\tsource_id\tlicense_status\tlicense_review_status\tprivacy\tsize_class\tfeatures\texpected_signals\tquality_tier\toriginal_url\tlocal_cache_path\tnotes'

usage() {
  cat <<'EOF'
usage: ./samples/quality_corpus/check.sh [--public-only | --private-only] [--id <id>] [--source <source_id>] [--format <format>] [--corpus-root <path>] [--lab-manifest <path>] [--require-lab] [--list] [--no-metadata] [--profile]

Modes:
  --public-only   run only checked-in public intake rows
  --private-only  legacy mode: run only the legacy local fallback manifest
  --list          list merged manifest rows after filters, without running conversion
  --no-metadata   run conversion without --with-metadata for profiling
  --profile       write per-row timing diagnostics to .tmp/quality_corpus/profile.tsv

Filters:
  --id <id>           match one exact row id
  --source <source>   match external rows by source_id
  --format <format>   match rows by format
  --corpus-root <path>
                      resolve external corpus payloads from this root first
  --lab-manifest <path>
                      resolve tracked external/local quality rows from this
                      manifest first
  --require-lab       fail if no lab quality-row manifest is available

Filter semantics:
  * multiple filters are combined with AND
  * source_id filtering only matches external rows
  * filters do not bypass license or file-presence gate semantics
  * external payload discovery checks, in order:
      --corpus-root
      MARKITDOWN_QUALITY_CORPUS
      MARKITDOWN_QUALITY_LAB/corpus
      markitdown-quality-lab/corpus
      ../markitdown-quality-lab/corpus
      .external/quality_corpus (legacy fallback)
  * lab quality-row manifest discovery checks, in order:
      --lab-manifest
      MARKITDOWN_QUALITY_MANIFEST
      MARKITDOWN_QUALITY_LAB/quality_rows/manifest.tsv
      markitdown-quality-lab/quality_rows/manifest.tsv
      ../markitdown-quality-lab/quality_rows/manifest.tsv
      legacy samples/quality_corpus/external_manifest.local.tsv
  * --no-metadata disables sidecar metadata generation but keeps all other checks
  * --profile is diagnostic-only and does not change pass/fail semantics

Notes:
  * empty public manifest is valid
  * missing lab quality-row manifest falls back to the legacy local manifest
    unless --require-lab is set
  * non-approved external rows are skipped
  * missing external legacy files are recorded as skipped when appropriate
  * this is a signal-level intake checker, not an exact-output regression gate
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --public-only)
      MODE="public"
      ;;
    --private-only)
      MODE="private"
      ;;
    --id)
      [[ $# -ge 2 ]] || {
        echo "missing value for --id" >&2
        usage >&2
        exit 1
      }
      FILTER_ID="$2"
      shift
      ;;
    --source)
      [[ $# -ge 2 ]] || {
        echo "missing value for --source" >&2
        usage >&2
        exit 1
      }
      FILTER_SOURCE="$2"
      shift
      ;;
    --format)
      [[ $# -ge 2 ]] || {
        echo "missing value for --format" >&2
        usage >&2
        exit 1
      }
      FILTER_FORMAT="$2"
      shift
      ;;
    --corpus-root)
      [[ $# -ge 2 ]] || {
        echo "missing value for --corpus-root" >&2
        usage >&2
        exit 1
      }
      CORPUS_ROOT_OVERRIDE="$2"
      shift
      ;;
    --lab-manifest)
      [[ $# -ge 2 ]] || {
        echo "missing value for --lab-manifest" >&2
        usage >&2
        exit 1
      }
      LAB_MANIFEST_OVERRIDE="$2"
      shift
      ;;
    --require-lab)
      REQUIRE_LAB=1
      ;;
    --list)
      LIST_ONLY=1
      ;;
    --no-metadata)
      METADATA_ENABLED=0
      ;;
    --profile)
      PROFILE_ENABLED=1
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
  shift
done

mkdir -p "$OUTPUT_DIR"

trim_cr() {
  local value="${1-}"
  value="${value%$'\r'}"
  printf '%s' "$value"
}

add_corpus_root_candidate() {
  local label="$1"
  local path="${2-}"
  if [[ -z "$path" ]]; then
    return 0
  fi
  CORPUS_ROOT_CANDIDATE_LABELS+=("$label")
  CORPUS_ROOT_CANDIDATES+=("$path")
}

add_quality_rows_manifest_candidate() {
  local label="$1"
  local path="${2-}"
  if [[ -z "$path" ]]; then
    return 0
  fi
  QUALITY_ROWS_MANIFEST_CANDIDATE_LABELS+=("$label")
  QUALITY_ROWS_MANIFEST_CANDIDATES+=("$path")
}

detect_corpus_root() {
  CORPUS_ROOT=""
  CORPUS_ROOT_SOURCE=""
  CORPUS_ROOT_CANDIDATES=()
  CORPUS_ROOT_CANDIDATE_LABELS=()

  add_corpus_root_candidate "--corpus-root" "$CORPUS_ROOT_OVERRIDE"
  add_corpus_root_candidate "MARKITDOWN_QUALITY_CORPUS" "${MARKITDOWN_QUALITY_CORPUS:-}"
  if [[ -n "${MARKITDOWN_QUALITY_LAB:-}" ]]; then
    add_corpus_root_candidate "MARKITDOWN_QUALITY_LAB/corpus" "${MARKITDOWN_QUALITY_LAB%/}/corpus"
  fi
  add_corpus_root_candidate "repo-local quality lab" "$ROOT/markitdown-quality-lab/corpus"
  add_corpus_root_candidate "sibling quality lab" "$ROOT/../markitdown-quality-lab/corpus"
  add_corpus_root_candidate "legacy sibling corpus" "$ROOT/../markitdown-quality-corpus"
  add_corpus_root_candidate "legacy .external fallback" "$ROOT/.external/quality_corpus"

  local i
  for i in "${!CORPUS_ROOT_CANDIDATES[@]}"; do
    local candidate="${CORPUS_ROOT_CANDIDATES[$i]}"
    local label="${CORPUS_ROOT_CANDIDATE_LABELS[$i]}"
    local abs="$candidate"
    if [[ "$abs" != /* ]]; then
      abs="$ROOT/$abs"
    fi
    local parent
    parent="$(dirname "$abs")"
    if [[ ! -d "$parent" ]]; then
      continue
    fi
    abs="$(cd "$parent" && pwd)/$(basename "$abs")"
    if [[ -d "$abs" ]]; then
      CORPUS_ROOT="$abs"
      CORPUS_ROOT_SOURCE="$label"
      return
    fi
  done
}

detect_quality_rows_manifest() {
  QUALITY_ROWS_MANIFEST=""
  QUALITY_ROWS_MANIFEST_SOURCE=""
  QUALITY_ROWS_MANIFEST_CANDIDATES=()
  QUALITY_ROWS_MANIFEST_CANDIDATE_LABELS=()

  add_quality_rows_manifest_candidate "--lab-manifest" "$LAB_MANIFEST_OVERRIDE"
  add_quality_rows_manifest_candidate "MARKITDOWN_QUALITY_MANIFEST" "${MARKITDOWN_QUALITY_MANIFEST:-}"
  if [[ -n "${MARKITDOWN_QUALITY_LAB:-}" ]]; then
    add_quality_rows_manifest_candidate \
      "MARKITDOWN_QUALITY_LAB/quality_rows/manifest.tsv" \
      "${MARKITDOWN_QUALITY_LAB%/}/quality_rows/manifest.tsv"
  fi
  add_quality_rows_manifest_candidate \
    "repo-local quality rows manifest" \
    "$ROOT/markitdown-quality-lab/quality_rows/manifest.tsv"
  add_quality_rows_manifest_candidate \
    "sibling quality rows manifest" \
    "$ROOT/../markitdown-quality-lab/quality_rows/manifest.tsv"
  add_quality_rows_manifest_candidate \
    "legacy local external manifest" \
    "$LEGACY_EXTERNAL_MANIFEST_PATH"

  local i
  for i in "${!QUALITY_ROWS_MANIFEST_CANDIDATES[@]}"; do
    local candidate="${QUALITY_ROWS_MANIFEST_CANDIDATES[$i]}"
    local label="${QUALITY_ROWS_MANIFEST_CANDIDATE_LABELS[$i]}"
    local abs="$candidate"
    if [[ "$abs" != /* ]]; then
      abs="$ROOT/$abs"
    fi
    local parent
    parent="$(dirname "$abs")"
    if [[ ! -d "$parent" ]]; then
      continue
    fi
    abs="$(cd "$parent" && pwd)/$(basename "$abs")"
    if [[ -f "$abs" ]]; then
      QUALITY_ROWS_MANIFEST="$abs"
      QUALITY_ROWS_MANIFEST_SOURCE="$label"
      return
    fi
  done
}

append_unique_path() {
  local value="$1"
  if [[ -z "$value" ]]; then
    return 0
  fi
  local existing
  for existing in "${TRIED_EXTERNAL_PATHS[@]-}"; do
    if [[ "$existing" == "$value" ]]; then
      return 0
    fi
  done
  TRIED_EXTERNAL_PATHS+=("$value")
}

resolve_external_input_path() {
  local original_path="$1"
  RESOLVED_EXTERNAL_PATH=""
  TRIED_EXTERNAL_PATHS=()

  local path="$original_path"
  if [[ "$path" == /* ]]; then
    append_unique_path "$path"
    if [[ -f "$path" ]]; then
      RESOLVED_EXTERNAL_PATH="$path"
      return 0
    fi
  else
    local repo_candidate="$ROOT/$path"
    local legacy_prefix=".external/quality_corpus/"
    local legacy_abs_prefix="$ROOT/.external/quality_corpus/"
    local relative_suffix=""
    if [[ "$path" == "$legacy_prefix"* ]]; then
      relative_suffix="${path#$legacy_prefix}"
    elif [[ "$repo_candidate" == "$legacy_abs_prefix"* ]]; then
      relative_suffix="${repo_candidate#$legacy_abs_prefix}"
    elif [[ -n "$CORPUS_ROOT" ]]; then
      relative_suffix="$path"
    fi

    if [[ -n "$CORPUS_ROOT" && -n "$relative_suffix" ]]; then
      local corpus_candidate="$CORPUS_ROOT/$relative_suffix"
      append_unique_path "$corpus_candidate"
      if [[ -f "$corpus_candidate" ]]; then
        RESOLVED_EXTERNAL_PATH="$corpus_candidate"
        return 0
      fi
    fi

    append_unique_path "$repo_candidate"
    if [[ -f "$repo_candidate" ]]; then
      RESOLVED_EXTERNAL_PATH="$repo_candidate"
      return 0
    fi
  fi

  return 1
}

format_missing_external_note() {
  local original_path="$1"
  if [[ "${#TRIED_EXTERNAL_PATHS[@]}" -eq 0 ]]; then
    printf 'external file missing: %s; set MARKITDOWN_QUALITY_CORPUS or pass --corpus-root' "$original_path"
    return
  fi
  local joined=""
  local item
  for item in "${TRIED_EXTERNAL_PATHS[@]}"; do
    if [[ -n "$joined" ]]; then
      joined="$joined | "
    fi
    joined="$joined$item"
  done
  printf 'external file missing: %s; tried: %s; hint: set MARKITDOWN_QUALITY_CORPUS or pass --corpus-root' "$original_path" "$joined"
}

normalize_text() {
  local path="$1"
  python3 - "$path" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
text = text.replace("\r\n", "\n").replace("\r", "\n")
sys.stdout.write(text)
PY
}

check_non_empty_output_file() {
  local path="$1"
  python3 - "$path" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8", errors="replace") as f:
    for chunk in iter(lambda: f.read(65536), ""):
        for ch in chunk:
            if not ch.isspace():
                raise SystemExit(0)
raise SystemExit(1)
PY
}

normalized_text_without_asset_urls() {
  local path="$1"
  python3 - "$path" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
text = text.replace("\r\n", "\n").replace("\r", "\n")

# Strip markdown image/link target paths and raw URLs before token-length checks.
text = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', r'!\1', text)
text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'\1', text)
text = re.sub(r'https?://\S+', '', text)

sys.stdout.write(text)
PY
}

normalize_public_row() {
  local scope="$1"
  local raw_line="$2"
  local delimiter=$'\x1f'
  local converted="${raw_line//$'\t'/$delimiter}"
  local id format path source_type license_status privacy size_class features expected_signals quality_tier notes
  IFS="$delimiter" read -r id format path source_type license_status privacy size_class features expected_signals quality_tier notes <<< "$converted"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$scope" \
    "$id" \
    "$format" \
    "$path" \
    "$source_type" \
    "" \
    "$license_status" \
    "approved" \
    "$privacy" \
    "$size_class" \
    "$features" \
    "$expected_signals" \
    "$quality_tier" \
    "" \
    "$notes"
}

normalize_external_row() {
  local raw_line="$1"
  local delimiter=$'\x1f'
  local converted="${raw_line//$'\t'/$delimiter}"
  local id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url local_cache_path notes
  IFS="$delimiter" read -r id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url local_cache_path notes <<< "$converted"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "external" \
    "$id" \
    "$format" \
    "$path" \
    "$source_type" \
    "$source_id" \
    "$license_status" \
    "$license_review_status" \
    "$privacy" \
    "$size_class" \
    "$features" \
    "$expected_signals" \
    "$quality_tier" \
    "$original_url" \
    "$notes"
}

manifest_rows_from_file() {
  local manifest_path="$1"
  local scope="$2"
  local expected_header="$3"
  local normalizer="$4"
  [[ -f "$manifest_path" ]] || return 0

  local line_no=0
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    raw_line="$(trim_cr "$raw_line")"
    line_no=$((line_no + 1))
    if [[ "$line_no" -eq 1 ]]; then
      if [[ "$raw_line" != "$expected_header" ]]; then
        echo "quality_corpus manifest header mismatch: $manifest_path" >&2
        echo "expected: $expected_header" >&2
        echo "actual:   $raw_line" >&2
        exit 1
      fi
      continue
    fi
    [[ -z "$raw_line" ]] && continue
    [[ "${raw_line#\#}" != "$raw_line" ]] && continue
    "$normalizer" "$scope" "$raw_line"
  done < "$manifest_path"
}

normalize_external_manifest_entry() {
  local _scope="$1"
  local raw_line="$2"
  normalize_external_row "$raw_line"
}

collect_manifest_rows() {
  local rows=()
  if [[ "$MODE" != "private" ]]; then
    while IFS= read -r row; do
      [[ -n "$row" ]] && rows+=("$row")
    done < <(manifest_rows_from_file "$MANIFEST_PATH" "public" "$PUBLIC_HEADER" normalize_public_row)
  fi
  if [[ "$MODE" != "public" && -n "$QUALITY_ROWS_MANIFEST" ]]; then
    while IFS= read -r row; do
      [[ -n "$row" ]] && rows+=("$row")
    done < <(manifest_rows_from_file "$QUALITY_ROWS_MANIFEST" "external" "$EXTERNAL_HEADER" normalize_external_manifest_entry)
  else
    if [[ "$MODE" != "public" && -f "$LEGACY_EXTERNAL_MANIFEST_PATH" ]]; then
      while IFS= read -r row; do
        [[ -n "$row" ]] && rows+=("$row")
      done < <(manifest_rows_from_file "$LEGACY_EXTERNAL_MANIFEST_PATH" "external" "$EXTERNAL_HEADER" normalize_external_manifest_entry)
    fi
  fi
  if [[ "${#rows[@]}" -eq 0 ]]; then
    return 0
  fi
  printf '%s\n' "${rows[@]}"
}

detect_corpus_root
detect_quality_rows_manifest

if [[ "$REQUIRE_LAB" -ne 0 && -z "$QUALITY_ROWS_MANIFEST" ]]; then
  echo "quality_corpus lab manifest not found" >&2
  local_manifest_idx=0
  for local_manifest_idx in "${!QUALITY_ROWS_MANIFEST_CANDIDATES[@]}"; do
    echo "tried: ${QUALITY_ROWS_MANIFEST_CANDIDATE_LABELS[$local_manifest_idx]} -> ${QUALITY_ROWS_MANIFEST_CANDIDATES[$local_manifest_idx]}" >&2
  done
  echo "hint: pass --lab-manifest or set MARKITDOWN_QUALITY_MANIFEST / MARKITDOWN_QUALITY_LAB" >&2
  exit 1
fi

filter_summary_value() {
  local value="${1-}"
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
  else
    printf '*'
  fi
}

metadata_summary_value() {
  if [[ "$METADATA_ENABLED" -ne 0 ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

is_known_bad_tier() {
  local quality_tier="${1-}"
  [[ "$quality_tier" == "known_bad" ]]
}

profile_now_ms() {
  python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

profile_enabled_summary_value() {
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

profile_init() {
  if [[ "$PROFILE_ENABLED" -eq 0 ]]; then
    return
  fi
  mkdir -p "$OUT_ROOT"
  printf 'row_id\tstage\telapsed_ms\tnotes\n' > "$PROFILE_TSV"
}

profile_record() {
  local row_id="$1"
  local stage="$2"
  local elapsed_ms="$3"
  local notes="${4-}"
  if [[ "$PROFILE_ENABLED" -eq 0 ]]; then
    return
  fi
  printf '%s\t%s\t%s\t%s\n' "$row_id" "$stage" "$elapsed_ms" "$notes" >> "$PROFILE_TSV"
}

profile_signal_stage_name() {
  local signal="${1-}"
  case "$signal" in
    no_empty_output)
      printf 'no_empty_output'
      ;;
    contains:*)
      printf 'contains'
      ;;
    contains_all:*)
      printf 'contains_all'
      ;;
    exact_count:*)
      printf 'exact_count'
      ;;
    min_count:*)
      printf 'min_count'
      ;;
    max_count:*)
      printf 'max_count'
      ;;
    not_contains:*)
      printf 'not_contains'
      ;;
    order:*)
      printf 'order'
      ;;
    page_noise_absent:*)
      printf 'page_noise_absent'
      ;;
    max_long_token_len:*)
      printf 'max_long_token_len'
      ;;
    line_fragmentation_max:*)
      printf 'line_fragmentation_max'
      ;;
    heading_marker:*)
      printf 'heading_marker'
      ;;
    table_marker)
      printf 'table_marker'
      ;;
    image_ref)
      printf 'image_ref'
      ;;
    link_ref)
      printf 'link_ref'
      ;;
    metadata_file)
      printf 'metadata_file'
      ;;
    review_note:*)
      printf 'review_note'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

profile_signal_notes() {
  local signal="${1-}"
  local status="${2-}"
  python3 - "$signal" "$status" <<'PY'
import sys
signal = sys.argv[1]
status = sys.argv[2]
signal = signal.replace("\t", " ").replace("\n", " ")
if len(signal) > 80:
    signal = signal[:77] + "..."
print(f"{status}; {signal}")
PY
}

row_matches_filters() {
  local row="$1"
  local delimiter=$'\x1f'
  local converted="${row//$'\t'/$delimiter}"
  local source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes
  IFS="$delimiter" read -r source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes <<< "$converted"

  if [[ -n "$FILTER_ID" && "$id" != "$FILTER_ID" ]]; then
    return 1
  fi
  if [[ -n "$FILTER_SOURCE" && "$source_id" != "$FILTER_SOURCE" ]]; then
    return 1
  fi
  if [[ -n "$FILTER_FORMAT" && "$format" != "$FILTER_FORMAT" ]]; then
    return 1
  fi
  return 0
}

print_filtered_rows() {
  printf 'id\tformat\tsource_id\tlicense_gate\tpath\n'
  local row
  for row in "${FILTERED_ROWS[@]-}"; do
    [[ -n "$row" ]] || continue
    local delimiter=$'\x1f'
    local converted="${row//$'\t'/$delimiter}"
    local source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes
    IFS="$delimiter" read -r source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes <<< "$converted"
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$format" "$source_id" "$license_review_status" "$path"
  done
}

count_assets_on_disk() {
  local out_dir="$1"
  if [[ ! -d "$out_dir/assets" ]]; then
    printf '0'
    return
  fi
  find "$out_dir/assets" -type f | wc -l | tr -d '[:space:]'
}

count_short_lines() {
  local path="$1"
  local threshold=40
  awk -v threshold="$threshold" '
    {
      line=$0
      gsub(/[[:space:]]+$/, "", line)
      if (line != "" && length(line) <= threshold) {
        count++
      }
    }
    END { print count + 0 }
  ' "$path"
}

stdin_contains_all_parts() {
  local parts="$1"
  python3 -c '
import sys

text = sys.stdin.read()
parts = [part for part in sys.argv[1].split("|") if part]
for part in parts:
    if part not in text:
        raise SystemExit(1)
' "$parts"
}

stdin_parts_in_order() {
  local parts="$1"
  python3 -c '
import sys

text = sys.stdin.read()
parts = [part for part in sys.argv[1].split("|") if part]
pos = -1
for part in parts:
    nxt = text.find(part, pos + 1)
    if nxt < 0:
        raise SystemExit(1)
    pos = nxt
' "$parts"
}

stdin_max_long_token_len() {
  local limit="$1"
  python3 -c '
import re
import sys

text = sys.stdin.read()
limit = int(sys.argv[1])
tokens = re.findall(r"\S+", text)
for token in tokens:
    if len(token) > limit:
        raise SystemExit(1)
' "$limit"
}

stdin_count_occurrences() {
  local kind="$1"
  local spec="$2"
  python3 -c '
import sys

kind = sys.argv[1]
spec = sys.argv[2]
text = sys.stdin.read()

if "=" not in spec:
    raise SystemExit(f"{kind}: invalid spec (expected TEXT=N): {spec}")

needle, expected_raw = spec.rsplit("=", 1)
if needle == "":
    raise SystemExit(f"{kind}: empty needle in spec: {spec}")
if not expected_raw.isdigit():
    raise SystemExit(f"{kind}: invalid count {expected_raw!r} for needle {needle!r}")

expected = int(expected_raw)
actual = text.count(needle)

if kind == "exact_count":
    ok = actual == expected
elif kind == "min_count":
    ok = actual >= expected
elif kind == "max_count":
    ok = actual <= expected
else:
    raise SystemExit(f"unknown count assertion kind: {kind}")

if not ok:
    raise SystemExit(
        f"{kind}: needle={needle!r} expected={expected} actual={actual}"
    )
' "$kind" "$spec"
}

check_signal() {
  local signal="$1"
  local markdown_path="$2"
  local metadata_path="$3"
  local output_dir="$4"
  local normalized_text="$5"

  case "$signal" in
    no_empty_output)
      check_non_empty_output_file "$markdown_path"
      ;;
    contains:*)
      [[ "$normalized_text" == *"${signal#contains:}"* ]]
      ;;
    contains_all:*)
      local rest="${signal#contains_all:}"
      printf '%s' "$normalized_text" | stdin_contains_all_parts "$rest"
      ;;
    exact_count:*)
      local spec="${signal#exact_count:}"
      printf '%s' "$normalized_text" | stdin_count_occurrences "exact_count" "$spec"
      ;;
    min_count:*)
      local spec="${signal#min_count:}"
      printf '%s' "$normalized_text" | stdin_count_occurrences "min_count" "$spec"
      ;;
    max_count:*)
      local spec="${signal#max_count:}"
      printf '%s' "$normalized_text" | stdin_count_occurrences "max_count" "$spec"
      ;;
    not_contains:*)
      [[ "$normalized_text" != *"${signal#not_contains:}"* ]]
      ;;
    heading_marker:*)
      local needle="${signal#heading_marker:}"
      grep -Eq "^[[:space:]]*#+[[:space:]]+.*${needle//\//\\/}.*$" "$markdown_path"
      ;;
    table_marker)
      grep -Eq '^[[:space:]]*\|.*\|[[:space:]]*$' "$markdown_path"
      ;;
    image_ref)
      grep -Eq '!\[[^]]*\]\([^)]*\)' "$markdown_path"
      ;;
    link_ref)
      grep -Eq '\[[^]]+\]\([^)]*\)' "$markdown_path"
      ;;
    metadata_file)
      [[ -f "$metadata_path" ]]
      ;;
    asset_count_min:*)
      local min_count="${signal#asset_count_min:}"
      local actual_count
      actual_count="$(count_assets_on_disk "$output_dir")"
      [[ "$actual_count" =~ ^[0-9]+$ ]] || return 1
      (( actual_count >= min_count ))
      ;;
    order:*)
      local rest="${signal#order:}"
      printf '%s' "$normalized_text" | stdin_parts_in_order "$rest"
      ;;
    line_fragmentation_max:*)
      local limit="${signal#line_fragmentation_max:}"
      local actual
      actual="$(count_short_lines "$markdown_path")"
      [[ "$actual" =~ ^[0-9]+$ ]] || return 1
      (( actual <= limit ))
      ;;
    max_long_token_len:*)
      local limit="${signal#max_long_token_len:}"
      local token_text
      token_text="$(normalized_text_without_asset_urls "$markdown_path")"
      printf '%s' "$token_text" | stdin_max_long_token_len "$limit"
      ;;
    page_noise_absent:*)
      [[ "$normalized_text" != *"${signal#page_noise_absent:}"* ]]
      ;;
    review_note:*)
      return 0
      ;;
    *)
      echo "unknown quality signal: $signal" >&2
      return 1
      ;;
  esac
}

dashboard_add() {
  local id="$1"
  local format="$2"
  local scope="$3"
  local source_id="$4"
  local quality_tier="$5"
  local status="$6"
  local passed_signals="$7"
  local total_signals="$8"
  local notes="$9"
  DASHBOARD_ROWS+=("$id|$format|$scope|$source_id|$quality_tier|$status|$passed_signals|$total_signals|$notes")
}

summary_add() {
  local id="$1"
  local format="$2"
  local scope="$3"
  local source_id="$4"
  local quality_tier="$5"
  local status="$6"
  local passed_signals="$7"
  local total_signals="$8"
  local notes="$9"
  SUMMARY_ROWS+=("$id|$format|$scope|$quality_tier|$status|$passed_signals|$total_signals|$notes")
  dashboard_add "$id" "$format" "$scope" "$source_id" "$quality_tier" "$status" "$passed_signals" "$total_signals" "$notes"
}

write_dashboard_views() {
  mkdir -p "$OUT_ROOT"
  {
    printf 'id\tformat\tscope\tsource_id\tquality_tier\tstatus\tpassed_signals\ttotal_signals\tnotes\n'
    local row
    for row in "${DASHBOARD_ROWS[@]-}"; do
      [[ -z "$row" ]] && continue
      printf '%s\n' "${row//|/$'\t'}"
    done
  } > "$ROWS_TSV"

  python3 - "$ROWS_TSV" "$SUMMARY_BY_FORMAT_TSV" "$SUMMARY_BY_SOURCE_TSV" "$SUMMARY_BY_TIER_TSV" "$KNOWN_BAD_TSV" "$UNEXPECTED_PASS_TSV" "$SKIPPED_LICENSE_TSV" <<'PY'
import csv
import sys
from collections import defaultdict

rows_path, by_format_path, by_source_path, by_tier_path, known_bad_path, unexpected_pass_path, skipped_license_path = sys.argv[1:]

with open(rows_path, "r", encoding="utf-8", newline="") as f:
    rows = list(csv.DictReader(f, delimiter="\t"))

STATUSES = [
    "pass",
    "fail",
    "skip",
    "skip_license",
    "skip_missing_file",
    "expected_fail",
    "unexpected_pass",
]
TIERS = ["gate", "reference", "stress", "known_bad"]

def write_rollup(path, key_name, key_fn):
    groups = defaultdict(lambda: {k: 0 for k in (["total"] + STATUSES + TIERS)})
    for row in rows:
        key = key_fn(row)
        group = groups[key]
        group["total"] += 1
        status = row["status"]
        tier = row["quality_tier"]
        if status in STATUSES:
            group[status] += 1
        if tier in TIERS:
            group[tier] += 1

    fieldnames = [key_name, "total"] + STATUSES + TIERS
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for key in sorted(groups):
            row = {key_name: key}
            row.update(groups[key])
            writer.writerow(row)

def write_filtered(path, predicate):
    fieldnames = [
        "id",
        "format",
        "scope",
        "source_id",
        "quality_tier",
        "status",
        "passed_signals",
        "total_signals",
        "notes",
    ]
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            if predicate(row):
                writer.writerow({k: row[k] for k in fieldnames})

write_rollup(by_format_path, "format", lambda row: row["format"] or "-")
write_rollup(by_source_path, "source_id", lambda row: row["source_id"] or "-")
write_rollup(by_tier_path, "quality_tier", lambda row: row["quality_tier"] or "-")
write_filtered(known_bad_path, lambda row: row["quality_tier"] == "known_bad")
write_filtered(unexpected_pass_path, lambda row: row["status"] == "unexpected_pass")
write_filtered(skipped_license_path, lambda row: row["status"] == "skip_license")
PY
}

run_row() {
  local row="$1"
  local row_start_ms=0
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    row_start_ms="$(profile_now_ms)"
  fi
  local delimiter=$'\x1f'
  local converted="${row//$'\t'/$delimiter}"
  local source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes
  IFS="$delimiter" read -r source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes <<< "$converted"

  local stage_start_ms=0
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    stage_start_ms="$(profile_now_ms)"
  fi
  if [[ "$source_scope" == "external" ]]; then
    if [[ "$license_review_status" != "approved" ]]; then
      if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
        profile_record "$id" "row_prepare" "$(( $(profile_now_ms) - stage_start_ms ))" "license_gate"
        profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "skip_license"
      fi
      summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "skip_license" 0 0 "license_review_status=$license_review_status"
      return
    fi
  fi

  local abs_path="$path"
  if [[ "$source_scope" == "external" ]]; then
    if ! resolve_external_input_path "$path"; then
      if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
        profile_record "$id" "row_prepare" "$(( $(profile_now_ms) - stage_start_ms ))" "missing_input"
        profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "missing_input"
      fi
      abs_path=""
      summary_add \
        "$id" \
        "$format" \
        "$source_scope" \
        "$source_id" \
        "$quality_tier" \
        "skip_missing_file" \
        0 \
        0 \
        "$(format_missing_external_note "$path")"
      return
    fi
    abs_path="$RESOLVED_EXTERNAL_PATH"
  else
    if [[ "$abs_path" != /* ]]; then
      abs_path="$ROOT/$abs_path"
    fi
  fi

  if [[ ! -f "$abs_path" ]]; then
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$id" "row_prepare" "$(( $(profile_now_ms) - stage_start_ms ))" "missing_input"
      profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "missing_input"
    fi
    case "$source_scope" in
      external)
        summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "skip_missing_file" 0 0 "$(format_missing_external_note "$path")"
        ;;
      private)
        summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "skip_missing_file" 0 0 "private local file missing"
        ;;
      *)
        summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "fail" 0 0 "input file missing"
        ;;
    esac
    return
  fi

  local row_dir="$OUTPUT_DIR/$id"
  rm -rf "$row_dir"
  mkdir -p "$row_dir"
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    profile_record "$id" "row_prepare" "$(( $(profile_now_ms) - stage_start_ms ))" "row_dir_ready"
  fi

  local output_md="$row_dir/$id.md"
  local cli_args=("normal")
  if [[ "$METADATA_ENABLED" -ne 0 ]]; then
    cli_args+=("--with-metadata")
  fi
  cli_args+=("$abs_path" "$output_md")
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    stage_start_ms="$(profile_now_ms)"
  fi
  if ! run_markitdown_cli "${cli_args[@]}" >/dev/null 2>&1; then
    local failure_status="fail"
    local failure_note="cli conversion failed"
    if is_known_bad_tier "$quality_tier"; then
      failure_status="expected_fail"
      failure_note="expected converter failure: cli conversion failed"
    fi
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$id" "convert" "$(( $(profile_now_ms) - stage_start_ms ))" "cli_failed"
      profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "$failure_status"
    fi
    summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "$failure_status" 0 0 "$failure_note"
    return
  fi
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    profile_record "$id" "convert" "$(( $(profile_now_ms) - stage_start_ms ))" "metadata=$(metadata_summary_value)"
    stage_start_ms="$(profile_now_ms)"
  fi

  local metadata_path="$row_dir/metadata/$id.metadata.json"
  local normalized_text
  normalized_text="$(normalize_text "$output_md")"
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    profile_record "$id" "load_output" "$(( $(profile_now_ms) - stage_start_ms ))" "markdown_loaded"
    stage_start_ms="$(profile_now_ms)"
  fi

  local total_signals=0
  local passed_signals=0
  local failed_details=()
  local review_notes=()
  local signal
  IFS=';' read -r -a signals <<< "$expected_signals"
  for signal in "${signals[@]}"; do
    signal="$(printf '%s' "$signal" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$signal" ]] && continue
    if [[ "$signal" == review_note:* ]]; then
      if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
        profile_record "$id" "signal_start:$(profile_signal_stage_name "$signal")" 0 "$(profile_signal_notes "$signal" "review")"
        profile_record "$id" "signal:$(profile_signal_stage_name "$signal")" 0 "$(profile_signal_notes "$signal" "review")"
      fi
      review_notes+=("${signal#review_note:}")
      continue
    fi
    total_signals=$((total_signals + 1))
    local signal_start_ms=0
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$id" "signal_start:$(profile_signal_stage_name "$signal")" 0 "$(profile_signal_notes "$signal" "start")"
      signal_start_ms="$(profile_now_ms)"
    fi
    if check_signal "$signal" "$output_md" "$metadata_path" "$row_dir" "$normalized_text"; then
      passed_signals=$((passed_signals + 1))
      if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
        profile_record "$id" "signal:$(profile_signal_stage_name "$signal")" "$(( $(profile_now_ms) - signal_start_ms ))" "$(profile_signal_notes "$signal" "pass")"
      fi
    else
      failed_details+=("$signal")
      if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
        profile_record "$id" "signal:$(profile_signal_stage_name "$signal")" "$(( $(profile_now_ms) - signal_start_ms ))" "$(profile_signal_notes "$signal" "fail")"
      fi
    fi
  done
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    profile_record "$id" "signal_check" "$(( $(profile_now_ms) - stage_start_ms ))" "signals=$total_signals"
    stage_start_ms="$(profile_now_ms)"
  fi

  if [[ "$total_signals" -eq 0 ]]; then
    local note_text="no expected signals configured"
    if [[ "${#review_notes[@]}" -gt 0 ]]; then
      note_text="$note_text; review: ${review_notes[*]}"
    fi
    summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "skip" 0 0 "$note_text"
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$id" "summary_row_write" "$(( $(profile_now_ms) - stage_start_ms ))" "skip"
      profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "skip"
    fi
    return
  fi

  if [[ "${#failed_details[@]}" -gt 0 ]]; then
    local note_text="failed: ${failed_details[*]}"
    local row_status="fail"
    if [[ "${#review_notes[@]}" -gt 0 ]]; then
      note_text="$note_text; review: ${review_notes[*]}"
    fi
    if is_known_bad_tier "$quality_tier"; then
      row_status="expected_fail"
      note_text="expected fail: ${failed_details[*]}"
      if [[ "${#review_notes[@]}" -gt 0 ]]; then
        note_text="$note_text; review: ${review_notes[*]}"
      fi
    fi
    summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "$row_status" "$passed_signals" "$total_signals" "$note_text"
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$id" "summary_row_write" "$(( $(profile_now_ms) - stage_start_ms ))" "$row_status"
      profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "$row_status"
    fi
    return
  fi

  local note_text="all signals passed"
  local row_status="pass"
  if [[ "${#review_notes[@]}" -gt 0 ]]; then
    note_text="$note_text; review: ${review_notes[*]}"
  fi
  if is_known_bad_tier "$quality_tier"; then
    row_status="unexpected_pass"
    note_text="known_bad row passed all signals; possible fix candidate"
    if [[ "${#review_notes[@]}" -gt 0 ]]; then
      note_text="$note_text; review: ${review_notes[*]}"
    fi
  fi
  summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "$row_status" "$passed_signals" "$total_signals" "$note_text"
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    profile_record "$id" "summary_row_write" "$(( $(profile_now_ms) - stage_start_ms ))" "$row_status"
    profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "$row_status"
  fi
}

write_summary() {
  local total="$1"
  local passed="$2"
  local failed="$3"
  local skipped="$4"
  local skipped_license="$5"
  local skipped_missing_file="$6"
  local expected_fail="$7"
  local unexpected_pass="$8"
  local no_manifest_rows="$9"
  local no_matching_rows="${10}"
  local summary_row_count="${#SUMMARY_ROWS[@]}"

  mkdir -p "$OUT_ROOT"
  {
    printf 'id\tformat\tscope\tquality_tier\tstatus\tpassed_signals\ttotal_signals\tnotes\n'
    printf 'PROFILE_ENABLED\t-\t-\t-\t-\t0\t0\t%s\n' "$(profile_enabled_summary_value)"
    printf 'METADATA_ENABLED\t-\t-\t-\t-\t0\t0\t%s\n' "$(metadata_summary_value)"
    printf 'CORPUS_ROOT\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$CORPUS_ROOT")"
    printf 'CORPUS_ROOT_SOURCE\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$CORPUS_ROOT_SOURCE")"
    printf 'QUALITY_ROWS_MANIFEST\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$QUALITY_ROWS_MANIFEST")"
    printf 'QUALITY_ROWS_MANIFEST_SOURCE\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$QUALITY_ROWS_MANIFEST_SOURCE")"
    printf 'FILTER_ID\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$FILTER_ID")"
    printf 'FILTER_SOURCE\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$FILTER_SOURCE")"
    printf 'FILTER_FORMAT\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$FILTER_FORMAT")"
    local row
    for row in "${SUMMARY_ROWS[@]-}"; do
      [[ -z "$row" ]] && continue
      printf '%s\n' "${row//|/$'\t'}"
    done
    printf 'TOTAL\t-\t-\t-\t-\t%s\t%s\ttotal rows processed\n' "$passed" "$total"
    printf 'PASSED\t-\t-\t-\t-\t%s\t-\tpassed rows\n' "$passed"
    printf 'FAILED\t-\t-\t-\t-\t%s\t-\tfailed rows\n' "$failed"
    printf 'SKIPPED\t-\t-\t-\t-\t%s\t-\tskipped rows\n' "$skipped"
    printf 'SKIPPED_LICENSE\t-\t-\t-\t-\t%s\t-\tskipped because license_review_status was not approved\n' "$skipped_license"
    printf 'SKIPPED_MISSING_FILE\t-\t-\t-\t-\t%s\t-\tskipped because the local cache or private file was missing\n' "$skipped_missing_file"
    printf 'EXPECTED_FAIL\t-\t-\t-\t-\t%s\t-\tknown_bad rows that failed as expected\n' "$expected_fail"
    printf 'UNEXPECTED_PASS\t-\t-\t-\t-\t%s\t-\tknown_bad rows that passed all checks unexpectedly\n' "$unexpected_pass"
    printf 'NO_MANIFEST_ROWS\t-\t-\t-\t-\t%s\t-\t1 means no rows selected\n' "$no_manifest_rows"
    printf 'NO_MATCHING_ROWS\t-\t-\t-\t-\t%s\t-\t1 means filters matched zero rows\n' "$no_matching_rows"
  } > "$SUMMARY_TSV"

  {
    echo "# Quality Corpus Summary"
    echo
    echo "Profile: $(if [[ "$PROFILE_ENABLED" -ne 0 ]]; then printf 'enabled'; else printf 'disabled'; fi)"
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      echo "Profile path: $PROFILE_TSV"
    fi
    echo
    echo "Metadata: $(if [[ "$METADATA_ENABLED" -ne 0 ]]; then printf 'enabled'; else printf 'disabled'; fi)"
    echo
    echo "Filters:"
    echo "- id: $(filter_summary_value "$FILTER_ID")"
    echo "- source: $(filter_summary_value "$FILTER_SOURCE")"
    echo "- format: $(filter_summary_value "$FILTER_FORMAT")"
    echo
    echo "- total: $total"
    echo "- passed: $passed"
    echo "- failed: $failed"
    echo "- skipped: $skipped"
    echo "- skipped_license: $skipped_license"
    echo "- skipped_missing_file: $skipped_missing_file"
    echo "- expected_fail: $expected_fail"
    echo "- unexpected_pass: $unexpected_pass"
    echo "- no_manifest_rows: $no_manifest_rows"
    echo "- no_matching_rows: $no_matching_rows"
    echo
    if [[ "$summary_row_count" -eq 0 && "$no_matching_rows" -ne 0 ]]; then
      echo "No manifest rows matched the active filters."
    elif [[ "$summary_row_count" -eq 0 ]]; then
      echo "No manifest rows selected."
    else
      echo "| ID | Format | Scope | Tier | Status | Passed | Total | Notes |"
      echo "| --- | --- | --- | --- | --- | ---: | ---: | --- |"
      local row
      for row in "${SUMMARY_ROWS[@]-}"; do
        [[ -z "$row" ]] && continue
        IFS='|' read -r id format scope tier status passed_count total_count notes_out <<< "$row"
        echo "| $id | $format | $scope | $tier | $status | $passed_count | $total_count | $notes_out |"
      done
      echo
      echo "## Expected Failures"
      echo
      if [[ "$expected_fail" -eq 0 ]]; then
        echo "None."
      else
        for row in "${SUMMARY_ROWS[@]-}"; do
          [[ -z "$row" ]] && continue
          IFS='|' read -r id format scope tier status passed_count total_count notes_out <<< "$row"
          [[ "$status" == "expected_fail" ]] || continue
          echo "- $id ($format, $tier): $notes_out"
        done
      fi
      echo
      echo "## Unexpected Passes"
      echo
      if [[ "$unexpected_pass" -eq 0 ]]; then
        echo "None."
      else
        for row in "${SUMMARY_ROWS[@]-}"; do
          [[ -z "$row" ]] && continue
          IFS='|' read -r id format scope tier status passed_count total_count notes_out <<< "$row"
          [[ "$status" == "unexpected_pass" ]] || continue
          echo "- $id ($format, $tier): $notes_out"
        done
      fi
    fi
  } > "$SUMMARY_MD"

  write_dashboard_views
}

SUMMARY_ROWS=()
DASHBOARD_ROWS=()
MANIFEST_ROWS=()
while IFS= read -r row; do
  [[ -n "$row" ]] && MANIFEST_ROWS+=("$row")
done < <(collect_manifest_rows)

if [[ "${#MANIFEST_ROWS[@]}" -eq 0 ]]; then
  write_summary 0 0 0 0 0 0 0 0 1 0
  echo "QUALITY CORPUS PASSED (no manifest rows selected)"
  echo "summary: $SUMMARY_TSV"
  echo "report: $SUMMARY_MD"
  exit 0
fi

FILTERED_ROWS=()
for row in "${MANIFEST_ROWS[@]}"; do
  if row_matches_filters "$row"; then
    FILTERED_ROWS+=("$row")
  fi
done

if [[ "${#FILTERED_ROWS[@]}" -eq 0 ]]; then
  write_summary 0 0 0 0 0 0 0 0 0 1
  echo "QUALITY CORPUS PASSED (no rows matched filters)"
  echo "summary: $SUMMARY_TSV"
  echo "report: $SUMMARY_MD"
  exit 0
fi

if [[ "$LIST_ONLY" -ne 0 ]]; then
  print_filtered_rows
  exit 0
fi

profile_init
resolve_markitdown_cli

validation_progress_init "quality_corpus" "${#FILTERED_ROWS[@]}"

for row in "${FILTERED_ROWS[@]}"; do
  IFS=$'\t' read -r source_scope id _ <<< "$row"
  validation_progress_step "$id"
  run_row "$row"
done

validation_progress_done

total_rows=0
passed_rows=0
failed_rows=0
skipped_rows=0
skipped_license_rows=0
skipped_missing_file_rows=0
expected_fail_rows=0
unexpected_pass_rows=0

for row in "${SUMMARY_ROWS[@]-}"; do
  [[ -z "$row" ]] && continue
  total_rows=$((total_rows + 1))
  IFS='|' read -r _ _ _ _ status _ _ _ <<< "$row"
  case "$status" in
    pass)
      passed_rows=$((passed_rows + 1))
      ;;
    fail)
      failed_rows=$((failed_rows + 1))
      ;;
    skip)
      skipped_rows=$((skipped_rows + 1))
      ;;
    skip_license)
      skipped_rows=$((skipped_rows + 1))
      skipped_license_rows=$((skipped_license_rows + 1))
      ;;
    skip_missing_file)
      skipped_rows=$((skipped_rows + 1))
      skipped_missing_file_rows=$((skipped_missing_file_rows + 1))
      ;;
    expected_fail)
      expected_fail_rows=$((expected_fail_rows + 1))
      ;;
    unexpected_pass)
      unexpected_pass_rows=$((unexpected_pass_rows + 1))
      ;;
  esac
done

write_summary "$total_rows" "$passed_rows" "$failed_rows" "$skipped_rows" "$skipped_license_rows" "$skipped_missing_file_rows" "$expected_fail_rows" "$unexpected_pass_rows" 0 0

if [[ "$failed_rows" -ne 0 ]]; then
  echo "QUALITY CORPUS FAILED"
  echo "summary: $SUMMARY_TSV"
  echo "report: $SUMMARY_MD"
  exit 1
fi

if [[ "$unexpected_pass_rows" -ne 0 ]]; then
  echo "QUALITY CORPUS PASSED WITH UNEXPECTED PASSES ($total_rows rows; $skipped_rows skipped; $expected_fail_rows expected_fail; $unexpected_pass_rows unexpected_pass)"
else
  echo "QUALITY CORPUS PASSED ($total_rows rows; $skipped_rows skipped; $expected_fail_rows expected_fail)"
fi
echo "summary: $SUMMARY_TSV"
echo "report: $SUMMARY_MD"
