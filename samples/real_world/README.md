# Real-World Corpus

This directory now holds a complex-only checked-in `real_world` corpus:
long-form or stress-style scenario samples that sit alongside the repository's
smaller feature-focused `main_process` regressions.
It is the `0.3.3` release-line checked scenario set for richer real-like
coverage, not a benchmark corpus.

Current status:

* 11 checked-in rows in `manifest.tsv`
* complex-only coverage across DOCX, PPTX, XLSX, PDF, HTML, ZIP, and EPUB
* metadata sidecar fixtures checked in for every row
* asset-reference existence checks enabled for asset-producing rows
* no benchmark claims attached to this corpus by default
* no change to the sealed H2++ / H3++ evidence basis

## Purpose

Use `samples/real_world/` for:

* synthetic or permissively licensed real-like documents
* long-form or noisy scenario coverage that should remain separate from the
  smaller single-feature regression corpus
* richer acceptance-style files that combine headings, lists, tables, images,
  notes, links, and sectioning in one file

Do not use this directory for:

* parser/core unsafe fixtures that belong under `samples/fixtures`
* benchmark-only corpora that belong under `samples/benchmark`
* human comparison narratives that belong under
  `docs/quality-comparisons`

## Layout

```text
samples/real_world/
  README.md
  manifest.tsv
  input/<format>/
  expected/<format>/
  metadata_expected/<format>/
```

Current checked format directories are:

* `docx`
* `pptx`
* `xlsx`
* `pdf`
* `html`
* `zip`
* `epub`

## Current Rows

| ID | Format | Focus |
| --- | --- | --- |
| `complex_docx_technical_whitepaper` | DOCX | long-form whitepaper with repeated figures, tables, nested lists, code, links, and text boxes |
| `complex_docx_review_feedback_packet` | DOCX | denser review packet with many footnotes and reviewer comments |
| `complex_pptx_investor_product_deck` | PPTX | 16-slide deck with notes, cards, table, links, hidden slide, and image appendix |
| `complex_xlsx_financial_operations_workbook` | XLSX | large multi-sheet workbook with overview and operational tables |
| `complex_xlsx_formula_audit_workbook` | XLSX | long formula-audit workbook with lightweight evaluation and missing-cache rows |
| `complex_xlsx_merged_sparse_assumptions_workbook` | XLSX | merged-cell and sparse-coverage policy workbook |
| `complex_pdf_text_whitepaper` | PDF | long text-PDF pack covering heading cleanup, cross-page merge, table-like output, URI links, and noise boundaries |
| `complex_html_documentation_site_page` | HTML | long documentation page with nav noise, callouts, tables, code, unsafe-link boundaries, and local figures |
| `complex_epub_training_manual` | EPUB | multi-chapter training manual with cover, nav, NCX, tables, lists, and anchor references |
| `complex_zip_project_export` | ZIP | project export with nested DOCX, PPTX, XLSX, HTML, data files, hidden entries, unsupported binary, and nested archive boundary |
| `complex_zip_structured_data_bundle` | ZIP | structured-data archive with CSV, TSV, JSON, YAML, XML, Markdown, text, and nested archive boundary |

## Manifest Schema

`manifest.tsv` uses the following columns:

| Column | Meaning |
| --- | --- |
| `id` | stable row id |
| `format` | format family |
| `input` | checked-in sample input path |
| `expected` | expected Markdown path |
| `metadata_expected` | optional expected metadata JSON path |
| `assets_expected` | optional asset policy token; current supported value is `refs_exist` |
| `description` | short human-readable description |
| `tags` | comma-separated free-form tags used for focused reruns |

Current `assets_expected` policy:

* empty: no extra asset validation beyond Markdown diff
* `refs_exist`: require every emitted `assets/...` reference to exist on disk

## Validation

Manifest-only validation:

```bash
./samples/check.sh --manifest-only
```

Full real-world validation:

```bash
./samples/check.sh --real-world
```

Focused complex rerun:

```bash
./samples/check.sh --real-world --tags complex
./samples/scripts/check_real_world.sh --tags complex
```

The default `./samples/check.sh` chain also runs the full real-world corpus.
The current 11-row set remains light enough to keep in the default validation
path.

## Notes

* the real-world corpus complements `main_process`; it does not replace it
* the real-world corpus is not a benchmark corpus
* complex rows do not widen H3++ performance claims by themselves
