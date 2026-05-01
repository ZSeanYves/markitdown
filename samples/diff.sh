#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLES_DIR="$ROOT/samples/main_process"
EXP_DIR="$SAMPLES_DIR/expected"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$TMP_ROOT/samples/diff"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

"$ROOT/samples/check_samples.sh"
"$ROOT/samples/check_assets.sh"

fail=0
found=0

FORMATS=("docx" "pdf" "xlsx" "html" "pptx" "csv" "tsv" "json" "yaml" "markdown" "zip")

for fmt in "${FORMATS[@]}"; do
  in_dir="$SAMPLES_DIR/$fmt"
  exp_dir="$EXP_DIR/$fmt"
  out_dir="$OUT_DIR/$fmt"

  if [[ ! -d "$in_dir" ]]; then
    continue
  fi

  mkdir -p "$exp_dir"
  mkdir -p "$out_dir"

  case "$fmt" in
    docx)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.docx" -print)
      ;;
    pdf)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.pdf" -print)
      ;;
    xlsx)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.xlsx" -print)
      ;;
    pptx)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.pptx" -print)
      ;;
    html)
      cmd=(find "$in_dir" -maxdepth 1 -type f \( -name "*.html" -o -name "*.htm" \) -print)
      ;;
    csv)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.csv" -print)
      ;;
    tsv)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.tsv" -print)
      ;;
    json)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.json" -print)
      ;;
    yaml)
      cmd=(find "$in_dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) -print)
      ;;
    markdown)
      cmd=(find "$in_dir" -maxdepth 1 -type f \( -name "*.md" -o -name "*.markdown" \) -print)
      ;;
    zip)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.zip" -print)
      ;;
    *)
      continue
      ;;
  esac

  while IFS= read -r f; do
    found=1
    base="$(basename "$f")"
    name="${base%.*}"

    out="$out_dir/$name.md"
    exp="$exp_dir/$name.md"

    echo "==> converting main_process/$fmt/$base"
    moon run "$ROOT/cli" -- normal "$f" "$out"

    if [[ ! -f "$exp" ]]; then
      echo "!! expected missing: $exp"
      echo "   create with: cp \"$out\" \"$exp\""
      fail=1
      continue
    fi

    echo "==> diff main_process/$fmt/$name"
    if ! diff -u "$exp" "$out"; then
      echo "!! mismatch: main_process/$fmt/$name"
      fail=1
    fi
  done < <("${cmd[@]}" | sort)
done

if [[ $found -eq 0 ]]; then
  echo "No sample files found under $SAMPLES_DIR for: ${FORMATS[*]}"
  exit 1
fi

if [[ $fail -ne 0 ]]; then
  echo "TEST FAILED"
  exit 1
fi

echo "ALL TESTS PASSED"
