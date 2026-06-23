#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
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

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" >"$out" 2>&1
  CAPTURED_STATUS=$?
  set -e
}

INPUT_DIR="$OUT_DIR/input"
mkdir -p "$INPUT_DIR/nested"

printf 'alpha\n' > "$INPUT_DIR/a.txt"
printf '# beta\n' > "$INPUT_DIR/b.md"
cp "$ROOT/samples/main_process/docx/metadata/docx_image_alt_title_basic.docx" "$INPUT_DIR/c.docx"
printf 'ignored\n' > "$INPUT_DIR/nested/ignored.txt"
printf 'bad\n' > "$INPUT_DIR/d.bin"

echo "==> batch subcommand is not exposed through the current main cli"
run_and_capture "$OUT_DIR/batch.txt" run_markitdown_cli batch "$INPUT_DIR" "$OUT_DIR/out"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "batch should fail closed through main cli"
assert_contains "$OUT_DIR/batch.txt" 'unsupported subcommand: batch is not migrated to the current main CLI yet'

echo "==> batch metadata flags also stay fail-closed"
run_and_capture "$OUT_DIR/batch_meta.txt" run_markitdown_cli batch --with-metadata "$INPUT_DIR" "$OUT_DIR/out-meta"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "batch --with-metadata should fail closed through main cli"
assert_contains "$OUT_DIR/batch_meta.txt" 'unsupported subcommand: batch is not migrated to the current main CLI yet'

echo "BATCH CONTRACT PASSED"
