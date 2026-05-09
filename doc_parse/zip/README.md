# ZIP Archive Layer

`doc_parse/zip` is the repository's ZIP archive foundation layer.

It provides deterministic archive open/read/list behavior, entry-path
normalization helpers, structured archive inventory, explicit validation
issues, and classifier-friendly errors for higher consumers such as
`doc_parse/ooxml`, `doc_parse/epub`, and `convert/zip`.

It is not a Markdown converter and it does not own OOXML or EPUB semantics.

## Status

Current status:

- `doc_parse/zip` is an external-decoder-backed publishable foundation candidate
- current delivery remains the importable subpackage
  `ZSeanYves/markitdown/doc_parse/zip`, not a separately split MoonBit module

## External Backend Note

Current backend boundary:

- archive structure parsing (EOCD, central directory, local headers, entry
  lookup) is implemented in this package
- deflate decoding is currently backed by the external
  `bikallem/compress/flate` dependency
- this package intentionally does not claim full ZIP-spec feature coverage just
  because an external codec dependency exists

The stable project boundary is the `doc_parse/zip` facade, not the underlying
codec dependency.

## Purpose

`doc_parse/zip` is responsible for:

- opening ZIP archives from `Bytes`
- listing archive entries
- reading entry bytes
- surfacing deterministic entry inventory
- normalizing archive entry paths conservatively
- surfacing validation issues for unsafe or suspicious archive shapes
- classifying lower-layer ZIP open/read failures

It intentionally does not own:

- Markdown conversion
- nested archive dispatch policy
- recursive archive conversion
- OOXML package semantics
- EPUB OPF/spine/nav semantics
- password recovery
- full ZIP repair

## Stable Candidate API

Current package-facing facade:

- `open_zip(bytes)`
- `list_entries(archive)`
- `has_entry(archive, path)`
- `read_entry(archive, path, max_output_size?)`

Structured inventory / inspect / validation:

- `normalize_entry_path(raw_path)`
- `list_entry_infos(archive)`
- `find_entry_info(archive, path)`
- `inspect_zip_inventory(archive)`
- `inspect_zip_archive(archive)`
- `classify_zip_error(err)`
- `collect_zip_validation_issues(archive)`
- `validate_zip_archive(archive)`

## Debug / Legacy Compatibility API

Current compatibility helper:

- `inspect_zip(bytes)`

This helper stays public for legacy/debug use, but the structured inspect and
validation helpers above are the preferred machine-readable contract for new
consumers.

## Minimal Examples

Open an archive and list raw entries:

```moonbit
let archive = @zip.open_zip(bytes)
let entries = @zip.list_entries(archive)
```

Read structured inventory:

```moonbit
let inventory = @zip.inspect_zip_inventory(archive)
let count = inventory.entry_count
let has_unsafe = inventory.has_unsafe_paths
```

Inspect one entry:

```moonbit
let info = @zip.find_entry_info(archive, "docs/readme.md")
```

Classify lower-layer open/read failures:

```moonbit
match try? @zip.read_entry(archive, "missing.txt") {
  Ok(bytes) => ignore(bytes)
  Err(err) => {
    let info = @zip.classify_zip_error(err)
    ignore(info.kind)
  }
}
```

Collect explicit validation issues:

```moonbit
let report = @zip.validate_zip_archive(archive)
for issue in report.issues {
  ignore(issue.kind)
}
```

## Path Safety Policy

Current normalization/validation policy:

- backslashes are normalized to `/`
- leading slash paths are treated as unsafe
- drive-letter paths such as `C:\tmp\evil.txt` are treated as unsafe
- `.` / `..` / empty path segments are treated as unsafe
- embedded NUL bytes are treated as unsafe
- directory entries are preserved in inventory rather than silently discarded
- duplicate normalized paths are surfaced as validation issues

Safety-critical note:

- this pass keeps archive opening compatibility-oriented for raw entry access
- unsafe normalized paths are surfaced through structured validation rather than
  silently normalized into a lossy path
- higher consumers can use `normalize_entry_path`, `inspect_zip_archive`, or
  `validate_zip_archive` to apply stricter archive-hygiene policy

## Error And Validation Model

Error model:

- `ZipError` remains the direct open/read error surface
- `classify_zip_error` provides a structured companion with direct-variant or
  best-effort message mapping metadata

Validation model:

- `ZipValidationIssue` is for explicit archive-hygiene findings after a
  successful `open_zip`
- validation issues do not automatically become hard failures for normal
  archive reading

Current validation issue coverage includes:

- unsafe entry paths
- duplicate normalized entry paths
- directory entries
- empty file entries
- unsupported compression methods
- nested archive candidates by extension

Current classifier signal includes:

- `MissingEntry`
- `UnsupportedCompressionMethod`
- `EncryptedEntry`
- `DuplicateEntryName`
- `UnsupportedFeature`
- `MalformedArchive`
- `ReadEntryFailed`
- `Unknown`

Reserved / future source-mapped signals:

- richer encrypted/password handling
- ZIP64 and multi-disk parser-source mapping
- data-descriptor/source-mapped unsupported mode details
- more complete compression-method matrix coverage
- stronger zip-bomb ratio reporting when the backend can expose the needed
  size metadata consistently

## Compatibility Surface

The following remain public because in-repo consumers still depend on them:

- `ZipArchive.bytes`
- `ZipArchive.entries`
- `ZipArchive.entry_index`
- `ZipEntryMeta`
- `open_zip`
- `list_entries`
- `read_entry`

## Internal Exposed Surface

Current lower-level surface that remains public for now, but should still be
treated as implementation-shaped rather than the long-term package boundary:

- `ZipArchive.bytes`
- `ZipArchive.entries`
- `ZipArchive.entry_index`
- `ZipEntryMeta`
- `ZipError`
- `CompressionMethod`

These types are currently useful to in-repo consumers and tests, but the stable
candidate recommendation for new users is to start from the facade and inspect
types above them.

These are still supported, but they are not the full long-term abstraction
boundary by themselves.

## Known Limits

Current limits:

- no full ZIP spec support claim
- no password or encrypted ZIP recovery
- no multi-disk ZIP support
- no ZIP64 support
- no full compression-method matrix
- no recursive archive conversion policy
- no full zip-bomb guarantee beyond bounded entry reads and explicit archive
  validation signals
- unsupported-feature classification still mixes direct variant mapping with
  best-effort message-based detail mapping

## Relationship To Other Packages

Current in-repo consumers:

- `doc_parse/ooxml` uses this package as the OOXML container primitive
- `doc_parse/epub` uses this package as the EPUB container primitive
- `convert/zip` consumes this package for archive inspection and entry bytes,
  while keeping archive-entry conversion policy above this layer

`doc_parse/zip` does not absorb OOXML, EPUB, or ZIP-converter semantic policy.

## Testing

Current lower-layer tests cover:

- sample ZIP/DOCX/XLSX/PPTX smoke open/read
- structured entry inventory
- raw entry read and missing-entry classification
- unsafe path validation
- duplicate normalized path validation
- unsupported compression reporting
- deterministic ordering

Repository-level validation should still include `moon test` and
`./samples/check.sh` so OOXML/EPUB/ZIP consumers stay regression-safe.

## Versioning / API Stability

Current versioning note:

- treat the current facade as an active hardening surface, not a frozen
  standalone module contract
- prefer `inspect_zip_inventory`, `inspect_zip_archive`, `classify_zip_error`,
  and `validate_zip_archive` for new package consumers
- expect future release-policy work before any independent `doc_parse/zip`
  module split
