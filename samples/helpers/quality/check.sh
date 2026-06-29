#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp.sh"
source "$ROOT/samples/helpers/shared/cli_runner.sh"

TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
QUALITY_TMP_ROOT="${QUALITY_TMP_ROOT:-$TMP_ROOT/quality}"
QUALITY_RUN_ID="${QUALITY_RUN_ID:-manual-$(date +%Y%m%d-%H%M%S)-$$}"
OUT_ROOT="${QUALITY_TMP_DIR:-$QUALITY_TMP_ROOT/runs/$QUALITY_RUN_ID}"
CLI_TMP_ROOT="${MARKITDOWN_CLI_TMP_DIR:-$OUT_ROOT/workspace}"
LOG_DIR="$OUT_ROOT/logs"
DIFF_DIR="$OUT_ROOT/diff"
RAW_DIR="$OUT_ROOT/raw"
REPORTS_DIR="$OUT_ROOT/reports"
ROW_REPORTS_DIR="$REPORTS_DIR/rows"
NONPASS_INDEX_MD="$REPORTS_DIR/nonpass.md"
OUTPUT_DIR="$RAW_DIR/outputs"
QUALITY_SIGNAL_EVALUATOR="$ROOT/samples/helpers/quality/evaluate_signals.py"
SUMMARY_TSV="$OUT_ROOT/summary.tsv"
SUMMARY_MD="$OUT_ROOT/summary.md"
ROWS_TSV="$OUT_ROOT/rows.tsv"
ARTIFACT_PLAN_ROOT="$OUT_ROOT/artifact_plan"
ARTIFACT_IDS_FILE="$ARTIFACT_PLAN_ROOT/artifact_ids.txt"
SUMMARY_BY_FORMAT_TSV="$OUT_ROOT/summary.by_format.tsv"
SUMMARY_BY_SOURCE_TSV="$OUT_ROOT/summary.by_source.tsv"
SUMMARY_BY_TIER_TSV="$OUT_ROOT/summary.by_tier.tsv"
KNOWN_BAD_TSV="$OUT_ROOT/known_bad.tsv"
UNEXPECTED_PASS_TSV="$OUT_ROOT/unexpected_pass.tsv"
SKIPPED_LICENSE_TSV="$OUT_ROOT/skipped_license.tsv"
FILTER_ID=""
FILTER_SOURCE=""
FILTER_FORMAT=""
LIST_ONLY=0
METADATA_MODE="auto"
METADATA_ENABLED=0
METADATA_STATUS="unresolved"
METADATA_NOTE=""
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
CLI_EXTRA_ARGS=()

EXTERNAL_HEADER=$'id\tformat\tpath\tsource_type\tsource_id\tlicense_status\tlicense_review_status\tprivacy\tsize_class\tfeatures\texpected_signals\tquality_tier\toriginal_url\tlocal_cache_path\tnotes'

usage() {
  cat <<'EOF'
usage: ./samples/helpers/quality/check.sh [internal/debug args]

Internal/debug options:
  --list          list manifest rows after filters, without running conversion
  --no-metadata   force conversion without metadata sidecars
  --with-metadata force conversion with --with-metadata and fail if unsupported
  --profile       write per-row timing diagnostics to a run-local profile.tsv
  --cli-arg ARG   append one extra CLI arg to every conversion command

Filters:
  --id <id>           match one exact row id
  --source <source>   match external rows by source_id
  --format <format>   match rows by format
  --corpus-root <path>
                      resolve external corpus payloads from this root first
  --lab-manifest <path>
                      resolve external/lab-managed quality rows from this
                      manifest first
  --require-lab       fail if no lab quality-row manifest is available

Filter semantics:
  * multiple filters are combined with AND
  * filters do not bypass license or file-presence gate semantics
  * external payload discovery checks, in order:
      --corpus-root
      MARKITDOWN_QUALITY_CORPUS
      MARKITDOWN_QUALITY_LAB/external_quality
      markitdown-quality-lab/external_quality
  * quality manifest discovery checks, in order:
      --lab-manifest
      MARKITDOWN_QUALITY_MANIFEST
      MARKITDOWN_QUALITY_LAB/external_quality/MANIFEST.tsv
      markitdown-quality-lab/external_quality/MANIFEST.tsv
  * metadata defaults to auto: this helper probes whether the main CLI
    supports --with-metadata and falls back to metadata-off when it does not
  * --no-metadata forces metadata-off
  * --with-metadata forces metadata-on and fails early if unsupported
  * --profile is diagnostic-only and does not change pass/fail semantics

Notes:
  * the preferred user entrypoint is bash samples/check_quality.sh
  * bash samples/check_quality.sh passes explicit lab paths and --require-lab
  * this helper does not fall back to repo-local rows or staging manifests
  * non-approved external rows are skipped
  * missing external files are recorded as skipped when appropriate
  * this is a signal-level intake checker, not an exact-output regression gate
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
      METADATA_MODE="off"
      ;;
    --with-metadata)
      METADATA_MODE="on"
      ;;
    --cli-arg)
      [[ $# -ge 2 ]] || {
        echo "missing value for --cli-arg" >&2
        usage >&2
        exit 1
      }
      CLI_EXTRA_ARGS+=("$2")
      shift
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
mkdir -p "$DIFF_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$RAW_DIR"
mkdir -p "$REPORTS_DIR"
mkdir -p "$ROW_REPORTS_DIR"

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
    add_corpus_root_candidate "MARKITDOWN_QUALITY_LAB/external_quality" "${MARKITDOWN_QUALITY_LAB%/}/external_quality"
  fi
  add_corpus_root_candidate "repo-local quality lab" "$ROOT/markitdown-quality-lab/external_quality"

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
      "MARKITDOWN_QUALITY_LAB/external_quality/MANIFEST.tsv" \
      "${MARKITDOWN_QUALITY_LAB%/}/external_quality/MANIFEST.tsv"
  fi
  add_quality_rows_manifest_candidate \
    "repo-local external_quality manifest" \
    "$ROOT/markitdown-quality-lab/external_quality/MANIFEST.tsv"

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
    local repo_quality_lab_candidate="$ROOT/markitdown-quality-lab/$path"
    local relative_suffix=""
    if [[ "$path" == external_quality/* ]]; then
      relative_suffix="${path#external_quality/}"
    elif [[ "$path" == markitdown-quality-lab/external_quality/* ]]; then
      relative_suffix="${path#markitdown-quality-lab/external_quality/}"
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

    append_unique_path "$repo_quality_lab_candidate"
    if [[ -f "$repo_quality_lab_candidate" ]]; then
      RESOLVED_EXTERNAL_PATH="$repo_quality_lab_candidate"
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

single_line_note() {
  local value="${1-}"
  value="$(printf '%s' "$value" | tr '\r\n\t' '   ' | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')"
  if [[ "${#value}" -gt 200 ]]; then
    value="${value:0:197}..."
  fi
  printf '%s' "$value"
}

tsv_field_unquote() {
  local value="${1-}"
  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
    value="${value//\"\"/\"}"
  fi
  printf '%s' "$value"
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

normalize_markdown_literal_text() {
  local path="$1"
  python3 - "$path" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
text = text.replace("\r\n", "\n").replace("\r", "\n")
text = re.sub(r'\\([\\`*_{}\[\]()#+!<>|])', r'\1', text)
sys.stdout.write(text)
PY
}

normalize_signal_literal() {
  local text="${1-}"
  python3 - "$text" <<'PY'
import re
import sys

text = sys.argv[1]
text = re.sub(r'\\([\\`*_{}\[\]()#+!<>|])', r'\1', text)
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
  local id format path source_type license_status privacy size_class features expected_signals quality_tier notes extra_fields
  IFS="$delimiter" read -r id format path source_type license_status privacy size_class features expected_signals quality_tier notes extra_fields <<< "$converted"
  id="$(tsv_field_unquote "$id")"
  format="$(tsv_field_unquote "$format")"
  path="$(tsv_field_unquote "$path")"
  source_type="$(tsv_field_unquote "$source_type")"
  license_status="$(tsv_field_unquote "$license_status")"
  privacy="$(tsv_field_unquote "$privacy")"
  size_class="$(tsv_field_unquote "$size_class")"
  features="$(tsv_field_unquote "$features")"
  expected_signals="$(tsv_field_unquote "$expected_signals")"
  quality_tier="$(tsv_field_unquote "$quality_tier")"
  notes="$(tsv_field_unquote "$notes")"
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
  local id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url local_cache_path notes extra_fields
  IFS="$delimiter" read -r id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url local_cache_path notes extra_fields <<< "$converted"
  id="$(tsv_field_unquote "$id")"
  format="$(tsv_field_unquote "$format")"
  path="$(tsv_field_unquote "$path")"
  source_type="$(tsv_field_unquote "$source_type")"
  source_id="$(tsv_field_unquote "$source_id")"
  license_status="$(tsv_field_unquote "$license_status")"
  license_review_status="$(tsv_field_unquote "$license_review_status")"
  privacy="$(tsv_field_unquote "$privacy")"
  size_class="$(tsv_field_unquote "$size_class")"
  features="$(tsv_field_unquote "$features")"
  expected_signals="$(tsv_field_unquote "$expected_signals")"
  quality_tier="$(tsv_field_unquote "$quality_tier")"
  original_url="$(tsv_field_unquote "$original_url")"
  local_cache_path="$(tsv_field_unquote "$local_cache_path")"
  notes="$(tsv_field_unquote "$notes")"
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
      if [[ "$raw_line" != "$expected_header" && "$raw_line" != "$expected_header"$'\t'* ]]; then
        echo "quality manifest header mismatch: $manifest_path" >&2
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
  if [[ -n "$QUALITY_ROWS_MANIFEST" ]]; then
    while IFS= read -r row; do
      [[ -n "$row" ]] && rows+=("$row")
    done < <(manifest_rows_from_file "$QUALITY_ROWS_MANIFEST" "external" "$EXTERNAL_HEADER" normalize_external_manifest_entry)
  fi
  if [[ "${#rows[@]}" -eq 0 ]]; then
    return 0
  fi
  printf '%s\n' "${rows[@]}"
}

detect_corpus_root
detect_quality_rows_manifest

if [[ -z "$QUALITY_ROWS_MANIFEST" ]]; then
  echo "quality lab manifest not found" >&2
  local_manifest_idx=0
  for local_manifest_idx in "${!QUALITY_ROWS_MANIFEST_CANDIDATES[@]}"; do
    echo "tried: ${QUALITY_ROWS_MANIFEST_CANDIDATE_LABELS[$local_manifest_idx]} -> ${QUALITY_ROWS_MANIFEST_CANDIDATES[$local_manifest_idx]}" >&2
  done
  echo "hint: clone/place markitdown-quality-lab in the repo root, pass --lab-manifest, or set MARKITDOWN_QUALITY_MANIFEST / MARKITDOWN_QUALITY_LAB" >&2
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

metadata_mode_summary_value() {
  printf '%s' "$METADATA_MODE"
}

metadata_status_summary_value() {
  printf '%s' "$METADATA_STATUS"
}

metadata_note_summary_value() {
  printf '%s' "$(filter_summary_value "$METADATA_NOTE")"
}

cli_extra_args_summary_value() {
  if [[ "${#CLI_EXTRA_ARGS[@]}" -eq 0 ]]; then
    printf '*'
    return
  fi

  local joined=""
  local arg
  for arg in "${CLI_EXTRA_ARGS[@]}"; do
    if [[ -n "$joined" ]]; then
      joined="$joined "
    fi
    joined="$joined$(printf '%q' "$arg")"
  done
  printf '%s' "$joined"
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

signal_eval_runner_summary_value() {
  printf '%s' "$QUALITY_SIGNAL_EVALUATOR"
}

artifact_groups_summary_value() {
  printf '%s' "${ARTIFACT_GROUP_COUNT:-0}"
}

selected_rows_summary_value() {
  printf '%s' "${SELECTED_ROW_COUNT:-0}"
}

executable_rows_summary_value() {
  printf '%s' "${EXECUTABLE_ROW_COUNT:-0}"
}

skip_no_signals_summary_value() {
  printf '%s' "${SKIPPED_NO_SIGNALS_COUNT:-0}"
}

python3_required() {
  if command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  echo "python3 is required for quality signal evaluation" >&2
  exit 1
}

artifact_safe_basename() {
  local input_path="$1"
  local base
  base="$(basename "$input_path")"
  base="${base%.*}"
  base="$(printf '%s' "$base" | tr -c '[:alnum:]' '_')"
  base="${base##_}"
  base="${base%%_}"
  if [[ -z "$base" ]]; then
    base="artifact"
  fi
  printf '%s' "$base"
}

artifact_short_hash() {
  local text="$1"
  python3 - "$text" <<'PY'
import hashlib
import sys

print(hashlib.sha1(sys.argv[1].encode("utf-8")).hexdigest()[:12])
PY
}

artifact_id_from_key() {
  local abs_path="$1"
  local artifact_key="$2"
  printf '%s__%s' "$(artifact_safe_basename "$abs_path")" "$(artifact_short_hash "$artifact_key")"
}

real_signal_count_from_expected() {
  local expected_signals="${1-}"
  python3 - "$expected_signals" <<'PY'
import sys

signals = [
    part.strip()
    for part in sys.argv[1].split(";")
    if part.strip() and not part.strip().startswith("review_note:")
]
print(len(signals))
PY
}

artifact_plan_init() {
  mkdir -p "$ARTIFACT_PLAN_ROOT"
  : > "$ARTIFACT_IDS_FILE"
}

artifact_plan_dir() {
  local artifact_id="$1"
  printf '%s/%s' "$ARTIFACT_PLAN_ROOT" "$artifact_id"
}

artifact_plan_rows_raw_path() {
  local artifact_id="$1"
  printf '%s/rows.raw.tsv' "$(artifact_plan_dir "$artifact_id")"
}

artifact_plan_abs_path_file() {
  local artifact_id="$1"
  printf '%s/abs_path.txt' "$(artifact_plan_dir "$artifact_id")"
}

artifact_plan_metadata_file() {
  local artifact_id="$1"
  printf '%s/metadata_enabled.txt' "$(artifact_plan_dir "$artifact_id")"
}

artifact_plan_rowcount_file() {
  local artifact_id="$1"
  printf '%s/row_count.txt' "$(artifact_plan_dir "$artifact_id")"
}

artifact_plan_register() {
  local artifact_id="$1"
  local abs_path="$2"
  local metadata_enabled="$3"
  local plan_dir
  plan_dir="$(artifact_plan_dir "$artifact_id")"
  if [[ ! -d "$plan_dir" ]]; then
    mkdir -p "$plan_dir"
    printf '%s\n' "$artifact_id" >> "$ARTIFACT_IDS_FILE"
    printf '%s' "$abs_path" > "$(artifact_plan_abs_path_file "$artifact_id")"
    printf '%s' "$metadata_enabled" > "$(artifact_plan_metadata_file "$artifact_id")"
    printf '0' > "$(artifact_plan_rowcount_file "$artifact_id")"
    : > "$(artifact_plan_rows_raw_path "$artifact_id")"
    ARTIFACT_GROUP_COUNT=$((ARTIFACT_GROUP_COUNT + 1))
  fi
}

artifact_plan_append_row() {
  local artifact_id="$1"
  local row="$2"
  local rows_raw
  rows_raw="$(artifact_plan_rows_raw_path "$artifact_id")"
  printf '%s\n' "$row" >> "$rows_raw"
  local rowcount_file
  rowcount_file="$(artifact_plan_rowcount_file "$artifact_id")"
  local count
  count="$(cat "$rowcount_file")"
  count=$((count + 1))
  printf '%s' "$count" > "$rowcount_file"
}

artifact_plan_abs_path() {
  local artifact_id="$1"
  cat "$(artifact_plan_abs_path_file "$artifact_id")"
}

artifact_plan_row_count() {
  local artifact_id="$1"
  cat "$(artifact_plan_rowcount_file "$artifact_id")"
}

artifact_plan_rows_each() {
  local artifact_id="$1"
  cat "$(artifact_plan_rows_raw_path "$artifact_id")"
}

quality_runner_label() {
  if [[ "${CLI_RUNNER_NOTE:-}" == built\ native\ CLI* ]]; then
    printf 'built'
    return
  fi
  case "${CLI_RUNNER_KIND:-}" in
    prebuilt-native|override)
      printf 'prebuilt'
      ;;
    moon-run)
      printf 'moon-run'
      ;;
    *)
      printf 'none'
      ;;
  esac
}

probe_with_metadata_support() {
  local probe_tmp_root
  probe_tmp_root="$(validation_cli_tmp_root)"
  local probe_dir
  probe_dir="$(sample_make_isolated_tmp_dir "$probe_tmp_root" "quality_metadata_probe")"
  local probe_output="$probe_dir/txt_plain.md"
  local probe_metadata="$probe_dir/metadata/txt_plain.metadata.json"
  local probe_input="$ROOT/samples/main_process/txt/markdown/txt_plain.txt"
  local status=0

  if ! run_markitdown_cli normal --with-metadata "$probe_input" "$probe_output" >/dev/null 2>"$probe_dir/probe.stderr"; then
    METADATA_STATUS="unsupported_option"
    METADATA_NOTE="this build rejects --with-metadata; external quality baseline falls back to metadata-off"
    status=1
  elif [[ -f "$probe_metadata" ]]; then
    METADATA_STATUS="supported_sidecar"
    METADATA_NOTE="this build accepts --with-metadata and emits metadata sidecars"
  else
    METADATA_STATUS="supported_without_sidecar"
    METADATA_NOTE="this build accepts --with-metadata but did not emit a metadata sidecar in the probe"
  fi

  rm -rf "$probe_dir"
  return "$status"
}

resolve_quality_metadata_mode() {
  case "$METADATA_MODE" in
    off)
      METADATA_ENABLED=0
      METADATA_STATUS="forced_off"
      METADATA_NOTE="metadata sidecars disabled by quality runner flag"
      return 0
      ;;
    on)
      if probe_with_metadata_support; then
        METADATA_ENABLED=1
        return 0
      fi
      echo "quality metadata probe failed while --with-metadata was forced" >&2
      echo "note: $METADATA_NOTE" >&2
      return 1
      ;;
    auto)
      if probe_with_metadata_support; then
        METADATA_ENABLED=1
      else
        METADATA_ENABLED=0
      fi
      return 0
      ;;
    *)
      echo "unknown metadata mode: $METADATA_MODE" >&2
      return 1
      ;;
  esac
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
  local literal_text="$6"

  case "$signal" in
    no_empty_output)
      check_non_empty_output_file "$markdown_path"
      ;;
    contains:*)
      local needle="${signal#contains:}"
      needle="$(normalize_signal_literal "$needle")"
      [[ "$literal_text" == *"$needle"* ]]
      ;;
    contains_all:*)
      local rest="${signal#contains_all:}"
      rest="$(normalize_signal_literal "$rest")"
      printf '%s' "$literal_text" | stdin_contains_all_parts "$rest"
      ;;
    exact_count:*)
      local spec="${signal#exact_count:}"
      spec="$(normalize_signal_literal "$spec")"
      printf '%s' "$literal_text" | stdin_count_occurrences "exact_count" "$spec"
      ;;
    min_count:*)
      local spec="${signal#min_count:}"
      spec="$(normalize_signal_literal "$spec")"
      printf '%s' "$literal_text" | stdin_count_occurrences "min_count" "$spec"
      ;;
    max_count:*)
      local spec="${signal#max_count:}"
      spec="$(normalize_signal_literal "$spec")"
      printf '%s' "$literal_text" | stdin_count_occurrences "max_count" "$spec"
      ;;
    not_contains:*)
      local needle="${signal#not_contains:}"
      needle="$(normalize_signal_literal "$needle")"
      [[ "$literal_text" != *"$needle"* ]]
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
      if [[ "$METADATA_ENABLED" -eq 0 ]]; then
        [[ "$METADATA_STATUS" == "unsupported_option" || "$METADATA_MODE" == "off" ]]
      else
        [[ -f "$metadata_path" ]]
      fi
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
      rest="$(normalize_signal_literal "$rest")"
      printf '%s' "$literal_text" | stdin_parts_in_order "$rest"
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
      local needle="${signal#page_noise_absent:}"
      needle="$(normalize_signal_literal "$needle")"
      [[ "$literal_text" != *"$needle"* ]]
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

quality_status_generates_report() {
  local status="$1"
  case "$status" in
    fail|expected_fail|unexpected_pass)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

quality_write_row_report() {
  local id="$1"
  local format="$2"
  local source_scope="$3"
  local source_id="$4"
  local quality_tier="$5"
  local status="$6"
  local input_path="$7"
  local output_md="$8"
  local stdout_path="$9"
  local stderr_path="${10}"
  local passed_signals="${11}"
  local total_signals="${12}"
  local notes="${13}"
  local failed_details="${14}"
  local review_details="${15}"
  local report_path="$ROW_REPORTS_DIR/$id.md"

  {
    echo "# Quality Row Report"
    echo
    echo "- ID: $id"
    echo "- Format: $format"
    echo "- Source scope: $source_scope"
    echo "- Source ID: $source_id"
    echo "- Tier: $quality_tier"
    echo "- Status: $status"
    echo "- Input: $input_path"
    if [[ -n "$output_md" ]]; then
      echo "- Output markdown: $output_md"
    fi
    if [[ -n "$stdout_path" ]]; then
      echo "- Stdout log: $stdout_path"
    fi
    if [[ -n "$stderr_path" ]]; then
      echo "- Stderr log: $stderr_path"
    fi
    echo "- Passed signals: $passed_signals"
    echo "- Total signals: $total_signals"
    echo "- Notes: $notes"
    if [[ -n "$failed_details" ]]; then
      echo "- Failed signals: $failed_details"
    fi
    if [[ -n "$review_details" ]]; then
      echo "- Review notes: $review_details"
    fi
  } > "$report_path"
}

write_nonpass_index() {
  {
    echo "# Non-pass Rows"
    echo
    local found=0
    local row
    for row in "${SUMMARY_ROWS[@]-}"; do
      [[ -z "$row" ]] && continue
      IFS='|' read -r id format scope tier status passed_count total_count notes_out <<< "$row"
      if ! quality_status_generates_report "$status"; then
        continue
      fi
      found=1
      echo "- [$id](rows/$id.md) ($format, $tier, $status): $notes_out"
    done
    if [[ "$found" -eq 0 ]]; then
      echo "No executed non-pass rows."
    fi
  } > "$NONPASS_INDEX_MD"
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
    "skip_no_signals",
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

decode_quality_row_field() {
  local row="$1"
  local field_index="$2"
  python3 - "$row" "$field_index" <<'PY'
import csv
import io
import sys

row = next(csv.reader(io.StringIO(sys.argv[1]), delimiter="\t"))
index = int(sys.argv[2])
print(row[index] if index < len(row) else "")
PY
}

quality_plan_row() {
  local row="$1"
  local row_start_ms=0
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    row_start_ms="$(profile_now_ms)"
  fi

  local delimiter=$'\x1f'
  local converted="${row//$'\t'/$delimiter}"
  local source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes
  IFS="$delimiter" read -r source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes <<< "$converted"

  local real_signal_count
  real_signal_count="$(real_signal_count_from_expected "$expected_signals")"

  if [[ "$source_scope" == "external" && "$license_review_status" != "approved" ]]; then
    summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "skip_license" 0 0 "license_review_status=$license_review_status"
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "skip_license"
    fi
    validation_progress_step_status "skipped" "license $id"
    return
  fi

  local abs_path="$path"
  if [[ "$source_scope" == "external" ]]; then
    if ! resolve_external_input_path "$path"; then
      summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "skip_missing_file" 0 0 "$(format_missing_external_note "$path")"
      if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
        profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "skip_missing_file"
      fi
      validation_progress_step_status "skipped" "$path"
      return
    fi
    abs_path="$RESOLVED_EXTERNAL_PATH"
  else
    if [[ "$abs_path" != /* ]]; then
      abs_path="$ROOT/$abs_path"
    fi
  fi

  if [[ ! -f "$abs_path" ]]; then
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
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "missing_input"
    fi
    validation_progress_step_status "skipped" "$path"
    return
  fi

  if [[ "$real_signal_count" == "0" ]]; then
    local note_text="no executable signals configured"
    summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "skip_no_signals" 0 0 "$note_text"
    SKIPPED_NO_SIGNALS_COUNT=$((SKIPPED_NO_SIGNALS_COUNT + 1))
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$id" "row_total" "$(( $(profile_now_ms) - row_start_ms ))" "skip_no_signals"
    fi
    validation_progress_step_status "skipped" "$path"
    return
  fi

  local cli_extra_summary
  cli_extra_summary="$(cli_extra_args_summary_value)"
  local artifact_key="$abs_path"$'\x1f'"$(metadata_summary_value)"$'\x1f'"$cli_extra_summary"$'\x1f'"normal"
  local artifact_id
  artifact_id="$(artifact_id_from_key "$abs_path" "$artifact_key")"

  artifact_plan_register "$artifact_id" "$abs_path" "$(metadata_summary_value)"
  artifact_plan_append_row "$artifact_id" "$row"
  EXECUTABLE_ROW_COUNT=$((EXECUTABLE_ROW_COUNT + 1))
  validation_progress_step "$path"
}

quality_write_artifact_rows_tsv() {
  local artifact_id="$1"
  local rows_tsv="$2"
  printf 'row_id\tformat\tsource_scope\tsource_id\tquality_tier\texpected_signals\n' > "$rows_tsv"
  while IFS= read -r row || [[ -n "$row" ]]; do
    [[ -n "$row" ]] || continue
    local delimiter=$'\x1f'
    local converted="${row//$'\t'/$delimiter}"
    local source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes
    IFS="$delimiter" read -r source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes <<< "$converted"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$id" \
      "$format" \
      "$source_scope" \
      "$source_id" \
      "$quality_tier" \
      "$expected_signals" >> "$rows_tsv"
  done < <(artifact_plan_rows_each "$artifact_id")
}

quality_run_signal_evaluator() {
  local artifact_id="$1"
  local output_md="$2"
  local metadata_path="$3"
  local artifact_dir="$4"
  local rows_tsv="$5"
  local results_tsv="$6"

  python3_required
  python3 "$QUALITY_SIGNAL_EVALUATOR" \
    --markdown "$output_md" \
    --metadata "$metadata_path" \
    --artifact-dir "$artifact_dir" \
    --metadata-enabled "$(metadata_summary_value)" \
    --metadata-status "$METADATA_STATUS" \
    --metadata-mode "$METADATA_MODE" \
    --rows-tsv "$rows_tsv" \
    --results-tsv "$results_tsv"
}

quality_result_field() {
  local result_row="$1"
  local field_index="$2"
  python3 - "$result_row" "$field_index" <<'PY'
import csv
import io
import sys

row = next(csv.reader(io.StringIO(sys.argv[1]), delimiter="\t"))
index = int(sys.argv[2])
print(row[index] if index < len(row) else "")
PY
}

quality_process_eval_results() {
  local artifact_id="$1"
  local abs_path="$2"
  local output_md="$3"
  local cli_stdout="$4"
  local cli_stderr="$5"
  local results_tsv="$6"
  local artifact_row_id="artifact:$artifact_id"
  local stage_start_ms=0
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    stage_start_ms="$(profile_now_ms)"
  fi

  while IFS= read -r result_row || [[ -n "$result_row" ]]; do
    [[ -n "$result_row" ]] || continue
    local row_id format source_scope source_id quality_tier passed_signals total_signals failed_signals review_notes
    row_id="$(quality_result_field "$result_row" 0)"
    [[ "$row_id" == "row_id" ]] && continue
    format="$(quality_result_field "$result_row" 1)"
    source_scope="$(quality_result_field "$result_row" 2)"
    source_id="$(quality_result_field "$result_row" 3)"
    quality_tier="$(quality_result_field "$result_row" 4)"
    passed_signals="$(quality_result_field "$result_row" 5)"
    total_signals="$(quality_result_field "$result_row" 6)"
    failed_signals="$(quality_result_field "$result_row" 7)"
    review_notes="$(quality_result_field "$result_row" 8)"

    local row_status="pass"
    local note_text="all signals passed"
    if [[ -n "$review_notes" ]]; then
      note_text="$note_text; review: $review_notes"
    fi

    if [[ -n "$failed_signals" ]]; then
      row_status="fail"
      note_text="failed: $failed_signals"
      if [[ -n "$review_notes" ]]; then
        note_text="$note_text; review: $review_notes"
      fi
      if is_known_bad_tier "$quality_tier"; then
        row_status="expected_fail"
        note_text="expected fail: $failed_signals"
        if [[ -n "$review_notes" ]]; then
          note_text="$note_text; review: $review_notes"
        fi
      fi
    elif is_known_bad_tier "$quality_tier"; then
      row_status="unexpected_pass"
      note_text="known_bad row passed all signals; possible fix candidate"
      if [[ -n "$review_notes" ]]; then
        note_text="$note_text; review: $review_notes"
      fi
    fi

    summary_add "$row_id" "$format" "$source_scope" "$source_id" "$quality_tier" "$row_status" "$passed_signals" "$total_signals" "$note_text"
    if quality_status_generates_report "$row_status"; then
      quality_write_row_report "$row_id" "$format" "$source_scope" "$source_id" "$quality_tier" "$row_status" "$abs_path" "$output_md" "$cli_stdout" "$cli_stderr" "$passed_signals" "$total_signals" "$note_text" "$failed_signals" "$review_notes"
    fi
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$row_id" "row_total" 0 "$row_status"
    fi
  done < "$results_tsv"

  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    profile_record "$artifact_row_id" "signal_eval" "$(( $(profile_now_ms) - stage_start_ms ))" "rows=$(artifact_plan_row_count "$artifact_id")"
  fi
}

quality_execute_artifact_group() {
  local artifact_id="$1"
  local abs_path
  abs_path="$(artifact_plan_abs_path "$artifact_id")"
  local artifact_dir="$OUTPUT_DIR/$artifact_id"
  local artifact_row_id="artifact:$artifact_id"
  rm -rf "$artifact_dir"
  mkdir -p "$artifact_dir"

  local output_md="$artifact_dir/result.md"
  local cli_stdout="$artifact_dir/convert.stdout.log"
  local cli_stderr="$artifact_dir/convert.stderr.log"
  local cli_args=("normal")
  if [[ "$METADATA_ENABLED" -ne 0 ]]; then
    cli_args+=("--with-metadata")
  fi
  if [[ "${#CLI_EXTRA_ARGS[@]}" -ne 0 ]]; then
    cli_args+=("${CLI_EXTRA_ARGS[@]}")
  fi
  cli_args+=("$abs_path" "$output_md")

  local stage_start_ms=0
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    stage_start_ms="$(profile_now_ms)"
  fi
  if ! run_markitdown_cli "${cli_args[@]}" >"$cli_stdout" 2>"$cli_stderr"; then
    local failure_reason
    failure_reason="$(single_line_note "$(sed -n '1,5p' "$cli_stderr" 2>/dev/null)")"
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      profile_record "$artifact_row_id" "convert" "$(( $(profile_now_ms) - stage_start_ms ))" "cli_failed"
    fi
    while IFS= read -r row || [[ -n "$row" ]]; do
      [[ -n "$row" ]] || continue
      local delimiter=$'\x1f'
      local converted="${row//$'\t'/$delimiter}"
      local source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes
      IFS="$delimiter" read -r source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes <<< "$converted"
      local failure_status="fail"
      local failure_note="cli conversion failed"
      if [[ -n "$failure_reason" ]]; then
        failure_note="$failure_note: $failure_reason"
      fi
      if is_known_bad_tier "$quality_tier"; then
        failure_status="expected_fail"
        failure_note="expected converter failure: $failure_note"
      fi
      summary_add "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "$failure_status" 0 0 "$failure_note"
      if quality_status_generates_report "$failure_status"; then
        quality_write_row_report "$id" "$format" "$source_scope" "$source_id" "$quality_tier" "$failure_status" "$abs_path" "$output_md" "$cli_stdout" "$cli_stderr" 0 0 "$failure_note" "" ""
      fi
      if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
        profile_record "$id" "row_total" 0 "$failure_status"
      fi
    done < <(artifact_plan_rows_each "$artifact_id")
    return
  fi
  if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
    profile_record "$artifact_row_id" "convert" "$(( $(profile_now_ms) - stage_start_ms ))" "metadata=$(metadata_summary_value)"
  fi

  local metadata_path="$artifact_dir/metadata/result.metadata.json"
  local rows_tsv="$artifact_dir/rows.tsv"
  local results_tsv="$artifact_dir/results.tsv"
  quality_write_artifact_rows_tsv "$artifact_id" "$rows_tsv"
  quality_run_signal_evaluator "$artifact_id" "$output_md" "$metadata_path" "$artifact_dir" "$rows_tsv" "$results_tsv"
  quality_process_eval_results "$artifact_id" "$abs_path" "$output_md" "$cli_stdout" "$cli_stderr" "$results_tsv"
}

write_summary() {
  local total="$1"
  local passed="$2"
  local failed="$3"
  local skipped="$4"
  local skipped_license="$5"
  local skipped_missing_file="$6"
  local skipped_no_signals="$7"
  local expected_fail="$8"
  local unexpected_pass="$9"
  local no_manifest_rows="${10}"
  local no_matching_rows="${11}"
  local summary_row_count="${#SUMMARY_ROWS[@]}"

  mkdir -p "$OUT_ROOT"
  {
    printf 'id\tformat\tscope\tquality_tier\tstatus\tpassed_signals\ttotal_signals\tnotes\n'
    printf 'PROFILE_ENABLED\t-\t-\t-\t-\t0\t0\t%s\n' "$(profile_enabled_summary_value)"
    printf 'METADATA_MODE\t-\t-\t-\t-\t0\t0\t%s\n' "$(metadata_mode_summary_value)"
    printf 'METADATA_ENABLED\t-\t-\t-\t-\t0\t0\t%s\n' "$(metadata_summary_value)"
    printf 'METADATA_STATUS\t-\t-\t-\t-\t0\t0\t%s\n' "$(metadata_status_summary_value)"
    printf 'METADATA_NOTE\t-\t-\t-\t-\t0\t0\t%s\n' "$(metadata_note_summary_value)"
    printf 'CORPUS_ROOT\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$CORPUS_ROOT")"
    printf 'CORPUS_ROOT_SOURCE\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$CORPUS_ROOT_SOURCE")"
    printf 'QUALITY_ROWS_MANIFEST\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$QUALITY_ROWS_MANIFEST")"
    printf 'QUALITY_ROWS_MANIFEST_SOURCE\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$QUALITY_ROWS_MANIFEST_SOURCE")"
    printf 'FILTER_ID\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$FILTER_ID")"
    printf 'FILTER_SOURCE\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$FILTER_SOURCE")"
    printf 'FILTER_FORMAT\t-\t-\t-\t-\t0\t0\t%s\n' "$(filter_summary_value "$FILTER_FORMAT")"
    printf 'CLI_EXTRA_ARGS\t-\t-\t-\t-\t0\t0\t%s\n' "$(cli_extra_args_summary_value)"
    printf 'SIGNAL_EVALUATOR\t-\t-\t-\t-\t0\t0\t%s\n' "$(signal_eval_runner_summary_value)"
    printf 'SELECTED_ROWS\t-\t-\t-\t-\t0\t0\t%s\n' "$(selected_rows_summary_value)"
    printf 'EXECUTABLE_ROWS\t-\t-\t-\t-\t0\t0\t%s\n' "$(executable_rows_summary_value)"
    printf 'ARTIFACT_GROUPS\t-\t-\t-\t-\t0\t0\t%s\n' "$(artifact_groups_summary_value)"
    printf 'SKIP_NO_SIGNALS\t-\t-\t-\t-\t%s\t-\tskipped because no real signals remained after removing review_note entries\n' "$skipped_no_signals"
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
    printf 'SKIPPED_NO_SIGNALS\t-\t-\t-\t-\t%s\t-\tskipped because the row had no executable signals\n' "$skipped_no_signals"
    printf 'EXPECTED_FAIL\t-\t-\t-\t-\t%s\t-\tknown_bad rows that failed as expected\n' "$expected_fail"
    printf 'UNEXPECTED_PASS\t-\t-\t-\t-\t%s\t-\tknown_bad rows that passed all checks unexpectedly\n' "$unexpected_pass"
    printf 'NO_MANIFEST_ROWS\t-\t-\t-\t-\t%s\t-\t1 means no rows selected\n' "$no_manifest_rows"
    printf 'NO_MATCHING_ROWS\t-\t-\t-\t-\t%s\t-\t1 means filters matched zero rows\n' "$no_matching_rows"
  } > "$SUMMARY_TSV"

  {
    echo "# Quality Summary"
    echo
    echo "Profile: $(if [[ "$PROFILE_ENABLED" -ne 0 ]]; then printf 'enabled'; else printf 'disabled'; fi)"
    if [[ "$PROFILE_ENABLED" -ne 0 ]]; then
      echo "Profile path: $PROFILE_TSV"
    fi
    echo
    echo "Metadata mode: $(metadata_mode_summary_value)"
    echo "Metadata: $(if [[ "$METADATA_ENABLED" -ne 0 ]]; then printf 'enabled'; else printf 'disabled'; fi)"
    echo "Metadata status: $(metadata_status_summary_value)"
    echo "Metadata note: $(metadata_note_summary_value)"
    echo "Signal evaluator: $(signal_eval_runner_summary_value)"
    echo "CLI extra args: $(cli_extra_args_summary_value)"
    echo
    echo "Filters:"
    echo "- id: $(filter_summary_value "$FILTER_ID")"
    echo "- source: $(filter_summary_value "$FILTER_SOURCE")"
    echo "- format: $(filter_summary_value "$FILTER_FORMAT")"
    echo
    echo "- selected_rows: $(selected_rows_summary_value)"
    echo "- executable_rows: $(executable_rows_summary_value)"
    echo "- artifact_groups: $(artifact_groups_summary_value)"
    echo "- total: $total"
    echo "- passed: $passed"
    echo "- failed: $failed"
    echo "- skipped: $skipped"
    echo "- skipped_license: $skipped_license"
    echo "- skipped_missing_file: $skipped_missing_file"
    echo "- skip_no_signals: $skipped_no_signals"
    echo "- expected_fail: $expected_fail"
    echo "- unexpected_pass: $unexpected_pass"
    echo "- no_manifest_rows: $no_manifest_rows"
    echo "- no_matching_rows: $no_matching_rows"
    echo
    echo "## Artifact layout"
    echo
    echo "- Raw executed outputs: $RAW_DIR"
    echo "- Non-pass index: $NONPASS_INDEX_MD"
    echo "- Row reports: $ROW_REPORTS_DIR"
    echo "- Workspace scratch: $CLI_TMP_ROOT"
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
      echo "## Non-pass Rows"
      echo
      if [[ "$failed" -eq 0 && "$expected_fail" -eq 0 && "$unexpected_pass" -eq 0 ]]; then
        echo "No executed non-pass rows."
      else
        echo "- Index: $NONPASS_INDEX_MD"
      fi
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
FILTERED_ROWS=()
SELECTED_ROW_COUNT=0
EXECUTABLE_ROW_COUNT=0
ARTIFACT_GROUP_COUNT=0
SKIPPED_NO_SIGNALS_COUNT=0
artifact_plan_init
while IFS= read -r row; do
  [[ -n "$row" ]] && MANIFEST_ROWS+=("$row")
done < <(collect_manifest_rows)

if [[ "${#MANIFEST_ROWS[@]}" -eq 0 ]]; then
  write_summary 0 0 0 0 0 0 0 0 0 1 0
  validation_progress_init "quality" 0
  validation_progress_zero "no manifest rows"
  echo "QUALITY CHECK PASSED (no manifest rows selected)"
  echo "summary: $SUMMARY_TSV"
  echo "report: $SUMMARY_MD"
  exit 0
fi

for row in "${MANIFEST_ROWS[@]}"; do
  if row_matches_filters "$row"; then
    FILTERED_ROWS+=("$row")
  fi
done
SELECTED_ROW_COUNT="${#FILTERED_ROWS[@]}"

if [[ "${#FILTERED_ROWS[@]}" -eq 0 ]]; then
  write_summary 0 0 0 0 0 0 0 0 0 0 1
  validation_progress_init "quality" 0
  validation_progress_zero "no matching rows"
  echo "QUALITY CHECK PASSED (no rows matched filters)"
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
resolve_quality_metadata_mode
echo "runner: $(quality_runner_label)"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi
echo "metadata-mode: $(metadata_mode_summary_value)"
echo "metadata-status: $(metadata_status_summary_value)"
if [[ -n "$METADATA_NOTE" ]]; then
  echo "metadata-note: $METADATA_NOTE"
fi
if [[ "${#CLI_EXTRA_ARGS[@]}" -ne 0 ]]; then
  echo "cli-extra-args: $(cli_extra_args_summary_value)"
fi

validation_progress_init "quality" "${#FILTERED_ROWS[@]}"

for row in "${FILTERED_ROWS[@]}"; do
  quality_plan_row "$row"
done

while IFS= read -r artifact_id || [[ -n "$artifact_id" ]]; do
  [[ -n "$artifact_id" ]] || continue
  quality_execute_artifact_group "$artifact_id"
done < "$ARTIFACT_IDS_FILE"

validation_progress_done

total_rows=0
passed_rows=0
failed_rows=0
skipped_rows=0
skipped_license_rows=0
skipped_missing_file_rows=0
skipped_no_signals_rows=0
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
    skip_no_signals)
      skipped_rows=$((skipped_rows + 1))
      skipped_no_signals_rows=$((skipped_no_signals_rows + 1))
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

write_summary "$total_rows" "$passed_rows" "$failed_rows" "$skipped_rows" "$skipped_license_rows" "$skipped_missing_file_rows" "$skipped_no_signals_rows" "$expected_fail_rows" "$unexpected_pass_rows" 0 0
write_nonpass_index

if [[ "$failed_rows" -ne 0 ]]; then
  echo "QUALITY CHECK FAILED"
  echo "quality_rows: $total_rows"
  echo "failed: $failed_rows"
  echo "skipped: $skipped_rows"
  echo "skip_no_signals: $skipped_no_signals_rows"
  echo "selected_rows: $SELECTED_ROW_COUNT"
  echo "executable_rows: $EXECUTABLE_ROW_COUNT"
  echo "artifact_groups: $ARTIFACT_GROUP_COUNT"
  echo "expected_fail: $expected_fail_rows"
  echo "quality_rows_manifest: $QUALITY_ROWS_MANIFEST"
  echo "quality_lab_path: $CORPUS_ROOT"
  echo "quality_tmp_dir: $OUT_ROOT"
  echo "quality_cli_tmp_dir: $CLI_TMP_ROOT"
  echo "summary: $SUMMARY_TSV"
  echo "report: $SUMMARY_MD"
  exit 1
fi

if [[ "$unexpected_pass_rows" -ne 0 ]]; then
  echo "QUALITY CHECK PASSED WITH UNEXPECTED PASSES ($total_rows rows; $skipped_rows skipped; $expected_fail_rows expected_fail; $unexpected_pass_rows unexpected_pass)"
else
  echo "QUALITY CHECK PASSED ($total_rows rows; $skipped_rows skipped; $expected_fail_rows expected_fail)"
fi
echo "quality_rows: $total_rows"
echo "failed: $failed_rows"
echo "skipped: $skipped_rows"
echo "skip_no_signals: $skipped_no_signals_rows"
echo "selected_rows: $SELECTED_ROW_COUNT"
echo "executable_rows: $EXECUTABLE_ROW_COUNT"
echo "artifact_groups: $ARTIFACT_GROUP_COUNT"
echo "expected_fail: $expected_fail_rows"
echo "quality_rows_manifest: $QUALITY_ROWS_MANIFEST"
echo "quality_lab_path: $CORPUS_ROOT"
echo "quality_tmp_dir: $OUT_ROOT"
echo "quality_cli_tmp_dir: $CLI_TMP_ROOT"
echo "summary: $SUMMARY_TSV"
echo "report: $SUMMARY_MD"
