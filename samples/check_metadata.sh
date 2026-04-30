#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
META_DIR="$ROOT/samples/metadata"
EXP_DIR="$META_DIR/expected"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$TMP_ROOT/samples/metadata"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

fail=0
found=0

FORMATS=("image" "html" "pdf" "pptx" "docx" "yaml" "markdown")

for fmt in "${FORMATS[@]}"; do
  in_dir="$META_DIR/$fmt"
  exp_dir="$EXP_DIR/$fmt"
  out_dir="$OUT_DIR/$fmt"

  if [[ ! -d "$in_dir" ]]; then
    continue
  fi

  mkdir -p "$exp_dir"
  mkdir -p "$out_dir"

  case "$fmt" in
    image|html)
      cmd=(find "$in_dir" -maxdepth 1 -type f \( -name "*.html" -o -name "*.htm" \) -print)
      ;;
    pdf)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.pdf" -print)
      ;;
    pptx)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.pptx" -print)
      ;;
    docx)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.docx" -print)
      ;;
    yaml)
      cmd=(find "$in_dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) -print)
      ;;
    markdown)
      cmd=(find "$in_dir" -maxdepth 1 -type f \( -name "*.md" -o -name "*.markdown" \) -print)
      ;;
    *)
      continue
      ;;
  esac

  while IFS= read -r f; do
    found=1
    base="$(basename "$f")"
    name="${base%.*}"

    sample_out_dir="$out_dir"
    if [[ "$fmt" == "docx" || "$fmt" == "pptx" ]]; then
      sample_out_dir="$out_dir/$name"
      rm -rf "$sample_out_dir"
      mkdir -p "$sample_out_dir"
    fi

    out="$sample_out_dir/$name.md"
    exp="$exp_dir/$name.md"

    echo "==> converting metadata/$fmt/$base"
    moon run "$ROOT/cli" -- normal "$f" "$out"

    if [[ ! -f "$exp" ]]; then
      echo "!! expected missing: $exp"
      echo "   create with: cp \"$out\" \"$exp\""
      fail=1
      continue
    fi

    echo "==> diff metadata/$fmt/$name"
    if ! diff -u "$exp" "$out"; then
      echo "!! mismatch: metadata/$fmt/$name"
      fail=1
    fi
  done < <("${cmd[@]}" | sort)
done

if [[ $found -eq 0 ]]; then
  echo "No metadata sample files found under $META_DIR for: ${FORMATS[*]}"
  exit 1
fi

if [[ $fail -ne 0 ]]; then
  echo "METADATA TEST FAILED"
  exit 1
fi

echo "ALL METADATA TESTS PASSED"
