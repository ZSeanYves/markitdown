# Pipeline

`pipeline/` continues transforming parser output into a more stable and renderable `DocumentIR`. Its passes recover reading order, heading hierarchy, table and caption bindings, asset ownership, and render hints.

## Responsibilities

- Normalize event streams and block streams into `DocumentIR`
- Chain structured passes while maintaining shared `PassContext`
- Recover reading order, section trees, tables, and caption bindings
- Build `DocumentAssembly` so render and provenance can consume structural overlays directly

## Key Entry Points

- `pipeline.mbt`
  `PassContext`, `IRPass`, `PassPipeline`, `build_document_with_default_pipeline`
- `event_document_builder.mbt`
  The low-level builder that turns event streams into document trees
- `passes_normalize.mbt`
  Text and whitespace normalization
- `passes_reading_order.mbt`
  Text-line merging, reading-order recovery, and header/footer cleanup
- `passes_structure.mbt`
  Heading and list recovery
- `passes_table_caption_asset.mbt`
  Table, caption, and asset-reference consolidation
- `passes_assembly.mbt`
  Section-tree and assembly construction

## Key Types

- `PassContext`
  Stores product mode, diagnostics, metadata, assets, source map, assembly, and other shared side channels
- `IRPass`
  A named, traceable IR transformation step
- `DocumentAssembly`
  A pipeline-built structural index reused by render and provenance

## Maintenance Rules

- Prefer adding a dedicated pass for new logic instead of continuing to grow existing large files
- Pass names must stay stable because diagnostics and regression tests consume pass traces
- Parsers should not pre-bake renderer-only layout decisions; that recovery logic should stay in the pipeline whenever possible
- Controlled parser-pull sink routes may skip document assembly only when the
  format contract does not require these passes and all output/provenance side
  channels remain equivalent.

## Validation

```bash
moon test
```
