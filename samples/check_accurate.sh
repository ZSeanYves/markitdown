                  #!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUALITY_CHECK="$ROOT/samples/helpers/quality/check.sh"
QUALITY_LAB_ROOT="${MARKITDOWN_QUALITY_LAB:-$ROOT/markitdown-quality-lab}"
ACCURATE_CORPUS_ROOT="$QUALITY_LAB_ROOT/external_accurate"
ACCURATE_MANIFEST_PATH="$ACCURATE_CORPUS_ROOT/MANIFEST.tsv"
ACCURATE_TMP_ROOT="${QUALITY_TMP_ROOT:-$ROOT/.tmp/accurate}"
DEFAULT_SMOKE_IMAGE_REL="ocr/self_synthetic/samples/layout/ocr_layout_self_heading_paragraph_0001.png"
ACCURATE_TESSERACT_CMD="${MARKITDOWN_ACCURATE_TESSERACT_CMD:-tesseract}"
ACCURATE_PDFTOPPM_CMD="${MARKITDOWN_ACCURATE_PDFTOPPM_CMD:-pdftoppm}"
declare -a ORIGINAL_ARGS=()
if [[ $# -gt 0 ]]; then
  ORIGINAL_ARGS=("$@")
fi

source "$ROOT/samples/helpers/shared/cli_runner.sh"
source "$ROOT/samples/helpers/shared/external_signal_suite.sh"

require_command() {
  local cmd="$1"
  if [[ "$cmd" == */* ]]; then
    if [[ ! -x "$cmd" ]]; then
      echo "missing runtime dependency: $cmd" >&2
      return 1
    fi
    return 0
  fi
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing runtime dependency: $cmd" >&2
    return 1
  fi
}

repo_local_runtime_python() {
  local repo_python="$ROOT/env/.venv-markitdown-runtime/bin/python"
  if [[ -x "$repo_python" ]]; then
    printf '%s' "$repo_python"
    return 0
  fi
  return 1
}

resolve_accurate_python_cmd() {
  if [[ -n "${MARKITDOWN_ACCURATE_PYTHON_CMD:-}" ]]; then
    printf '%s' "$MARKITDOWN_ACCURATE_PYTHON_CMD"
    return 0
  fi
  if [[ -n "${MARKITDOWN_RUNTIME_PYTHON:-}" && -x "${MARKITDOWN_RUNTIME_PYTHON}" ]]; then
    printf '%s' "$MARKITDOWN_RUNTIME_PYTHON"
    return 0
  fi
  if repo_local_runtime_python >/dev/null; then
    repo_local_runtime_python
    return 0
  fi
  printf 'python3'
}

default_paddle_wrapper_cmd() {
  local python_cmd
  if [[ -n "${MARKITDOWN_RUNTIME_PYTHON:-}" && -x "${MARKITDOWN_RUNTIME_PYTHON}" ]]; then
    python_cmd="$MARKITDOWN_RUNTIME_PYTHON"
  else
    python_cmd="$(repo_local_runtime_python)" || return 1
  fi
  printf '%q %q' "$python_cmd" "$ROOT/samples/env/ocr/paddle_ocr_wrapper.py"
}

ensure_default_paddle_wrapper() {
  if [[ -z "${MARKITDOWN_PADDLE_OCR_CMD:-}" ]]; then
    MARKITDOWN_PADDLE_OCR_CMD="$(default_paddle_wrapper_cmd)" || {
      echo "accurate runtime is not configured: repo-local Paddle virtualenv was not found under ./env/ and MARKITDOWN_PADDLE_OCR_CMD is unset" >&2
      return 1
    }
    export MARKITDOWN_PADDLE_OCR_CMD
  fi
}

wrapper_smoke_test() {
  local python_cmd="$1"
  local smoke_image="$2"
  "$python_cmd" - "$MARKITDOWN_PADDLE_OCR_CMD" "$smoke_image" <<'PY'
import json
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

cmd_text, image_path = sys.argv[1:]
path = Path(image_path)
if not path.is_file():
    raise SystemExit(f"accurate smoke image missing: {image_path}")

argv = shlex.split(cmd_text)
if not argv:
    raise SystemExit("MARKITDOWN_PADDLE_OCR_CMD resolved to an empty command")

with tempfile.TemporaryDirectory(prefix="markitdown-accurate-smoke-") as tmp:
    request_json = Path(tmp) / "request.json"
    result_json = Path(tmp) / "result.json"
    request_json.write_text(
        json.dumps(
            {
                "provider": "paddle_ocr",
                "version": "v2",
                "jobs": [
                    {
                        "job_id": "smoke-1",
                        "image_path": str(path),
                        "language": "eng",
                    }
                ],
            },
            ensure_ascii=True,
        ),
        encoding="utf-8",
    )
    completed = subprocess.run(
        argv + ["--batch-json", str(request_json), "--result-json", str(result_json)],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip() or f"exit={completed.returncode}"
        raise SystemExit(f"paddle wrapper smoke test failed: {detail}")

    try:
        payload = json.loads(result_json.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"paddle wrapper smoke test emitted invalid result JSON: {exc}") from exc

provider_name = payload.get("provider_name")
jobs = payload.get("jobs")
if provider_name != "paddle_ocr":
    raise SystemExit(f"unexpected paddle wrapper provider_name: {provider_name!r}")
if not isinstance(jobs, list) or not jobs:
    raise SystemExit("paddle wrapper smoke test returned no OCR jobs")
first_job = jobs[0] if isinstance(jobs[0], dict) else {}
pages = first_job.get("pages")
if first_job.get("status") != "ok" or not isinstance(pages, list) or not pages:
    raise SystemExit("paddle wrapper smoke test returned no successful OCR pages")
PY
}

accurate_runtime_preflight() {
  local preflight_log="$1"
  local smoke_image="$2"
  local python_cmd
  python_cmd="$(resolve_accurate_python_cmd)"
  {
    echo "preflight: checking accurate runtime dependencies"
    require_command "$ACCURATE_TESSERACT_CMD" || return 1
    require_command "$ACCURATE_PDFTOPPM_CMD" || return 1
    require_command "$python_cmd" || return 1
    if [[ "${MARKITDOWN_ACCURATE_SKIP_PADDLE_IMPORT_CHECK:-0}" != "1" ]]; then
      "$python_cmd" - <<'PY' || return 1
import paddle  # noqa: F401
import paddleocr  # noqa: F401
PY
    fi
    ensure_default_paddle_wrapper || return 1
    wrapper_smoke_test "$python_cmd" "$smoke_image" || return 1
    resolve_markitdown_cli >/dev/null || return 1
    echo "preflight: ok"
    echo "python: $python_cmd"
    echo "paddle_wrapper: $MARKITDOWN_PADDLE_OCR_CMD"
  } >"$preflight_log" 2>&1
}

SIGNAL_SUITE_ENTRYPOINT="samples/check_accurate.sh"
SIGNAL_SUITE_USAGE_TITLE="Run the external accurate validation entrypoint."
SIGNAL_SUITE_CORPUS_LABEL="external accurate"
SIGNAL_SUITE_CORPUS_DIRNAME="external_accurate"
SIGNAL_SUITE_SUPPORTED_FORMATS="docx ocr odp ods odt pdf pptx xlsx"
SIGNAL_SUITE_USAGE_EXTRA=$'  * performs an accurate runtime preflight before row execution\n  * unsupported formats fail closed and print the supported accurate format list\n'
SIGNAL_SUITE_USAGE_EXAMPLES=$'  ./samples/check_accurate.sh\n  ./samples/check_accurate.sh --pdf\n  ./samples/check_accurate.sh --ocr\n  ./samples/check_accurate.sh --id pdf_niosh_scanned_like_debug'
SIGNAL_SUITE_TMP_ROOT="$ACCURATE_TMP_ROOT"
SIGNAL_SUITE_RUN_ID_PREFIX="accurate"
SIGNAL_SUITE_RESULT_PREFIX="accurate"
SIGNAL_SUITE_CHECK="$QUALITY_CHECK"
SIGNAL_SUITE_LAB_ROOT="$QUALITY_LAB_ROOT"
SIGNAL_SUITE_CORPUS_ROOT="$ACCURATE_CORPUS_ROOT"
SIGNAL_SUITE_MANIFEST_PATH="$ACCURATE_MANIFEST_PATH"
SIGNAL_SUITE_SUMMARY_INTRO="External accurate rows from ./markitdown-quality-lab. These rows validate accurate-only behavior and no repo-local accurate corpus fallback is used."
SIGNAL_SUITE_MISSING_TITLE="EXTERNAL ACCURATE CORPUS NOT FOUND"
SIGNAL_SUITE_MISSING_HINTS=$'place markitdown-quality-lab at the official repo-root location\nsync the external lab so ./markitdown-quality-lab/external_accurate exists\nofficial location: ./markitdown-quality-lab'

signal_suite_before_run() {
  local _run_dir="$1"
  local log_dir="$2"
  local _run_label="$3"
  local smoke_image_path="$ACCURATE_CORPUS_ROOT/$DEFAULT_SMOKE_IMAGE_REL"
  local preflight_log_path="$log_dir/preflight.log"
  if ! accurate_runtime_preflight "$preflight_log_path" "$smoke_image_path"; then
    echo "accurate: preflight failed"
    echo "run: $(display_path "$ROOT" "$_run_dir")"
    echo "preflight-log: $(display_path "$ROOT" "$preflight_log_path")"
    sed -n '1,40p' "$preflight_log_path" >&2 || true
    exit 1
  fi
}

signal_suite_write_summary_extra() {
  local preflight_log_path="$LOG_DIR/preflight.log"
  echo
  echo "## Preflight"
  echo
  echo "- Log: $(display_path "$ROOT" "$preflight_log_path")"
  echo "- Paddle wrapper: ${MARKITDOWN_PADDLE_OCR_CMD:-unset}"
}

signal_suite_run "$@"
