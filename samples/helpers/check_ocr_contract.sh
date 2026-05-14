#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "ocr_contract")"
ALLOW_MOON_RUN="${MARKITDOWN_OCR_CONTRACT_ALLOW_MOON_RUN:-0}"

if [[ "$ALLOW_MOON_RUN" == "1" ]]; then
  export MARKITDOWN_ALLOW_MOON_RUN=1
fi

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_ocr_cli
if [[ "$CLI_RUNNER_KIND" == "prebuilt-native" || "$CLI_RUNNER_KIND" == "override" ]]; then
  probe_image="$OUT_DIR/ocr_runner_probe.png"
  printf 'fake image\n' > "$probe_image"
  probe_out="$OUT_DIR/ocr_runner_probe.txt"
  set +e
  "$CLI_BIN" --provider noop "$probe_image" >"$probe_out" 2>&1
  probe_status=$?
  set -e
  if grep -Fq 'noop OCR provider does not perform recognition' "$probe_out"; then
    :
  else
    echo "[ocr-contract] skip: native CLI does not support OCR flags; run moon build --target native or enable manual moon-run fallback"
    if [[ "$ALLOW_MOON_RUN" != "1" ]]; then
      exit 0
    fi
    CLI_RUNNER_KIND="moon-run"
    CLI_RUNNER_NOTE="manual OCR contract moon-run fallback enabled via MARKITDOWN_OCR_CONTRACT_ALLOW_MOON_RUN=1"
    CLI_BIN=""
  fi
  if [[ "$probe_status" -ne 0 ]] && [[ "$ALLOW_MOON_RUN" == "1" ]] && [[ "$CLI_RUNNER_KIND" != "moon-run" ]]; then
    CLI_RUNNER_KIND="moon-run"
    CLI_RUNNER_NOTE="native OCR flag probe failed; manual moon-run fallback enabled via MARKITDOWN_OCR_CONTRACT_ALLOW_MOON_RUN=1"
    CLI_BIN=""
  fi
elif [[ "$CLI_RUNNER_KIND" == "moon-run" ]]; then
  if [[ "$ALLOW_MOON_RUN" != "1" ]]; then
    echo "[ocr-contract] skip: native CLI runner unavailable; enable MARKITDOWN_OCR_CONTRACT_ALLOW_MOON_RUN=1 for manual moon-run fallback"
    exit 0
  fi
  CLI_RUNNER_NOTE="manual OCR contract moon-run fallback enabled via MARKITDOWN_OCR_CONTRACT_ALLOW_MOON_RUN=1"
fi
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

assert_file_not_exists() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "unexpected path exists: $path"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq "$needle" "$path" || fail "expected $path to contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  if grep -Fq "$needle" "$path"; then
    fail "did not expect $path to contain: $needle"
  fi
}

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" >"$out" 2>&1
  CAPTURED_STATUS=$?
  set -e
}

run_with_fake_tesseract() {
  local out="$1"
  shift
  MARKITDOWN_OCR_PROVIDER_CMD_TESSERACT_CLI="$FAKE_TESSERACT" "$@" >"$out" 2>&1
}

FAKE_TESSERACT="$OUT_DIR/fake_tesseract.sh"
cat >"$FAKE_TESSERACT" <<EOF
#!/bin/sh
if [ "\${1-}" = "--version" ]; then
  echo 'tesseract 5.0.0'
  exit 0
fi
echo 'Fake OCR text'
EOF
chmod +x "$FAKE_TESSERACT"

FAKE_IMAGE="$OUT_DIR/page.png"
printf 'fake image\n' > "$FAKE_IMAGE"
FAKE_TEXT="$OUT_DIR/page.txt"
UNSUPPORTED_INPUT="$OUT_DIR/page.bin"
printf 'fake non-image\n' > "$UNSUPPORTED_INPUT"

TXT_INPUT="$ROOT/samples/main_process/txt/txt_plain.txt"
TXT_OUTPUT="$OUT_DIR/txt_plain.md"

echo "==> ocr unknown provider fails clearly"
run_and_capture "$OUT_DIR/unknown_provider.txt" run_markitdown_ocr_cli --provider missing-provider "$FAKE_IMAGE"
assert_contains "$OUT_DIR/unknown_provider.txt" 'error: unknown OCR provider: missing-provider'

echo "==> ocr unsupported extension fails clearly"
run_and_capture "$OUT_DIR/unsupported_input.txt" run_markitdown_ocr_cli --provider tesseract-cli "$UNSUPPORTED_INPUT"
assert_contains "$OUT_DIR/unsupported_input.txt" 'error: OCR input type is unsupported for provider mode:'
assert_contains "$OUT_DIR/unsupported_input.txt" 'supported image inputs: png/jpg/jpeg/tif/tiff/bmp/webp; PDF stays on explicit PDF OCR path'

echo "==> ocr unavailable provider stays explicit"
MARKITDOWN_OCR_PROVIDER_CMD_TESSERACT_CLI=missing-tesseract-cli-for-contract run_and_capture "$OUT_DIR/unavailable_provider.txt" run_markitdown_ocr_cli --provider tesseract-cli "$FAKE_IMAGE"
assert_contains "$OUT_DIR/unavailable_provider.txt" 'error: tesseract-cli unavailable: install Tesseract and language data, or choose another provider'

echo "==> ocr image input routes through explicit provider path"
run_with_fake_tesseract "$OUT_DIR/fake_ocr_stdout.txt" run_markitdown_ocr_cli --provider tesseract-cli "$FAKE_IMAGE" "$FAKE_TEXT"
assert_file_exists "$FAKE_TEXT"
assert_contains "$FAKE_TEXT" 'Fake OCR text'
assert_file_not_exists "$OUT_DIR/metadata/page.metadata.json"

echo "==> normal path does not auto ocr or probe providers"
resolve_markitdown_cli
MARKITDOWN_OCR_PROVIDER_CMD_TESSERACT_CLI=missing-tesseract-cli-for-contract run_markitdown_cli normal "$TXT_INPUT" "$TXT_OUTPUT"
assert_file_exists "$TXT_OUTPUT"
assert_not_contains "$TXT_OUTPUT" 'Fake OCR text'

echo "OCR CONTRACT PASSED"
