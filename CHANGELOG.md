# Changelog

## 0.3.0

This release closes the repository's first full-format H2 milestone.

### Highlights

* All primary formats now have H2-complete support contracts:
  * TXT
  * Markdown
  * CSV / TSV
  * JSON
  * YAML / YML
  * XML
  * HTML / HTM
  * XLSX
  * ZIP
  * EPUB
  * DOCX
  * PPTX
  * PDF
* Multi-format conversion, Markdown output, metadata sidecars, asset export,
  and origin/provenance wiring are now stable project-wide product surfaces.
* Batch conversion v1 is available for non-recursive directory conversion.
* Sample validation scripts were reorganized around:
  * `./samples/check.sh`
  * `./samples/check_main_process.sh`
  * `./samples/check_metadata.sh`
  * `./samples/check_assets.sh`
  * advanced helpers and benchmark tools under `./samples/scripts/`
* Validation now prefers a probe-validated native CLI when available and falls
  back to `moon run` only when needed.
* The PDF lower layer now lives under `doc_parse/pdf`, backed by a
  repository-local maintained fork under `vendor/mbtpdf`.
* Benchmark, batch-profiling, and regression-warning tools are available for
  H3 performance work.

### Notes

* H2 complete does not mean every advanced format-specific feature is fully
  implemented.
* Known limitations remain documented in
  `docs/support-and-limits.md`.
