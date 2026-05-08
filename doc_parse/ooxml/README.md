# OOXML Package Layer

`doc_parse/ooxml` is a MoonBit OOXML package parser for ZIP-based Office
containers such as DOCX, PPTX, and XLSX.

It is intended to be a reusable lower-layer package: it opens OOXML archives,
lists and reads parts, parses `[Content_Types].xml`, parses package and
part-level `.rels`, indexes conventional media assets, exposes lightweight
`docProps`, and provides structured inspect/debug reports.

It is not a Word/PowerPoint/Excel semantic converter.

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
- Produce structured package inventory and inspect reports for parts, content
  types, and relationships.
- Reject invalid relationship targets.
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

Text-normalization boundary:

- `doc_parse/ooxml` does not own shared document cleanup or canonical Unicode
  normalization policy.
- Format converters may reuse `core/text_normalization.mbt` at carefully chosen
  text-only seams, but that policy stays above this package.

## Public APIs

Usage note:

- Add `ZSeanYves/markitdown/doc_parse/ooxml` as a dependency in your MoonBit
  package.
- Open OOXML bytes with `open_ooxml_package(bytes)`.
- Consume package parts, content types, relationships, media assets, and
  inspect reports from this layer.

Package facade:

- `open_ooxml_package(bytes)`
- `has_part(pkg, part_name)`
- `read_part_bytes(pkg, part_name)`
- `read_part_text(pkg, part_name)`
- `list_parts(pkg)`
- `list_parts_by_prefix(pkg, prefix)`

Content types:

- `lookup_content_type_default(pkg, extension)`
- `lookup_content_type_override(pkg, part_name)`
- `lookup_content_type(pkg, part_name)`
- `list_parts_by_content_type(pkg, content_type)`

Relationships:

- `has_relationships_part(pkg, source_part)`
- `read_package_relationships(pkg)`
- `read_part_relationships(pkg, source_part)`
- `resolve_relationship(pkg, source_part, rel_id)`
- `find_relationship_by_id(pkg, source_part, rel_id)`
- `find_relationships_by_type(pkg, source_part, rel_type_suffix)`

Structured inspect:

- `inspect_ooxml_inventory(pkg)`
- `inspect_ooxml_package(pkg)`
- `list_part_infos(pkg)`
- `find_part_info(pkg, part_name)`
- `list_content_type_infos(pkg)`
- `list_relationship_infos(pkg, source_part)`
- `classify_ooxml_error(err)`

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

## Minimal Examples

Open a package and list parts:

```moonbit
let pkg = @ox.open_ooxml_package(bytes)
let parts = @ox.list_parts(pkg)
```

Read package inventory:

```moonbit
let inventory = @ox.inspect_ooxml_inventory(pkg)
let count = inventory.part_count
let has_core = inventory.has_core_properties
```

Resolve a relationship safely:

```moonbit
let rels = @ox.read_part_relationships(pkg, "word/document.xml")
let target = @ox.resolve_relationship(pkg, "word/document.xml", "rId5")
```

Query effective content type:

```moonbit
let ct = @ox.lookup_content_type(pkg, "word/document.xml")
let xml_default = @ox.lookup_content_type_default(pkg, "xml")
```

Classify lower-layer errors:

```moonbit
match try? @ox.read_part_relationships(pkg, "word/document.xml") {
  Ok(rels) => ignore(rels)
  Err(err) => {
    let info = @ox.classify_ooxml_error(err)
    ignore(info.kind)
  }
}
```

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
- Prefer deterministic output order for listing, inspect, and debug APIs.
- Fail closed on normalized part-path collisions, malformed relationship XML,
  and unsafe normalized targets.
- Treat missing optional OOXML parts, such as docProps or part relationships, as
  empty/`None` where that is part of the public contract.
- Preserve target mode information so callers can avoid treating external links
  as internal package parts.
- Keep the package-facing inspect surface structured; debug dump strings remain
  convenience helpers and are not the primary machine-readable contract.
- Keep duplicate relationship-id handling compatible for now; it remains a known
  lower-layer boundary rather than a default fail-closed behavior.
- Keep debug dump output human-readable and lossy; it is not a machine schema.

## Safety Boundaries

- Unsafe part names and parent-traversal targets fail closed.
- External relationship targets are classified and preserved, not fetched.
- Malformed `[Content_Types].xml` and malformed `.rels` fail closed.
- Directory entries are skipped from package part inventory.
- Duplicate normalized part paths and duplicate normalized content-type
  overrides fail closed.
- Duplicate relationship ids remain compatibility behavior for now; they are not
  promoted to default parser failure in the current package contract.

## Tests

The primary tests live in `doc_parse/ooxml/tests`.

Run:

```bash
moon test doc_parse/ooxml/tests --target native
```

The broader safety net for behavior that consumes this layer is:

```bash
moon check
./samples/check.sh
```

Current lower-layer coverage includes:

- positive package open/read/list/query on DOCX/PPTX/XLSX samples
- structured inventory/inspect reporting
- missing part classification
- malformed `[Content_Types].xml` classification
- malformed `.rels` classification
- deterministic inventory ordering
- deterministic package dump smoke checks
- duplicate relationship-id compatibility boundary
- unsafe relationship-target failure
- external relationship classification
- normalized part collision failure
- duplicate normalized content-type override failure

## Current Limits

- This package does not implement full OOXML specification coverage.
- This package does not parse DOCX/PPTX/XLSX semantic structure into final
  document meaning.
- This package does not fetch remote targets from external relationships.
- This package does not parse macro/VBA payload semantics.
- XML parsing is intentionally lightweight and only targets the small tag and
  attribute patterns required by current package-level helpers.
- Error taxonomy is additive and classifier-based today; the top-level
  `OoxmlError` variants stay compatibility-oriented for existing consumers.
- Content type and relationship APIs are package infrastructure, not full
  format semantics.
- The media asset index covers conventional OOXML media directories only:
  `word/media`, `ppt/media`, and `xl/media`.
- Document properties cover a small stable subset of core/app properties.
- Debug dumps are intended for inspection and can evolve; they are not a stable
  interchange format.

## Relationship to `convert/*`

- `convert/docx`, `convert/pptx`, and `convert/xlsx` are consumers of this
  lower-layer package.
- They own final semantic conversion behavior.
- `doc_parse/ooxml` stays package-oriented and does not absorb higher-layer
  converter heuristics.
