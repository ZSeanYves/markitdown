# Samples Overview

The `samples/` tree is split by responsibility. A sample may appear in more
than one area when it serves different checked-in contracts, but those roles
should stay explicit.

## Sample Families

### `samples/main_process`

Purpose:

* user-visible Markdown output regression
* main conversion-path behavior

Rules:

* every checked-in sample should have expected Markdown under
  `samples/main_process/expected/<format>/`
* success-path samples belong here
* fail-closed and parser-only boundary cases should usually stay in
  `samples/test`

### `samples/metadata`

Purpose:

* sidecar behavior regression via `--with-metadata`

Rules:

* expected Markdown lives under `samples/metadata/expected/<format>/`
* sidecar fixture snapshots live under `samples/test/metadata/`
* metadata samples do not replace `main_process` coverage

### `samples/assets`

Purpose:

* asset materialization and Markdown asset-reference regression

Rules:

* expected Markdown lives under `samples/assets/expected/<format>/`
* asset paths referenced by emitted Markdown must exist on disk

### `samples/test`

Purpose:

* parser/core/unit-test-only fixtures
* fail-closed boundaries
* unsafe inputs
* lower-layer behavior that does not belong in main output regression

Rules:

* files here do not need expected Markdown
* this is the preferred place for unsafe ZIP/EPUB/PDF and similar boundary
  fixtures

### `samples/benchmark`

Purpose:

* checked-in benchmark corpus rows
* small, stable, reproducible local performance signals

Rules:

* benchmark presence is not quality evidence by itself
* benchmark rows may reuse checked-in sample content, but the benchmark role
  should remain explicit in `corpus.tsv` or `compare_corpus.tsv`
* benchmark corpora must not be treated as the sole correctness contract

### `docs/quality-comparisons`

Purpose:

* checked-in external-comparison records

Rules:

* these are narrative records, not automated test fixtures
* they may reference sample files, but should not become the only place where
  a feature is validated

## Validation Commands

Use these entrypoints:

```bash
./samples/check.sh
./samples/check_main_process.sh
./samples/check_metadata.sh
./samples/check_assets.sh
./samples/scripts/check_cli_contract.sh
./samples/scripts/check_batch_contract.sh
./samples/scripts/check_corpus_manifest.sh
```

For benchmark corpus policy, see
[samples/benchmark/README.md](./benchmark/README.md).
