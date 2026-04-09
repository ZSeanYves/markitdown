#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLES_DIR="$ROOT/samples/docx"
EXPECTED_DIR="$ROOT/samples/expected/docx"
OUT_DIR="$ROOT/.tmp_test_out/docx"

UPDATE_MODE=0
KEEP_OUT=0

usage() {
  cat <<'USAGE'
Usage: samples/run_docx_samples.sh [--update] [--keep-out]

Run DOCX sample regression tests only.

Options:
  --update    Auto-create/update missing expected markdown from fresh outputs.
  --keep-out  Keep .tmp_test_out/docx content (default clears before run).
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --update)
      UPDATE_MODE=1
      ;;
    --keep-out)
      KEEP_OUT=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$SAMPLES_DIR" ]]; then
  echo "DOCX samples directory not found: $SAMPLES_DIR" >&2
  exit 1
fi

mkdir -p "$EXPECTED_DIR"
if [[ $KEEP_OUT -eq 0 ]]; then
  rm -rf "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

declare -A INPUT_NAMES=()
declare -A EXPECTED_NAMES=()

while IFS= read -r f; do
  base="$(basename "$f")"
  name="${base%.docx}"
  INPUT_NAMES["$name"]=1
done < <(find "$SAMPLES_DIR" -maxdepth 1 -type f -name '*.docx' -print | sort)

while IFS= read -r f; do
  base="$(basename "$f")"
  name="${base%.md}"
  EXPECTED_NAMES["$name"]=1
done < <(find "$EXPECTED_DIR" -maxdepth 1 -type f -name '*.md' -print | sort)

if [[ ${#INPUT_NAMES[@]} -eq 0 ]]; then
  echo "No DOCX sample inputs found in $SAMPLES_DIR" >&2
  exit 1
fi

fail=0

echo "[docx] Input samples: ${#INPUT_NAMES[@]}"
echo "[docx] Expected markdown: ${#EXPECTED_NAMES[@]}"

for name in "${!INPUT_NAMES[@]}"; do
  input="$SAMPLES_DIR/$name.docx"
  out="$OUT_DIR/$name.md"
  exp="$EXPECTED_DIR/$name.md"

  echo "==> converting docx/$name.docx"
  moon run "$ROOT/src/cli" -- convert "$input" -o "$out" --max-heading 6

  if [[ ! -f "$exp" ]]; then
    if [[ $UPDATE_MODE -eq 1 ]]; then
      cp "$out" "$exp"
      echo "++ created expected: $exp"
      continue
    fi

    echo "!! expected missing: $exp"
    echo "   hint: run with --update to create it"
    fail=1
    continue
  fi

  echo "==> diff docx/$name"
  if ! diff -u "$exp" "$out"; then
    echo "!! mismatch: docx/$name"
    if [[ $UPDATE_MODE -eq 1 ]]; then
      cp "$out" "$exp"
      echo "++ updated expected: $exp"
    else
      fail=1
    fi
  fi
done

for name in "${!EXPECTED_NAMES[@]}"; do
  if [[ -z "${INPUT_NAMES[$name]:-}" ]]; then
    echo "!! expected-only case (missing input): $EXPECTED_DIR/$name.md"
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  echo "DOCX SAMPLE TEST FAILED"
  exit 1
fi

echo "DOCX SAMPLE TEST PASSED"
