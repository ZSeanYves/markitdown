#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

while IFS='=' read -r name _; do
  if [[ "$name" == MARKITDOWN_* ]]; then
    unset "$name"
  fi
done < <(env)

rm -rf env

echo "[deps] removed repo-managed optional runtime state: $ROOT/env"
for command_name in ffmpeg tesseract pdftoppm markitdown; do
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '[deps] ambient %s=%s\n' "$command_name" "$(command -v "$command_name")"
  else
    printf '[deps] ambient %s=<missing>\n' "$command_name"
  fi
done
