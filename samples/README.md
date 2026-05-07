# Samples Overview

The `samples/` tree now uses one unified checked-in input corpus under
`samples/main_process/`. Metadata-heavy and asset-heavy cases still exist, but
they now live under the same format trees instead of separate top-level sample
families. Each format package keeps its own checked expectations under
`samples/main_process/<format>/expected/`.

All checked sample inputs and expected outputs are committed to the repository.
Normal validation and CI do not require running any sample generator step.

## Directory Roles

| Path | Current role | Checked by | Output type | Status |
| --- | --- | --- | --- | --- |
| `samples/main_process/` | checked-in user-visible regression inputs across all formats, with per-format `expected/` subtrees | `check.sh` | source inputs plus expected outputs | keep |
| `samples/fixtures/` | parser/core/fail-closed fixtures plus lower-layer metadata snapshots | MoonBit tests, contract scripts | fixture inputs and lower-layer snapshots | keep |
| `samples/benchmark/` | checked-in benchmark corpus | `bench.sh`, internal bench scripts | performance corpus rows | keep |
| `samples/real_world/` | reserved complex-scenario corpus for future richer samples | `check.sh --real-world` | Markdown plus optional metadata/assets checks | new |
| `samples/scripts/` | internal validation, benchmark, and maintainer-only helper scripts | developer/manual | shell implementation and maintenance helpers | document |
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

### `samples/real_world/`

Purpose:

* future richer complex-scenario corpus
* synthetic or permissively licensed real-like documents
* multiple structures in one file for later expansion

Rules:

* this is not a replacement for `main_process`
* this is not a benchmark corpus by default
* rows are controlled by `samples/real_world/manifest.tsv`
* full conversion is opt-in through `./samples/check.sh --real-world`
* default `samples/check.sh` only validates the manifest schema through
  `--manifest-only`

## Coverage Matrix

| Format | main_process | metadata cases | asset cases | metadata expected | benchmark | quality records | real_world slot |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DOCX | yes | yes | yes | yes | yes | yes | reserved |
| PPTX | yes | yes | yes | yes | yes | yes | reserved |
| XLSX | yes | yes | n/a | yes | yes | yes | reserved |
| PDF | yes | yes | yes | yes | yes | yes | reserved |
| HTML | yes | yes | yes | yes | yes | yes | reserved |
| ZIP | yes | yes | yes | yes | yes | yes / not comparable | reserved |
| EPUB | yes | yes | yes | yes | yes | yes | reserved |
| CSV / TSV | yes | yes | n/a | yes | yes | maybe | optional |
| JSON / YAML / XML | yes | yes | n/a | yes | yes | maybe | optional |
| TXT / Markdown | yes | yes | n/a | yes | yes | maybe | optional |

Interpretation:

* `main_process`: checked input corpus and Markdown regression
* `metadata cases`: cases typically exercised with `--with-metadata`
* `asset cases`: cases expected to materialize local assets or asset refs
* `metadata expected`: exact checked sidecar fixtures, when present
* `benchmark`: performance evidence
* `quality records`: human comparison docs
* `real_world slot`: reserved complex-scenario corpus space, not current H2++ evidence

## Script Index

| Script | Purpose | Default gate? |
| --- | --- | --- |
| `samples/check.sh` | public sample-validation entrypoint; default full chain plus focused modes `--markdown-only`, `--metadata-only`, `--assets-only`, `--contracts-only`, `--manifest-only`, and `--real-world` | yes |
| `samples/bench.sh` | public benchmark entrypoint; suite dispatcher for `--suite smoke`, `--suite compare`, and `--suite batch-profile` | manual |
| `samples/scripts/check_samples.sh` | internal enrollment-integrity helper used by `check.sh --manifest-only` and the default full chain | yes via `check.sh` |
| `samples/scripts/check_cli_contract.sh` | internal CLI contract implementation | yes via `check.sh` |
| `samples/scripts/check_batch_contract.sh` | internal batch contract implementation | yes via `check.sh` |
| `samples/scripts/check_debug_contract.sh` | internal debug CLI contract implementation | yes via `check.sh` |
| `samples/scripts/check_corpus_manifest.sh` | internal benchmark manifest helper | yes via `check.sh --manifest-only` |
| `samples/scripts/check_real_world.sh` | internal real-world corpus helper | yes via `check.sh --manifest-only`, opt-in via `check.sh --real-world` |
| `samples/scripts/bench_*.sh` | internal benchmark suite implementations | yes via `bench.sh` |
| `samples/scripts/bench_warn.sh` | maintainer-only benchmark warning helper | manual / internal |
| `samples/scripts/list_sample_inventory.sh` | maintainer-only inventory summary helper | manual / internal |

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

Opt-in complex-scenario validation:

```bash
./samples/check.sh --real-world
```

Benchmark entrypoints:

```bash
./samples/bench.sh --suite smoke
./samples/bench.sh --suite compare
./samples/bench.sh --suite batch-profile
```

For benchmark corpus policy, see
[samples/benchmark/README.md](./benchmark/README.md).
