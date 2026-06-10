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

## Phase 1.5f Mixed Page/Document Test Audit

This audit maps the remaining mixed page/document-adjacent vendor tests against
the Phase 1.5e object-facts contracts. It intentionally does not implement the
raw bridge and does not change runtime source.

Audit scope:

- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage`
- `doc_parse/pdf/vendor/mbtpdf/io/pdfread`
- `doc_parse/pdf/vendor/mbtpdf/graphics/pdfimage`
- `doc_parse/pdf/vendor/mbtpdf/graphics/pdfops`
- `doc_parse/pdf/vendor/mbtpdf/graphics/pdfspace`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfdest`

The focused scan covered 35 test files in those packages:

- `document/pdfpage`: 11 test files.
- `io/pdfread`: 12 test files.
- `graphics/pdfimage`: 3 test files.
- `graphics/pdfops`: 5 test files.
- `graphics/pdfspace`: 3 test files.
- `document/pdfdest`: 1 test file.

Capability mapping:

| Capability | Covered by 1.5e contract? | Still uniquely covered by old test? | Can delete old section/file? | Needs replacement first? | Notes |
|---|---|---|---|---|---|
| Simple page boxes, crop box, rotation | Yes | Yes, for missing mediabox fallback, `/Contents` shapes, malformed kids, and page-tree build errors | No whole-file deletion | Yes, before trimming `pdfpage_pagetree_read_coverage_test.mbt` | 1.5e covers raw facts, not logging, singleton content streams, malformed tree behavior, or build-side errors. |
| Raw `UserUnit` reachability | Yes | No comparable old typed coverage found | No deletion impact | Typed `UserUnit` contract needed before facade migration | 1.5e documents the current `Page.rest` behavior. |
| Inherited resources and simple XObject refs | Yes | Yes, for resource merging, XObject stream mutation, missing subtype errors, and non-indirect reference failures | No whole-file deletion | Replacement needed for process/merge behavior before trimming `pdfpage_xobject_test.mbt` | 1.5e only protects reachability of form/image refs. |
| Link annotation URI and rectangle smoke | Yes | Yes, for `change_pages` destination transforms, OpenAction rewriting, annotation action rewriting, unsupported action logging, and matrix handling | No whole-file deletion | Change-page/link transform contracts needed first | 1.5e protects object facts, not page editing behavior. |
| Widget and AcroForm basic facts | Yes | Yes, real object-stream widget e2e and compact object stream parsing remain unique | No | Keep existing replacement and widget e2e tests | Object-stream parsing is covered by 1.5c; real widget fixture remains intentionally kept. |
| Outline title and simple destination smoke | Yes | Yes, for destination variants, named/string destination resolution, action transforms, clipping, name-tree resolution, and nested bookmark behavior | No | Rich destination/outline contracts needed before trimming `pdfdest_test.mbt` or bookmark tests | 1.5e is only a smoke contract. |
| Image XObject metadata | Yes | Yes, for image masks, named color resources, BPC defaults, raw/JPEG/JPX/JBIG2 handling, decode arrays, indexed/ICCBased/Lab/DeviceN, and ToGet streams | No | Image decode and colorspace contracts needed first | 1.5e does not decode bytes. |
| Inline image metadata and bytes in content ops | Partially | Yes, inline images, flate/DCT parsing, malformed inline-image errors, bad filter handling, and trailing operator parsing | No | Inline-image source/event contracts needed first | `pdfops_inline_image_test.mbt` is not replaced by image XObject metadata. |
| Content operator parsing/source attribution | 1.5c covers source attribution | Yes, broad operator parsing, malformed operands, unknown ops, color components, and string emission remain unique | No | Operator parse/error contracts needed before any trim | Do not delete `pdfops_source_contract_test.mbt`. |
| Color space read/write behavior | No, except image metadata uses DeviceRGB | Yes, read/write CalGray, CalRGB, Lab, Indexed, ICCBased, Pattern, Separation, DeviceN, and error branches remain unique | No | Read-only facade contracts needed before write-side split | `pdfspace_write_test.mbt` is write/read oriented but not safely replaced by 1.5e. |
| Page output/editing, prefix, renumber, `pdf_of_pages` | Mostly no | Yes, resource/operator renaming, inline image color-space renaming, page extraction, labels, branch page trees, and content mutation remain unique | Not this round | Decide whether PDF v2 needs these; otherwise move to vendor-slow or delete in later batch | These are likely candidates for future trim, but not by 1.5e alone. |
| Malformed reader behavior | 1.5c has strict smoke | Yes, header, stream, parse, fallback, malformed object, root/trailer, revision, and lexical edge cases remain unique | No | Keep malformed lane | Malformed/source behavior is explicitly protected. |
| Encryption reader behavior | No | Yes | No | Security facade contracts needed first | `pdfread_encryption_test.mbt` is not object-facts coverage. |

Old abilities now covered by object-facts contracts:

- Basic visibility of page `MediaBox`, `CropBox`, `Rotate`, and raw
  `UserUnit`.
- Basic inherited resources and XObject object-reference reachability.
- Basic link annotation `/Annots`, `/Subtype /Link`, `/Rect`, and URI action
  facts.
- Basic widget `/T`, `/TU`, `/V`, `/Rect`, `/AP`, and catalog `AcroForm`
  fields.
- Basic outline title and destination target smoke.
- Basic image XObject metadata and resource object reference.

Abilities still uniquely covered by old tests:

- Page-tree malformed kids, missing mediabox fallback, direct versus indirect
  content stream shapes, root/trailer error handling, page-tree build behavior.
- Page editing and output-side behavior: `change_pages`, `pdf_of_pages`,
  `add_prefix`, `renumber_pages`, `replace_inherit`, `fixup_*`, and
  prepend/postpend content mutation.
- Destination variants and transforms beyond the 1.5e smoke test: named
  destinations, string destinations, action dictionaries, name tree resolution,
  clipping, and malformed destination objects.
- Image decode and color handling: image masks, BPC defaults, DCT/JPX/JBIG2,
  indexed palettes, ICCBased/Lab/DeviceN, decode arrays, ToGet streams, and
  error branches.
- Inline image parsing inside content streams, including filter errors, DCT
  bytes, flate decode, trailing operators, color space lookup, and malformed
  inline-image markers.
- Operator parser edge behavior, unknown operator handling, component parsing,
  string emission, and malformed operands.
- Color space read/write coverage for rich color spaces.
- Malformed reader, xref/header/stream/parser edge behavior, and encryption
  detection.

Deletion decision for Phase 1.5f:

- No test files were deleted in this round.
- No replacement tests were deleted.
- No new replacement tests were added.

Rationale:

- Several old sections duplicate the simple facts covered by 1.5e, but no
  focused file in the audited set is wholly replaced by 1.5e.
- The candidate files that look deletion-friendly at first glance are mixed with
  behavior that still protects local modification or future facade risk.
- Deleting sections inside mixed files would reduce clarity only slightly while
  making later audit harder. Whole-file or clearly isolated deletes should wait
  for narrower contracts or a vendor-slow lane decision.

Next deletion prerequisites:

- Add page-read contracts for missing mediabox fallback, content stream shapes,
  and malformed page-tree kids before trimming page-tree coverage sections.
- Add read-only resource merge and Form XObject source-attribution contracts
  before trimming `pdfpage_xobject_test.mbt`.
- Add destination/outline contracts for named/string destinations, action
  dictionaries, name-tree resolution, and nested outlines before trimming
  `pdfdest_test.mbt` or bookmark-heavy tests.
- Add image decode contracts or explicitly move image decode to vendor-slow
  before trimming `pdfimage_test.mbt` or `pdfimage_e2e_test.mbt`.
- Add inline-image source-event contracts before trimming
  `pdfops_inline_image_test.mbt`.
- Decide whether page editing/output behavior (`change_pages`, `pdf_of_pages`,
  prefix, renumber, fixups) is PDF v2 relevant. If it is not, move it to a
  vendor-slow lane or delete it in a later small batch after documenting that
  the facade does not consume those APIs.
- Keep malformed/source-attribution, object-stream widget, text/font, and
  replacement contract tests until stronger facade contracts exist.

## Phase 1.5g Narrow Mixed-Behavior Contracts

This batch adds small contracts for the mixed page/document behaviors that the
Phase 1.5f audit identified as still unique. It does not delete old tests and
does not change vendor runtime source.

New contracts:

- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_tree_contract_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage/pdfpage_resource_contract_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/document/pdfdest/pdfdest_contract_test.mbt`
- `doc_parse/pdf/vendor/mbtpdf/graphics/pdfops/pdfops_inline_image_contract_test.mbt`

Coverage added:

- Nested page-tree traversal with inherited `MediaBox`, `CropBox`, `Rotate`,
  and `Resources`, stable page order, page count, and fail-closed missing-kid
  behavior.
- Page-local resource override plus explicit local-first resource union through
  `combine_pdf_resources`, including Form XObject object-reference identity.
- Destination arrays for `XYZ`, `Fit`, `FitH`, and `FitV`, plus catalog named
  destinations, name-tree string destinations, and GoTo action `/D` facts.
- Inline image `BI` / `ID` / `EI` source attribution through
  `parse_operators_with_source`, with `W`, `H`, `CS`, `BPC`, and `F` metadata
  preserved without entering a full image decode lane.

1.5f coverage now better isolated:

- Page-tree read facts no longer depend only on broad page-tree coverage tests.
- Resource and Form XObject reference facts no longer depend only on
  XObject-processing mutation tests.
- Destination variant facts no longer depend only on the broad destination test
  file.
- Inline image source events no longer depend only on broader inline image
  parsing and decode tests.

Still not covered by narrow contracts:

- Full image decode behavior, image masks, color conversion, and codec-specific
  payload handling.
- Vector/path semantics and graphics-state interpretation beyond operator
  source events.
- Rich color spaces such as ICCBased, Lab, Indexed, Separation, DeviceN, and
  Pattern.
- Encryption and crypto reader behavior.
- Page editing/output behavior such as `change_pages`, `pdf_of_pages`, prefix,
  renumber, fixups, and content mutation.
- Complex malformed-reader behavior beyond the small page-tree missing-child
  and existing malformed smoke tests.

Next-round options:

- Phase 1.5h can be an image decode lane that separates metadata/source events
  from byte decode, masks, and rich color-space behavior.
- Alternatively, Phase 1.5h can trim a small page editing/output-only batch if
  PDF v2 explicitly does not consume those APIs and the remaining parser-facing
  facts are covered by contracts.
