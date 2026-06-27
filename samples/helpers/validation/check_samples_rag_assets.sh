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
  python3 "$RAG_CHECKER" "$actual_json" "$expected_json" "$scope"
}
