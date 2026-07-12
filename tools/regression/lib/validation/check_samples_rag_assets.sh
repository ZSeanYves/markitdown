#!/usr/bin/env bash

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

assets_dirs_equal() {
  local expected_dir="$1"
  local actual_dir="$2"
  python3 - "$expected_dir" "$actual_dir" <<'PY'
import filecmp
import sys
from pathlib import Path

expected = Path(sys.argv[1])
actual = Path(sys.argv[2])

def walk(root: Path):
    if not root.exists():
        return {}
    out = {}
    for path in sorted(root.rglob("*")):
        if path.is_file():
            out[path.relative_to(root).as_posix()] = path.read_bytes()
    return out

left = walk(expected)
right = walk(actual)
if left.keys() != right.keys():
    print("asset file set mismatch")
    sys.exit(1)
for key in left:
    if left[key] != right[key]:
        print(f"asset bytes mismatch: {key}")
        sys.exit(1)
print("ok")
PY
}

validate_rag_fixture() {
  local actual_json="$1"
  local expected_json="$2"
  local scope="$3"
  python3 - "$actual_json" "$expected_json" "$scope" <<'PY'
import json
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(message)
    sys.exit(1)


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"json parse failed for {path}: {exc}")


def ensure(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def json_obj(value, label: str):
    ensure(isinstance(value, dict), f"{label} must be an object")
    return value


def json_arr(value, label: str):
    ensure(isinstance(value, list), f"{label} must be an array")
    return value


def expect_equal(actual, expected, label: str) -> None:
    ensure(actual == expected, f"{label} mismatch: expected {expected!r}, got {actual!r}")


def list_contains_expected_item(actual_items, expected_item, label: str) -> bool:
    if expected_item in actual_items:
        return True
    if label.endswith(".container_paths") and isinstance(expected_item, str):
        for actual_item in actual_items:
            if isinstance(actual_item, str) and actual_item.endswith(expected_item):
                return True
    return False


def expect_subset(actual, expected, label: str) -> None:
    if isinstance(expected, dict):
        actual = json_obj(actual, label)
        for key, value in expected.items():
            ensure(key in actual, f"{label} missing key: {key}")
            expect_subset(actual[key], value, f"{label}.{key}")
        return
    if isinstance(expected, list):
        ensure(isinstance(actual, list), f"{label} must be an array")
        for item in expected:
            ensure(
                list_contains_expected_item(actual, item, label),
                f"{label} missing item: {item!r}",
            )
        return
    expect_equal(actual, expected, label)


def expect_contains_map(actual_map, expected_map, label: str) -> None:
    actual_map = json_obj(actual_map, label)
    expected_map = json_obj(expected_map, f"{label} spec")
    expect_subset(actual_map, expected_map, label)


def expect_source_map(actual, policy: str) -> None:
    ensure(policy in {"required", "optional", "null"}, f"unsupported source_map policy: {policy}")
    if policy == "required":
      ensure(actual is not None, "source_map must be present")
    elif policy == "null":
      ensure(actual is None, "source_map must be null")


def expect_chunk_count(chunks, spec):
    spec = json_obj(spec, "chunk_count")
    if "exact" in spec:
        expect_equal(len(chunks), spec["exact"], "chunk_count.exact")
    if "min" in spec:
        ensure(len(chunks) >= spec["min"], f"chunk_count.min mismatch: expected >= {spec['min']}, got {len(chunks)}")


def expect_chunk(chunk, spec, index: int) -> None:
    label = f"chunks[{index}]"
    spec = json_obj(spec, label)
    if "kind" in spec:
        expect_equal(chunk.get("kind"), spec["kind"], f"{label}.kind")
    if "heading_path" in spec:
        expect_equal(chunk.get("heading_path"), spec["heading_path"], f"{label}.heading_path")
    text = chunk.get("text", "")
    ensure(isinstance(text, str), f"{label}.text must be a string")
    for item in spec.get("text_contains_all", []):
        ensure(item in text, f"{label}.text missing fragment: {item!r}")
    for item in spec.get("text_not_contains", []):
        ensure(item not in text, f"{label}.text unexpectedly contains fragment: {item!r}")
    if "source_ref_count" in spec:
        source_refs = json_arr(chunk.get("source_refs"), f"{label}.source_refs")
        expect_equal(len(source_refs), spec["source_ref_count"], f"{label}.source_ref_count")
    if "asset_ref_count" in spec:
        asset_refs = json_arr(chunk.get("asset_refs"), f"{label}.asset_refs")
        expect_equal(len(asset_refs), spec["asset_ref_count"], f"{label}.asset_ref_count")
    if "location_contains" in spec:
        metadata = json_obj(chunk.get("metadata"), f"{label}.metadata")
        ensure("location" in metadata, f"{label}.metadata missing key: location")
        expect_contains_map(metadata["location"], spec["location_contains"], f"{label}.metadata.location")


def main() -> None:
    if len(sys.argv) != 4:
        fail("usage: check_rag_fixture.py <actual.json> <expected.rag.json> <scope>")

    actual_path = Path(sys.argv[1])
    expected_path = Path(sys.argv[2])
    _scope = sys.argv[3]

    actual = load_json(actual_path)
    expected = load_json(expected_path)

    actual = json_obj(actual, "actual")
    expected = json_obj(expected, "expected")

    for key in ["output_format", "detected_format", "parser_mode", "convert_mode"]:
        if key in expected:
            expect_equal(actual.get(key), expected[key], key)

    if "metadata_contains" in expected:
        expect_contains_map(actual.get("metadata"), expected["metadata_contains"], "metadata")

    if "diagnostics_contains" in expected:
        expect_contains_map(actual.get("diagnostics"), expected["diagnostics_contains"], "diagnostics")

    if "source_map" in expected:
        expect_source_map(actual.get("source_map"), expected["source_map"])

    chunks = json_arr(actual.get("chunks"), "chunks")
    if "chunk_count" in expected:
        expect_chunk_count(chunks, expected["chunk_count"])

    expected_chunks = json_arr(expected.get("chunks", []), "expected.chunks")
    ensure(len(chunks) >= len(expected_chunks), f"chunks length mismatch: expected at least {len(expected_chunks)}, got {len(chunks)}")
    for index, chunk_spec in enumerate(expected_chunks):
        expect_chunk(json_obj(chunks[index], f"chunks[{index}]"), chunk_spec, index)

    print("ok")


if __name__ == "__main__":
    main()
PY
}
