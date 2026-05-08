# pdfwrite

Write PDF documents to files, channels, or memory buffers.

## Overview

The `pdfwrite` package provides functions to:

- Serialize `Pdf` documents to byte streams
- Write to files, channels, or in-memory buffers
- Optionally encrypt output with passwords
- Generate object streams for compression
- Convert PDF objects to string representation

## Types

### PdfWrite

PDF writing context.

```mbt nocheck
pub struct PdfWrite { ... }
pub fn PdfWrite::new(logger? : (String) -> Unit = @pdfe.logger.val) -> PdfWrite
```

## Writing PDFs

### To File (Simple)

```mbt nocheck
@pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, "/path/to/output.pdf")
```

### To File (With Options)

```mbt nocheck
@pdfwritefs.PdfWriteFs::new().pdf_to_file_options(
  preserve_objstm=false,    // Keep existing object streams
  generate_objstm=true,     // Create new object streams
  compress_objstm=true,     // Compress object streams
  encryption=None,          // Optional encryption
  build_new_id=true,        // Generate new /ID entry
  pdf~,
  filename="/path/to/output.pdf",
)
```

### To Channel (async)

```mbt nocheck
@pdfwritefs.PdfWriteFs::new().pdf_to_channel(
  encryption=None,
  build_new_id=true,
  pdf~,
  channel,
)
```

### To Output Stream

```mbt nocheck
let (output, data) = @pdfio.Output::of_bytes(65536)
@pdfwrite.PdfWrite::new().pdf_to_output(
  encryption=None,
  build_new_id=true,
  pdf~,
  output~,
)
let bytes = output.extract_bytes(data)
```

## Encryption

### Creating Encryption Settings

```mbt nocheck
///|
let encryption = @pdfwrite.Encryption::new(
  @pdfcrypt.EncryptionMethod::AES256,
  user_password="user",
  owner_password="owner",
  permissions=[@pdfcrypt.Permission::Print, @pdfcrypt.Permission::Copy],
)
```

### Writing Encrypted PDF

```mbt nocheck
@pdfwritefs.PdfWriteFs::new().pdf_to_file_options(
  encryption=Some(encryption),
  build_new_id=true,
  pdf~,
  filename="/path/to/encrypted.pdf",
)
```

### Re-encryption

To re-encrypt an already-encrypted PDF (using its saved encryption metadata):

```mbt nocheck
@pdfwritefs.PdfWriteFs::new().pdf_to_file_options(
  recrypt="user-password",           // Password for the existing encryption
  encryption=None,                   // Uses saved encryption metadata
  build_new_id=false,
  pdf~,
  filename="/path/to/output.pdf",
)
```

## Object Streams

PDF 1.5+ supports object streams for compression:

```mbt nocheck
// Generate compressed object streams
@pdfwritefs.PdfWriteFs::new().pdf_to_file_options(
  generate_objstm=true,   // Create object streams
  compress_objstm=true,   // Compress with deflate
  encryption=None,
  build_new_id=true,
  pdf~,
  filename="/path/to/compressed.pdf",
)

// Preserve existing object streams
@pdfwritefs.PdfWriteFs::new().pdf_to_file_options(
  preserve_objstm=true,
  encryption=None,
  build_new_id=true,
  pdf~,
  filename="/path/to/output.pdf",
)
```

## Object Serialization

### Convert Object to String

```mbt check
///|
test "string_of_pdf serializes objects" {
  let obj : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
  ])
  let s = @pdfwrite.PdfWrite::new().string_of_pdf(obj)
  assert_true(s.contains("/Type"))
  assert_true(s.contains("/Page"))
}
```

## Logging

```mbt nocheck
// Redirect warnings/debug output during writing.
let write_ctx = @pdfwrite.PdfWrite::new(logger=_ => ())
ignore(write_ctx)
```

## Encryption Methods

```mbt nocheck
///|
pub type EncryptionMethod = @pdfcrypt.EncryptionMethod

// Available methods:
// AES256       - AES 256-bit (PDF 2.0, recommended)
// AES128       - AES 128-bit (PDF 1.6+)
// ARC4(Int)    - RC4 with key length (legacy)
```

## Encryption Struct

```mbt nocheck
///|
pub struct Encryption {
  encryption_method : EncryptionMethod
  user_password : String
  owner_password : String
  permissions : Array[@pdfcrypt.Permission]
}
```
