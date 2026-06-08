# PPTX v2 Replacement Closeout

Date: 2026-06-08
HEAD at path-alignment update: `2d99ea6`

## Summary

PPTX v2 is now folded into the current runtime package paths:

- parser/model: `doc_parse/pptx`
- lowering/product policy: `convert/pptx`

There is no `doc_parse/pptx_v2` or `convert/pptx_v2` package in the current
repository. Older closeout notes described a temporary parallel `_v2` package;
that architecture has been consolidated into the active paths above.

Normal PPTX conversion uses a single parser-owned typed model path:

```text
OOXML package
 -> doc_parse/pptx part graph and typed source/model facts
 -> PptxDocument
 -> convert/pptx Markdown/IR/assets/origin/product policy
```

The converter does not own raw OOXML parsing, slide/package scanning, or
relationship parsing in normal runtime.

## Runtime References

- `convert/convert/dispatcher.mbt`: PPTX dispatch calls `@pptx.parse_pptx`.
- `convert/convert/moon.pkg`: imports `convert/pptx`.
- `convert/zip_core/moon.pkg`: embedded PPTX conversion imports `convert/pptx`.
- `bench/moon.pkg`: product-path bench imports `convert/pptx`.
- `bench/parser_layer/moon.pkg`: parser bench imports `doc_parse/pptx`.
- `debug/debug_app.mbt`: route registry reports `convert/pptx`.
- `convert/pptx/test`: lowering tests target the current `convert/pptx`
  package.
- `doc_parse/pptx/tests`: parser/model tests target the current
  `doc_parse/pptx` package.

## Boundary Status

`doc_parse/pptx` owns:

- OOXML package open and part graph construction
- presentation slide order
- slide/layout/master/notes/comment part traversal
- relationships and media refs
- shape tree, group shapes, geometry, z/source order, placeholders
- notes/comments/comment authors
- chart, SmartArt, OLE, connector, decorative, unsupported, and media warnings
- document properties metadata
- performance budgets for slides, shapes, group depth, relationships, table
  cells/text runs, media refs, layout/master candidates, custom properties, and
  source-node count

`convert/pptx` owns:

- headings and Markdown/IR lowering
- slide/comment/note placement
- RichTable/product rendering choices
- image asset export and origin metadata
- unsupported placeholder wording
- product metadata projection

## Raw Scan Audit

`convert/pptx` grep for normal-runtime raw OOXML scanners found no structural
parser path. Hits for `ppt/presentation.xml`, `ppt/slides`, `ppt/notesSlides`,
`.rels`, and relationship XML are in `convert/pptx/test` fixture construction.

The normal lowering entrypoint consumes `@pptxdoc.PptxDocument`; it does not
read `ppt/...` parts or parse XML to recover missing facts.

## Runtime Glue Audit

- No duplicate PPTX runtime path was found.
- No normal runtime v1, oracle, hidden fallback, or compare path was found.
- `fallback`, `legacy`, `counter`, and `v2` wording is limited to docs/tests or
  product/profile terminology, not a runtime dispatch mechanism.
- Existing hidden-slide behavior is typed model/product semantics, not fallback.

## Validation

Path-alignment validation should be run on the current packages:

```bash
moon check doc_parse/pptx convert/pptx
moon test doc_parse/pptx/tests
moon test convert/pptx/test
bash samples/check.sh --format pptx
bash samples/check_quality.sh --format pptx
bash samples/bench.sh --layer convert --format pptx --iterations 1 --warmup 0
```

Most recent audit run before this path-alignment update:

- `moon check doc_parse/pptx convert/pptx` passed.
- `moon test doc_parse/pptx/tests` passed, 6/6.
- `moon test convert/pptx/test` passed, 4/4.
- `bash samples/check.sh --format pptx` passed, 108/108.
- `bash samples/check_quality.sh --format pptx` passed, 49 checked, 3 skipped.
- one-row convert bench passed.

## Remaining Work

- Bound media byte materialization and table span expansion more explicitly.
- Keep documentation, generated interfaces, and route descriptions aligned with
  the active package paths.
- Keep future implementation slices inside `doc_parse/pptx` and `convert/pptx`;
  do not recreate parallel `pptx_v2` packages.
