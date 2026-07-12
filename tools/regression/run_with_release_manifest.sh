#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT=""
declare -a ARTIFACTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT="${2:?--output requires a path}"
      shift 2
      ;;
    --artifact)
      ARTIFACTS+=("${2:?--artifact requires a path}")
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "unknown wrapper argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$OUTPUT" || $# -eq 0 ]]; then
  echo "usage: run_with_release_manifest.sh --output PATH [--artifact PATH] -- COMMAND [ARG...]" >&2
  exit 2
fi

STARTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf -v COMMAND_TEXT '%q ' "$@"
COMMAND_TEXT="${COMMAND_TEXT% }"
set +e
"$@"
COMMAND_STATUS=$?
set -e
FINISHED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

MANIFEST_ARGS=(
  --root "$ROOT"
  --output "$OUTPUT"
  --command "$COMMAND_TEXT"
  --status "$([[ $COMMAND_STATUS -eq 0 ]] && printf pass || printf fail)"
  --exit-code "$COMMAND_STATUS"
  --started-at "$STARTED_AT"
  --finished-at "$FINISHED_AT"
)
if [[ $COMMAND_STATUS -eq 0 ]]; then
  for artifact in "${ARTIFACTS[@]}"; do
    MANIFEST_ARGS+=(--artifact "$artifact")
  done
fi

python3 "$ROOT/tools/regression/lib/shared/release_manifest.py" "${MANIFEST_ARGS[@]}"
MANIFEST_STATUS=$?
if [[ $COMMAND_STATUS -ne 0 ]]; then
  exit "$COMMAND_STATUS"
fi
exit "$MANIFEST_STATUS"
