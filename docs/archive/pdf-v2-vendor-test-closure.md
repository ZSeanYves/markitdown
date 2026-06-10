# PDF v2 Vendor Test Closure

This note records the PDF v2 vendor test-closure trimming policy for the local
`doc_parse/pdf/vendor/mbtpdf` copy.

## Why

`mbtpdf` is treated as a vendored PDF substrate. The main repository should keep
tests that protect local modifications and PDF v2 consumption contracts, but it
should not run every upstream-only writer, debug, filesystem, and standalone
library regression as part of normal PDF v2 work.

## Deletion Principles

- Keep replacement contract tests added for PDF v2.
- Keep real widget fixture coverage until a smaller facade-level test replaces
  it.
- Keep text/font, CMap/ToUnicode, GBK, malformed-reader, image/vector, and
  annotation/form tests until their PDF v2 contracts are narrower.
- Delete only tests that exercise upstream-only writer, root facade, filesystem,
  debug, or page-output editing behavior.
- Do not change vendor runtime behavior while trimming test closure.

## Batch 1 Deleted Tests

- `doc_parse/pdf/vendor/mbtpdf/core/pdfio/pdfio_debug_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_ops_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_pdf_of_pages_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/io/pdfiofs/pdfiofs_channel_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/io/pdfwrite/pdfwrite_encrypt_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/io/pdfwrite/pdfwrite_extra_wbtest.mbt`
- `doc_parse/pdf/vendor/mbtpdf/io/pdfwrite/pdfwrite_roundtrip_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/io/pdfwrite/pdfwrite_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/mbtpdf_test.mbt`

These tests cover writer-only output, file/channel helpers, debug helpers, root
facade file IO, and page-output editing flows. They are not direct PDF v2 parser
or facade contract coverage.

## Replacement Coverage Kept

- `doc_parse/pdf/vendor/mbtpdf/io/pdfread/pdfread_replacement_contract_wbtest.mbt`
- `doc_parse/pdf/vendor/mbtpdf/graphics/pdfops/pdfops_source_contract_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/font/pdfcmap/pdfcmap_replacement_contract_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/text/pdftextread/pdftext_replacement_contract_test.mbt`

These protect compact object-stream widget boundaries, source-attributed content
ops, ToUnicode/CMap essentials, GBK fallback, ToUnicode precedence, and strict
malformed-reader behavior.

## Intentionally Kept For Now

- `doc_parse/pdf/vendor/mbtpdf/io/pdfread/pdfread_object_stream_widget_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/io/pdfread/pdfread_malformed*.mbt`
- `doc_parse/pdf/vendor/mbtpdf/text/pdftextread/*_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/font/pdfcmap/*_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/graphics/pdfops/*_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/graphics/pdfimage/*_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfdest/*_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_targets_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_xobject_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_change_extra_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_fixups_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_prefix_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_renumber_test.mbt`

These either protect local reader/text behavior, source attribution, image/vector
or annotation/form facts, or are still mixed with behavior that needs a narrower
replacement before deletion.

## Later Batches

- Split page editing tests that mix link/annotation/resource behavior before
  deleting writer-only portions.
- Add image metadata and annotation/form geometry contract tests before trimming
  broader image/page/document tests.
- Consider a separate optional vendor-slow lane for cryptographic and codec
  exhaustiveness if those tests are removed from normal development closure.

## Phase 1.5e Object-Facts Contracts

This batch adds narrow, synthetic object-facts contracts before deleting more
mixed page/document tests. The new tests are:

- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_object_facts_contract_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/graphics/pdfimage/pdfimage_metadata_contract_test.mbt`

They cover these PDF v2 substrate facts:

- Page `MediaBox`, `CropBox`, `Rotate`, and raw `UserUnit` reachability.
- Inherited page `Resources` and `XObject` references for form and image
  objects.
- Link annotation `/Annots`, `/Subtype /Link`, `/Rect`, and URI action facts.
- Widget annotation and catalog `AcroForm` basics: `/Fields`, `/T`, `/TU`, `/V`,
  `/Rect`, and `/AP` reference reachability.
- Outline title plus destination target facts through `pdfmarks` and `pdfdest`.
- Image XObject metadata: `/Width`, `/Height`, `/ColorSpace`,
  `/BitsPerComponent`, `/Filter`, and resource object reference.

These contracts prepare a later trim of mixed page/document tests that primarily
exercise upstream page editing, bookmark writing, or broad document manipulation
while also incidentally touching the facts above.

Known gaps and intentionally deferred scope:

- `UserUnit` is not a typed `Page` field today; the contract records that it is
  still available in `Page.rest`.
- Image metadata is covered without decoding image payload bytes.
- Outline coverage is a title/destination smoke contract, not full nested
  outline mutation coverage.
- Complex page editing, page extraction, renumbering, and duplicate fixup flows
  still require their current mixed tests until narrower replacement contracts
  exist.

Do not delete these groups yet:

- Real widget fixture e2e coverage.
- Text/font, CMap/ToUnicode, GBK, malformed-reader, and source-attribution
  tests.
- Image/vector decoding tests.
- Annotation/form tests beyond the raw object-facts contract.
- Complex page/resource inheritance, page fixup, and page renumbering tests.

Future deletion conditions:

- Keep only page/document tests that protect local runtime contracts, PDF v2 raw
  bridge facts, malformed input behavior, or fixtures not yet expressible by a
  smaller synthetic test.
- Delete mixed upstream tests only after their parser-facing facts are covered by
  small object-facts contracts or are confirmed irrelevant to PDF v2.
- Continue trimming in small batches with targeted `moon test` validation.
