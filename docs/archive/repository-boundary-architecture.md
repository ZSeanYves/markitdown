# Main repository and external lab architecture

Status: adopted repository boundary contract

This contract defines the architecture boundary between the MoonBit
`markitdown` main repository and the external `markitdown-quality-lab`
repository. The boundary keeps the product repository self-contained while
allowing an external lab to provide larger quality, benchmark, provenance, and
training signals.

## Problem Statement

The main repository and the external lab have different jobs, but their files
can easily blur together. Main-repository scripts, external samples, benchmark
corpora, quality audits, temporary downloads, and cleanup caches all exercise
the same product behavior, so an unclear boundary can turn optional external
signal into an implicit product dependency.

The architecture goal is:

- keep the main repository able to build, test, and run by itself
- allow the external lab to provide quality and benchmark signal
- prevent external corpora, reports, staging data, and temporary workspaces from
  becoming hidden dependencies of normal product validation
- make missing external data explicit instead of quietly replacing it with local
  samples or caches

## Architecture Boundary

The architecture boundary separates four concerns:

- main-repository product implementation and self-contained validation
- external-lab quality, benchmark, provenance, and training assets
- bridge entrypoints that connect the two repositories when optional external
  signal is requested
- ignored temporary workspaces that store run output but do not own data

## Repository Boundary

The main repository owns product implementation and self-contained validation:

- MoonBit runtime, parser, converter, IR, CLI, and package metadata
- repo-local samples and expected outputs
- `moon check`, `moon test`, and `samples/check.sh`
- bridge entrypoints that can invoke optional external signal

The main repository must build, test, and run when `markitdown-quality-lab` is
absent.

The external lab owns external assets and evidence:

- `external_quality/`
- `external_bench/`
- `pdf_model_training/`
- external sample payloads
- source catalogs, provenance records, and license evidence
- benchmark corpora and benchmark run inputs
- PDF/model training, audit, and experiment assets

The external lab may exercise main-repository behavior, but it is not a
required dependency for the main repository's public-only build, test, or
runtime path.

## Responsibilities

Responsibility is split by repository ownership, not by which script happens to
exercise a sample. The main repository owns product behavior and self-contained
checks. The external lab owns external data and evidence. Bridge scripts own
execution, reporting, and clear failure behavior.

### Main Repository Responsibilities

The main repository is responsible for:

- implementing format parsing, conversion, runtime behavior, and CLI behavior
- keeping repo-local samples small, intentional, and suitable for public
  self-contained regression
- ensuring `moon check`, `moon test`, and `samples/check.sh` do not read the
  external lab
- providing bridge scripts that can locate and run external checks when the lab
  is present
- writing bridge output to ignored temporary workspaces rather than formal
  product or corpus paths

The main repository does not own external corpus layout, source evidence, or
benchmark payloads.

### External Lab Responsibilities

The external lab is responsible for:

- storing formal external quality samples under `external_quality/`
- storing formal external benchmark samples under `external_bench/`
- storing independent PDF/model training and audit assets under
  `pdf_model_training/`
- keeping each formal corpus bounded by `MANIFEST.tsv` and
  `SOURCE_CATALOG.tsv`
- requiring provenance and license evidence before a source enters a formal
  corpus
- keeping temporary downloads, cleanup reports, audit tools, and generated
  reports outside the formal architecture layers

External lab changes may reveal product bugs or performance changes. They must
not require runtime, parser, or converter edits as a side effect of corpus
cleanup.

## Non-responsibilities

The main repository does not own external corpus payloads, source catalogs,
license evidence, benchmark corpora, PDF/model training assets, cleanup reports,
or audit tools.

The external lab does not own product runtime, parser, converter, IR, CLI,
repo-local product samples, or the public self-contained product gate.

Bridge scripts do not own corpus layout, do not provide product runtime
behavior, and do not turn optional external signal into a main-repository build
or test dependency.

Temporary tools, audit scripts, cleanup reports, generated reports, and local
caches are not architecture layers.

## Bridge Entrypoints

The main repository has two external bridge entrypoints:

- `samples/check_quality.sh` reads `markitdown-quality-lab/external_quality/`
  through its formal manifest and reports external quality signal.
- `samples/bench.sh` reads `markitdown-quality-lab/external_bench/` through its
  formal manifest and reports benchmark signal.

Bridge entrypoints coordinate discovery, execution, summary output, and `.tmp`
workspace creation. They do not own the external corpus and must not invent a
local replacement corpus.

When the external lab or a required manifest is missing, a bridge must fail
clearly or state that optional external signal is unavailable. It must not
silently fall back to repo-local samples, staging directories, local caches, or
temporary downloads.

## Dependency Direction

The dependency direction is one-way and explicit:

- The main repository may reference the external lab only through bridge
  scripts.
- Product runtime, parser, converter, IR, and CLI code cannot import, read, or
  require external lab files.
- `samples/check.sh` cannot read the external lab.
- The external lab may contain data that exercises main-repository behavior.
- External lab cleanup must not require runtime, parser, or converter changes as
  side effects.
- The architecture does not require a Git submodule, package-manager link, or
  vendored external lab checkout.

## Data Ownership Rules

Repo-local samples belong to the main repository. They define public,
self-contained product regression coverage and may be used by `samples/check.sh`.

`external_quality/` and `external_bench/` samples belong to the external lab.
They are formal external corpora only when covered by the appropriate
`MANIFEST.tsv` and `SOURCE_CATALOG.tsv`.

`pdf_model_training/` belongs to the external lab as an independent training,
audit, and experiment area. It is not quality corpus layout, benchmark corpus
layout, or main-repository runtime architecture.

Local caches, ignored `.tmp` workspaces, cleanup reports, one-off audit scripts,
and generated reports are owned by neither the formal corpus nor the product
runtime.

## Architecture Layers / Areas

The architecture has these durable areas:

- product implementation in the main repository
- repo-local product regression samples in the main repository
- external quality corpus in `markitdown-quality-lab/external_quality/`
- external benchmark corpus in `markitdown-quality-lab/external_bench/`
- independent PDF/model training and audit assets in
  `markitdown-quality-lab/pdf_model_training/`
- bridge entrypoints in the main repository
- ignored `.tmp` run workspaces

Only product implementation, repo-local samples, bridge entrypoints, and ignored
run workspaces are main-repository areas. External corpora and training assets
remain external-lab areas.

## Validation Strategy

Boundary validation should check both the self-contained product path and the
optional bridge path:

- run `moon check`
- run `moon test`
- run `samples/check.sh`
- run `samples/check_quality.sh` when `markitdown-quality-lab/external_quality`
  and its manifest are available
- run `samples/bench.sh` when `markitdown-quality-lab/external_bench` and its
  manifest are available
- verify that bridge failures for a missing external lab are explicit and do not
  silently substitute local samples
- inspect diffs to confirm external corpus cleanup did not modify runtime,
  parser, or converter code as a side effect

## Runtime Invariants

- Main build, test, and check succeed without the external lab.
- `samples/check.sh` never reads the external lab.
- `samples/check_quality.sh` never reads repo-local samples as fallback.
- `samples/bench.sh` never uses repo-local samples as benchmark corpus.
- External corpus changes never modify runtime, parser, or converter code as a
  side effect.
- Missing external lab state has an explicit user-facing message.
- Temporary tools, audit scripts, and cleanup reports are not architecture
  layers.

## Non-goals

This contract is not:

- a Git submodule architecture
- a package-manager contract
- legal advice
- a benchmark performance claim
- the PDF model training architecture
- a mandate that public product checks depend on external corpora
- a cleanup checklist for one particular migration

## Change Rules

Changes that affect the boundary must preserve self-contained main-repository
validation. A new product test, runtime path, parser behavior, converter
behavior, or CLI behavior cannot require the external lab.

Changes that affect bridge entrypoints must keep corpus ownership in the
external lab and must keep missing-lab behavior explicit.

Changes that affect external corpora must update manifests, source catalogs, and
provenance records together. Provenance and license evidence is required before
a source becomes part of a formal external corpus.

Historical cleanup notes may be kept only when they explain why the current
boundary exists. They are not execution plans and must not redefine the
architecture.
