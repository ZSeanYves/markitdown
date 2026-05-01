# Metadata Sidecar (`*.metadata.json`)

## 1) Positioning

The metadata sidecar is a **companion output for engineering consumption** and is not part of the Markdown main body.

Its main purposes include:

- provenance and auditing
- asset indexing
- RAG / chunk preprocessing
- automated acceptance verification

## 2) How to Enable It

Enable it via the CLI flag `--with-metadata`:

```bash
moon run cli -- normal --with-metadata <input> <output.md>
moon run cli -- ocr --with-metadata <input> <output.md>
moon run cli -- debug --with-metadata <all|extract|raw|pipeline> <input> <output.md>
````

Note: if no output Markdown file is provided (stdout mode), the sidecar is currently not written to disk.

## 3) Output Path Rule

The sidecar is always written into the `metadata/` subdirectory next to the Markdown output:

* Markdown: `out/demo.md`
* Sidecar: `out/metadata/demo.metadata.json`

The rule can be summarized as:

`<markdown_dir>/metadata/<markdown_stem>.metadata.json`

## 4) Current Schema: Main Fields

Top level:

* `version`
* `source_name`
* `format`
* `markdown_file`
* `document` (document-level properties object or `null`)
* `summary` (`block_count` / `asset_count`)
* `blocks[]`
* `assets[]`

Current G2 Origin / Source Location status:

* additive origin schema extension is complete
* additive origin fields are emitted sparsely
* OOXML origin refinement is complete at the current repository boundary
* structured/text origin refinement is complete at the current repository boundary
* HTML image `source_path` refinement is complete at the current repository boundary
* the metadata schema version and top-level shape are unchanged

Current G3 image-context status:

* unified `ImageBlock` / `ImageData` semantics are in use for image-first
  converters
* DOCX source-native `descr/title` mapping is complete at the current
  repository boundary
* PPTX source-native picture `descr/title` mapping is complete at the current
  repository boundary
* the metadata schema version and top-level shape remain unchanged

Current G5.2 table-header metadata status:

* Core IR now has both legacy `Block::Table(Array[Array[String]])` and
  `Block::RichTable(TableData)`.
* `TableData` carries `rows` plus `header_rows`; `header_rows` is explicit
  source header semantics.
* The metadata schema version and top-level shape remain unchanged.
* `blocks[].table` is an additive optional field for structured table data.
* Only `RichTable` populates `blocks[].table` with `rows` and `header_rows`.
* Legacy `Table` omits `blocks[].table`.
* Table text remains the existing flat table text representation for both
  legacy `Table` and `RichTable`.

Current provenance boundary:

* sidecar origin is best-effort source location for engineering traceability
* it is not a full layout trace, DOM path model, or char-range anchoring system
* default sidecar emission of full PDF `source_refs` and bbox is not enabled
* table cell-level provenance is not enabled
* table cell-level metadata, alignment, rowspan/colspan, merged-cell
  reconstruction, and table-cell origin are not enabled
* HTML DOM path anchoring is not enabled
* JSON / YAML nested key-path anchoring is not enabled

### 4.1 Role of `document`

`document` represents file-level document properties. It is deliberately kept at
the top level and is not mixed into `summary`, `origin`, `blocks[]`, or
`assets[]`.

For OOXML inputs (`docx` / `pptx` / `xlsx`), the CLI sidecar path reads
`docProps/core.xml` and `docProps/app.xml` through the shared OOXML package
layer. If the input is not OOXML, or if document properties cannot be read, the
field is `null`.

Current fields:

* `title`
* `subject`
* `creator`
* `description`
* `keywords`
* `created`
* `modified`
* `application`
* `pages`
* `words`
* `slides`
* `sheets`

All fields are optional strings and may be `null` even when `document` is
present.

### 4.2 Role of `blocks[]`

Current unified `ImageBlock` / `ImageData` contract:

* `path`: emitted asset path
* `alt_text`: source-native image hint when available
* `title`: source-native title-like hint when available
* `caption`: primary semantic caption when confidence is high enough
* `origin`: optional IR-side image origin

This is the shared image contract used by HTML, DOCX, PPTX, and PDF image-first
paths.

`blocks[]` represents engineering information from the **content-block perspective**:

* `block_index`: block sequence number
* `block_type`: block type
* `text`: extracted block text (depending on type)
* `origin`: provenance information (optional)
* `image`: extra image-block information (only for image blocks)

Current serialized `blocks[].image` field surface:

* `path`
* `alt_text`
* `title`
* `caption`

Current serialized `blocks[].origin` field surface:

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

Current verifiable block-origin fill ranges:

* XLSX blocks: source row/column span plus `relationship_id`
* CSV / TSV blocks: physical `line_start` / `line_end` plus
  `row_index = 1` / `column_index = 1`
* JSON / YAML blocks: root `key_path = "$"`
* Markdown blocks: conservative `line_start` / `line_end`

Block origin remains block-scoped. The current IR does not carry row/cell-level
table provenance.

Table blocks in sidecar output:

* Legacy `Table` and `RichTable` both serialize as the existing table block type.
* The `text` field remains Markdown-like flat table text.
* `RichTable` also serializes `table: { rows, header_rows }`.
* Legacy `Table` does not synthesize explicit header semantics and keeps
  the optional `table` field absent.
* The sidecar does not expose cell-level metadata, alignment, rowspan/colspan,
  merged-cell reconstruction, cell type, or table-cell origin.

### 4.3 Role of `assets[]`

`assets[]` represents engineering information from the **asset-level perspective**:

* `path`: asset path
* `asset_type`: asset type (currently mainly `image`)
* `alt_text` / `title` / `caption`
* `origin`
* `nearby_caption`

Current sidecar reuse rule for image-context fields:

* `assets[].alt_text`, `assets[].title`, and `assets[].caption` are not inferred
  independently on the asset side
* they are populated by joining the asset `path` back to the corresponding
  `ImageBlock`
* `nearby_caption` remains the mirrored asset-origin field for asset-oriented
  lookup, not a second caption-inference result

Current serialized `assets[].origin` field surface:

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

Current verifiable asset-origin fill ranges:

* PDF assets: `object_ref`
* PPTX assets: `relationship_id` / `source_path`
* DOCX assets: `relationship_id` / `source_path`
* HTML image assets: `source_path` from normalized local `<img src>`

Current verifiable image-context fill ranges:

* HTML: `<img alt> -> alt_text`, `<img title> -> title`,
  `<figcaption> -> caption`, local `<img src> -> source_path`
* DOCX: `ImageBlock`, drawing `descr -> alt_text`, drawing `title -> title`,
  asset-origin `relationship_id / source_path`
* PPTX: `ImageBlock`, `p:cNvPr descr -> alt_text`, `p:cNvPr title -> title`,
  synthetic alt only as fallback, asset-origin `relationship_id / source_path`
* PDF: `ImageBlock`, `object_ref`, and conservative bbox-gated single-image
  caption attachment
* XLSX: no image conversion path at the current stage

Additive origin fields are emitted sparsely: absent optional values are omitted
instead of being serialized as `null`. Existing v1 fields keep their historical
shape.

`relationship_id` is only populated for formats that actually have a stable
relationship model. HTML does not have one in the current contract.

## 5) Relationship Between `ImageData.caption` and `nearby_caption`

The current contract is:

* `ImageData.caption` is the primary semantic caption value for an image.
* `nearby_caption` is the mirrored / indexing field on the asset side.
* It is not a separate semantic caption slot and should not be treated as an
  independent caption-inference result.
* If `nearby_caption` exists, it is expected to match the primary caption value,
  so it can be used for engineering search and consistency checks.

## 6) Minimal JSON Example

```json
{
  "version": "1",
  "source_name": "demo.pdf",
  "format": "pdf",
  "markdown_file": "demo.md",
  "document": null,
  "summary": { "block_count": 3, "asset_count": 1 },
  "blocks": [
    {
      "block_index": 0,
      "block_type": "heading",
      "text": "Example Title",
      "origin": { "format": "pdf", "source_name": "demo.pdf", "page": 1 },
      "image": null
    }
  ],
  "assets": [
    {
      "path": "assets/image01.png",
      "asset_type": "image",
      "alt_text": null,
      "title": null,
      "caption": "Figure 1 Example",
      "origin": {
        "format": "pdf",
        "source_name": "demo.pdf",
        "page": 1,
        "origin_id": "img-1",
        "object_ref": "3 0 R"
      },
      "nearby_caption": "Figure 1 Example"
    }
  ]
}
```

## 7) “Stable Contract” at the Current Stage

### 7.1 What Can Be Treated as a Stable Engineering Contract

The following can currently be treated as stable and safe to rely on:

* the sidecar naming and directory rule (`metadata/<stem>.metadata.json`)
* top-level key fields: `version/source_name/format/markdown_file/document/summary/blocks/assets`
* `document` as the dedicated file-level metadata area, with `null` used when unavailable
* the dual-view separation between `blocks[]` and `assets[]`
* the relationship between the primary image caption field and the mirrored `nearby_caption`
* the current sidecar origin field surface for `blocks[].origin` and `assets[].origin`
* origin extensions are additive and sparse; consumers should tolerate missing optional fields

### 7.2 Future Enhancements (Do Not Make Strong Coupling Assumptions Yet)

The following belong to future enhancement directions and should not yet be treated as strongly stable assumptions:

* finer-grained anchoring (`bbox` / `char-range` / full PDF source refs)
* more advanced semantic fields (especially for complex PDF and advanced OOXML scenarios)
* completeness of field population in certain weak-semantic or ambiguous cases

Current explicit non-goals:

* default sidecar emission of full PDF `source_refs`
* default sidecar emission of bbox
* HTML DOM path anchoring
* HTML block `line_start` / `line_end`
* table cell-level provenance
* JSON / YAML nested key-path anchoring
* default PDF annotation-link Markdown emission
* PDF / PPTX multi-image caption pairing
* using OOXML `name` as image caption or title
* XLSX image support
* remote HTML image fetch

```
