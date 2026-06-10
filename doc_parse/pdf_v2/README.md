# PDF v2 Parser Scaffold

`doc_parse/pdf_v2` is an experimental parser package for the PDF v2
architecture contract in `docs/archive/pdf-v2-architecture.md`.

This package does not replace `doc_parse/pdf` or the current `convert/pdf`
runtime. Dispatcher behavior is unchanged.

Boundaries for this scaffold:

- The parser owns source events, source references, geometry, text facts,
  layout facts, warnings, risks, and classifier-ready features.
- Convert owns product policy, Markdown decisions, and final IR lowering.
- PDF input must be scanned once by the future vendor/raw/parser path.
- Convert must not reopen, rescan, or reinterpret raw PDF bytes.
- No fallback to the old PDF runtime is introduced here.
- No Python runtime, model file, DocLayNet data, `features.tsv`, `model.pkl`,
  or external quality-lab file is read at runtime.
- The vendor/core facade is part of the v2 rewrite scope, but this phase only
  defines a fail-closed scaffold contract.

The files in this package intentionally define typed contracts before real PDF
reading is wired. Unsupported or incomplete capabilities should be represented
as warnings and risks rather than hidden fallback behavior.
