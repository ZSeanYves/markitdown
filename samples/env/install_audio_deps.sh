#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/env/share/install_runtime_deps_common.sh"

usage() {
  cat <<'EOF'
Usage: ./samples/env/install_audio_deps.sh [--model MODEL]

Install runtime dependencies for audio transcription.

Supported models:
  en-us-small   default
  cn-small

This installs:
  - ffmpeg
  - unzip
  - repo-local Python virtualenv package: vosk
  - one local Vosk model

Python packages are installed into a repo-local virtualenv under `./env/`.
If Python with `venv` support is missing, the script installs that runtime first.
This script also records the repo-managed `ffmpeg` path under
`./env/managed-paths/`, and writes a stable env file that exports
MARKITDOWN_AUDIO_CMD and MARKITDOWN_AUDIO_MODEL_PATH.
EOF
}

MODEL_KEY="en-us-small"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      [[ $# -ge 2 ]] || die "missing value for --model"
      MODEL_KEY="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

platform_family="$(resolve_platform_family)"
system_packages=()
case "$platform_family" in
  brew)
    system_packages+=(ffmpeg unzip)
    if ! python_command_available; then
      system_packages+=(python)
    fi
    ;;
  apt)
    system_packages+=(ffmpeg unzip)
    if ! python_command_available; then
      system_packages+=(python3 python3-venv)
    elif ! python_supports_venv; then
      system_packages+=(python3-venv)
    fi
    ;;
esac
install_system_packages "$platform_family" "${system_packages[@]}"
write_managed_command_path_record ffmpeg ffmpeg

venv_pip_install_packages vosk
mark_executable "$ROOT/samples/env/audio/audio_transcribe_wrapper.py"
mark_executable "$ROOT/samples/env/share/install_audio_vosk_model.sh"

"$ROOT/samples/env/share/install_audio_vosk_model.sh" --model "$MODEL_KEY"

python_bin="$(resolve_runtime_python_bin)"
wrapper_path="$ROOT/samples/env/audio/audio_transcribe_wrapper.py"
wrapper_cmd="$(join_shell_command "$python_bin" "$wrapper_path")"
model_path="$(default_audio_model_path)"
env_path="$(generated_env_path audio.env.sh)"
write_export_env_file \
  "$env_path" \
  MARKITDOWN_RUNTIME_VENV "$(runtime_venv_path)" \
  MARKITDOWN_RUNTIME_PYTHON "$python_bin" \
  MARKITDOWN_AUDIO_CMD "$wrapper_cmd" \
  MARKITDOWN_AUDIO_MODEL_PATH "$model_path"

log_note "Audio dependencies are ready."
log_note "ffmpeg: $(command -v ffmpeg)"
log_note "Managed ffmpeg record: $(managed_command_record_path ffmpeg)"
log_note "Repo-local Python: $python_bin"
log_note "Repo-local virtualenv: $(runtime_venv_path)"
log_note "Wrapper: $wrapper_path"
log_note "Model: $model_path"
log_note "Env file written to: $env_path"
log_note "Load it in your shell with:"
print_source_hint "$env_path"
