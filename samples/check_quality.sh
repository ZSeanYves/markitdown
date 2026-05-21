#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUALITY_CHECK="$ROOT/samples/helpers/quality/check.sh"
QUALITY_LAB_ROOT="${MARKITDOWN_QUALITY_LAB:-$ROOT/markitdown-quality-lab}"

usage() {
  cat <<'EOF'
usage: bash ./samples/check_quality.sh [quality runner args]

Run the optional signal-level quality validation entrypoint.

Default behavior:
  * requires the repo-local quality-lab for the full local/external row set
  * delegates to samples/helpers/quality/check.sh

Examples:
  bash ./samples/check_quality.sh
  bash ./samples/check_quality.sh --format pdf
  bash ./samples/check_quality.sh --public-only

If the repo-local quality-lab is not present, clone it with:
  git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
EOF
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -d "$QUALITY_LAB_ROOT" ]]; then
  cat >&2 <<EOF
quality-lab not found: $QUALITY_LAB_ROOT
clone it into the repo root or set MARKITDOWN_QUALITY_LAB:
  git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
EOF
  exit 1
fi

exec bash "$QUALITY_CHECK" "$@"
