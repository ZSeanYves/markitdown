#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/samples/tmp_helpers.sh"
ASSETS_DIR="$ROOT/samples/assets"
EXP_DIR="$ASSETS_DIR/expected"
MAIN_SAMPLES_DIR="$ROOT/samples/main_process"
MAIN_EXP_DIR="$MAIN_SAMPLES_DIR/expected"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "assets")"

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

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

fail=0
found=0

FORMATS=("pdf" "pptx" "html" "docx")

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
    docx)
      cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.docx" -print)
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

zip_dir="$MAIN_SAMPLES_DIR/zip"
zip_exp_dir="$MAIN_EXP_DIR/zip"

if [[ -d "$zip_dir" ]]; then
  while IFS= read -r zip_sample; do
    [[ -z "$zip_sample" ]] && continue
    found=1

    base="$(basename "$zip_sample")"
    name="${base%.*}"
    zip_out_dir="$OUT_DIR/zip-$name"
    zip_out_md="$zip_out_dir/$name.md"
    zip_expected="$zip_exp_dir/$name.md"

    mkdir -p "$zip_out_dir"

    echo "==> checking zip assets"
    echo "==> converting main_process/zip/$base"
    moon run "$ROOT/cli" -- normal "$zip_sample" "$zip_out_md"

    if [[ ! -f "$zip_out_md" ]]; then
      echo "missing markdown output for zip asset sample: $zip_out_md"
      fail=1
      continue
    fi

    if [[ ! -f "$zip_expected" ]]; then
      echo "!! expected missing: $zip_expected"
      echo "   create with: cp \"$zip_out_md\" \"$zip_expected\""
      fail=1
      continue
    fi

    echo "==> diff main_process/zip/$name"
    if ! diff -u "$zip_expected" "$zip_out_md"; then
      echo "!! mismatch: main_process/zip/$name"
      fail=1
    fi

    refs="$(extract_asset_refs "$zip_out_dir")"
    if [[ -n "${refs//[$'\t\r\n ']}" ]]; then
      missing=0
      while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        if [[ ! -f "$zip_out_dir/$ref" ]]; then
          echo "missing asset for main_process/zip/$name: $zip_out_dir/$ref"
          missing=1
        fi
      done <<< "$refs"

      if [[ $missing -ne 0 ]]; then
        fail=1
      fi
    fi
  done < <(find "$zip_dir" -maxdepth 1 -type f -name "*.zip" -print | sort)
fi

epub_dir="$MAIN_SAMPLES_DIR/epub"
epub_exp_dir="$MAIN_EXP_DIR/epub"

if [[ -d "$epub_dir" ]]; then
  while IFS= read -r epub_sample; do
    [[ -z "$epub_sample" ]] && continue
    found=1

    base="$(basename "$epub_sample")"
    name="${base%.*}"
    epub_out_dir="$OUT_DIR/epub-$name"
    epub_out_md="$epub_out_dir/$name.md"
    epub_expected="$epub_exp_dir/$name.md"

    mkdir -p "$epub_out_dir"

    echo "==> checking epub assets"
    echo "==> converting main_process/epub/$base"
    moon run "$ROOT/cli" -- normal "$epub_sample" "$epub_out_md"

    if [[ ! -f "$epub_out_md" ]]; then
      echo "missing markdown output for epub asset sample: $epub_out_md"
      fail=1
      continue
    fi

    if [[ ! -f "$epub_expected" ]]; then
      echo "!! expected missing: $epub_expected"
      echo "   create with: cp \"$epub_out_md\" \"$epub_expected\""
      fail=1
      continue
    fi

    echo "==> diff main_process/epub/$name"
    if ! diff -u "$epub_expected" "$epub_out_md"; then
      echo "!! mismatch: main_process/epub/$name"
      fail=1
    fi

    refs="$(extract_asset_refs "$epub_out_dir")"
    if [[ -n "${refs//[$'\t\r\n ']}" ]]; then
      missing=0
      while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        if [[ ! -f "$epub_out_dir/$ref" ]]; then
          echo "missing asset for main_process/epub/$name: $epub_out_dir/$ref"
          missing=1
        fi
      done <<< "$refs"

      if [[ $missing -ne 0 ]]; then
        fail=1
      fi
    fi
  done < <(find "$epub_dir" -maxdepth 1 -type f -name "*.epub" -print | sort)
fi

if [[ $found -eq 0 ]]; then
  echo "No asset sample files found under $ASSETS_DIR for: ${FORMATS[*]}"
  exit 1
fi

if [[ $fail -ne 0 ]]; then
  echo "ASSET TEST FAILED"
  exit 1
fi

echo "ALL ASSET TESTS PASSED"
