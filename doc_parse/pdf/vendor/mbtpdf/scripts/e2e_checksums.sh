#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
checksum_file="$root_dir/testdata/e2e_checksums.txt"

cd "$root_dir"

fixtures=(
  "testdata/e2e/merge_dummy.pdf"
  "testdata/e2e/pdfjs_tracemonkey.pdf"
  "testdata/pdfjs_identity_tounicode.pdf"
  "testdata/SFAA_Japanese.pdf"
)

case "${1:-}" in
  --check)
    shasum -a 256 -c "$checksum_file"
    ;;
  "")
    for f in "${fixtures[@]}"; do
      if [[ ! -f "$f" ]]; then
        echo "missing fixture: $f" >&2
        exit 1
      fi
    done
    : > "$checksum_file"
    for f in "${fixtures[@]}"; do
      shasum -a 256 "$f" >> "$checksum_file"
    done
    ;;
  *)
    echo "usage: $(basename "$0") [--check]" >&2
    exit 2
    ;;
esac
