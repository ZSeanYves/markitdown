#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/scripts/tmp_helpers.sh"
source "$ROOT/samples/scripts/validation_helpers.sh"
REAL_WORLD_DIR="$ROOT/samples/real_world"
MANIFEST_PATH="$REAL_WORLD_DIR/manifest.tsv"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "real_world")"
MODE="full"
PYTHON3_CHECKED=0

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

usage() {
  cat <<'EOF'
usage: ./samples/check.sh --real-world [--manifest-only]

Modes:
  --manifest-only   validate manifest header, row schema, and referenced paths
                    without running conversions

Current assets_expected policy:
  empty             no extra asset validation
  refs_exist        require emitted assets/... references to exist on disk

Notes:
  * zero-row manifests are valid and return success
  * full mode is opt-in and intended for future richer complex-scenario samples
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest-only)
      MODE="manifest-only"
      shift
      ;;
    --help|-h)
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

require_python3_once() {
  if [[ "$PYTHON3_CHECKED" -eq 1 ]]; then
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    PYTHON3_CHECKED=1
    return 0
  fi
  echo "python3 is required for real_world metadata fixture comparison" >&2
  exit 1
}

resolve_path() {
  local path="${1-}"
  if [[ "$path" == /* ]]; then
    printf '%s' "$path"
  else
    printf '%s/%s' "$ROOT" "$path"
  fi
}

trim_trailing_cr() {
  local value="${1-}"
  value="${value%$'\r'}"
  printf '%s' "$value"
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

compare_json_fixture_or_record() {
  local scope="$1"
  local input_path="$2"
  local expected_json="$3"
  local actual_json="$4"
  local detail

  require_python3_once

  set +e
  detail="$(python3 - "$expected_json" "$actual_json" <<'PY'
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
    changed = sorted(
        key for key in expected_keys | actual_keys if expected.get(key) != actual.get(key)
    )
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
    validation_record_failure "$scope" "$input_path" "$expected_json" "$actual_json" "$detail"
    return 1
  fi

  return 0
}

ENTRY_LINES=()

load_manifest() {
  local header_seen=0
  local header expected_header
  expected_header=$'id\tformat\tinput\texpected\tmetadata_expected\tassets_expected\tdescription\ttags'

  if [[ ! -f "$MANIFEST_PATH" ]]; then
    echo "real_world manifest missing: $MANIFEST_PATH" >&2
    exit 1
  fi

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    raw_line="$(trim_trailing_cr "$raw_line")"
    if [[ "$header_seen" -eq 0 ]]; then
      header_seen=1
      header="$raw_line"
      if [[ "$header" != "$expected_header" ]]; then
        echo "real_world manifest header mismatch" >&2
        echo "expected: $expected_header" >&2
        echo "actual:   $header" >&2
        exit 1
      fi
      continue
    fi

    [[ -z "$raw_line" ]] && continue
    [[ "${raw_line#\#}" != "$raw_line" ]] && continue

    local id fmt input expected metadata_expected assets_expected description tags extra
    IFS=$'\t' read -r id fmt input expected metadata_expected assets_expected description tags extra <<< "$raw_line"

    if [[ -n "${extra-}" ]]; then
      echo "real_world manifest row has too many columns: $raw_line" >&2
      exit 1
    fi

    if [[ -z "$id" || -z "$fmt" || -z "$input" || -z "$expected" ]]; then
      echo "real_world manifest row missing required fields: $raw_line" >&2
      exit 1
    fi

    local input_abs expected_abs metadata_abs
    input_abs="$(resolve_path "$input")"
    expected_abs="$(resolve_path "$expected")"

    if [[ ! -f "$input_abs" ]]; then
      echo "real_world input missing: $input" >&2
      exit 1
    fi
    if [[ ! -f "$expected_abs" ]]; then
      echo "real_world expected markdown missing: $expected" >&2
      exit 1
    fi

    if [[ -n "$metadata_expected" ]]; then
      metadata_abs="$(resolve_path "$metadata_expected")"
      if [[ ! -f "$metadata_abs" ]]; then
        echo "real_world metadata fixture missing: $metadata_expected" >&2
        exit 1
      fi
    fi

    if [[ -n "$assets_expected" && "$assets_expected" != "refs_exist" ]]; then
      echo "unsupported assets_expected policy for row $id: $assets_expected" >&2
      echo "supported values: empty, refs_exist" >&2
      exit 1
    fi

    ENTRY_LINES+=("$raw_line")
  done < "$MANIFEST_PATH"

  if [[ "$header_seen" -eq 0 ]]; then
    echo "real_world manifest is empty: $MANIFEST_PATH" >&2
    exit 1
  fi

  echo "REAL WORLD SAMPLE MANIFEST OK (${#ENTRY_LINES[@]} rows)"
}

load_manifest

if [[ "$MODE" == "manifest-only" || "${#ENTRY_LINES[@]}" -eq 0 ]]; then
  exit 0
fi

resolve_markitdown_cli
echo "runner: $CLI_RUNNER_KIND"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

validation_progress_init "real_world" "${#ENTRY_LINES[@]}"

for raw_line in "${ENTRY_LINES[@]}"; do
  id=""
  fmt=""
  input=""
  expected=""
  metadata_expected=""
  assets_expected=""
  description=""
  tags=""
  IFS=$'\t' read -r id fmt input expected metadata_expected assets_expected description tags <<< "$raw_line"

  input_abs="$(resolve_path "$input")"
  expected_abs="$(resolve_path "$expected")"
  expected_name="$(basename "$expected")"
  expected_stem="${expected_name%.md}"
  scope="real_world/$fmt/$id"
  sample_out_dir="$OUT_DIR/$fmt/$id"
  output_md="$sample_out_dir/$expected_name"
  diff_path="$sample_out_dir/$expected_stem.diff"

  mkdir -p "$sample_out_dir"
  validation_progress_step "$fmt/$id"

  if [[ -n "$metadata_expected" ]]; then
    if ! run_markitdown_cli normal --with-metadata "$input_abs" "$output_md"; then
      validation_record_failure "$scope" "$input_abs" "$expected_abs" "$output_md" "conversion failed"
      continue
    fi
  else
    if ! run_markitdown_cli normal "$input_abs" "$output_md"; then
      validation_record_failure "$scope" "$input_abs" "$expected_abs" "$output_md" "conversion failed"
      continue
    fi
  fi

  if [[ ! -f "$output_md" ]]; then
    validation_record_failure "$scope" "$input_abs" "$expected_abs" "$output_md" "missing markdown output"
    continue
  fi

  validation_diff_or_record "$scope" "$input_abs" "$expected_abs" "$output_md" "$diff_path" || true

  if [[ -n "$metadata_expected" ]]; then
    actual_metadata="$sample_out_dir/metadata/$expected_stem.metadata.json"
    expected_metadata_abs="$(resolve_path "$metadata_expected")"
    if [[ ! -f "$actual_metadata" ]]; then
      validation_record_failure "$scope" "$input_abs" "$expected_metadata_abs" "$actual_metadata" "missing metadata sidecar"
      continue
    fi
    compare_json_fixture_or_record "$scope" "$input_abs" "$expected_metadata_abs" "$actual_metadata" || true
  fi

  if [[ "$assets_expected" == "refs_exist" ]]; then
    check_asset_refs_or_record "$scope" "$sample_out_dir" || true
  fi
done

echo "output dir: $OUT_DIR"
validation_finish "ALL REAL WORLD SAMPLES PASSED" "FAILED REAL WORLD SAMPLES"
