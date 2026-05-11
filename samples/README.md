# Samples Overview

The `samples/` tree now uses one unified checked-in input corpus under
`samples/main_process/`. Metadata-heavy and asset-heavy cases still exist, but
they now live under the same format trees instead of separate top-level sample
families. Each format package keeps its own checked expectations under
`samples/main_process/<format>/expected/`.

All checked sample inputs and expected outputs are committed to the repository.
Normal validation and CI do not require running any sample generator step.
The repository exposes `./samples/check.sh` and `./samples/bench.sh` as the
public sample entrypoints; everything under `samples/helpers/` is internal
implementation or maintainer-only helper surface.

## Directory Roles

| Path | Current role | Checked by | Output type | Status |
| --- | --- | --- | --- | --- |
| `samples/main_process/` | checked-in user-visible regression inputs across all formats, with per-format `expected/` subtrees | `check.sh` | source inputs plus expected outputs | keep |
| `samples/fixtures/` | parser/core/fail-closed fixtures plus lower-layer metadata snapshots | MoonBit tests, contract scripts | fixture inputs and lower-layer snapshots | keep |
| `samples/benchmark/` | checked-in benchmark corpus | `bench.sh`, internal bench scripts | performance corpus rows | keep |
| `samples/quality_corpus/` | signal-level external/private quality intake skeleton | `quality_corpus/check.sh` | intake manifests plus local reports | keep |
| `samples/helpers/` | internal validation, benchmark, and maintainer-only helper scripts | developer/manual | shell implementation and maintenance helpers | document |
| `docs/quality-comparisons/` | human-readable external comparison records | manual review | narrative comparison docs | keep |

## Taxonomy

### `samples/main_process/`

Purpose:

* stable Markdown output regression
* format-focused cases plus richer metadata/asset scenarios
* the single checked-in user-visible input corpus

Layout rules:

* primary format inputs live under `samples/main_process/<format>/`
* metadata-heavy or asset-heavy subcases may live in nested subdirs such as
  `metadata/` or `assets/` when they need local resource isolation or naming
  separation
* checked Markdown and exact CLI metadata expectations live under
  `samples/main_process/<format>/expected/`
* local support files such as HTML `img/` resources may live alongside the
  subcases that need them

### `samples/main_process/<format>/expected/`

Purpose:

* checked Markdown expectations for every enrolled sample
* exact CLI metadata sidecar fixtures for selected metadata cases

Rules:

* expected Markdown mirrors the sample relative path beneath its format root
* example:
  `samples/main_process/html/metadata/html_metadata_basic.html`
  maps to
  `samples/main_process/html/expected/metadata/html_metadata_basic.md`
* not every sample has a checked metadata fixture
* when a fixture exists, it mirrors the sample relative path
* metadata fixtures use the same `expected/` subtree with
  `.metadata.json` filenames, for example
  `samples/main_process/html/expected/metadata/html_metadata_basic.metadata.json`
* the validator still checks sidecar structure for metadata-enabled cases even
  when no exact fixture is checked in

### `samples/fixtures/metadata/`

Purpose:

* lower-layer metadata JSON snapshots for MoonBit tests
* parser/emitter-level provenance checks that do not have to match the CLI
  sidecar exactly

Rules:

* this directory is distinct from the CLI-facing
  `samples/main_process/<format>/expected/*.metadata.json` fixtures
* use it for MoonBit snapshot-style metadata evidence, not for release-style
  shell validation

### `samples/fixtures/`

Purpose:

* lower-layer parser/core fixtures
* fail-closed boundaries
* unsafe archives and malformed packages

Rules:

* fixtures here are not the user-visible regression corpus
* ZIP and EPUB boundary fixtures stay here

### `samples/benchmark/`

Purpose:

* checked-in performance corpus
* explicit benchmark governance rows
* reproducible local smoke and comparison evidence

Rules:

* corpus membership is controlled by `corpus.tsv` and `compare_corpus.tsv`
* benchmark presence is not quality proof by itself
* outputs go to `.tmp/bench/...`

### `samples/quality_corpus/`

Purpose:

* signal-level external/private quality intake
* local gating for real or public samples that should not be forced into exact fixtures
* optional intake path for manually curated external/public-dataset/tool-fixture rows

Rules:

* this is not an exact regression replacement for `main_process`
* public `manifest.tsv` may be intentionally empty until external rows are curated
* private local rows belong under `samples/quality_corpus/private/`
* local external rows belong under `samples/quality_corpus/external_manifest.local.tsv`
* missing private manifests must not fail the checker
* missing external manifests must not fail the checker
* external rows require explicit license review before execution
* external/public rows require manual license review before vendoring

## Coverage Matrix

| Format | main_process | metadata cases | asset cases | metadata expected | benchmark | quality records | quality intake |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DOCX | yes | yes | yes | yes | yes | yes | external/private |
| PPTX | yes | yes | yes | yes | yes | yes | external/private |
| XLSX | yes | yes | n/a | yes | yes | yes | external/private |
| PDF | yes | yes | yes | yes | yes | yes | external/private |
| HTML | yes | yes | yes | yes | yes | yes | external/private |
| ZIP | yes | yes | yes | yes | yes | yes / not comparable | external/private |
| EPUB | yes | yes | yes | yes | yes | yes | external/private |
| CSV / TSV | yes | yes | n/a | yes | yes | maybe | external/private |
| JSON / YAML / XML | yes | yes | n/a | yes | yes | maybe | external/private |
| TXT / Markdown | yes | yes | n/a | yes | yes | maybe | external/private |

Interpretation:

* `main_process`: checked input corpus and Markdown regression
* `metadata cases`: cases typically exercised with `--with-metadata`
* `asset cases`: cases expected to materialize local assets or asset refs
* `metadata expected`: exact checked sidecar fixtures, when present
* `benchmark`: performance evidence
* `quality records`: human comparison docs
* `quality intake`: signal-level external/private intake, not a current global
  quality guarantee

## Script Index

| Script | Purpose | Default gate? |
| --- | --- | --- |
| `samples/check.sh` | public sample-validation entrypoint; default full chain plus focused modes `--markdown-only`, `--metadata-only`, `--assets-only`, `--contracts-only`, and `--manifest-only` | yes |
| `samples/bench.sh` | public benchmark entrypoint; suite dispatcher for `--suite smoke`, `--suite compare`, and `--suite batch-profile` | manual |
| `samples/quality_corpus/check.sh` | signal-level external/private intake checker | manual |
| `samples/quality_corpus/compare_tools.sh` | optional tool availability/reference probe | manual |
| `samples/helpers/check_samples.sh` | internal enrollment-integrity helper used by `check.sh --manifest-only` and the default full chain | yes via `check.sh` |
| `samples/helpers/check_cli_contract.sh` | internal CLI contract implementation | yes via `check.sh` |
| `samples/helpers/check_batch_contract.sh` | internal batch contract implementation | yes via `check.sh` |
| `samples/helpers/check_debug_contract.sh` | internal debug CLI contract implementation | yes via `check.sh` |
| `samples/helpers/check_corpus_manifest.sh` | internal benchmark manifest helper | yes via `check.sh --manifest-only` |
| `samples/helpers/bench_*.sh` | internal benchmark suite implementations and rerun helpers | yes via `bench.sh` |
| `samples/helpers/bench_warn.sh` | maintainer-only benchmark warning helper | manual / internal |
| `samples/helpers/list_sample_inventory.sh` | maintainer-only inventory summary helper | manual / internal |

## Validation Commands

Default validation:

```bash
./samples/check.sh
```

Focused validation:

```bash
./samples/check.sh --metadata-only
./samples/check.sh --assets-only
./samples/check.sh --markdown-only
./samples/check.sh --contracts-only
./samples/check.sh --manifest-only
```

Signal-level intake check:

```bash
bash ./samples/quality_corpus/check.sh
bash ./samples/quality_corpus/tools/fetch_external_samples.sh --list-sources
```

Benchmark entrypoints:

```bash
./samples/bench.sh --suite smoke --kind smoke
./samples/bench.sh --suite compare
./samples/bench.sh --suite batch-profile
./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
./samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
```

For benchmark commands and output locations, see
[docs/benchmarking.md](../docs/benchmarking.md).

For benchmark corpus policy, see
[samples/benchmark/README.md](./benchmark/README.md).
