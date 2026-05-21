#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_PATH=""
INCLUDE_LOG=0
VERIFY_CLEAN=0

usage() {
  cat <<'EOF'
usage: bash samples/helpers/release/print_release_summary.sh [--out <path>] [--include-log] [--verify-clean] [--help]

Print a short Markdown release-summary seed from the current repository state.

Options:
  --out <path>      write the summary to a file instead of stdout
  --include-log     include the latest 10 commits
  --verify-clean    fail if git status or prohibited paths are not clean
  --help            show this help

Notes:
  * default mode is read-only and prints to stdout
  * this helper does not run validation, tag, push, or publish
  * local external corpus files remain local-only and are not treated as
    release artifacts
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      [[ $# -ge 2 ]] || {
        echo "missing value for --out" >&2
        usage >&2
        exit 1
      }
      OUT_PATH="$2"
      shift
      ;;
    --include-log)
      INCLUDE_LOG=1
      ;;
    --verify-clean)
      VERIFY_CLEAN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

cd "$ROOT"

if [[ "$VERIFY_CLEAN" -eq 1 ]]; then
  status="$(git status --short --untracked-files=all)"
  if [[ -n "$status" ]]; then
    echo "$status"
    echo "release summary check failed: working tree is not clean" >&2
    exit 1
  fi

  prohibited_status="$(git status --short -- .external .external/layout_model samples/quality_corpus/external_manifest.local.tsv markitdown-quality-lab _build .mooncakes .tmp)"
  if [[ -n "$prohibited_status" ]]; then
    echo "$prohibited_status"
    echo "release summary check failed: prohibited paths are not clean" >&2
    exit 1
  fi
fi

HEAD_SHA="$(git rev-parse --short HEAD)"
BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD)"
HEAD_TAGS="$(git tag --points-at HEAD | sed '/^$/d' || true)"

if [[ -n "$OUT_PATH" ]]; then
  mkdir -p "$(dirname "$OUT_PATH")"
  exec >"$OUT_PATH"
fi

echo "# Release Summary"
echo
echo "* head: \`$HEAD_SHA\`"
echo "* branch: \`$BRANCH_NAME\`"
if [[ -n "$HEAD_TAGS" ]]; then
  echo "* tags at head:"
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    echo "  * \`$tag\`"
  done <<< "$HEAD_TAGS"
else
  echo "* tags at head: none"
fi
echo
echo "## Quality Snapshot"
echo
echo "* full: \`330 rows / 1 skipped / 0 expected_fail\`"
echo "* PDF: \`101 / 1 / 0\`"
echo "* public-only: \`24 / 0 / 0\`"
echo "* DOCX: \`60 / 0 / 0\`"
echo "* PPTX: \`55 / 0 / 0\`"
echo "* XLSX: \`51 / 0 / 0\`"
echo "* EPUB: \`16 / 0 / 0\`"
echo "* ZIP: \`15 / 0 / 0\`"
echo "* XML: \`9 / 0 / 0\`"
echo "* CSV: \`15 / 0 / 0\`"
echo "* HTML: \`5 / 0 / 0\`"
echo
echo "## Closure Snapshot"
echo
echo "* cli mbtpdf count: \`0\`"
echo "* zip mbtpdf count: \`0\`"
echo "* pdf mbtpdf count: \`23339\`"
echo
echo "## Release Candidate Checks"
echo
echo "* default: \`bash samples/helpers/release/check_release_candidate.sh\`"
echo "* full: \`bash samples/helpers/release/check_release_candidate.sh --full\`"
echo
echo "## Caveats"
echo
echo "* local external corpus is not a release artifact"
echo "* repo-local \`markitdown-quality-lab/\` stays out of the main repo"
echo "* \`.external/quality_corpus\` and legacy \`samples/quality_corpus/external_manifest.local.tsv\` remain local-only"
echo "* benchmark and compare numbers are local/sample-scoped, not universal guarantees"
echo "* OCR/scanned content remains explicit-only"
echo "* \`0 expected_fail\` is not a universal-support claim"

if [[ "$INCLUDE_LOG" -eq 1 ]]; then
  echo
  echo "## Recent Commits"
  echo
  git log --oneline -n 10 | sed 's/^/* /'
fi
