# OOXML Package Layer

`doc_parse/ooxml` is a MoonBit OOXML package parser for ZIP-based Office
containers such as DOCX, PPTX, and XLSX.

It is intended to be a reusable lower-layer package: it opens OOXML archives,
lists and reads parts, parses `[Content_Types].xml`, parses package and
part-level `.rels`, indexes conventional media assets, exposes lightweight
`docProps`, and provides structured inspect/debug reports.

It is not a Word/PowerPoint/Excel semantic converter.

## Candidate Status

Current status:

- `doc_parse/ooxml` is treated as an OOXML package foundation candidate
  within the current repository scope
- current delivery remains the importable subpackage
  `ZSeanYves/markitdown/doc_parse/ooxml`, not a separately split MoonBit
  module
- this candidate status does not claim full OOXML or full Office semantic
  coverage

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

Validation:

- `collect_ooxml_validation_issues(pkg, mode=Strict)`
- `validate_ooxml_package(pkg, mode=Strict)`

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

Run explicit strict validation:

```moonbit
let report = @ox.validate_ooxml_package(pkg)
for issue in report.issues {
  ignore(issue.kind)
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

## API Stability

Stable-candidate surface:

- `open_ooxml_package`
- `has_part`
- `read_part_bytes`
- `read_part_text`
- `list_parts`
- `list_parts_by_prefix`
- `lookup_content_type_default`
- `lookup_content_type_override`
- `lookup_content_type`
- `list_parts_by_content_type`
- `read_package_relationships`
- `read_part_relationships`
- `find_relationship_by_id`
- `find_relationships_by_type`
- `resolve_relationship`
- `inspect_ooxml_inventory`
- `inspect_ooxml_package`
- `list_part_infos`
- `find_part_info`
- `list_content_type_infos`
- `list_relationship_infos`
- `list_media_assets`
- `read_core_properties`
- `read_app_properties`
- `classify_ooxml_error`
- `collect_ooxml_validation_issues`
- `validate_ooxml_package`

Debug convenience surface:

- `dump_ooxml_package`
- `dump_package_summary`
- `dump_relationships_summary`
- `dump_media_assets_summary`
- `dump_properties_summary`

Compatibility surface, but not ideal for external long-term reliance:

- `OoxmlPackage.archive`
- `OoxmlPackage.part_index`
- `OoxmlPackage.content_types_default`
- `OoxmlPackage.content_types_override`

These remain public today because current in-repo converter consumers still
touch them directly. Tightening them would require a future major-version style
API pass.

Versioning note:

- additive APIs such as inspect, classifier, and validation helpers are the
  preferred evolution path
- compatibility-preserving behavior wins over aggressive breakage in the current
  repository line
- any future field-visibility tightening should be treated as a release-policy
  change, not a silent refactor

## Safety Boundaries

- Unsafe part names and parent-traversal targets fail closed.
- External relationship targets are classified and preserved, not fetched.
- Malformed `[Content_Types].xml` and malformed `.rels` fail closed.
- Directory entries are skipped from package part inventory.
- Duplicate normalized part paths and duplicate normalized content-type
  overrides fail closed.
- Duplicate relationship ids remain compatibility behavior for now; they are not
  promoted to default parser failure in the current package contract.

Strict validation policy:

- default `open_ooxml_package` stays compatibility-oriented
- explicit strict validation reports package hygiene issues such as duplicate
  relationship ids
- external relationships are reported as validation issues but never fetched
- OOXML package opening inherits the shared ZIP reader's narrow Level 1
  data-descriptor compatibility; full ZIP64, encrypted, multi-disk, and
  streaming data-descriptor support remain unsupported

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

## Performance Note

Current performance note:

- package open, part lookup, relationship parsing, and content-type indexing
  are lower-layer costs of this package
- benchmark product timings should still be separated from converter-side
  semantic lowering
- performance work must not weaken part-path normalization or relationship
  safety checks

## Current Limits

- This package does not implement full OOXML specification coverage.
- This package does not parse DOCX/PPTX/XLSX semantic structure into final
  document meaning.
- This package does not fetch remote targets from external relationships.
- This package does not parse macro/VBA payload semantics.
- `read_part_text` is a package-local XML/text helper for OOXML parts; it is
  not a converter-level text policy surface.
- XML parsing is intentionally lightweight and only targets the small tag and
  attribute patterns required by current package-level helpers.
- Error taxonomy is additive and classifier-based today; the top-level
  `OoxmlError` variants stay compatibility-oriented for existing consumers.
- Content type and relationship APIs are package infrastructure, not full
  format semantics.
- The media asset index covers conventional OOXML media directories only:
  `word/media`, `ppt/media`, and `xl/media`.
- Document properties cover a small stable subset of core/app properties, not
  the full OOXML docProps/custom-properties space.
- Debug dumps are intended for inspection and can evolve; they are not a stable
  interchange format.

## Errors vs Validation Issues

- `OoxmlError` represents open/read/resolve failures.
- `OoxmlValidationIssue` represents explicit hygiene findings collected by
  strict validation.
- Use `classify_ooxml_error` for failure analysis.
- Use `validate_ooxml_package` when you want stricter package-policy reporting
  without changing normal package opening behavior.

## Relationship to `convert/*`

- `convert/docx`, `convert/pptx`, and `convert/xlsx` are consumers of this
  lower-layer package.
- They own final semantic conversion behavior.
- `doc_parse/ooxml` stays package-oriented and does not absorb higher-layer
  converter heuristics.
