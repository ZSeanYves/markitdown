# Optional Runtime Management

`tools/env/` manages every dependency that is intentionally outside the native
MoonBit core. Core document readers do not require this directory at runtime.

## Public entrypoints

```bash
./tools/env/optional_deps.sh install core
./tools/env/optional_deps.sh install balance
./tools/env/optional_deps.sh install audio
./tools/env/optional_deps.sh install accurate
./tools/env/optional_deps.sh install bench
./tools/env/optional_deps.sh install all

./tools/env/optional_deps.sh check all
./tools/env/reset_test_env.sh
```

Profiles have narrow ownership:

| Profile | Installs | Product boundary |
| --- | --- | --- |
| `core` | nothing | verifies the dependency-free native boundary |
| `balance` | Tesseract | top-level image OCR and standalone ZIP image children |
| `audio` | Vosk, model, ffmpeg | optional `wav/mp3/m4a` transcription |
| `accurate` | PaddleOCR, models, pdftoppm | optional direct-image/PDF accurate routes |
| `bench` | Microsoft MarkItDown environment | development comparison only |

`install` creates repo-local state under ignored `env/`. `check` is read-only
and rejects missing, incomplete, or fingerprint-incompatible state. Official
wrappers establish their deterministic child-process environment themselves;
generated `env/*.env.sh` files are available for custom shells but are not
required for normal repo-root CLI runs.

Large model downloads retain stable partial files and resume after interruption.
HTTP range-capable servers use four segments by default. Override this with
`MARKITDOWN_DOWNLOAD_SEGMENTS=1..8`. Regional or internal mirrors can be tried
before the configured origin with a comma-separated
`MARKITDOWN_MODEL_MIRROR_BASE_URLS`; the configured SHA-256 remains mandatory
for every source.

## Internal layout

- `lib/`: installer, lock, fingerprint, package-manager, and model logic.
- `config/`: profile, tool, model, and Python lock data.
- `wrappers/`: stable OCR and audio process ABIs.
- `installers/`: four compatibility entrypoints retained for older automation.
- `share/`: implementation helpers used by the manager.

New documentation and automation must call `optional_deps.sh`; do not introduce
new direct calls to `installers/`.

## Verification

```bash
find tools/env -type f -name '*.sh' -print0 | xargs -0 bash -n
python3 -m unittest discover -s tools/env/lib/tests -p 'test_*.py'
```
