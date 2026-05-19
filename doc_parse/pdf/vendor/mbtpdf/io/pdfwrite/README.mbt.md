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
let (output, data) = @pdfio.Output::of_bytes(65536)
@pdfwrite.PdfWrite::new().pdf_to_output(
  encryption=Some(encryption),
  build_new_id=true,
  pdf~,
  output~,
)
let bytes = output.extract_bytes(data)
ignore(bytes)
```

### Re-encryption

To re-encrypt an already-encrypted PDF (using its saved encryption metadata):

```mbt nocheck
let (output, data) = @pdfio.Output::of_bytes(65536)
@pdfwrite.PdfWrite::new().pdf_to_output(
  encryption=None,                   // Uses saved encryption metadata
  build_new_id=false,
  pdf~,
  output~,
)
let bytes = output.extract_bytes(data)
ignore(bytes)
```

## Object Streams

PDF 1.5+ supports object streams for compression:

```mbt nocheck
// Generate compressed object streams
let (output, data) = @pdfio.Output::of_bytes(65536)
@pdfwrite.PdfWrite::new().pdf_to_output(
  preserve_objstm=false,
  generate_objstm=true,
  compress_objstm=true,
  encryption=None,
  build_new_id=true,
  pdf~,
  output~,
)
let bytes = output.extract_bytes(data)
ignore(bytes)

// Preserve existing object streams
@pdfwrite.PdfWrite::new().pdf_to_output(
  preserve_objstm=true,
  generate_objstm=false,
  compress_objstm=true,
  encryption=None,
  build_new_id=true,
  pdf~,
  output~,
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
