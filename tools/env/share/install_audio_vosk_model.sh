#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/tools/env/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./tools/env/share/install_audio_vosk_model.sh [--model MODEL] [--check] [--force]

Install or verify one managed Vosk model in the repo-local env state.

Options:
  --model MODEL  Managed model key. Supported: en-us-small, cn-small.
  --check        Verify the current managed state without mutating it.
  --force        Reinstall the model even if a matching install already exists.
  -h, --help     Show this help.
EOF
}

MODEL_KEY="en-us-small"
declare -a PASSTHROUGH=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      [[ $# -ge 2 ]] || env_die "missing value for --model"
      MODEL_KEY="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      PASSTHROUGH+=("$1")
      shift
      ;;
  esac
done

sync_env_model --key "$MODEL_KEY" "${PASSTHROUGH[@]}"
