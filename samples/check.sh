#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLE_IMPL="$ROOT/samples/helpers/validation/check_samples_impl.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
CLI_TMP_ROOT="${MARKITDOWN_CLI_TMP_DIR:-$TMP_ROOT/workspace}"

ONLY_MODE=""
FORMAT_FILTER=""

usage() {
  cat <<'EOF'
Usage: ./samples/check.sh [--markdown-only | --metadata-only | --assets-only] [--format FMT]

Runs repo-local samples/main_process regression checks.

Options:
  --markdown-only     Run only Markdown expected-output checks.
  --metadata-only     Run only metadata sidecar checks.
  --assets-only       Run only asset-reference checks.
  --format FMT        Restrict checks to one format, for example yaml.
  -h, --help          Show this help.

Default:
  Run markdown, metadata, and assets checks for all formats.
EOF
}

fail_usage() {
  echo "$1" >&2
  usage >&2
  exit 1
}

set_only_mode() {
  local mode="$1"
  if [[ -n "$ONLY_MODE" ]]; then
    fail_usage "choose at most one of --markdown-only, --metadata-only, --assets-only"
  fi
  ONLY_MODE="$mode"
}

deprecated_arg() {
  fail_usage "$1 is deprecated; supported options are --markdown-only, --metadata-only, --assets-only, and --format FMT"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown-only)
      set_only_mode "markdown-only"
      ;;
    --metadata-only)
      set_only_mode "metadata-only"
      ;;
    --assets-only)
      set_only_mode "assets-only"
      ;;
    --format)
      shift
      if [[ $# -eq 0 || "${1:-}" == --* ]]; then
        fail_usage "--format requires a value"
      fi
      FORMAT_FILTER="$1"
      ;;
    --full|--main-process|--contracts-only|--manifest-only)
      deprecated_arg "$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail_usage "unknown argument: $1"
      ;;
  esac
  shift
done

run_impl() {
  local mode="$1"
  local args=("--$mode")
  if [[ -n "$FORMAT_FILTER" ]]; then
    args+=(--format "$FORMAT_FILTER")
  fi
  env MARKITDOWN_CLI_TMP_DIR="$CLI_TMP_ROOT" "$SAMPLE_IMPL" "${args[@]}"
}

if [[ -n "$ONLY_MODE" ]]; then
  run_impl "$ONLY_MODE"
  exit 0
fi

run_impl "markdown-only"
run_impl "metadata-only"
run_impl "assets-only"
