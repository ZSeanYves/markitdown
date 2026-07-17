# ODF Readers

`format_readers/odf/` prepares ODT, ODS, and ODP source models from their
ZIP-based packages. Shared package parsing lives under `shared/`; thin
`odt/`, `ods/`, and `odp/` packages expose format-specific preparation.

## Bounded Package Reads

ODF sources use the shared seekable ZIP archive. Required XML parts are read
through bounded entries, while optional media is materialized only when its
size fits the asset budget. Repeated rows, columns, cells, and spaces are
clamped or rejected by explicit limits so declared counts cannot cause
unbounded expansion.

## Boundaries

The reader does not execute macros, calculate formulas, fetch external
relationships, or reproduce editor layout. Product semantics, accurate feature
selection, output assets, and provenance finalization stay in `formats/odt`,
`formats/ods`, `formats/odp`, convert, and render.

## Validation

```bash
moon test format_readers/odf --target native
bash tools/regression/check_balance.sh --format odt
```
