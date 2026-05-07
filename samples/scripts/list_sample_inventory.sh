#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

formats=(xlsx html zip epub docx pptx pdf csv tsv json yaml xml markdown txt)

count_files() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -maxdepth 1 -type f | wc -l | tr -d '[:space:]'
}

printf 'format\tmain_process\tmetadata\tassets\tfixtures\tbenchmark\tquality_records\tmetadata_fixtures\n'
for fmt in "${formats[@]}"; do
  main_count="$(count_files "$ROOT/samples/main_process/$fmt")"
  meta_count="$(count_files "$ROOT/samples/metadata/$fmt")"
  assets_count="$(count_files "$ROOT/samples/assets/$fmt")"
  test_count="$(count_files "$ROOT/samples/fixtures/$fmt")"
  bench_count="$(count_files "$ROOT/samples/benchmark/$fmt")"
  quality_count="$(find "$ROOT/docs/quality-comparisons" -maxdepth 1 -type f -name "${fmt}*.md" | wc -l | tr -d '[:space:]')"
  fixture_count="$(find "$ROOT/samples/fixtures/metadata" -maxdepth 1 -type f -name "${fmt}*.metadata.json" | wc -l | tr -d '[:space:]')"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$fmt" \
    "$main_count" \
    "$meta_count" \
    "$assets_count" \
    "$test_count" \
    "$bench_count" \
    "$quality_count" \
    "$fixture_count"
done
