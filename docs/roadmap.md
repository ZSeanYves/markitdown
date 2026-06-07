# Roadmap

This page lists the current forward direction after the documentation cleanup
and DOCX v2 runtime switch.

## Completed Baseline

Completed structural work:

* DOCX v2 is the current runtime path.
* The old DOCX v1 runtime fallback has been removed.
* DOCX now follows an OOXML package -> source -> normalized model -> lowering
  architecture.
* Shared IR carries note references and resolved note definitions where a
  source supports them safely.
* Image OCR is available through the main CLI and `convert/vision`.
* PDF scan diagnostics remain report-only.

## Near-Term Work

Current priorities:

* refresh validation notes after the docs reset
* capture a new DOCX v2 performance snapshot
* keep `docs/quality-comparisons/` intact until its dedicated refresh
* keep the three active ledgers current:
  * [parser-defects.md](./parser-defects.md)
  * [format-limits.md](./format-limits.md)
  * [convert-defects.md](./convert-defects.md)
* use the archived [DOCX architecture contract](./archive/docx-architecture.md)
  as the model for future format rewrite contracts

## Format Model Rewrites

Future format rewrites should prefer explicit source/model/lowering boundaries:

* parser packages provide source-native facts
* converter packages own product policy and IR lowering
* duplicated source parsing should be removed or justified
* diagnostics and quality-lab tooling should not become runtime dependencies

Likely follow-up areas:

* PPTX typed slide/content model
* XLSX typed workbook/sheet/cell model cleanup
* HTML parser/converter boundary cleanup
* EPUB package/spine/body model cleanup
* PDF diagnostics and native-text rules kept narrow and deterministic

## OCR Direction

Image OCR is shipped through the main CLI and remains dependent on local
Tesseract runtime support.

Future OCR work should stay explicit and auditable:

* PDF OCR remains future provider work
* provider selection should not become hidden fallback behavior
* real-world OCR corpora belong in quality-lab
* main-repo OCR fixtures should stay tiny and license-clean
* OCR semantic hints do not imply Markdown table/key-value/caption
  reconstruction until that output policy is intentionally shipped

## Documentation Direction

Top-level docs should describe current product state. Historical process notes
should not return to the current docs path unless they are rewritten as active
contracts or working ledgers.
