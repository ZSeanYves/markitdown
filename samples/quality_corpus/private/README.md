# Private Local Quality Samples

This directory is for local-only quality corpus rows.

Supported file:

* `manifest.local.tsv`
* `files/`

That file is optional and should stay untracked.

Use this area for:

* local real PDFs
* local PPTX/DOCX/XLSX/HTML files
* customer or internal examples that cannot be committed

Rules:

* do not commit private source files
* do not commit `manifest.local.tsv`
* do not commit `files/`
* do not commit generated output from private runs
* keep private outputs under `.tmp/quality_corpus/`

Start from:

* [`manifest.example.tsv`](./manifest.example.tsv)
