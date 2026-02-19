#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLES_DIR="$ROOT/samples"
EXP_DIR="$SAMPLES_DIR/expected"
OUT_DIR="$ROOT/.tmp_test_out"

mkdir -p "$EXP_DIR"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

fail=0
found=0

# 只扫描 samples/ 这一层的 pdf（不递归）
while IFS= read -r pdf; do
  found=1
  name="$(basename "$pdf" .pdf)"
  out="$OUT_DIR/$name.md"
  exp="$EXP_DIR/$name.md"

  echo "==> converting $name.pdf"
  moon run "$ROOT/src/cli" -- convert "$pdf" -o "$out"

  if [[ ! -f "$exp" ]]; then
    echo "!! expected missing: $exp"
    echo "   create with: cp \"$out\" \"$exp\""
    fail=1
    continue
  fi

  echo "==> diff $name"
  if ! diff -u "$exp" "$out"; then
    echo "!! mismatch: $name"
    fail=1
  fi
done < <(find "$SAMPLES_DIR" -maxdepth 1 -type f -name '*.pdf' -print | sort)

if [[ $found -eq 0 ]]; then
  echo "No PDF files found in $SAMPLES_DIR"
  exit 1
fi

if [[ $fail -ne 0 ]]; then
  echo "TEST FAILED"
  exit 1
fi

echo "ALL TESTS PASSED"
