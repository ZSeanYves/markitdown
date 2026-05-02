# Metadata Sidecar

The metadata sidecar is the machine-readable companion output to Markdown. It
is for provenance, indexing, and auditing, not for the main reading flow.

## Enable It

```bash
moon run cli -- normal --with-metadata <input> <output.md>
```

The sidecar is written to:

```text
<markdown_dir>/metadata/<markdown_stem>.metadata.json
```

## Top-level Shape

Current top-level fields:

* `version`
* `source_name`
* `format`
* `markdown_file`
* `document`
* `summary`
* `blocks`
* `assets`

Current schema principles:

* schema version is unchanged
* new provenance fill is additive
* optional values are emitted sparsely

## `document`

`document` is the file-level metadata object.

Common current uses:

* OOXML document properties
* EPUB OPF `title / creator / date / modified`

When unavailable, `document` is `null`.

## `blocks[]`

`blocks[]` is the content-block view.

Important current fields:

* `block_index`
* `block_type`
* `text`
* `origin`
* `image` for image blocks
* optional `table` for `RichTable`

Current block-origin field surface:

* `source_name`
* `format`
* `page`
* `slide`
* `sheet`
* `block_index`
* `heading_path`
* `line_start`
* `line_end`
* `row_index`
* `column_index`
* `object_ref`
* `relationship_id`
* `key_path`

Examples of current fill behavior:

* CSV / TSV: physical line range plus row/column origin
* JSON / YAML: root `key_path = "$"`
* Markdown: conservative line ranges
* TXT: paragraph-level `line_start / line_end`
* XML: one conservative `CodeBlock` summary with whole-document line range
* EPUB: spine item path as EPUB-level provenance

## `assets[]`

`assets[]` is the exported-resource view.

Important current fields:

* `path`
* `asset_type`
* `alt_text`
* `title`
* `caption`
* `origin`
* `nearby_caption`

Current asset-origin field surface:

* `source_name`
* `format`
* `page`
* `slide`
* `sheet`
* `origin_id`
* `object_ref`
* `relationship_id`
* `source_path`
* `row_index`
* `column_index`
* `key_path`
* `nearby_caption`

Current strong examples:

* PDF assets populate `object_ref`
* DOCX / PPTX assets populate `relationship_id` and source path identity
* HTML local images populate normalized `source_path`
* ZIP / EPUB remapped assets preserve container-level provenance
* TXT and XML produce no assets

## Image Context Contract

Shared current image contract:

* `ImageBlock` / `ImageData` carries `path`, `alt_text`, `title`, `caption`,
  and `origin`
* `blocks[].image` serializes image-block data
* `assets[].alt_text/title/caption` are populated by joining asset `path` back
  to the corresponding `ImageBlock`
* `nearby_caption` is the asset-side mirror of the main caption value, not a
  second independent caption system

## Current Boundary

The sidecar currently does not promise:

* full bbox or char-range anchoring
* DOM path anchoring
* table cell-level provenance
* nested provenance for every JSON/YAML inner node
* rich PDF link provenance beyond the current narrow high-confidence URI path
* extra asset output for TXT or XML

For full per-format support boundaries, see
[docs/support-and-limits.md](./support-and-limits.md).
