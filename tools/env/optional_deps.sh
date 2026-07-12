#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACTION="install"
PROFILE=""

usage() {
  cat <<'EOF'
Usage: tools/env/optional_deps.sh [install|check] PROFILE [OPTIONS]

Profiles:
  core      No external runtime; validates that the native core is dependency-free.
  balance   Tesseract for top-level image OCR and standalone ZIP image children.
  audio     Vosk, ffmpeg, and the local speech model.
  accurate  PaddleOCR models/runtime plus pdftoppm for optional accurate OCR/PDF.
  bench     Microsoft MarkItDown reference environment used only by benchmarks.
  all       Install or check balance, audio, accurate, and bench serially.

Options after PROFILE are passed to the managed environment installer.
EOF
}

if [[ $# -gt 0 && ( "$1" == "install" || "$1" == "check" ) ]]; then
  ACTION="$1"
  shift
fi
if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi
PROFILE="$1"
shift

run_profile() {
  local profile="$1"
  shift
  local args=(install --profile "$profile")
  if [[ "$ACTION" == "check" ]]; then
    args+=(--check)
  fi
  python3 "$ROOT/tools/env/lib/manage.py" "${args[@]}" "$@"
}

case "$PROFILE" in
  core)
    [[ "$ACTION" == "check" ]] || echo "[deps] core_native requires no optional runtime installation."
    echo "[deps] core_native boundary: ready"
    ;;
  balance|audio|accurate|bench)
    run_profile "$PROFILE" "$@"
    ;;
  all)
    for profile in balance audio accurate bench; do
      run_profile "$profile" "$@"
    done
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "unknown optional dependency profile: $PROFILE" >&2
    usage >&2
    exit 2
    ;;
esac
