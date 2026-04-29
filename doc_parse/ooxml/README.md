# OOXML Package Layer

## Positioning

`doc_parse/ooxml` is the shared low-level OOXML package substrate for DOCX,
PPTX, and XLSX support.

It sits below `convert/docx`, `convert/pptx`, and `convert/xlsx`. The package
understands the OOXML ZIP container, package parts, content types,
relationships, media parts, and lightweight document properties. It does not
recover final Markdown structure.

## Supported Scope

Current supported scope:

- Open OOXML ZIP packages from `Bytes`.
- Read and list package parts.
- Query `[Content_Types].xml` defaults and overrides.
- Read package-root and part-level relationships.
- Preserve relationship target mode as `Internal` or `External`.
- Resolve internal relationship targets relative to a source part.
- Query relationships by id or type suffix.
- Build a package-level media asset index for `word/media`, `ppt/media`, and
  `xl/media`.
- Read lightweight `docProps/core.xml` and `docProps/app.xml` fields.
- Produce human-readable debug dumps for package summaries, relationships,
  media assets, and properties.

## Non-Goals

This package intentionally does not:

- Parse DOCX paragraphs, styles, numbering, or tables into final content blocks.
- Parse PPTX slide shapes, reading order, layout, or captions.
- Parse XLSX worksheets into Markdown tables.
- Decide Markdown rendering semantics.
- Define metadata sidecar schema.
- Export assets to disk.
- Provide a CLI surface.

Those responsibilities belong to `convert/*`, `core/*`, and `cli/*`.

## Public APIs

Package facade:

- `open_ooxml_package(bytes)`
- `has_part(pkg, part_name)`
- `read_part_bytes(pkg, part_name)`
- `list_parts(pkg)`
- `list_parts_by_prefix(pkg, prefix)`

Content types:

- `lookup_content_type(pkg, part_name)`
- `list_parts_by_content_type(pkg, content_type)`

Relationships:

- `has_relationships_part(pkg, source_part)`
- `read_package_relationships(pkg)`
- `read_part_relationships(pkg, source_part)`
- `resolve_relationship(pkg, source_part, rel_id)`
- `find_relationship_by_id(pkg, source_part, rel_id)`
- `find_relationships_by_type(pkg, source_part, rel_type_suffix)`

Media assets:

- `list_media_assets(pkg)`

Document properties:

- `read_core_properties(pkg)`
- `read_app_properties(pkg)`

Debug dumps:

- `dump_ooxml_package(pkg)`
- `dump_package_summary(pkg)`
- `dump_relationships_summary(pkg)`
- `dump_media_assets_summary(pkg)`
- `dump_properties_summary(pkg)`

## File Layout

- `ooxml_package.mbt`: package open/read/list facade.
- `ooxml_content_types.mbt`: `[Content_Types].xml` parsing and content type
  lookup.
- `ooxml_relationships.mbt`: relationship parsing, target mode handling, and
  relationship lookup/resolve helpers.
- `ooxml_part_name.mbt`: part-name normalization and relative target
  resolution.
- `ooxml_assets.mbt`: package-level media asset indexing.
- `ooxml_props.mbt`: lightweight docProps reading.
- `ooxml_xml_util.mbt`: small XML tag/attribute/text helpers used by this
  package.
- `ooxml_dump.mbt`: read-only human-readable debug summaries.
- `ooxml_types.mbt`: public data types and errors.

## Design Principles

- Keep this layer read-only and package-oriented.
- Keep format-specific semantic recovery out of `doc_parse/ooxml`.
- Prefer deterministic output order for listing and debug APIs.
- Treat missing optional OOXML parts, such as docProps or part relationships, as
  empty/`None` where that is part of the public contract.
- Preserve target mode information so callers can avoid treating external links
  as internal package parts.
- Keep debug dump output human-readable and lossy; it is not a machine schema.

## Tests

The primary tests live in `doc_parse/ooxml/tests`.

Run:

```bash
moon test doc_parse/ooxml/tests --target native
```

The broader safety net for behavior that consumes this layer is:

```bash
moon check
./samples/diff.sh
./samples/check_metadata.sh
./samples/check_assets.sh
```

## Current Limits

- XML parsing is intentionally lightweight and only targets the small tag and
  attribute patterns required by current package-level helpers.
- Content type and relationship APIs are package infrastructure, not full
  format semantics.
- The media asset index covers conventional OOXML media directories only:
  `word/media`, `ppt/media`, and `xl/media`.
- Document properties cover a small stable subset of core/app properties.
- Debug dumps are intended for inspection and can evolve; they are not a stable
  interchange format.
