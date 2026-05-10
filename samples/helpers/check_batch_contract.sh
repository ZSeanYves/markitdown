#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "batch_contract")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_cli
echo "runner: $CLI_RUNNER_KIND"
echo "runner_class: $(runner_class_for_kind "$CLI_RUNNER_KIND")"
echo "runner_command: $(markitdown_runner_command_prefix)"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

fail() {
  echo "[fail] $1" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file missing: $path"
}

assert_dir_exists() {
  local path="$1"
  [[ -d "$path" ]] || fail "expected directory missing: $path"
}

assert_file_not_exists() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "unexpected path exists: $path"
}

INPUT_DIR="$OUT_DIR/input"
NO_META_OUT="$OUT_DIR/no_meta"
WITH_META_OUT="$OUT_DIR/with_meta"
mkdir -p "$INPUT_DIR/nested"

printf 'alpha\n' > "$INPUT_DIR/a.txt"
printf '# beta\n' > "$INPUT_DIR/b.md"
cp "$ROOT/samples/main_process/docx/metadata/docx_image_alt_title_basic.docx" "$INPUT_DIR/c.docx"
printf 'ignored\n' > "$INPUT_DIR/nested/ignored.txt"
printf 'bad\n' > "$INPUT_DIR/d.bin"

echo "==> batch without metadata"
set +e
run_markitdown_cli batch "$INPUT_DIR" "$NO_META_OUT"
status=$?
set -e
if [[ "$status" -ne 1 ]]; then
  fail "expected batch without metadata to exit 1 because unsupported inputs are recorded; got $status"
fi
assert_file_exists "$NO_META_OUT/002-a/a.md"
assert_file_exists "$NO_META_OUT/001-b/b.md"
assert_file_exists "$NO_META_OUT/004-c/c.md"
assert_dir_exists "$NO_META_OUT/004-c/assets"
assert_file_exists "$NO_META_OUT/batch-summary.tsv"
assert_file_not_exists "$NO_META_OUT/002-a/metadata/a.metadata.json"
assert_file_not_exists "$NO_META_OUT/001-b/metadata/b.metadata.json"
assert_file_not_exists "$NO_META_OUT/004-c/metadata/c.metadata.json"
grep -q $'\tskipped_directory\t' "$NO_META_OUT/batch-summary.tsv" || fail "batch summary missing skipped_directory row"
grep -q $'\tunsupported\t' "$NO_META_OUT/batch-summary.tsv" || fail "batch summary missing unsupported row"

echo "==> batch with metadata"
set +e
run_markitdown_cli batch --with-metadata "$INPUT_DIR" "$WITH_META_OUT"
status=$?
set -e
if [[ "$status" -ne 1 ]]; then
  fail "expected batch with metadata to exit 1 because unsupported inputs are recorded; got $status"
fi
assert_file_exists "$WITH_META_OUT/002-a/a.md"
assert_file_exists "$WITH_META_OUT/001-b/b.md"
assert_file_exists "$WITH_META_OUT/004-c/c.md"
assert_file_exists "$WITH_META_OUT/002-a/metadata/a.metadata.json"
assert_file_exists "$WITH_META_OUT/001-b/metadata/b.metadata.json"
assert_file_exists "$WITH_META_OUT/004-c/metadata/c.metadata.json"
assert_dir_exists "$WITH_META_OUT/004-c/assets"
assert_file_exists "$WITH_META_OUT/batch-summary.tsv"

echo "BATCH CONTRACT PASSED"
