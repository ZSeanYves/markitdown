#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"

SAMPLES_DIR="$ROOT/samples/main_process"
FIXTURE_METADATA_DIR="$ROOT/samples/fixtures/metadata"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
if [[ -n "${CHECK_SAMPLES_OUT_DIR:-}" ]]; then
  OUT_DIR="$CHECK_SAMPLES_OUT_DIR"
  mkdir -p "$OUT_DIR"
  CLEANUP_OUT_DIR=0
else
  OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "main_process")"
  CLEANUP_OUT_DIR=1
fi

MODE="markdown-only"
FORMAT_FILTER=""
SPECIAL_MODE=""
FORMATS=("csv" "tsv" "txt" "json" "jsonl" "ndjson" "xml" "yaml" "html" "markdown" "zip" "epub" "docx" "xlsx" "pptx" "pdf")

trap 'status=$?; if [[ "$CLEANUP_OUT_DIR" -ne 0 ]]; then sample_cleanup_tmp_dir "$OUT_DIR"; fi; exit "$status"' EXIT

usage() {
  cat <<'EOF'
Internal usage: check_samples_impl.sh [--markdown-only] [--format FMT] [--check-inventory] [--list-inventory]
EOF
}

supported_formats() {
  local IFS=","
  echo "${FORMATS[*]}"
}

sample_inventory_formats() {
  printf '%s\n' xlsx html zip epub docx pptx pdf csv tsv json yaml xml markdown txt
}

format_is_supported() {
  local target="$1"
  local fmt
  for fmt in "${FORMATS[@]}"; do
    if [[ "$fmt" == "$target" ]]; then
      return 0
    fi
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown-only)
      MODE="markdown-only"
      ;;
    --format)
      shift
      if [[ $# -eq 0 || "${1:-}" == --* ]]; then
        echo "--format requires a value" >&2
        usage >&2
        exit 1
      fi
      FORMAT_FILTER="$1"
      ;;
    --check-inventory)
      SPECIAL_MODE="check-inventory"
      ;;
    --list-inventory)
      SPECIAL_MODE="list-inventory"
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

if [[ -n "$FORMAT_FILTER" ]] && ! format_is_supported "$FORMAT_FILTER"; then
  echo "unsupported format for current main CLI gate: $FORMAT_FILTER is not migrated to the current main CLI yet" >&2
  echo "supported gate formats: $(supported_formats)" >&2
  echo "supported format restoration is currently limited to the root pipeline set; no legacy fallback is used here" >&2
  exit 1
fi

require_python3() {
  if command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  echo "python3 is required for metadata sidecar validation" >&2
  exit 1
}

extract_asset_refs() {
  local dir="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -o --no-filename "assets/[A-Za-z0-9_./-]+" "$dir" -g '*.md' | sort -u || true
    return
  fi
  find "$dir" -type f -name '*.md' -print0 \
    | xargs -0 grep -hoE "assets/[A-Za-z0-9_./-]+" \
    | sort -u || true
}

check_asset_refs_or_record() {
  local scope="$1"
  local out_dir="$2"
  local refs ref missing=0
  refs="$(extract_asset_refs "$out_dir")"
  if [[ -z "${refs//[$'\t\r\n ']}" ]]; then
    return 0
  fi
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -f "$out_dir/$ref" ]]; then
      validation_record_failure "$scope" "$scope" "" "$out_dir/$ref" "missing asset"
      missing=1
    fi
  done <<< "$refs"
  return "$missing"
}

validate_metadata_sidecar() {
  local scope="$1"
  local input_path="$2"
  local fmt="$3"
  local markdown_path="$4"
  local metadata_path="$5"
  local sample_out_dir="$6"
  local detail

  if [[ ! -f "$metadata_path" ]]; then
    validation_record_failure "$scope" "$input_path" "$metadata_path" "$metadata_path" "missing metadata sidecar"
    return 1
  fi

  set +e
  detail="$(python3 - "$metadata_path" "$input_path" "$fmt" "$markdown_path" "$sample_out_dir" <<'PY'
import json
import sys
from pathlib import Path

meta_path = Path(sys.argv[1])
input_path = Path(sys.argv[2])
expected_format = sys.argv[3]
markdown_path = Path(sys.argv[4])
sample_out_dir = Path(sys.argv[5])

try:
    data = json.loads(meta_path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"json parse failed: {exc}")
    sys.exit(1)

if not isinstance(data, dict):
    print("top-level metadata must be a JSON object")
    sys.exit(1)

required_top = [
    "version",
    "source_name",
    "format",
    "markdown_file",
    "document",
    "summary",
    "blocks",
    "assets",
]
for key in required_top:
    if key not in data:
        print(f"missing top-level key: {key}")
        sys.exit(1)

if data["source_name"] != input_path.name:
    print(f"source_name mismatch: expected {input_path.name}, got {data['source_name']!r}")
    sys.exit(1)

if data["format"] != expected_format:
    print(f"format mismatch: expected {expected_format}, got {data['format']!r}")
    sys.exit(1)

if data["markdown_file"] != markdown_path.name:
    print(f"markdown_file mismatch: expected {markdown_path.name}, got {data['markdown_file']!r}")
    sys.exit(1)

summary = data["summary"]
if not isinstance(summary, dict):
    print("summary must be an object")
    sys.exit(1)

for key in ["block_count", "asset_count"]:
    if key not in summary:
        print(f"summary missing key: {key}")
        sys.exit(1)
    if not isinstance(summary[key], int):
        print(f"summary key {key} must be an integer")
        sys.exit(1)

blocks = data["blocks"]
assets = data["assets"]
if not isinstance(blocks, list):
    print("blocks must be an array")
    sys.exit(1)
if not isinstance(assets, list):
    print("assets must be an array")
    sys.exit(1)

if summary["block_count"] != len(blocks):
    print(f"summary.block_count mismatch: expected {len(blocks)}, got {summary['block_count']}")
    sys.exit(1)
if summary["asset_count"] != len(assets):
    print(f"summary.asset_count mismatch: expected {len(assets)}, got {summary['asset_count']}")
    sys.exit(1)

require_document = expected_format in {"docx", "pptx", "xlsx", "epub"}
document = data["document"]
if require_document and document is None:
    print(f"document must be present for format {expected_format}")
    sys.exit(1)
if document is not None and not isinstance(document, dict):
    print("document must be null or an object")
    sys.exit(1)

for index, block in enumerate(blocks):
    if not isinstance(block, dict):
        print(f"blocks[{index}] must be an object")
        sys.exit(1)
    for key in ["block_index", "block_type", "text"]:
        if key not in block:
            print(f"blocks[{index}] missing key: {key}")
            sys.exit(1)
    if not isinstance(block["block_index"], int):
        print(f"blocks[{index}].block_index must be an integer")
        sys.exit(1)
    if "origin" not in block:
        print(f"blocks[{index}] missing key: origin")
        sys.exit(1)

seen_paths = set()
for index, asset in enumerate(assets):
    if not isinstance(asset, dict):
        print(f"assets[{index}] must be an object")
        sys.exit(1)
    for key in ["path", "asset_type"]:
        if key not in asset:
            print(f"assets[{index}] missing key: {key}")
            sys.exit(1)
    path = asset["path"]
    if not isinstance(path, str) or path.strip() == "":
        print(f"assets[{index}].path must be a non-empty string")
        sys.exit(1)
    if path in seen_paths:
        print(f"duplicate asset path: {path}")
        sys.exit(1)
    seen_paths.add(path)
    resolved = sample_out_dir / path
    if not resolved.is_file():
        print(f"asset file missing on disk: {path}")
        sys.exit(1)

asset_files = []
asset_root = sample_out_dir / "assets"
if asset_root.is_dir():
    for child in asset_root.rglob("*"):
        if child.is_file():
            asset_files.append(child.relative_to(sample_out_dir).as_posix())

if asset_files and not assets:
    print("assets directory is non-empty but metadata assets[] is empty")
    sys.exit(1)

if not asset_files and assets:
    print("metadata assets[] is non-empty but assets directory is empty")
    sys.exit(1)

if sorted(asset_files) != sorted(seen_paths):
    print(
        "asset path mismatch between metadata and disk: "
        f"metadata={sorted(seen_paths)} disk={sorted(asset_files)}"
    )
    sys.exit(1)

print(
    f"ok blocks={len(blocks)} assets={len(assets)} "
    f"document={'present' if document is not None else 'null'}"
)
PY
)"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    validation_record_failure "$scope" "$input_path" "$metadata_path" "$metadata_path" "$detail"
    return 1
  fi

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> metadata validated $scope ($detail)"
  fi
  return 0
}

validate_metadata_fixture_json() {
  local scope="$1"
  local input_path="$2"
  local expected_metadata="$3"
  local actual_metadata="$4"
  local detail

  set +e
  detail="$(python3 - "$expected_metadata" "$actual_metadata" <<'PY'
import json
import sys
from pathlib import Path

expected_path = Path(sys.argv[1])
actual_path = Path(sys.argv[2])

try:
    expected = json.loads(expected_path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"expected fixture json parse failed: {exc}")
    sys.exit(1)

try:
    actual = json.loads(actual_path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"actual sidecar json parse failed: {exc}")
    sys.exit(1)

if expected != actual:
    expected_keys = set(expected.keys()) if isinstance(expected, dict) else set()
    actual_keys = set(actual.keys()) if isinstance(actual, dict) else set()
    changed = sorted(key for key in expected_keys | actual_keys if expected.get(key) != actual.get(key))
    if changed:
      print("json fixture mismatch at keys: " + ", ".join(changed[:8]))
    else:
      print("json fixture mismatch")
    sys.exit(1)

print("ok")
PY
)"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    validation_record_failure "$scope" "$input_path" "$expected_metadata" "$actual_metadata" "$detail"
    return 1
  fi

  return 0
}

count_non_hidden_files() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -maxdepth 1 -type f ! -name '.*' | wc -l | tr -d '[:space:]'
}

count_main_process_inventory_samples() {
  local fmt="$1"
  local dir="$SAMPLES_DIR/$fmt"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  if [[ "$fmt" == "pdf" ]]; then
    enrolled_pdf_root_samples | sed '/^$/d' | wc -l | tr -d '[:space:]'
    return
  fi
  find "$dir" -type f \
    ! -name '.*' \
    ! -path '*/expected' \
    ! -path '*/expected/*' \
    ! -path '*/expected_next' \
    ! -path '*/expected_next/*' \
    ! -path '*/img/*' \
    ! -name '*.jpg' \
    ! -name '*.jpeg' \
    ! -name '*.png' \
    ! -name '*.gif' \
    ! -name '*.webp' \
    ! -name '*.bmp' \
    ! -name '*.svg' \
    ! -name '*.key' \
    | wc -l | tr -d '[:space:]'
}

enrolled_pdf_root_samples() {
  printf '%s\n' "root_native_text_baseline.pdf"
}

count_quality_manifest_rows() {
  local fmt="$1"
  local manifest="$ROOT/samples/helpers/quality/manifest.tsv"
  if [[ ! -f "$manifest" ]]; then
    printf '0'
    return
  fi
  awk -F '\t' -v fmt="$fmt" '
    NR == 1 { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    $2 == fmt { count++ }
    END { print count + 0 }
  ' "$manifest"
}

count_quality_comparison_reports() {
  local fmt="$1"
  local dir="$ROOT/docs/quality-comparisons"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -maxdepth 1 -type f -name "${fmt}*.md" | wc -l | tr -d '[:space:]'
}

inventory_list() {
  local fmt
  printf 'format\tmain_process\tmetadata_cases\tasset_cases\tfixtures\tbenchmark_retired\tquality_records\tquality_intake_public\tmetadata_expected\n'
  while IFS= read -r fmt; do
    [[ -z "$fmt" ]] && continue
    local main_count meta_count assets_count fixture_count quality_count quality_manifest_count metadata_expected_count
    main_count="$(count_main_process_inventory_samples "$fmt")"
    meta_count="$(count_non_hidden_files "$SAMPLES_DIR/$fmt/metadata")"
    assets_count="$(count_non_hidden_files "$SAMPLES_DIR/$fmt/assets")"
    fixture_count="$(count_non_hidden_files "$ROOT/samples/fixtures/$fmt")"
    quality_count="$(count_quality_comparison_reports "$fmt")"
    quality_manifest_count="$(count_quality_manifest_rows "$fmt")"
    metadata_expected_count="$(find "$SAMPLES_DIR/$fmt/expected" -type f -name '*.metadata.json' 2>/dev/null | wc -l | tr -d '[:space:]')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$fmt" \
      "$main_count" \
      "$meta_count" \
      "$assets_count" \
      "$fixture_count" \
      "0" \
      "$quality_count" \
      "$quality_manifest_count" \
      "$metadata_expected_count"
  done < <(sample_inventory_formats)
}

sample_integrity_is_noise_file() {
  local base="$1"
  [[ "$base" == .* ]] && return 0
  [[ "$base" == *~ ]] && return 0
  [[ "$base" == *.swp ]] && return 0
  [[ "$base" == *.tmp ]] && return 0
  return 1
}

sample_integrity_discover_inputs() {
  local fmt="$1"
  local in_dir="$SAMPLES_DIR/$fmt"
  case "$fmt" in
    docx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.docx" -print ;;
    pdf)
      while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        printf '%s/%s\n' "$in_dir" "$rel"
      done < <(enrolled_pdf_root_samples)
      ;;
    xlsx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.xlsx" -print ;;
    pptx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.pptx" -print ;;
    html) find "$in_dir" -path "$in_dir/expected" -prune -o -type f \( -name "*.html" -o -name "*.htm" \) -print ;;
    csv) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.csv" -print ;;
    tsv) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.tsv" -print ;;
    txt) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.txt" -print ;;
    xml) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.xml" -print ;;
    json) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.json" -print ;;
    yaml) find "$in_dir" -path "$in_dir/expected" -prune -o -type f \( -name "*.yaml" -o -name "*.yml" \) -print ;;
    markdown) find "$in_dir" -path "$in_dir/expected" -prune -o -type f \( -name "*.md" -o -name "*.markdown" \) -print ;;
    zip) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.zip" -print ;;
    epub) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.epub" -print ;;
    *) return 0 ;;
  esac
}

sample_integrity_expected_bases() {
  local fmt="$1"
  local exp_dir="$2"
  if [[ "$fmt" == "pdf" ]]; then
    enrolled_pdf_root_samples | sed 's/\.pdf$//'
    return
  fi
  find "$exp_dir" -type f -name '*.md' -print | sort | while read -r path; do
    rel="${path#$exp_dir/}"
    if [[ "$rel" == reference/* ]]; then
      continue
    fi
    echo "${rel%.md}"
  done | sort -u
}

check_sample_inventory_integrity() {
  local formats=("docx" "pdf" "xlsx" "html" "pptx" "csv" "tsv" "txt" "xml" "json" "yaml" "markdown" "zip" "epub")
  local fail=0 group_count=0 quiet_integrity=0 fmt in_dir exp_dir input_bases expected_bases missing_input missing_expected

  if validation_bool_enabled "${SAMPLES_QUIET_INTEGRITY:-0}"; then
    quiet_integrity=1
  fi

  if [[ "$quiet_integrity" -eq 0 ]]; then
    echo "==> sample integrity check"
  fi

  for fmt in "${formats[@]}"; do
    group_count=$((group_count + 1))
    in_dir="$SAMPLES_DIR/$fmt"
    exp_dir="$in_dir/expected"

    if [[ ! -d "$in_dir" ]]; then
      echo "[warn] input dir missing: $in_dir"
      continue
    fi

    mkdir -p "$exp_dir"

    input_bases="$(sample_integrity_discover_inputs "$fmt" | sort | while read -r path; do
      rel="${path#$in_dir/}"
      base="$(basename "$rel")"
      if sample_integrity_is_noise_file "$base"; then
        continue
      fi
      echo "${rel%.*}"
    done | sort -u)"

    expected_bases="$(sample_integrity_expected_bases "$fmt" "$exp_dir")"

    if validation_bool_enabled "$SAMPLES_VERBOSE"; then
      printf '\n[%s]\n' "$fmt"
    fi

    missing_input="$(comm -23 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"
    missing_expected="$(comm -13 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"

    if [[ -n "$missing_input" ]]; then
      if [[ "$quiet_integrity" -eq 1 ]]; then
        printf '[%s]\n' "$fmt"
      fi
      while IFS= read -r base; do
        [[ -z "$base" ]] && continue
        echo "  [error] expected exists but input missing:"
        echo "    - $base"
        fail=1
      done <<< "$missing_input"
    fi

    if [[ -n "$missing_expected" ]]; then
      if [[ "$quiet_integrity" -eq 1 && -z "$missing_input" ]]; then
        printf '[%s]\n' "$fmt"
      fi
      echo "  [error] input exists but expected missing:"
      while IFS= read -r base; do
        [[ -z "$base" ]] && continue
        echo "    - $base"
      done <<< "$missing_expected"
      fail=1
    fi

    if [[ -z "$missing_input" && -z "$missing_expected" ]] && validation_bool_enabled "$SAMPLES_VERBOSE"; then
      echo "  [ok] sample/expected enrollment is consistent"
    fi
  done

  if [[ "$fail" -ne 0 ]]; then
    printf '\nSAMPLE INTEGRITY CHECK FAILED\n'
    exit 1
  fi

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    printf '\nSAMPLE INTEGRITY CHECK PASSED\n'
  else
    printf 'SAMPLE INTEGRITY CHECK PASSED (%s groups)\n' "$group_count"
  fi
}

if [[ -n "$SPECIAL_MODE" ]]; then
  if [[ -n "$FORMAT_FILTER" ]]; then
    echo "--format cannot be combined with --$SPECIAL_MODE" >&2
    usage >&2
    exit 1
  fi
  case "$SPECIAL_MODE" in
    check-inventory)
      check_sample_inventory_integrity
      exit 0
      ;;
    list-inventory)
      inventory_list
      exit 0
      ;;
  esac
fi

discover_samples() {
  local fmt="$1"
  local in_dir="$SAMPLES_DIR/$fmt"
  case "$fmt" in
    docx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.docx" -print ;;
    pdf)
      while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        printf '%s/%s\n' "$in_dir" "$rel"
      done < <(enrolled_pdf_root_samples)
      ;;
    xlsx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.xlsx" -print ;;
    pptx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.pptx" -print ;;
    html) find "$in_dir" -path "$in_dir/expected" -prune -o -type f \( -name "*.html" -o -name "*.htm" \) -print ;;
    csv) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.csv" -print ;;
    tsv) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.tsv" -print ;;
    txt) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.txt" -print ;;
    xml) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.xml" -print ;;
    json) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.json" -print ;;
    jsonl) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.jsonl" -print ;;
    ndjson) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.ndjson" -print ;;
    yaml) find "$in_dir" -path "$in_dir/expected" -prune -o -type f \( -name "*.yaml" -o -name "*.yml" \) -print ;;
    markdown) find "$in_dir" -path "$in_dir/expected" -prune -o -type f \( -name "*.md" -o -name "*.markdown" \) -print ;;
    zip) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.zip" -print ;;
    epub) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.epub" -print ;;
    *) return 0 ;;
  esac
}

sample_has_metadata_dimension() {
  local rel="$1"
  [[ "$rel" == metadata/* || "$rel" == */metadata/* ]]
}

resolve_expected_metadata_fixture() {
  local fmt="$1"
  local rel_no_ext="$2"
  local name="$3"

  if [[ -f "$SAMPLES_DIR/$fmt/expected/$rel_no_ext.metadata.json" ]]; then
    printf '%s\n' "$SAMPLES_DIR/$fmt/expected/$rel_no_ext.metadata.json"
    return 0
  fi

  if [[ -f "$FIXTURE_METADATA_DIR/$name.metadata.json" ]]; then
    printf '%s\n' "$FIXTURE_METADATA_DIR/$name.metadata.json"
    return 0
  fi

  return 1
}

resolve_expected_markdown_fixture() {
  local fmt="$1"
  local rel_no_ext="$2"

  if [[ "$fmt" == "xlsx" && -f "$SAMPLES_DIR/$fmt/expected_next/$rel_no_ext.md" ]]; then
    printf '%s\n' "$SAMPLES_DIR/$fmt/expected_next/$rel_no_ext.md"
    return 0
  fi
  if [[ "$fmt" == "pptx" && -f "$SAMPLES_DIR/$fmt/expected_next/$rel_no_ext.md" ]]; then
    printf '%s\n' "$SAMPLES_DIR/$fmt/expected_next/$rel_no_ext.md"
    return 0
  fi

  printf '%s\n' "$SAMPLES_DIR/$fmt/expected/$rel_no_ext.md"
}

sample_is_asset_relevant() {
  local fmt="$1"
  local rel="$2"
  local expected_markdown="$3"
  if [[ "$rel" == assets/* || "$rel" == */assets/* ]]; then
    return 0
  fi
  if [[ "$fmt" == "zip" || "$fmt" == "epub" ]]; then
    return 0
  fi
  if [[ -f "$expected_markdown" ]] && grep -q "assets/" "$expected_markdown"; then
    return 0
  fi
  return 1
}

sample_matches_mode() {
  local fmt="$1"
  local rel="$2"
  local expected_markdown="$3"
  case "$MODE" in
    full|markdown-only)
      return 0
      ;;
    metadata-only)
      sample_has_metadata_dimension "$rel"
      return $?
      ;;
    assets-only)
      sample_is_asset_relevant "$fmt" "$rel" "$expected_markdown"
      return $?
      ;;
    *)
      return 0
      ;;
  esac
}

resolve_markitdown_cli
echo "runner: $CLI_RUNNER_KIND"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

ACTIVE_FORMATS=("${FORMATS[@]}")
if [[ -n "$FORMAT_FILTER" ]]; then
  ACTIVE_FORMATS=("$FORMAT_FILTER")
fi

SAMPLE_LIST=()
for fmt in "${ACTIVE_FORMATS[@]}"; do
  in_dir="$SAMPLES_DIR/$fmt"
  [[ -d "$in_dir" ]] || continue
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel="${f#$in_dir/}"
    SAMPLE_LIST+=("$fmt|$rel")
  done < <(discover_samples "$fmt" | sort)
done

FILTERED_LIST=()
for entry in "${SAMPLE_LIST[@]}"; do
  IFS='|' read -r fmt rel <<< "$entry"
  exp="$(resolve_expected_markdown_fixture "$fmt" "${rel%.*}")"
  if sample_matches_mode "$fmt" "$rel" "$exp"; then
    FILTERED_LIST+=("$entry")
  fi
done

if [[ ${#FILTERED_LIST[@]} -eq 0 ]]; then
  echo "No enrolled sample files matched mode=$MODE format=${FORMAT_FILTER:-all} under $SAMPLES_DIR"
  exit 1
fi

label="main_process_markdown"
success_message="ALL MAIN PROCESS MARKDOWN TESTS PASSED"
failure_message="FAILED MAIN PROCESS MARKDOWN SAMPLES"
if [[ -n "$FORMAT_FILTER" ]]; then
  label="${label}_${FORMAT_FILTER}"
  success_message="$success_message ($FORMAT_FILTER)"
  failure_message="$failure_message ($FORMAT_FILTER)"
fi

validation_progress_init "$label" "${#FILTERED_LIST[@]}"

for entry in "${FILTERED_LIST[@]}"; do
  IFS='|' read -r fmt rel <<< "$entry"
  base="$(basename "$rel")"
  name="${base%.*}"
  rel_no_ext="${rel%.*}"
  input_path="$SAMPLES_DIR/$fmt/$rel"
  exp="$(resolve_expected_markdown_fixture "$fmt" "$rel_no_ext")"
  scope="main_process/$fmt/$rel_no_ext"
  sample_out_dir="$OUT_DIR/$fmt/$rel_no_ext"
  normal_dir="$sample_out_dir/normal"
  normal_md="$normal_dir/$name.md"
  normal_diff="$normal_dir/$name.diff"

  mkdir -p "$normal_dir"
  validation_progress_step "$fmt/$rel"

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> converting $scope"
  fi
  if ! run_markitdown_cli normal "$input_path" "$normal_md"; then
    validation_record_failure "$scope" "$input_path" "$exp" "$normal_md" "conversion failed"
    continue
  fi

  if [[ ! -f "$exp" ]]; then
    validation_record_failure "$scope" "$input_path" "$exp" "$normal_md" "expected missing"
  else
    validation_diff_or_record "$scope" "$input_path" "$exp" "$normal_md" "$normal_diff" || true
  fi
done

validation_finish "$success_message" "$failure_message"
