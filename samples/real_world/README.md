# Real-World Corpus Skeleton

This directory is reserved for richer complex-scenario samples that are closer
to real document bundles than the repository's smaller feature-isolated
regression cases.

It is intentionally lightweight today:

* no checked-in sample rows yet
* no benchmark claims attached to this corpus by default
* no change to the current H2++ / H3++ evidence basis

## Purpose

Use `samples/real_world/` for:

* synthetic or permissively licensed real-like documents
* multi-structure samples that combine headings, lists, tables, images, notes,
  links, and sectioning in one file
* future richer acceptance and scenario coverage that should remain separate
  from the smaller single-feature regression corpus

Do not use this directory for:

* parser/core unsafe fixtures that belong under `samples/fixtures`
* benchmark-only corpora that belong under `samples/benchmark`
* human comparison narratives that belong under `docs/quality-comparisons`

## Layout

```text
samples/real_world/
  README.md
  manifest.tsv
  input/<format>/
  expected/<format>/
  metadata_expected/<format>/
```

Current checked placeholder format directories are:

* `docx`
* `pptx`
* `xlsx`
* `pdf`
* `html`
* `zip`
* `epub`

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
| `tags` | comma-separated free-form tags |

Current `assets_expected` policy:

* empty: no extra asset validation beyond Markdown diff
* `refs_exist`: require every emitted `assets/...` reference to exist on disk

Future richer asset manifests can be added later if needed, but the current
schema is intentionally minimal.

## Validation

Manifest-only validation:

```bash
./samples/check.sh --manifest-only
```

Full opt-in conversion validation:

```bash
./samples/check.sh --real-world
```

Zero-row manifests are valid and should return:

```text
REAL WORLD SAMPLE MANIFEST OK (0 rows)
```

## Row Example

Example row shape:

```tsv
docx_report	docx	samples/real_world/input/docx/report.docx	samples/real_world/expected/docx/report.md	samples/real_world/metadata_expected/docx/report.metadata.json	refs_exist	richer docx scenario	headings,tables,images
```

This example is illustrative only; no sample row is checked in yet.
