#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/tools/env/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./tools/env/install_bench_baseline_deps.sh [--check] [--force] [--python PATH] [--no-sudo]

Install or verify the managed benchmark baseline runtime.

Options:
  --check       Verify the current managed state without mutating it.
  --force       Rebuild generated state such as the profile virtualenv.
  --python PATH Python executable used to create the managed virtualenv.
  --no-sudo     Reserved for interface consistency; bench has no system tools.
  -h, --help    Show this help.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

install_env_profile bench "$@"
