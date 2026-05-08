# Text Normalization Options Audit

This document audits text normalization options for `markitdown-mb`.

It is intentionally not a claim that full Unicode normalization is already
implemented project-wide.

Current intended result:

* separate PDF-specific decode responsibilities from cross-format cleanup
* audit whether `vendor/mbtpdf` already contains reusable Unicode
  normalization capability
* audit current MoonBit ecosystem options before designing new plumbing
* recommend a low-risk layering path that does not spread ad hoc cleanup into
  individual converters
* record current P1 status now that a Unicode normalization backend is wired
  into the project facade

Non-goals of this audit:

* no converter/parser/emitter main-chain rewrite
* no PDF output semantic change
* no moving document-level cleanup into `vendor/mbtpdf`
* no claim of standards-conformant Unicode normalization without conformance
  evidence

## 1. Problem Definition

The repository already has text cleanup logic, but the responsibility boundary
is easy to blur:

* PDF-specific character decode concerns live in the PDF stack
* cross-format text cleanup concerns should be shared at project level
* standards-based Unicode normalization should come from an auditable library
  or a later well-tested implementation

The practical problem is not only PDF.

Future shared needs apply across PDF, DOCX, PPTX, HTML, TXT, Markdown, and
other formats:

* line-ending normalization
* NBSP and Unicode space handling
* zero-width cleanup
* soft hyphen handling
* ligature expansion when appropriate
* optional fullwidth or punctuation compatibility cleanup
* later optional NFC/NFKC standard normalization

The repository already contains a project-level text cleanup substrate in
[`core/text_normalization.mbt`](/Users/winter/Documents/Moonbit/markitdown/core/text_normalization.mbt:1).
That substrate remains the project facade. As of P1, it now also has a wired
Unicode normalization backend for explicit canonical requests, but it still
should not be described as full standards-conformant normalization for the
whole project:

* it supports profile-based cleanup for `PdfText`, `PdfCompareText`,
  `HtmlText`, `OoxmlText`, and others
* it now exposes direct facade helpers for `NFD/NFC/NFKD/NFKC` and
  `is_normalized`-style checks
* default cleanup profiles still keep canonical normalization disabled unless
  explicitly requested
* conformance evidence is still incomplete because `NormalizationTest.txt`
  coverage has not been added yet

So the current design question is:

* keep decode in the PDF layer
* keep shared cleanup in the project text layer
* decide whether a true NFC/NFKC engine should be adopted now, wrapped later,
  or deferred

## 2. Existing Repository State

Current shared cleanup is already centralized more than the older PDF-only
mental model suggests.

Relevant current files:

* [`core/text_normalization.mbt`](/Users/winter/Documents/Moonbit/markitdown/core/text_normalization.mbt:1)
* [`core/test/text_normalization_test.mbt`](/Users/winter/Documents/Moonbit/markitdown/core/test/text_normalization_test.mbt:1)
* [`doc_parse/pdf/text/unicode_compat.mbt`](/Users/winter/Documents/Moonbit/markitdown/doc_parse/pdf/text/unicode_compat.mbt:1)
* [`convert/pdf/pdf_text_compare.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_text_compare.mbt:1)
* [`convert/pdf/pdf_noise.mbt`](/Users/winter/Documents/Moonbit/markitdown/convert/pdf/pdf_noise.mbt:170)

What the current core layer already does:

* line-ending normalization
* optional NBSP normalization
* optional Unicode space normalization
* optional zero-width removal
* optional soft hyphen removal
* optional ligature expansion
* optional quote and dash normalization
* optional fullwidth and CJK punctuation normalization
* PDF-private glyph fallback
* stronger PDF comparison cleanup profile
* explicit facade-backed `NFD/NFC/NFKD/NFKC` through `tonyfettes/unicode`

What it explicitly does not do yet:

* conformance-tested Unicode normalization
* project-wide default canonical normalization in converter behavior
* standards-conformance claims backed by `NormalizationTest.txt`

That existing substrate is the right place for the project facade. The backend
for explicit canonical normalization is now wired, but the next step is still
to improve verification rather than re-spread rules across converters.

## 3. Layering Decision

The clean responsibility split should be:

### 3.1 PDF decoding layer

Owned by `vendor/mbtpdf` and the PDF lower layer.

Responsibilities:

* `ToUnicode` parsing
* CMap parsing
* PDF font encoding handling
* glyph-name to Unicode mapping
* PDFDocEncoding and related decode paths
* raw PDF text bytes to decoded Unicode text

### 3.2 Document text cleanup layer

Owned by project-level text normalization facade.

Responsibilities:

* NBSP cleanup
* Unicode space cleanup
* zero-width cleanup
* soft hyphen cleanup
* ligature cleanup where format/profile permits
* CRLF normalization
* whitespace collapse for comparison-oriented profiles
* optional fullwidth and punctuation cleanup

### 3.3 Unicode normalization layer

Owned by an auditable normalization backend, wrapped by the project facade.

Responsibilities:

* NFC
* NFD
* NFKC
* NFKD
* `is_normalized`-style checks if available
* later conformance validation against normalization test data

Key rule:

* even when PDF extraction uses `ToUnicode` or CMap, document-level cleanup
  must remain outside `vendor/mbtpdf`

## 4. Part A: `vendor/mbtpdf` Audit

### 4.1 Summary

`vendor/mbtpdf` does not currently provide general Unicode normalization such
as NFC/NFD/NFKC/NFKD.

It does provide substantial PDF text decoding capability, including:

* `/ToUnicode` CMap parsing
* PDF font encoding resolution
* glyph-name to Unicode mapping
* PDFDocEncoding and UTF decode helpers
* text extractor logic that applies font decode during PDF text extraction

So `mbtpdf` is already the right place for PDF raw/text decoding, but not the
right place for cross-format cleanup.

### 4.2 Evidence: no general normalization engine

Search hits for `normalize` in `vendor/mbtpdf` mostly refer to unrelated local
normalization such as PDF name normalization or width handling, not Unicode
normalization forms.

No audited file in `vendor/mbtpdf` exposed:

* NFC
* NFD
* NFKC
* NFKD
* generic `normalize(form, text)`
* `is_normalized`
* decomposition/composition algorithms for Unicode text normalization

### 4.3 Evidence: PDF decode capability exists

Audited files:

* [`vendor/mbtpdf/font/pdfcmap/pdfcmap.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/font/pdfcmap/pdfcmap.mbt:1)
* [`vendor/mbtpdf/font/pdfcmap/README.mbt.md`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/font/pdfcmap/README.mbt.md:1)
* [`vendor/mbtpdf/font/pdffont/encoding.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/font/pdffont/encoding.mbt:1)
* [`vendor/mbtpdf/font/pdfglyphlist/pdfglyphlist.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/font/pdfglyphlist/pdfglyphlist.mbt:1)
* [`vendor/mbtpdf/text/pdftext/read.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/text/pdftext/read.mbt:350)
* [`vendor/mbtpdf/text/pdftext/extract.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/text/pdftext/extract.mbt:1)
* [`vendor/mbtpdf/text/pdftext/text.mbt`](/Users/winter/Documents/Moonbit/markitdown/vendor/mbtpdf/text/pdftext/text.mbt:1)

Observed capabilities:

* `font/pdfcmap` parses `/ToUnicode` CMaps and maps character codes to Unicode
  strings
* `text/pdftext/read.mbt` reads font encodings, descendant CID font data, and
  attaches parsed `ToUnicode` maps to font descriptors
* `font/pdffont/encoding.mbt` constructs encoding tables for Standard,
  MacRoman, WinAnsi, MacExpert, custom differences, and fill-undefined cases
* `font/pdfglyphlist` embeds Adobe glyph-list mappings and standard encoding
  tables
* `text/pdftext/extract.mbt` decodes PDF text strings through current font
  extractors and converts codepoints to UTF-8

This is exactly the kind of PDF-specific decoding that should remain in
`mbtpdf`.

### 4.4 What should stay in `mbtpdf`

Keep these responsibilities in `vendor/mbtpdf`:

* raw PDF string decoding
* font encoding interpretation
* `/ToUnicode` and CMap parsing
* glyph-name mapping
* PDFDocEncoding conversions
* PDF-specific predefined CMap handling

These tasks depend on PDF internals and belong close to font and extractor
logic.

### 4.5 What should not move into `mbtpdf`

Do not move these into `vendor/mbtpdf`:

* generic NBSP cleanup
* generic soft hyphen cleanup across formats
* zero-width cleanup across formats
* fullwidth compatibility folding shared by TXT/HTML/OOXML/PDF
* profile-based comparison cleanup
* future general NFC/NFKC facade

Reason:

* they are document-level, cross-format concerns
* pushing them into `mbtpdf` would couple PDF lower-layer decode with
  higher-level text policy
* the same cleanup policies are already useful outside PDF

## 5. Part B: MoonBit Library Audit

## 5.1 `tonyfettes/unicode@0.3.0`

### Summary

`tonyfettes/unicode` is the only audited MoonBit package in this round that
looks like a real Unicode normalization candidate.

It appears usable as a backend for a project facade.

### What it provides

Audited files:

* `.tmp/text_normalization_audit/audit/.mooncakes/tonyfettes/unicode/normalization/normalization.mbt`
* `.tmp/text_normalization_audit/audit/.mooncakes/tonyfettes/unicode/normalization/decomposition.mbt`
* `.tmp/text_normalization_audit/audit/.mooncakes/tonyfettes/unicode/normalization/composition.mbt`
* `.tmp/text_normalization_audit/audit/.mooncakes/tonyfettes/unicode/normalization/canonical_order.mbt`
* `.tmp/text_normalization_audit/audit/.mooncakes/tonyfettes/unicode/normalization/hangul.mbt`
* `.tmp/text_normalization_audit/audit/.mooncakes/tonyfettes/unicode/internal/ucd/decomposition.mbt`
* `.tmp/text_normalization_audit/audit/.mooncakes/tonyfettes/unicode/internal/ucd/composition.mbt`
* `.tmp/text_normalization_audit/audit/.mooncakes/tonyfettes/unicode/internal/ucd/ccc.mbt`

Confirmed API:

* `nfd`
* `nfc`
* `nfkd`
* `nfkc`
* `normalize(s, form)`
* `is_normalized(s, form)`

Confirmed normalization-form enum:

* `NFD`
* `NFC`
* `NFKD`
* `NFKC`

Confirmed implementation ingredients:

* canonical decomposition lookup
* compatibility decomposition lookup
* canonical combining class lookup and reordering
* canonical composition lookup
* Hangul algorithmic decomposition and composition
* embedded Unicode data tables

### Key capability checks

The package structure and implementation support the audit targets:

* composed/decomposed accents:
  * `nfd("é") -> "e + combining acute"` is consistent with implementation
  * `nfc("e + combining acute") -> "é"` is supported by decomposition +
    composition flow
* ligature compatibility decomposition:
  * `nfkd`/`nfkc` use compatibility decomposition
  * compatibility tables include mappings such as ligature forms
* fullwidth forms:
  * compatibility decomposition tables include fullwidth code points
  * `nfkc("Ａ") -> "A"` is the intended behavior

We also verified the practical source relationship:

* `sennenki/slugify` depends on `tonyfettes/unicode/normalization`
* its README and implementation both state normalization is `NFKD`

### Tests and conformance evidence

Strengths:

* the implementation is nontrivial and structured like a true normalization
  library
* the package is used by its own `idna` module, which relies on `nfc` and
  `is_normalized`

Weaknesses:

* during this audit we did not find checked-in blackbox/whitebox test files in
  the downloaded package tree
* we did not find `NormalizationTest.txt`
* we did not find equivalent conformance fixtures shipped with the package

Conclusion:

* it is promising and probably the strongest native MoonBit option found
* it is not yet enough to justify claiming conformance without project-side
  verification

### License and project fit

Confirmed metadata:

* license: Apache-2.0
* repository: `https://github.com/moonbit-community/tonyfettes-unicode`

Project fit:

* fetched successfully through `moon add` in an isolated temp project
* package layout is normal MoonBit package structure
* no immediate native-target incompatibility was found during audit

### Recommendation on `tonyfettes/unicode`

Recommended usage pattern:

* wrap it behind internal project facade functions
* do not call it directly from converters
* gate standards claims behind project-owned conformance tests

Current project status:

* this recommendation has now been applied in P1
* the backend is wired into `core/text_normalization.mbt`
* explicit canonical facade APIs now call the backend instead of a warning-only
  placeholder
* converters still should not import `tonyfettes/unicode` directly

## 5.2 `sennenki/slugify`

### Summary

`sennenki/slugify` is not a normalization backend.

It is useful as evidence that another MoonBit package already trusts
`tonyfettes/unicode` for NFKD.

### NFKD source

Audited files:

* `.tmp/text_normalization_audit/audit/.mooncakes/sennenki/slugify/moon.mod.json`
* `.tmp/text_normalization_audit/audit/.mooncakes/sennenki/slugify/moon.pkg`
* `.tmp/text_normalization_audit/audit/.mooncakes/sennenki/slugify/slugify.mbt`
* `.tmp/text_normalization_audit/audit/.mooncakes/sennenki/slugify/README.mbt.md`

Confirmed facts:

* `moon.mod.json` depends on `tonyfettes/unicode = 0.3.0`
* `moon.pkg` imports `"tonyfettes/unicode/normalization" @normalization`
* `slugify.mbt` calls `@normalization.nfkd(input)` in `normalize_for_slug`
* it strips combining marks after normalization

Therefore:

* its NFKD is not self-implemented
* its NFKD source is `tonyfettes/unicode`

### Why this matters

This is good ecosystem evidence:

* the normalization package is already being consumed by another MoonBit
  package
* that consumption pattern is exactly "normalize first, then apply
  domain-specific cleanup"

That is also the right shape for `markitdown-mb`.

## 5.3 `kesmeey/unicodeUtil`

### Summary

`unicodeUtil` is a character-property and case utility toolkit, not a Unicode
normalization engine.

### What it is useful for

Audited files:

* `.tmp/text_normalization_audit/audit/.mooncakes/kesmeey/unicodeUtil/README.md`
* `.tmp/text_normalization_audit/audit/.mooncakes/kesmeey/unicodeUtil/src/lib/unicodeUtil.mbt`
* `.tmp/text_normalization_audit/audit/.mooncakes/kesmeey/unicodeUtil/src/lib/unicodeUtil_test.mbt`

Useful helper scenarios:

* `is_mark` when stripping combining marks after decomposition
* `is_space`, `is_punct`, `is_control`, `is_letter`, `is_number` style
  property checks
* Unicode-aware case conversion for some scenarios
* character-category predicates for cleanup heuristics

### Why it is not a normalization solution

Not found during audit:

* NFC/NFD/NFKC/NFKD API
* decomposition/composition engine
* generic `normalize(form, text)`
* `is_normalized`
* Unicode normalization conformance assets

So:

* it may help some cleanup heuristics
* it should not be mistaken for the main normalization algorithm

## 5.4 `unicodewidth.mbt`

No mature MoonBit-native normalization package was found in this audit under a
`unicodewidth`-style direction.

Conceptually:

* width libraries implement width/display-width style concerns such as UAX #11
* they do not solve Unicode normalization

Even if a width helper is available later, it belongs to formatting and layout
logic, not normalization core.

## 6. Candidate Options

## 6.1 Option A: rely on `vendor/mbtpdf`

Status:

* reject as the primary normalization strategy

Reason:

* `mbtpdf` is good at PDF decode, not generic cross-format normalization

Use only for:

* PDF raw/text decoding
* `ToUnicode`/CMap/font/glyph handling

## 6.2 Option B: wrap `tonyfettes/unicode`

Status:

* strongest current MoonBit-native option found

Pros:

* real normalization forms exposed
* UCD tables embedded
* `normalize` and `is_normalized` exist
* already reused by another MoonBit package
* Apache-2.0

Cons:

* no conformance evidence found in package tree during this audit
* project must add its own verification before claiming standards conformance

Recommended use:

* internal facade only
* not direct converter dependency

## 6.3 Option C: use `unicodeUtil` as helper only

Status:

* useful helper, not primary solution

Pros:

* property predicates can support cleanup

Cons:

* no normalization engine

Recommended use:

* optional supplemental helper only

## 6.4 Option D: keep only current project cleanup facade

Status:

* valid P0 fallback

Pros:

* already in repo
* already shared
* already profile-driven
* low risk

Cons:

* cannot honestly claim standard Unicode normalization
* if used as the only fallback baseline, it would not provide real
  NFC/NFKC canonical normalization

Recommended use:

* immediate baseline if third-party adoption is deferred

## 6.5 Option E: port Rust `unicode-normalization`

Status:

* justified only if stronger standards confidence is required and third-party
  MoonBit package evidence remains insufficient

Pros:

* likely stronger maturity and ecosystem trust
* clear route to conformance-oriented validation

Cons:

* highest implementation and maintenance cost
* unnecessary as first move if `tonyfettes/unicode` is acceptable behind a
  facade

Required bar:

* ship project-side conformance validation with `NormalizationTest.txt` or
  equivalent corpus

## 7. Recommended Route

Recommended staged path:

### Stage 1

Keep current project-level cleanup facade as the policy layer.

Meaning:

* continue using `core/text_normalization.mbt` as the cross-format surface
* do not push cleanup rules down into `vendor/mbtpdf`
* do not wire third-party Unicode APIs directly into converters

### Stage 2

If dependency adoption is acceptable, add `tonyfettes/unicode` behind the
facade.

Meaning:

* implement internal adapter functions for true NFC/NFD/NFKC/NFKD
* keep current cleanup profiles unchanged in public shape
* swap canonical normalization stage from warning-only to real implementation
  through one internal layer

Current status:

* completed in P1 for facade-level explicit canonical normalization
* not yet elevated to a conformance claim

### Stage 3

Add project-owned verification before making stronger standards claims.

Minimum bar:

* accent compose/decompose cases
* ligature compatibility cases
* fullwidth compatibility cases
* Hangul cases
* project-integrated normalization regression tests

Gold bar:

* `NormalizationTest.txt` or equivalent conformance corpus

### Stage 4

Only if Stage 2 is not sufficient, consider porting Rust
`unicode-normalization`.

Use this path when:

* MoonBit package quality is insufficient
* conformance gaps matter materially
* long-term ownership cost is justified

## 8. Answer to the Audit Questions

### 8.1 Did `mbtpdf` already have Unicode normalization?

No.

It has PDF decode machinery, not a general Unicode normalization engine.

### 8.2 Did `mbtpdf` already have PDF text decode capability such as
`ToUnicode`/CMap/font encoding?

Yes.

That capability is substantial and should remain there.

### 8.3 Which abilities should stay in `mbtpdf`?

Keep:

* `ToUnicode`
* CMap
* font encoding
* glyph-name mapping
* PDF string decoding

### 8.4 Which abilities should live in the project text normalization layer?

Keep at project level:

* NBSP cleanup
* zero-width cleanup
* soft hyphen cleanup
* ligature cleanup policy
* line-ending cleanup
* profile-based comparison cleanup
* future wrapped NFC/NFKC integration

### 8.5 Is `tonyfettes/unicode` usable?

Yes, with caution.

Usable as an internal backend candidate:

* provides `NFC/NFD/NFKC/NFKD`
* provides `normalize`
* provides `is_normalized`
* ships embedded Unicode data tables

But:

* do not claim standards conformance yet
* add project-side conformance tests first

### 8.6 Where does `sennenki/slugify` get NFKD from?

From `tonyfettes/unicode/normalization`.

### 8.7 What can `unicodeUtil` help with?

Helper-only scenarios:

* combining-mark detection
* Unicode property checks
* case and character-category heuristics

Not:

* main normalization engine

### 8.8 Was a mature MoonBit-native solution found?

Partially.

Best candidate found:

* `tonyfettes/unicode`

But "mature enough to claim conformance immediately" was not established during
this audit because conformance fixtures/tests were not found in the package
tree.

### 8.9 Is a Rust `unicode-normalization` port recommended now?

Not as the first step.

Recommended only if:

* `tonyfettes/unicode` adoption is rejected
* or conformance requirements outgrow confidence in the MoonBit package

## 9. Final Recommendation

Recommended policy:

* keep PDF decoding in `mbtpdf`
* keep shared cleanup in the existing project text facade
* prefer wrapping `tonyfettes/unicode` behind that facade
* do not expose third-party normalization APIs directly in converters
* do not claim full Unicode normalization until conformance tests are added

Current implementation note:

* the facade backend is now connected to `tonyfettes/unicode`
* cleanup and canonical normalization remain separate layers
* default converter behavior should remain unchanged because default profiles
  still keep canonical normalization disabled

If dependency adoption is blocked:

* continue with current `text_cleanup`-style facade as P0
* describe it as cleanup, not full Unicode normalization

If future standards pressure increases:

* port Rust `unicode-normalization`
* validate against `NormalizationTest.txt`
