# HTML Option 2 Closeout Report

Date: 2026-06-08
HEAD: `4871b3d`
Decision: `Option 2 existing-package refactor`
Status: `parser-owned semantic facts runtime path`

## Summary

HTML did not take the DOCX/PPTX replacement path. It also did not take the XLSX
Option 1 path, where the existing converter already mostly consumed a typed
parser model.

HTML remains on Option 2: keep the existing `doc_parse/html` and `convert/html`
packages, keep the existing dispatcher wiring, and complete the cleanup inside
those packages. The current work built parser-owned semantic facts, guarded
lowering coverage, parity hardening, quarantine/caller audits, and finally the
M11 runtime switch.

After M11, normal HTML runtime is routed through parser-owned semantic facts.
No `doc_parse/html_v2` or `convert/html_v2` package was created. Dispatcher
wiring was not switched. Samples expected output and quality-lab fixtures were
not changed.

## Current Runtime Pipeline

Current normal conversion follows this path:

```text
HTML bytes
 -> UTF-8 text / input provenance
 -> doc_parse/html parse_html_document(text)
 -> parser-owned tolerant DOM/source model
 -> parser-owned semantic facts / warnings / guards
 -> convert/html fact runtime lowering
 -> core Document / Markdown / RichTable / assets / metadata / origins
```

HTML bytes are no longer used by `convert/html` as the source-discovery input
for blocks, inlines, tables, notes, body/scope, noise, images, or links.

`convert/html` may still retain bytes/path context for input provenance, profile
byte counts, UTF-8 input handling, asset source path context, and origin
metadata. It should not use bytes for tag, attribute, table, inline, note, or
body scanning in the normal runtime.

## Single-Scan Parser/Convert Contract

`doc_parse/html` owns:

- tokenizer
- tolerant DOM/source model
- tag, attribute, text, comment, and doctype facts
- body and scope facts
- block, inline, link, image, table, list, blockquote, pre/code, figure, note,
  and noise facts
- malformed and unsupported warnings
- parser and semantic guard facts

`convert/html` owns:

- Markdown and IR lowering
- whitespace and product policy
- RichTable rendering
- image, asset, and origin policy
- note placement policy
- noise skip/preserve policy
- metadata and profile policy

`convert/html` no longer owns normal-runtime:

- raw HTML tag scanning
- raw attribute parsing
- raw table extraction
- raw inline extraction
- raw note discovery
- raw body/scope scanning
- direct tokenization

## Completed Work and Milestones

- M0: architecture contract
- M1: block semantic facts
- M2: inline/link/image facts
- M3: table facts
- M4: list/blockquote/pre/code/figure facts
- M5: unsupported/warning taxonomy
- M6: blockquote + pre/code semantic lowering
- M6.5: paragraph/inline spacing facts
- M7a: paragraph/simple inline lowering
- M7b: heading/safe link paragraph lowering
- M7c: safe list lowering
- M7d: safe image/figure lowering
- M7e: safe simple table lowering
- M8: guard constants + guard reason counters
- M8b: obsolete raw scanner audit map
- M9: parity hardening
- M9.5: notes/footnotes, complex table, scope/body, complex inline/image/link,
  and noise candidate facts
- M10: caller map + quarantine labeling
- M11: parser-owned semantic facts runtime switch

## Parser Semantic Facts

The parser-owned semantic layer now covers:

- block facts
- paragraph facts
- inline facts
- link and image facts
- table facts
- list and list item facts
- blockquote facts
- pre/code facts
- figure and figcaption facts
- notes and footnotes facts
- document scope, body, and malformed-root facts
- product noise candidate facts
- unsupported and warning facts
- guard thresholds and guard summaries

These facts are the structural source for HTML conversion. Convert lowering is
allowed to apply product policy over them, but not to rediscover the same
structure from raw HTML in the normal path.

## Convert Fact Runtime

M11 adds and uses:

```text
convert/html/html_fact_runtime.mbt
```

The main lowering entrypoint is:

```text
html_semantic_document_to_blocks
```

It consumes `@dphtml.HtmlSemanticDocument` and lowers parser facts into core
blocks, metadata, note definitions, asset maps, and origins.

Safe and common structures now lower from parser facts:

- paragraphs and inline text
- headings
- safe links
- images and figures
- lists
- blockquotes
- pre/code blocks
- simple tables

Complex and product-policy behavior is represented through parser facts plus
convert policy, not through convert raw scanning. This includes conservative
table handling, note placement, unsafe or remote image/link behavior, noise
skip/preserve decisions, and product metadata/origin construction.

## Raw Scanner Retirement and Quarantine

The following files are no longer normal-runtime source-discovery paths:

- `convert/html/html_dom.mbt`
- `convert/html/html_inlines.mbt`
- `convert/html/html_table.mbt`
- `convert/html/html_notes.mbt`
- `convert/html/html_bytes.mbt`
- `convert/html/html_tag_attrs.mbt`
- `convert/html/html_noise_rules.mbt`

They still contain quarantine/deletion surfaces and some convert-owned product
helpers. M11 intentionally does not mix full scanner deletion into the runtime
switch closeout.

M11 deleted one isolated obsolete helper:

```text
convert/html/html_bytes.mbt: find_tag_block_inner
```

Focused `moon check` still reports quarantine warnings for:

- `scan_html_nodes_with_skip_ranges`
- `scan_html_notes`
- `HtmlByteRange`
- `nodes_to_blocks`

These are remaining scanner/projection debt. They are not normal-runtime source
discovery after M11 and should be handled in a later scanner deletion or
quarantine cleanup slice.

## Validation

M11 validation status:

```text
moon info && moon fmt
```

Result: passed.

```text
moon check doc_parse/html convert/html
```

Result: passed.

```text
moon test doc_parse/html/tests
```

Result: passed, 47/47 tests.

```text
moon test convert/html/test
```

Result: passed, 61/61 tests.

```text
bash samples/check.sh --format html
```

Result: passed, 111/111 checked.

```text
bash samples/check_quality.sh --format html
```

Result: passed, 2/2 checked.

```text
bash samples/bench.sh --layer convert --format html --iterations 1 --warmup 0
```

Result: passed, median `2562.000ms`.

```text
moon check
```

Result: passed.

Full `moon test` was not run in M11.

Known warnings in the validation snapshot:

- non-HTML EPUB unused-function warning:
  `convert/epub/epub_part_cache.mbt:53`
- non-HTML Markdown deprecated Debug warning:
  `convert/markdown/test/markdown_passthrough_test.mbt:185`
- HTML quarantine warnings listed in the raw scanner quarantine section above

## Boundary Checks

Boundary status after M11:

- No `doc_parse/html_v2` package or directory.
- No `convert/html_v2` package or directory.
- `html_v2` appears only in architecture contract prohibition or acceptance
  text.
- No dispatcher diff.
- No CLI, ZIP, bench, or debug wiring diff.
- No samples expected diff.
- No quality-lab diff.
- No normal-runtime legacy or oracle glue.
- Remaining `fallback` hits are historical docs, test path helpers, fixture
  text, image placeholder/product wording, or documentation wording.
- Remaining `counter` hits are profile/test observability, not runtime oracle
  glue.

## Parity and Non-Goals

M11 preserved HTML sample and quality parity without expected-output updates.

Non-goals for this closeout:

- full browser HTML5 tree builder behavior
- CSS layout or rendering
- JavaScript execution
- remote image fetching
- pixel-perfect rendering
- full accessibility tree
- moving Markdown/RichTable/assets/origin/noise product policy into the parser
- deleting every raw scanner helper in the same runtime switch commit

## Remaining Work

Recommended independent follow-up slices:

- scanner quarantine/deletion after caller cleanup
- notes lowering hardening
- complex table hardening
- malformed/body scope hardening
- complex inline/image/link hardening
- reduce remaining quarantine warnings
- optional full `moon test` cleanup/classification for unrelated failures

## Current Assessment

HTML Option 2 is now satisfied for the normal runtime contract.

Parser is the single source of HTML structure. `doc_parse/html` owns tokenizing,
tolerant DOM/source facts, semantic facts, warnings, and guards. `convert/html`
is the product lowering and policy layer.

No replacement package is needed. Remaining raw scanner surfaces are
quarantine/deletion debt, not normal-runtime source discovery.

## Git Snapshot

Report generation was requested on top of the uncommitted M11 HTML work.

HEAD:

```text
4871b3d
```

Status before generating this report included M11 HTML/docs dirty files:

```text
 M convert/html/html_bytes.mbt
 M convert/html/html_dom.mbt
 M convert/html/html_guards.mbt
 M convert/html/html_inlines.mbt
 M convert/html/html_notes.mbt
 M convert/html/html_parser.mbt
 M convert/html/html_profile.mbt
 M convert/html/html_semantic_lowering.mbt
 M convert/html/html_table.mbt
 M convert/html/html_to_ir.mbt
 M convert/html/test/html_parser_test.mbt
 M doc_parse/html/html_parser.mbt
 M doc_parse/html/html_semantic.mbt
 M doc_parse/html/tests/html_parser_test.mbt
 M docs/archive/html-architecture.md
?? convert/html/html_fact_runtime.mbt
```

After report generation, expected status additionally includes:

```text
?? docs/report/HTML-Option2-closeout.md
```

Staged files should remain empty. This report should not be staged or committed
unless explicitly requested.
