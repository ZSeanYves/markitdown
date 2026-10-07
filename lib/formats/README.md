# Formats

`formats/` owns product-level text parsers and their lowering into the shared
`DocumentIR` path. Readers and decoders stay in `internal/readers`; format
packages select semantics, diagnostics, assets and source mappings.

Every supported format follows:

```text
Input → detect/probe → ParserRegistry → ParseResult → shared pipeline → output
```

Embedded images remain document assets. Image and audio inputs are detected so
the CLI can return a stable `UnsupportedCapability` error, but they have no
production parser or runtime dependency. Subtitle files keep cue timing as
text metadata.

The ZIP/EPUB/Office/ODF packages preserve bounded entry selection, path and
collision checks, CRC validation, lazy reads, attachment budgets and the same
source/provenance rules as standalone formats.
