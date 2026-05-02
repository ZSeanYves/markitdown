#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/samples/scripts/tmp_helpers.sh"
source "$ROOT/samples/scripts/validation_helpers.sh"
META_DIR="$ROOT/samples/metadata"
EXP_DIR="$META_DIR/expected"
META_FIXTURE_DIR="$ROOT/samples/test/metadata"
ALT_META_FIXTURE_DIR="$ROOT/samples/expected/metadata"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "metadata")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

require_python3() {
  if command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  echo "python3 is required for metadata sidecar validation" >&2
  exit 1
}

resolve_expected_metadata_fixture() {
  local fmt="$1"
  local name="$2"

  if [[ -f "$ALT_META_FIXTURE_DIR/$name.metadata.json" ]]; then
    printf '%s\n' "$ALT_META_FIXTURE_DIR/$name.metadata.json"
    return 0
  fi

  if [[ -f "$ALT_META_FIXTURE_DIR/$fmt/$name.metadata.json" ]]; then
    printf '%s\n' "$ALT_META_FIXTURE_DIR/$fmt/$name.metadata.json"
    return 0
  fi

  if [[ -f "$META_FIXTURE_DIR/$name.metadata.json" ]]; then
    printf '%s\n' "$META_FIXTURE_DIR/$name.metadata.json"
    return 0
  fi

  return 1
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

resolve_markitdown_cli
require_python3

echo "runner: $CLI_RUNNER_KIND"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

FORMATS=("html" "pdf" "pptx" "docx" "xlsx" "csv" "tsv" "txt" "xml" "yaml" "markdown" "zip" "epub")

discover_metadata_samples() {
  local fmt="$1"
  local in_dir="$META_DIR/$fmt"
  case "$fmt" in
    html) find "$in_dir" -maxdepth 1 -type f \( -name "*.html" -o -name "*.htm" \) -print ;;
    pdf) find "$in_dir" -maxdepth 1 -type f -name "*.pdf" -print ;;
    pptx) find "$in_dir" -maxdepth 1 -type f -name "*.pptx" -print ;;
    docx) find "$in_dir" -maxdepth 1 -type f -name "*.docx" -print ;;
    xlsx) find "$in_dir" -maxdepth 1 -type f -name "*.xlsx" -print ;;
    csv) find "$in_dir" -maxdepth 1 -type f -name "*.csv" -print ;;
    tsv) find "$in_dir" -maxdepth 1 -type f -name "*.tsv" -print ;;
    txt) find "$in_dir" -maxdepth 1 -type f -name "*.txt" -print ;;
    xml) find "$in_dir" -maxdepth 1 -type f -name "*.xml" -print ;;
    yaml) find "$in_dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) -print ;;
    markdown) find "$in_dir" -maxdepth 1 -type f \( -name "*.md" -o -name "*.markdown" \) -print ;;
    zip) find "$in_dir" -maxdepth 1 -type f -name "*.zip" -print ;;
    epub) find "$in_dir" -maxdepth 1 -type f -name "*.epub" -print ;;
    *) return 0 ;;
  esac
}

SAMPLE_LIST=()
for fmt in "${FORMATS[@]}"; do
  in_dir="$META_DIR/$fmt"
  [[ -d "$in_dir" ]] || continue
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    SAMPLE_LIST+=("$fmt|$f")
  done < <(discover_metadata_samples "$fmt" | sort)
done

if [[ ${#SAMPLE_LIST[@]} -eq 0 ]]; then
  echo "No metadata sample files found under $META_DIR for: ${FORMATS[*]}"
  exit 1
fi

validation_progress_init "metadata" "${#SAMPLE_LIST[@]}"

for entry in "${SAMPLE_LIST[@]}"; do
  IFS='|' read -r fmt f <<< "$entry"
  base="$(basename "$f")"
  name="${base%.*}"
  exp_dir="$EXP_DIR/$fmt"
  out_dir="$OUT_DIR/$fmt"
  sample_out_dir="$out_dir/$name"

  out="$sample_out_dir/$name.md"
  exp="$exp_dir/$name.md"
  diff_path="$sample_out_dir/$name.diff"
  metadata_path="$sample_out_dir/metadata/$name.metadata.json"
  metadata_diff_path="$sample_out_dir/$name.metadata.diff"
  expected_metadata=""
  if expected_metadata="$(resolve_expected_metadata_fixture "$fmt" "$name")"; then
    :
  else
    expected_metadata=""
  fi

  mkdir -p "$exp_dir" "$sample_out_dir"
  validation_progress_step "$fmt/$base"

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> converting metadata/$fmt/$base"
  fi
  if ! run_markitdown_cli normal --with-metadata "$f" "$out"; then
    validation_record_failure "metadata/$fmt/$name" "$f" "$exp" "$out" "conversion failed"
    continue
  fi

  if [[ ! -f "$exp" ]]; then
    validation_record_failure "metadata/$fmt/$name" "$f" "$exp" "$out" "expected missing"
    continue
  fi

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> diff metadata/$fmt/$name"
  fi
  validation_diff_or_record "metadata/$fmt/$name" "$f" "$exp" "$out" "$diff_path" || true

  validate_metadata_sidecar "metadata/$fmt/$name" "$f" "$fmt" "$out" "$metadata_path" "$sample_out_dir" || true

  if [[ -n "$expected_metadata" ]]; then
    validate_metadata_fixture_json "metadata/$fmt/$name sidecar" "$f" "$expected_metadata" "$metadata_path" || true
  fi
done

validation_finish "ALL METADATA TESTS PASSED" "FAILED METADATA SAMPLES"
