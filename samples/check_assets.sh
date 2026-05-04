#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/samples/scripts/tmp_helpers.sh"
source "$ROOT/samples/scripts/validation_helpers.sh"
ASSETS_DIR="$ROOT/samples/assets"
EXP_DIR="$ASSETS_DIR/expected"
MAIN_SAMPLES_DIR="$ROOT/samples/main_process"
MAIN_EXP_DIR="$MAIN_SAMPLES_DIR/expected"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "assets")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

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

resolve_markitdown_cli
echo "runner: $CLI_RUNNER_KIND"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

SAMPLE_LIST=()

FORMATS=("pdf" "pptx" "html" "docx")
for fmt in "${FORMATS[@]}"; do
  in_dir="$ASSETS_DIR/$fmt"
  [[ -d "$in_dir" ]] || continue
  case "$fmt" in
    pdf) cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.pdf" -print) ;;
    pptx) cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.pptx" -print) ;;
    docx) cmd=(find "$in_dir" -maxdepth 1 -type f -name "*.docx" -print) ;;
    html) cmd=(find "$in_dir" -maxdepth 1 -type f \( -name "*.html" -o -name "*.htm" \) -print) ;;
    *) continue ;;
  esac
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    SAMPLE_LIST+=("assets|$fmt|$f")
  done < <("${cmd[@]}" | sort)
done

for fmt in zip epub; do
  in_dir="$MAIN_SAMPLES_DIR/$fmt"
  [[ -d "$in_dir" ]] || continue
  ext="$fmt"
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    SAMPLE_LIST+=("main_process|$fmt|$f")
  done < <(find "$in_dir" -maxdepth 1 -type f -name "*.${ext}" -print | sort)
done

if [[ ${#SAMPLE_LIST[@]} -eq 0 ]]; then
  echo "No asset sample files found under $ASSETS_DIR"
  exit 1
fi

validation_progress_init "assets" "${#SAMPLE_LIST[@]}"

for entry in "${SAMPLE_LIST[@]}"; do
  IFS='|' read -r family fmt f <<< "$entry"
  base="$(basename "$f")"
  name="${base%.*}"

  if [[ "$family" == "assets" ]]; then
    exp_md="$EXP_DIR/$fmt/$name.md"
    sample_out_dir="$OUT_DIR/$fmt/$name"
    scope="assets/$fmt/$name"
    out_md="$sample_out_dir/$name.md"
  else
    exp_md="$MAIN_EXP_DIR/$fmt/$name.md"
    sample_out_dir="$OUT_DIR/$fmt-$name"
    scope="main_process/$fmt/$name"
    out_md="$sample_out_dir/$name.md"
  fi

  mkdir -p "$sample_out_dir"
  validation_progress_step "$fmt/$base"

  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> converting $scope"
  fi
  if [[ "$family" == "assets" ]]; then
    if ! run_markitdown_cli normal "$f" "$sample_out_dir"; then
      validation_record_failure "$scope" "$f" "$exp_md" "$out_md" "conversion failed"
      continue
    fi
  else
    if ! run_markitdown_cli normal "$f" "$out_md"; then
      validation_record_failure "$scope" "$f" "$exp_md" "$out_md" "conversion failed"
      continue
    fi
  fi

  if [[ ! -f "$out_md" ]]; then
    validation_record_failure "$scope" "$f" "$exp_md" "$out_md" "missing markdown output"
    continue
  fi

  if [[ ! -f "$exp_md" ]]; then
    validation_record_failure "$scope" "$f" "$exp_md" "$out_md" "expected missing"
    continue
  fi

  diff_path="$sample_out_dir/$name.diff"
  if validation_bool_enabled "$SAMPLES_VERBOSE"; then
    echo "==> diff $scope"
  fi
  validation_diff_or_record "$scope" "$f" "$exp_md" "$out_md" "$diff_path" || true
  check_asset_refs_or_record "$scope" "$sample_out_dir" || true
done

validation_finish "ALL ASSET TESTS PASSED" "FAILED ASSET SAMPLES"
