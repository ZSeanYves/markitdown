#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"

SAMPLES_DIR="$ROOT/samples/main_process"
FIXTURE_METADATA_DIR="$ROOT/samples/fixtures/metadata"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "main_process")"

MODE="full"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

usage() {
  cat <<'EOF'
Internal usage: check_samples_impl.sh [--markdown-only | --metadata-only | --assets-only]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown-only)
      MODE="markdown-only"
      ;;
    --metadata-only)
      MODE="metadata-only"
      ;;
    --assets-only)
      MODE="assets-only"
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

discover_samples() {
  local fmt="$1"
  local in_dir="$SAMPLES_DIR/$fmt"
  case "$fmt" in
    docx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.docx" -print ;;
    pdf) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.pdf" -print ;;
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
require_python3

echo "runner: $CLI_RUNNER_KIND"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

FORMATS=("docx" "pdf" "xlsx" "html" "pptx" "csv" "tsv" "txt" "xml" "json" "yaml" "markdown" "zip" "epub")

SAMPLE_LIST=()
for fmt in "${FORMATS[@]}"; do
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
  exp="$SAMPLES_DIR/$fmt/expected/${rel%.*}.md"
  if sample_matches_mode "$fmt" "$rel" "$exp"; then
    FILTERED_LIST+=("$entry")
  fi
done

if [[ ${#FILTERED_LIST[@]} -eq 0 ]]; then
  echo "No enrolled sample files matched mode=$MODE under $SAMPLES_DIR"
  exit 1
fi

label="main_process"
success_message="ALL MAIN PROCESS TESTS PASSED"
failure_message="FAILED MAIN PROCESS SAMPLES"
case "$MODE" in
  metadata-only)
    label="main_process_metadata"
    success_message="ALL MAIN PROCESS METADATA TESTS PASSED"
    failure_message="FAILED MAIN PROCESS METADATA SAMPLES"
    ;;
  assets-only)
    label="main_process_assets"
    success_message="ALL MAIN PROCESS ASSET TESTS PASSED"
    failure_message="FAILED MAIN PROCESS ASSET SAMPLES"
    ;;
  markdown-only)
    label="main_process_markdown"
    success_message="ALL MAIN PROCESS MARKDOWN TESTS PASSED"
    failure_message="FAILED MAIN PROCESS MARKDOWN SAMPLES"
    ;;
esac

validation_progress_init "$label" "${#FILTERED_LIST[@]}"

for entry in "${FILTERED_LIST[@]}"; do
  IFS='|' read -r fmt rel <<< "$entry"
  base="$(basename "$rel")"
  name="${base%.*}"
  rel_no_ext="${rel%.*}"
  input_path="$SAMPLES_DIR/$fmt/$rel"
  exp="$SAMPLES_DIR/$fmt/expected/$rel_no_ext.md"
  expected_metadata=""
  if sample_has_metadata_dimension "$rel"; then
    if expected_metadata="$(resolve_expected_metadata_fixture "$fmt" "$rel_no_ext" "$name")"; then
      :
    else
      expected_metadata=""
    fi
  fi
  scope="main_process/$fmt/$rel_no_ext"
  sample_out_dir="$OUT_DIR/$fmt/$rel_no_ext"
  normal_dir="$sample_out_dir/normal"
  with_meta_dir="$sample_out_dir/with_metadata"
  normal_md="$normal_dir/$name.md"
  normal_diff="$normal_dir/$name.diff"
  with_meta_md="$with_meta_dir/$name.md"
  with_meta_diff="$with_meta_dir/$name.diff"
  with_meta_sidecar="$with_meta_dir/metadata/$name.metadata.json"

  mkdir -p "$normal_dir" "$with_meta_dir"
  validation_progress_step "$fmt/$rel"

  if [[ "$MODE" != "metadata-only" ]]; then
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

    if [[ "$MODE" == "full" || "$MODE" == "assets-only" ]] && sample_is_asset_relevant "$fmt" "$rel" "$exp"; then
      check_asset_refs_or_record "$scope" "$normal_dir" || true
    fi
  fi

  if [[ "$MODE" != "markdown-only" && "$MODE" != "assets-only" ]] && sample_has_metadata_dimension "$rel"; then
    if validation_bool_enabled "$SAMPLES_VERBOSE"; then
      echo "==> converting with metadata $scope"
    fi
    if ! run_markitdown_cli normal --with-metadata "$input_path" "$with_meta_md"; then
      validation_record_failure "$scope metadata" "$input_path" "$exp" "$with_meta_md" "conversion failed"
      continue
    fi

    if [[ ! -f "$exp" ]]; then
      validation_record_failure "$scope metadata" "$input_path" "$exp" "$with_meta_md" "expected missing"
    else
      validation_diff_or_record "$scope metadata" "$input_path" "$exp" "$with_meta_md" "$with_meta_diff" || true
    fi

    validate_metadata_sidecar "$scope metadata" "$input_path" "$fmt" "$with_meta_md" "$with_meta_sidecar" "$with_meta_dir" || true

    if [[ -f "$expected_metadata" ]]; then
      validate_metadata_fixture_json "$scope metadata sidecar" "$input_path" "$expected_metadata" "$with_meta_sidecar" || true
    fi
  fi
done

validation_finish "$success_message" "$failure_message"
