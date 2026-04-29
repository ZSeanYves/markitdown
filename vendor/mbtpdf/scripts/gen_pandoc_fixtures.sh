#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/testdata/pandoc"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc is required to generate fixtures" >&2
  exit 1
fi

if ! command -v tectonic >/dev/null 2>&1; then
  echo "tectonic is required (pandoc --pdf-engine=tectonic)" >&2
  exit 1
fi

mkdir -p "$FIXTURE_DIR"

pandoc "$FIXTURE_DIR/pandoc_basic.md" \
  -o "$FIXTURE_DIR/pandoc_basic.pdf" \
  --pdf-engine=tectonic

pandoc "$FIXTURE_DIR/pandoc_unicode.md" \
  -o "$FIXTURE_DIR/pandoc_unicode.pdf" \
  --pdf-engine=tectonic
