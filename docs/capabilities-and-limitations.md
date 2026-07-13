# Capabilities and Limitations

`markitdown-mb` converts supported inputs through one path:

```text
detect -> probe -> route -> parse -> DocumentIR -> render
```

`balance` is the default product mode. `accurate` and `stream` are accepted
only where the table says so; unsupported mode requests return a non-zero error
instead of silently falling back.

Support levels used below:

- **Mainstream**: covers the structures normally needed for document ingestion.
- **Common subset**: useful for typical files, but not a complete language or
  editor implementation.
- **Optional**: requires a local runtime installed through `tools/env/`.

## Format Matrix

| Format | Level | What is preserved | Modes | Important boundary |
| --- | --- | --- | --- | --- |
| `txt` | Mainstream | Unicode text and line order | balance, stream | No inferred document structure |
| `csv`, `tsv` | Mainstream | Quoted/multiline cells, rows and Markdown tables | balance, stream | Delimiter tables only; no spreadsheet formulas or styles |
| `srt`, `vtt` | Mainstream | Cue IDs, timings, settings, common inline tags; VTT header/NOTE/STYLE/REGION | balance, stream | Bad cues may be skipped with diagnostics; not a media player |
| `json` | Mainstream | Nested objects/arrays, scalar types, table/list lowering and source paths | balance, stream | Invalid JSON fails closed; no JSON Schema evaluation |
| `jsonl`, `ndjson` | Mainstream | Record order and per-record structure | balance, stream | Blank malformed records are diagnosed; no cross-record schema |
| `yaml`, `yml` | Mainstream | Multiple documents, flow/block collections, scalars, anchors, aliases and merge keys | balance, stream | Safe core tags only; alias expansion is depth/node/byte bounded |
| `toml` | Mainstream | TOML 1.0 values, dates, numeric forms, dotted/quoted keys, tables, inline tables and array-of-tables | balance | Conflicting declarations fail; no distinct stream mode |
| `xml` | Mainstream | Elements, attributes, namespaces, text hierarchy and source paths | balance, stream | External entities and network/file access are disabled |
| `html`, `htm` | Mainstream | Headings, sections, lists, links, figures, details, tables, entities, ARIA names and local images | balance, stream | Malformed recovery is bounded; no CSS layout, script execution or remote fetch |
| `markdown`, `md` | Mainstream | CommonMark/GFM-style headings, lists, code, tables, task lists, links, footnotes and frontmatter | balance, stream | No plugin execution; local images are copied only when safely resolvable |
| `ipynb` | Mainstream | nbformat 4 cells, execution metadata, stream/display/error outputs, MIME selection and attachments | balance, stream | Does not execute kernels; unsupported MIME stays diagnostic |
| `eml` | Mainstream | Folded/encoded headers, charsets, transfer encoding, multipart trees, CID, attachments and nested messages | balance, stream | Recursion and attachment sizes are bounded; remote content is not fetched |
| `msg` | Alias only | Parsed through the EML/mail path | balance, stream | **Not** native Outlook binary MSG support |
| `tex`, `latex` | Common subset | Sections, lists, tables, figures/captions, links, references, citations, math, footnotes and verbatim | balance | No TeX execution; unknown macros preserve readable arguments/text; includes are not loaded |
| `rst` | Common subset | Headings, lists, quotes, roles, directives, footnotes, definitions, tables, code and images | balance | Includes are references only; no directive/plugin execution |
| `adoc`, `asciidoc` | Common subset | Attributes, xrefs, admonitions, nested lists, source blocks, tables, images and footnotes | balance | Includes do not access the network or arbitrary files |
| `zip` | Bounded container | Supported child documents, headings per entry, provenance and exported assets | balance only | No nested archive recursion; unsafe/colliding paths and resource bombs fail closed |
| `epub` | Mainstream | Metadata, spine order, navigation/NCX, chapter HTML, links and images | balance, stream | Encrypted/DRM content and remote resources are unsupported |
| `docx` | Mainstream | Paragraphs, headings, lists, tables, links, text boxes, notes/comments and images | balance, accurate | No stream mode; complex drawing/layout and editor round-trip are non-goals |
| `xlsx` | Mainstream | Sheets, typed/cached values, tables, formulas as text, merges, hidden state, comments, hyperlinks and drawings/images | balance, accurate, stream | Formulas are not recalculated; macros and editor layout are unsupported |
| `pptx` | Mainstream | Slide order, text, lists, tables, links, images, notes, hidden slides and basic chart/group summaries | balance, accurate | No stream mode; animations and pixel-perfect slide layout are unsupported |
| `odt` | Mainstream | Styles, headings, lists, tables, links, images, notes and comments | balance, accurate, stream | Complex page layout and editor round-trip are not reproduced |
| `ods` | Mainstream | Typed cells, formulas as text, merges/covered cells, repeated rows/columns, hidden state, comments and images | balance, accurate, stream | Formulas are not recalculated; advanced charts/macros are limited |
| `odp` | Mainstream | Slides, frames/groups, reading order, text, tables, images, notes, hidden slides and basic chart text | balance, accurate, stream | Animations and presentation rendering are not reproduced |
| `pdf` | Mainstream, bounded | Native text, fonts/CMaps, page order, simple tables, links, outlines, forms and supported embedded image assets | balance, accurate | Balance does not OCR scanned pages; encrypted PDFs fail closed; accurate uses external full-page raster/OCR |
| `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff` | Optional | OCR text, page/line geometry and provider provenance | balance, accurate | Only top-level images and standalone unreferenced ZIP images are OCR inputs; document-embedded images remain assets |
| `wav`, `mp3`, `m4a` | Optional | Transcript segments, timing, language/runtime metadata | balance | Requires Vosk; compressed input may require ffmpeg; no diarization or accurate/stream mode |

## Accurate and Stream Boundaries

`accurate` has two meanings, both explicit:

- PDF and direct images use an external high-fidelity OCR/layout route.
- DOCX/XLSX/PPTX/ODT/ODS/ODP stay on their native parser and enable additional
  semantic recovery such as hidden content, notes, spans or reading order.

All other formats reject `accurate`. Explicit `stream` is limited to:

```text
txt csv tsv srt vtt json jsonl ndjson ipynb xml yaml html markdown eml
epub xlsx odt ods odp
```

`stream` changes execution/storage behavior, not the promised Markdown meaning.

## Assets and OCR

Local assets are written only at the output boundary. Paths must be safe and
relative; absolute paths, `..`, protocols, remote downloads and silent
overwrites are rejected. Markdown references must resolve to materialized files
or be removed with a diagnostic.

Document images are assets, never implicit OCR work. OCR applies only to a pure
image input or an unreferenced standalone image inside a balance-mode ZIP.
Native balanced PDF may export supported embedded images, but does not OCR them.
PNG/JPEG are the common asset contract; GIF/WebP/SVG/JP2/TIFF/JBIG2 are retained
when the source container and encoding can be saved safely. PDF DCT images stay
JPEG, while decoded Gray/RGB/CMYK/Indexed images and masks are normalized to PNG.

## General Safety Limits

Parsers enforce format-specific limits for input bytes, nesting, archive entry
count, decompressed size, compression ratio, object/page trees, MIME recursion,
aliases and materialized assets. Security, encryption and integrity failures
fail closed. Recoverable unknown structures may preserve readable content with
a stable warning instead of discarding the whole document.

The project does not provide browser/editor-grade rendering, password recovery,
remote includes, external XML entities, parser-time network access, arbitrary
file reads, or native Outlook MSG decoding.

For runtime installation see
[environment-dependencies.md](./environment-dependencies.md). For the exact
regression decision rules see
[tools/regression/README.md](../tools/regression/README.md).
