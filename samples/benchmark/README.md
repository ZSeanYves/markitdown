# Benchmark Corpus Policy

This directory holds the repository's checked-in benchmark manifests, synthetic
benchmark samples, and warning-policy files.

It is intentionally not a dumping ground for every interesting local document.

## Corpus Tiers

### Tier 0: Regression samples

Location:

* `samples/main_process`
* `samples/metadata`
* `samples/assets`

Purpose:

* correctness and golden-output regression
* H2/H3 behavior protection

Rules:

* checked in
* small and explainable
* every sample should have a clear intent

### Tier 1: Benchmark smoke corpus

Location:

* `samples/benchmark/corpus.tsv`
* files under `samples/benchmark/<format>/...`

Purpose:

* stable same-machine smoke signals
* conservative warning coverage through `bench_warn`

Rules:

* checked in
* size-conscious
* optimized for stable signals, not for full real-world coverage

### Tier 2: Synthetic stress corpus

Typical shape:

* generated large rows
* many-entry archives
* large sheets
* nested structured data

Preferred storage policy:

* keep generators, manifests, or documented parameters where possible
* avoid checking in large binary artifacts unless they are clearly justified
* record generation seed/parameters when a synthetic sample matters to a
  benchmark story

### Tier 3: Real-world public corpus

Preferred shape:

* external/manual corpus manifest
* public provenance and license clarity
* locally downloaded and manually managed

Recommended manifest shape:

* `samples/benchmark/external_corpus.tsv` or a local derivative of
  `corpus_manifest.example.tsv`

Rules:

* do not commit large public corpora casually
* keep license and provenance explicit
* decide daily/pre-release participation intentionally

### Tier 4: Private/manual corpus

Purpose:

* local profiling on confidential or customer-shaped inputs
* one-off investigations

Rules:

* do not commit private corpora
* do not write private benchmark conclusions as universal claims
* summarize findings in docs without shipping sensitive inputs

## Checked-in Files

Current checked-in benchmark control files:

* `corpus.tsv`
* `compare_corpus.tsv`
* `perf_thresholds.tsv`
* `corpus_manifest.example.tsv`
* `../scripts/check_corpus_manifest.sh`

Role of each checked-in control:

* `corpus.tsv`: checked-in Tier 1 smoke/image/metadata/extended benchmark rows
* `compare_corpus.tsv`: overlap-only comparison rows against Microsoft
  MarkItDown; it is not a blanket support-parity list
* `perf_thresholds.tsv`: conservative local warning thresholds for selected
  suites/rows
* `corpus_manifest.example.tsv`: template for public/private/manual corpus
  manifests

For runner classes, comparability policy, and raw result-field expectations,
see [docs/benchmark-governance.md](../../docs/benchmark-governance.md).

## Manifest Checker

Validate the checked-in example manifest:

```bash
./samples/scripts/check_corpus_manifest.sh
./samples/scripts/check_corpus_manifest.sh samples/benchmark/corpus_manifest.example.tsv
```

The checker is intentionally a light governance helper:

* offline
* local-only
* not part of the default `samples/check.sh` contract today
* suitable for validating future public/private/manual manifest additions

Manifest fields:

```text
id	format	tier	path_or_uri	size_bytes	license	provenance	include_daily	include_pre_release	notes
```

Field notes:

* `id`: unique stable manifest id
* `format`: repository format family or `mixed`
* `tier`: `regression`, `smoke`, `synthetic`, `public`, `private`, `manual`
* `path_or_uri`: repo path, local path, or URL depending on the tier
* `size_bytes`: optional non-negative integer when known
* `license`: explicit provenance/license marker
* `provenance`: how the row entered the workflow
* `include_daily` / `include_pre_release`: governance-only booleans
* `notes`: optional human context

## How To Add A Benchmark Sample

1. Decide which corpus tier the sample belongs to.
2. Prefer a small, stable checked-in sample for Tier 1.
3. If the sample is large or synthetic, record how it was produced.
4. If the sample is real-world or sensitive, keep it out of the repository and
   use a manifest or local notes instead.
5. Update warning thresholds only when repeated native measurements justify it.

For checked-in smoke samples:

* add the file under `samples/benchmark/<format>/...`
* add or update the row in `corpus.tsv`
* update the example manifest only if it remains a useful checked-in example
* run `./samples/scripts/check_corpus_manifest.sh`

Current XLSX second-round checked-in benchmark additions:

* `xlsx_formula_heavy.xlsx`
* `xlsx_formula_eval_arithmetic.xlsx`
* `xlsx_formula_eval_ranges.xlsx`
* `xlsx_formula_heavy_missing_cache.xlsx`
* `xlsx_formula_unsupported_many.xlsx`
* `xlsx_merged_heavy.xlsx`
* `xlsx_typed_cells.xlsx`

These rows are intended to support the XLSX H2++ / H3++ sprint:

* cached-formula policy
* lightweight missing-cache formula evaluation v1
* merged-cell policy
* typed-cell policy

They are still local checked-in engineering corpus rows, not broad market-wide
performance claims by themselves.

Current HTML second-round checked-in benchmark additions:

* `html_link_heavy.html`
* `html_asset_heavy_local.html`
* `html_malformed_common.html`
* HTML metadata rows for `html_metadata_table_links`,
  `html_metadata_span_boundary`, and `html_metadata_unsafe_link_boundary`

These rows are intended to support the HTML H2++ / H3++ sprint:

* safe-link boundary coverage
* local-asset export behavior
* malformed/common HTML degradation behavior
* metadata-on overhead for HTML-specific sidecar rows

They remain checked-in engineering corpus rows, not blanket claims about every
web page or browser-like HTML workload.

Current ZIP second-round checked-in benchmark additions:

* `zip_unsupported_degrade.zip`
* ZIP metadata rows for `zip_metadata_mixed_supported`,
  `zip_metadata_assets_remap`, `zip_metadata_unsupported_entries`, and
  `zip_metadata_nested_archive_boundary`

These rows are intended to support the ZIP H2++ / H3++ sprint:

* mixed supported-entry dispatch and aggregation
* archive asset-remap behavior
* unsupported/nested-archive degrade visibility
* metadata-on overhead for ZIP container sidecars

They are checked-in native corpus rows, not blanket claims about all ZIP
archives and not a promise of fair external overlap comparison.

Current EPUB second-round checked-in benchmark additions:

* `epub_assets_duplicate.epub`
* `epub_ncx_toc.epub`
* `epub_unsupported_degrade.epub`
* EPUB metadata rows for:
  * `epub_metadata_package_rich`
  * `epub_metadata_spine_order`
  * `epub_metadata_nav_toc`
  * `epub_metadata_assets_cover`
  * `epub_metadata_warning_item`
  * `epub_metadata_duplicate_asset_names`

These rows are intended to support the EPUB H2++ / H3++ sprint:

* OPF package/spine ordering
* EPUB3 nav and NCX fallback coverage
* cover/local-asset remap and duplicate asset-name isolation
* warning/degrade behavior for missing/unsupported spine items
* metadata-on overhead for EPUB package/spine/assets sidecars

They are checked-in engineering corpus rows, not blanket claims about every
EPUB reader workload or all ebook conversion paths.

Current DOCX second-round checked-in benchmark additions:

* `docx_table_heavy.docx`
* `docx_link_heavy.docx`
* `docx_image_heavy.docx`
* `docx_notes_comments_heavy.docx`
* DOCX metadata rows for:
  * `docx_metadata_docprops_rich`
  * `docx_metadata_links_images`
  * `docx_metadata_notes_comments`
  * `docx_metadata_table_complex`
  * `docx_metadata_textbox_header_footer`

These rows are intended to support the DOCX H2++ / H3++ sprint:

* nested/style-linked lists and hyperlink-heavy paragraph coverage
* multiline/merged-boundary table coverage
* local image asset export behavior
* notes/comments append-policy overhead
* metadata-on overhead for DOCX document/relationship/asset sidecars

They are checked-in engineering corpus rows, not blanket claims about every
Word document or full layout-engine workloads.

Current PPTX second-round checked-in benchmark additions:

* `pptx_link_heavy.pptx`
* `pptx_notes_heavy.pptx`
* `pptx_layout_heavy.pptx`
* PPTX metadata rows for:
  * `pptx_metadata_docprops_rich`
  * `pptx_metadata_links_images`
  * `pptx_metadata_notes_hidden`
  * `pptx_metadata_table_grid`
  * `pptx_metadata_caption_like`

These rows are intended to support the PPTX H2++ / H3++ sprint:

* slide-order/title/bullet overlap evidence
* hyperlink and local-image asset behavior
* speaker-notes and hidden-slide policy
* callout/grid/layout-heavy heuristic coverage
* metadata-on overhead for PPTX slide/shape/asset provenance

They remain checked-in engineering corpus rows, not blanket claims about all
PowerPoint layouts or full presentation-rendering workloads.

For public/private/manual corpora:

* do not add the real files to the repository
* use a local or external manifest derived from `corpus_manifest.example.tsv`
* keep private paths out of checked-in files

## Warning Policy Reminder

Thresholds in `perf_thresholds.tsv` are conservative manual warnings:

* not a formal SLA
* not a blanket CI hard gate
* intended for native-preferred local runs with local-machine caveats
