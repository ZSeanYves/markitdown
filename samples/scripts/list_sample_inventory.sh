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
  find "$dir" -maxdepth 1 -type f ! -name '.*' | wc -l | tr -d '[:space:]'
}

count_main_process_samples() {
  local fmt="$1"
  local dir="$ROOT/samples/main_process/$fmt"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -type f \
    ! -name '.*' \
    ! -path '*/expected' \
    ! -path '*/expected/*' \
    ! -path '*/img/*' \
    ! -name '*.jpg' \
    ! -name '*.jpeg' \
    ! -name '*.png' \
    ! -name '*.gif' \
    ! -name '*.webp' \
    ! -name '*.bmp' \
    ! -name '*.svg' \
    ! -name '*.key' \
    | wc -l | tr -d '[:space:]'
}

printf 'format\tmain_process\tmetadata_cases\tasset_cases\tfixtures\tbenchmark\treal_world\tquality_records\tmetadata_expected\n'
for fmt in "${formats[@]}"; do
  main_count="$(count_main_process_samples "$fmt")"
  meta_count="$(count_files "$ROOT/samples/main_process/$fmt/metadata")"
  assets_count="$(count_files "$ROOT/samples/main_process/$fmt/assets")"
  fixture_count="$(count_files "$ROOT/samples/fixtures/$fmt")"
  bench_count="$(count_files "$ROOT/samples/benchmark/$fmt")"
  real_world_count="$(count_files "$ROOT/samples/real_world/input/$fmt")"
  quality_count="$(find "$ROOT/docs/quality-comparisons" -maxdepth 1 -type f -name "${fmt}*.md" | wc -l | tr -d '[:space:]')"
  metadata_expected_count="$(find "$ROOT/samples/main_process/$fmt/expected" -type f -name '*.metadata.json' 2>/dev/null | wc -l | tr -d '[:space:]')"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$fmt" \
    "$main_count" \
    "$meta_count" \
    "$assets_count" \
    "$fixture_count" \
    "$bench_count" \
    "$real_world_count" \
    "$quality_count" \
    "$metadata_expected_count"
done
