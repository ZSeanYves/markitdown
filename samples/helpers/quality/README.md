# samples/helpers/quality

Role:
  internal implementation for the external quality bridge

Owns:
  `check.sh`
  `manifest.tsv`
  `schemas/`
  run summaries and signal-level validation flow used by `samples/check_quality.sh`

Does not own:
  repo-local sample checks
  product runtime behavior
  corpus storage
  release orchestration

Public entrypoint:
  `bash samples/check_quality.sh`

Corpus source:
  `markitdown-quality-lab/external_quality/`

Notes:
  repo-local samples are not used as external quality rows
  generated outputs go under `.tmp/quality/`

See:
  [samples/README.md](../../README.md)
