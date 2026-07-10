#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/tools/env/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./tools/env/install_audio_deps.sh [--model MODEL] [--check] [--force] [--python PATH] [--no-sudo]

Install or verify the managed audio runtime.

Options:
  --model MODEL   Managed Vosk model key. Supported: en-us-small, cn-small.
  --check         Verify the current managed state without mutating it.
  --force         Rebuild generated state such as the profile virtualenv or model install.
  --python PATH   Python executable used to create the managed virtualenv.
  --no-sudo       Refuse to escalate privileges for package-manager installs.
  -h, --help      Show this help.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

install_env_profile audio "$@"
