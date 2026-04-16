#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> metadata integrity check"
echo "==> repo root: $ROOT"

echo "==> [1/3] generate required binary samples"
"$ROOT/samples/check_samples.sh"

echo "==> [2/3] run origin metadata tests"
moon test "$ROOT/convert/convert/test" --filter "origin_metadata/"

echo "==> [3/3] run image context tests"
moon test "$ROOT/convert/convert/test" --filter "image_context/"

echo "metadata integrity check passed"
