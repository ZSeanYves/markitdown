# pdfread

Read PDF files and construct in-memory `Pdf` documents.

## Overview

The `pdfread` package provides functions to:

- Read PDF files from disk, channels, or memory
- Parse cross-reference tables and object streams
- Handle encrypted documents with password support
- Support lazy loading for large files
- Query document revisions and encryption

## Types

### PdfRead

PDF reading context.

```mbt nocheck
pub struct PdfRead { ... }
pub fn PdfRead::new() -> PdfRead
```

## Reading PDFs

### From Input Stream

```mbt nocheck
// Read with all stream data loaded

///|
let pdf = @pdfread.PdfRead::new().pdf_of_input(
  user_password=None,
  owner_password=None,
  input,
)
```

### Lazy Loading

For large files, use lazy loading to defer stream data:

```mbt nocheck
// Streams loaded on-demand

///|
let pdf = @pdfread.PdfRead::new().pdf_of_input_lazy(
  user_password=None,
  owner_password=None,
  input,
)
```

### From File (async)

```mbt nocheck
///|
let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(
  user_password=None,
  owner_password=None,
  filename="/path/to/document.pdf",
)
```

### From Channel (async)

```mbt nocheck
///|
let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_channel(
  user_password=None,
  owner_password=None,
  channel,
)
```

## Password-Protected Documents

For encrypted PDFs:

```mbt nocheck
// With user password

///|
let pdf = @pdfread.PdfRead::new().pdf_of_input(
  user_password=Some("secret"),
  owner_password=None,
  input,
)

// With owner password

///|
let pdf = @pdfread.PdfRead::new().pdf_of_input(
  user_password=None,
  owner_password=Some("admin123"),
  input,
)
```

## Document Revisions

PDF files can have multiple revisions (incremental saves):

```mbt nocheck
// Count revisions

///|
let num_revisions = @pdfread.PdfRead::new().revisions(input)

// Read specific revision

///|
let pdf = @pdfread.PdfRead::new().pdf_of_input(
  revision=2,
  user_password=None,
  owner_password=None, // Read second revision
  input,
)
```

## Encryption Information

### Query Encryption Method

```mbt nocheck
let method = @pdfread.PdfRead::new().what_encryption(pdf)
match method {
  None => println("Not encrypted")
  Some(AES128) => println("AES 128-bit")
  Some(AES256) => println("AES 256-bit")
  Some(ARC4(40)) => println("RC4 40-bit")
  Some(ARC4(128)) => println("RC4 128-bit")
  _ => ()
}
```

### Query Permissions

```mbt nocheck
let perms = @pdfread.PdfRead::new().permissions(pdf)
for perm in perms {
  match perm {
    Print => println("Printing allowed")
    Copy => println("Copying allowed")
    Edit => println("Editing allowed")
    _ => ()
  }
}
```

## Debug Options

```mbt nocheck
// Enable debug output

///|
let reader = @pdfread.PdfRead::new(read_debug=true)

// Treat all documents as malformed (for testing)

///|
let reader_force_malformed = @pdfread.PdfRead::new(
  debug_always_treat_malformed=true,
)

// Raise errors on malformed documents

///|
let reader_strict = @pdfread.PdfRead::new(error_on_malformed=true)
```

## Error Handling

Reading raises `@pdf.PdfError` on parse failures:

```mbt nocheck
try {
  let pdf = @pdfread.PdfRead::new().pdf_of_input!(
    user_password=None,
    owner_password=None,
    input,
  )
  // use pdf...
} catch {
  @pdf.PdfError::Msg(msg) => println("Parse error: \{msg}")
}
```

## Internal Structure

The package handles:

- **Cross-reference tables**: Traditional `xref` tables and compressed xref streams
- **Object streams**: Compressed object storage (PDF 1.5+)
- **Linearization**: Optimized web viewing (detected and handled)
- **Encryption**: RC4 and AES decryption with key derivation
