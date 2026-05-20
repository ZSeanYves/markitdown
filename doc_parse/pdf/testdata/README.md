# PDF Testdata

This directory keeps small, repo-tracked PDF fixtures that are required by
main-repo MoonBit tests.

These files are intentionally distinct from the broader external quality corpus
and PDF layout-classifier training/eval assets in `markitdown-quality-lab/`.

Current policy:

* runtime/product code must not depend on `markitdown-quality-lab/`
* MoonBit tests that are part of normal `moon test` should use repo-tracked
  fixtures when the files are small and license-clear
* broader corpora, training sets, eval manifests, and model reports stay in
  `markitdown-quality-lab/`

## pdfjs annotation fixtures

`doc_parse/pdf/testdata/pdfjs/` contains a small subset of Apache-2.0
`pdf.js` test PDFs copied from the quality lab because they are directly
required by:

* `convert/pdf/test/pdf_parse_test.mbt`
* `doc_parse/pdf/test/pdf_model_debug_test.mbt`
* `doc_parse/pdf/raw/mbtpdf_annotation_adapter_wbtest.mbt`
* `doc_parse/pdf/vendor/mbtpdf/io/pdfread/pdfread_object_stream_widget_test.mbt`

Source project:

* https://github.com/mozilla/pdf.js
* license: Apache-2.0

When refreshing these fixtures:

1. update the canonical source copy in `markitdown-quality-lab/corpus`
2. copy only the minimal test-required subset back into this directory
3. do not move training/eval corpora or large fixture sets back into the main
   repository
