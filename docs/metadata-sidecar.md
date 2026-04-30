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

`blocks[]` represents engineering information from the **content-block perspective**:

* `block_index`: block sequence number
* `block_type`: block type
* `text`: extracted block text (depending on type)
* `origin`: provenance information (optional)
* `image`: extra image-block information (only for image blocks)

Block `origin` keeps the original v1 fields (`source_name`, `page`, `slide`,
`sheet`, `block_index`, `heading_path`) and may also include additive optional
fields when the converter has stable source information:

* `format`
* `line_start` / `line_end`
* `row_index` / `column_index`
* `object_ref`
* `relationship_id`
* `key_path`

### 4.3 Role of `assets[]`

`assets[]` represents engineering information from the **asset-level perspective**:

* `path`: asset path
* `asset_type`: asset type (currently mainly `image`)
* `alt_text` / `title` / `caption`
* `origin`
* `nearby_caption`

Asset `origin` keeps the original v1 fields (`source_name`, `page`, `slide`,
`sheet`, `origin_id`, `nearby_caption`) and may also include additive optional
fields when available:

* `format`
* `object_ref`
* `relationship_id`
* `source_path`
* `row_index` / `column_index`
* `key_path`

Additive origin fields are emitted sparsely: absent optional values are omitted
instead of being serialized as `null`. Existing v1 fields keep their historical
shape.

## 5) Relationship Between `ImageData.caption` and `nearby_caption`

The current contract is:

* `ImageData.caption` is the primary semantic caption value for an image.
* `nearby_caption` is the mirrored / indexing field on the asset side.
* If `nearby_caption` exists, it is expected to match the primary caption value, so it can be used for engineering search and consistency checks.

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
* origin extensions are additive and sparse; consumers should tolerate missing optional fields

### 7.2 Future Enhancements (Do Not Make Strong Coupling Assumptions Yet)

The following belong to future enhancement directions and should not yet be treated as strongly stable assumptions:

* finer-grained anchoring (`bbox` / `char-range` / full PDF source refs)
* more advanced semantic fields (especially for complex PDF and advanced OOXML scenarios)
* completeness of field population in certain weak-semantic or ambiguous cases

```
