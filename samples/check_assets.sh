#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS_DIR="$ROOT/samples/assets"
EXP_DIR="$ASSETS_DIR/expected"
OUT_DIR="$ROOT/.tmp_assets_test"

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

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

fail=0
found=0

FORMATS=("pdf" "pptx" "html")

for fmt in "${FORMATS[@]}"; do
  in_dir="$ASSETS_DIR/$fmt"
  exp_dir="$EXP_DIR/$fmt"
  out_dir="$OUT_DIR/$fmt"

  if [[ ! -d "$in_dir" ]]; then
    continue
  fi

  mkdir -p "$exp_dir"
  mkdir -p "$out_dir"

  case "$fmt" in
    pdf)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.pdf" -print)
      ;;
    pptx)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.pptx" -print)
      ;;
    html)
      cmd=(find "$in_dir" -maxdepth 1 -type f \( -name "*.html" -o -name "*.htm" \) -print)
      ;;
    *)
      continue
      ;;
  esac

  echo "==> checking ${fmt} assets"

  while IFS= read -r f; do
    found=1
    base="$(basename "$f")"
    name="${base%.*}"

    sample_out_dir="$out_dir/$name"
    rm -rf "$sample_out_dir"
    mkdir -p "$sample_out_dir"

    out_md="$sample_out_dir/$name.md"
    exp_md="$exp_dir/$name.md"

    echo "==> converting assets/$fmt/$base"
    moon run "$ROOT/cli" -- normal "$f" "$sample_out_dir"

    if [[ ! -f "$out_md" ]]; then
      echo "missing markdown output for assets/$fmt: $out_md"
      fail=1
      continue
    fi

    if [[ ! -f "$exp_md" ]]; then
      echo "!! expected missing: $exp_md"
      echo "   create with: cp \"$out_md\" \"$exp_md\""
      fail=1
      continue
    fi

    echo "==> diff assets/$fmt/$name"
    if ! diff -u "$exp_md" "$out_md"; then
      echo "!! mismatch: assets/$fmt/$name"
      fail=1
    fi

    refs="$(extract_asset_refs "$sample_out_dir")"
    if [[ -n "${refs//[$'\t\r\n ']}" ]]; then
      missing=0
      while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        if [[ ! -f "$sample_out_dir/$ref" ]]; then
          echo "missing asset for assets/$fmt/$name: $sample_out_dir/$ref"
          missing=1
        fi
      done <<< "$refs"

      if [[ $missing -ne 0 ]]; then
        fail=1
      fi
    fi
  done < <("${cmd[@]}" | sort)
done

if [[ $found -eq 0 ]]; then
  echo "No asset sample files found under $ASSETS_DIR for: ${FORMATS[*]}"
  exit 1
fi

if [[ $fail -ne 0 ]]; then
  echo "ASSET TEST FAILED"
  exit 1
fi

echo "ALL ASSET TESTS PASSED"