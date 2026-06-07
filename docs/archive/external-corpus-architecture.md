# External corpus architecture

Status: adopted external corpus layout and provenance contract

This contract defines the formal external corpus architecture used by the
MoonBit `markitdown` project. It separates durable quality and benchmark
corpora from staging files, caches, audit outputs, cleanup tools, and historical
artifacts.

## Problem Statement

External corpora need a stable shape. Without one, sample payloads, staging
rows, cache directories, archives, reports, scripts, and temporary downloads can
all appear to be equally authoritative. That makes consumers fragile and can
pull data without provenance or license evidence into formal quality or
benchmark runs.

The architecture goals are:

- make `MANIFEST.tsv` and `SOURCE_CATALOG.tsv` the formal corpus boundary
- keep quality and benchmark corpora structurally similar
- require provenance and license evidence before formal inclusion
- prevent cleanup tools from rewriting sample semantics
- prevent staging, cache, archive, and report paths from becoming formal sample
  paths
- make it clear that not every file under a directory is a corpus sample

## Scope

This contract applies to:

```text
markitdown-quality-lab/external_quality/
markitdown-quality-lab/external_bench/
```

It also defines how those areas relate to the external lab root. It does not
define the internal layout of `pdf_model_training/`, except to keep that area
separate from formal quality and benchmark corpora.

## Architecture Boundary

The external corpus boundary is the combination of a corpus area, its
`MANIFEST.tsv`, its `SOURCE_CATALOG.tsv`, and payload files under
`<format>/<source>/...`.

Files outside that boundary can support maintenance, but they are not formal
samples. Root cleanup tools, one-off audit scripts, reports, generated outputs,
local caches, ignored `.tmp` workspaces, and historical staging directories are
outside the architecture boundary.

## External Lab Root

The external lab root should remain small:

```text
markitdown-quality-lab/
  README.md
  LICENSES.md
  external_quality/
  external_bench/
  pdf_model_training/
```

`.git/` is Git metadata and is not part of the corpus contract.

`.gitignore` may exist to protect local ignored files such as caches,
`local_only/`, generated reports, or `__pycache__/`. It is not a corpus area.

Root-level `archive/`, `scripts/`, `licenses/`, `.tmp/`, `.github/`, cache,
debug, generated, report, and cleanup-helper directories are not target business
structure. Temporary tools, audit scripts, cleanup reports, and generated
reports may support maintenance, but they are not architecture layers.

Durable provenance or license notes belong in:

- the relevant `SOURCE_CATALOG.tsv`
- the relevant area `README.md`
- root `LICENSES.md`

## Responsibilities

The external corpus architecture is responsible for:

- defining durable quality and benchmark corpus layout
- making manifest rows the only formal sample entrypoint
- making source catalog rows the machine-checkable provenance and license index
- keeping payload files under stable format and source directories
- separating sidecar evidence from conversion samples
- excluding staging, cache, archive, temporary, tooling, debug, report, and
  generated-output paths from formal sample references

It must provide enough structure for bridge scripts to consume external signal
without making the external lab a required main-repository dependency.

## Non-responsibilities

This architecture does not own main-repository runtime behavior, parser
behavior, converter behavior, CLI behavior, repo-local product samples, or
public self-contained validation.

It does not define the internal `pdf_model_training/` layout and does not turn
benchmark measurements into product performance guarantees.

Temporary tools, audit scripts, cleanup reports, dry-run inventories, generated
reports, and local caches are maintenance artifacts, not architecture layers.

## Architecture Layers / Areas

The formal external corpus is composed of these layers:

- external lab root
- corpus areas
- formal corpus layout
- manifest layer
- source catalog layer
- provenance and license layer
- sample payload layer
- sidecar and resource policy
- consumer contract

The following sections define each layer.

## Corpus Areas

`external_quality/` stores external samples used for quality regression signal.
It is consumed by `samples/check_quality.sh`.

`external_bench/` stores external samples used for benchmark signal. It is
consumed by `samples/bench.sh`.

`pdf_model_training/` stores independent PDF/model training, audit, and
experiment assets. It is not a quality corpus, benchmark corpus, or public
main-repository gate.

Quality and benchmark corpora may contain different rows and formats, but they
share the same formal architecture: README, manifest, source catalog, and
`<format>/<source>/...` payload directories.

## Formal Corpus Layout

Each formal corpus area uses this top-level shape:

```text
external_quality/
  README.md
  MANIFEST.tsv
  SOURCE_CATALOG.tsv
  <format>/
    <source>/
      ...

external_bench/
  README.md
  MANIFEST.tsv
  SOURCE_CATALOG.tsv
  <format>/
    <source>/
      ...
```

Only these top-level entries are formal corpus entries:

- `README.md`
- `MANIFEST.tsv`
- `SOURCE_CATALOG.tsv`
- lower-case format directories

Formal sample payloads live under:

```text
<format>/<source>/...
```

Format directories use lower-case format names. Source directories use stable
source identifiers. A file is a formal sample only when the manifest registers
it and the source catalog covers its source. Directory placement alone is not
formal inclusion.

Allowed format directory names are:

```text
csv
docx
epub
html
json
markdown
ocr
pdf
pptx
tsv
txt
xlsx
xml
yaml
zip
```

`external_quality/` and `external_bench/` are not required to contain every
format. `external_bench/` may contain fewer formats than `external_quality/`,
but it must not use a different root layout.

## Manifest Layer

`MANIFEST.tsv` is the only formal row entrypoint for a corpus. Every formal
sample has one manifest row.

Each row identifies the stable facts needed by consumers, including:

- stable row id
- format
- source or source id
- formal relative sample path
- expected behavior, quality note, skip policy, or expected-fail policy when
  applicable

For `external_bench/`, every formal `rel_path` resolves inside
`external_bench/`.

For `external_quality/`, formal path fields such as `rel_path`,
`proposed_rel_path`, `path`, `input_path`, and `target_path` resolve inside
`external_quality/`, except for rows explicitly marked as unresolved blockers.

Unresolved rows are allowed only as explicit blockers or historical migration
markers. They must not be consumed as valid sample payloads.

Manifest readers tolerate extra columns and project the fields they need. Extra
helper or migration columns are allowed only when public consumers do not depend
on undocumented column positions.

## Source Catalog Layer

`SOURCE_CATALOG.tsv` is the machine-checkable source, license, and provenance
index for a corpus. Every source id used by `MANIFEST.tsv` is covered by
`SOURCE_CATALOG.tsv`.

Each source entry includes:

- source id
- source or origin URL, or a documented origin description
- license, SPDX expression, or license reference
- notes or evidence when needed

The exact schema may differ between `external_quality/` and `external_bench/`.
Readers and checkers identify source and license fields by documented field
names, not by positional assumptions.

No formal source row may use:

- empty license
- `UNKNOWN`
- `needs_review`
- empty source or origin

If source or license evidence is unavailable, the source is blocked or removed
from the formal manifest and source catalog.

## Provenance and License Layer

Formal corpus inclusion requires evidence, not assumptions. A directory name,
project name, or sample filename is not sufficient license evidence by itself.

Acceptable evidence can include:

- source catalog row with license and origin
- upstream `LICENSE`, `NOTICE`, `README`, or `SOURCE` files
- project-owned sample statement
- government or public-domain source statement
- explicit permissive or document license

`LICENSES.md` is the human-readable provenance and license summary. If
`SOURCE_CATALOG.tsv` and `LICENSES.md` disagree, update the source catalog
first, then update `LICENSES.md`. `LICENSES.md` must not hide catalog blockers.

This contract is not legal advice and does not guarantee that a corpus has no
legal risk. It requires recorded provenance and license evidence before formal
use.

## Sample Payload Layer

Payload files under `<format>/<source>/...` are durable sample inputs and related
resources. Cleanup tools must preserve sample semantics. A maintenance command
may move or delete payloads only when the corresponding manifest and source
catalog changes are made in the same scoped change.

No cleanup tool may rewrite file or path semantics by naive text replacement.
For example, replacing every `archive` segment with `container` is forbidden.
Path checks must understand path segments and field meaning.

`archive` as a filename concept is not automatically forbidden. For example,
`zip_nested_archive_boundary.zip` can be a valid sample name when it is a real
sample with a manifest row and source evidence.

`META-INF/container.xml` is a valid EPUB sidecar. The word `container` in a
legitimate EPUB path must not be confused with invented fake paths.

## Sidecar and Resource Policy

Sidecar files can be formal samples only when intentionally registered in the
manifest.

EPUB resources such as `META-INF/container.xml`, CSS, images, fonts, OPF, and
NCX files may be registered when they provide useful quality coverage and have
source and license evidence.

Source sidecars such as `README`, `SOURCE`, `LICENSE`, and `NOTICE` may live
under `<format>/<source>/` when they document provenance. They are not
conversion samples unless the manifest says so.

Generated expected outputs, diffs, logs, reports, and temporary unpacked
workspaces do not become formal samples by being placed near payload files.

## Forbidden Areas

Formal corpus rows must not reference these path segments:

```text
_quality_rows_staging/
_bench_rows_staging/
_incoming/
_local_cache/
_tools/
_licenses/
archive/
legacy/
tmp/
.tmp/
cache/
debug/
reports/
logs/
generated-only/
outputs/
```

No formal sample may live under staging, cache, archive, temporary, tooling,
debug, report, or generated-output paths. Forbidden checks must use path
segments and field semantics, not naive substring matching.

Temporary tools, audit scripts, cleanup reports, dry-run inventories, generated
summaries, and local caches are maintenance artifacts. They are not corpus
areas, architecture layers, or formal source evidence by themselves.

## Consumer Contract

`samples/check_quality.sh` consumes:

```text
markitdown-quality-lab/external_quality/MANIFEST.tsv
```

`samples/bench.sh` consumes:

```text
markitdown-quality-lab/external_bench/MANIFEST.tsv
```

Consumer scripts may support `--format FMT`. They must fail clearly when the
external lab, corpus area, or manifest is missing. They must not silently fall
back to staging directories, local caches, temporary downloads, or repo-local
samples.

`external_quality/` is external quality signal, not repo-local product
regression. `external_bench/` benchmark results are same-corpus,
same-machine, same-parameters feedback and are not universal performance
claims.

## Validation Strategy

Corpus validation should check:

- root layout contains only accepted durable entries
- every manifest row path resolves inside its corpus area
- every formal source id is covered by `SOURCE_CATALOG.tsv`
- no source catalog row uses `UNKNOWN`, `needs_review`, empty license, or empty
  source
- no formal manifest path references staging, cache, archive, temporary,
  tooling, debug, report, or generated-output path segments
- sidecar resources are intentionally registered when treated as samples
- removed unlicensed sources are removed from manifest, source catalog, payload
  files when unreferenced, and `LICENSES.md`
- consumer scripts read formal manifests and fail clearly when formal corpora
  are unavailable

Quality changes can be checked with `samples/check_quality.sh` for the affected
formats. Benchmark layout changes can be checked with `samples/bench.sh` for the
affected formats and layers.

## Runtime Invariants

- Formal corpus entrypoints are `MANIFEST.tsv` files.
- Every formal sample is covered by source catalog evidence.
- Missing provenance or license evidence blocks formal inclusion.
- Files in staging, cache, archive, temporary, tooling, debug, report, or
  generated-output paths are not formal samples.
- Cleanup tools do not rewrite sample semantics.
- Consumer scripts do not silently fall back to local samples or caches.
- Temporary tools, audit scripts, and cleanup reports are not architecture
  layers.

## Non-goals

This contract does not:

- define the PDF model training layout
- make benchmark results universal performance claims
- provide legal advice
- require public product checks to depend on external corpora
- require retaining legacy staging or archive layouts
- define a one-time cleanup plan
- move files or rewrite scripts by itself

## Change Rules

A corpus change is valid only when formal manifests, source catalogs, payloads,
and provenance summaries remain consistent.

Adding a source requires provenance and license evidence before the source enters
a formal manifest or source catalog.

Removing a source requires removing its manifest rows, removing source catalog
rows, removing payload files when no remaining manifest row references them, and
updating `LICENSES.md` when relevant.

Moving or renaming a payload requires updating the manifest in the same scoped
change. Destructive cleanup should be preceded by an inventory and path
coverage check, but the inventory and cleanup report must not become formal
corpus structure.

Historical migration notes may explain why a rule exists. They must not turn the
contract into a future task list or make staging paths valid consumer inputs.
