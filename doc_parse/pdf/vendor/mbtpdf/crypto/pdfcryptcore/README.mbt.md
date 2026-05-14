# pdfcrypt

PDF encryption and decryption operations.

## Overview

The `pdfcrypt` package provides:

- Encryption methods (AES, RC4)
- Permission flags for document restrictions
- Decryption of encrypted documents
- Encryption of output documents

## Encryption Methods

```mbt nocheck
///|
pub(all) enum EncryptionMethod {
  AES256 // AES 256-bit (recommended, PDF 2.0)
  AES128 // AES 128-bit (PDF 1.6+)
  ARC4(Int) // RC4 with key length (legacy)
}
```

## Permissions

Control what users can do with encrypted documents:

```mbt nocheck
///|
pub(all) enum Permission {
  Print // Allow printing
  Edit // Allow editing
  Copy // Allow copying text
  Annot // Allow annotations
  Forms // Allow form filling
  Extract // Allow accessibility extraction
  Assemble // Allow page assembly
  Hqprint // Allow high-quality printing
}
```

### Getting Permissions

```mbt nocheck
let perms = @pdfread.PdfRead::new().permissions(pdf)
for perm in perms {
  match perm {
    @pdfcrypt.Permission::Print => println("Print allowed")
    @pdfcrypt.Permission::Copy => println("Copy allowed")
    _ => ()
  }
}
```

### Permission Conversion

```mbt nocheck
// Convert permission flags to/from integer

///|
let banlist = @pdfcrypt.PdfCrypt::new().banlist_of_p(flags)
```

## Encrypting Documents

When writing PDFs, use `@pdfwrite` with encryption:

```mbt nocheck
let encryption = @pdfwrite.Encryption::new(
  @pdfcrypt.EncryptionMethod::AES256,
  user_password="user123",
  owner_password="owner456",
  permissions=[
    @pdfcrypt.Permission::Print,
    @pdfcrypt.Permission::Copy,
  ],
)

@pdfwritefs.PdfWriteFs::new().pdf_to_file_options(
  encryption=Some(encryption),
  build_new_id=true,
  pdf~,
  filename="encrypted.pdf",
)
```

## Decrypting Documents

When reading encrypted PDFs:

```mbt nocheck
// With user password

///|
let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(
  user_password=Some("user123"),
  owner_password=None,
  filename="encrypted.pdf",
)

// With owner password (full access)

///|
let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(
  user_password=None,
  owner_password=Some("owner456"),
  filename="encrypted.pdf",
)
```

## Checking Encryption

```mbt nocheck
let method = @pdfread.PdfRead::new().what_encryption(pdf)
match method {
  None => println("Not encrypted")
  Some(@pdfcrypt.EncryptionMethod::AES256) => println("AES 256-bit")
  Some(@pdfcrypt.EncryptionMethod::AES128) => println("AES 128-bit")
  Some(@pdfcrypt.EncryptionMethod::ARC4(40)) => println("RC4 40-bit")
  Some(@pdfcrypt.EncryptionMethod::ARC4(128)) => println("RC4 128-bit")
  _ => println("Other encryption")
}
```

## Security Notes

- **AES256** is recommended for new documents
- **ARC4** is considered legacy and less secure
- User password allows restricted access based on permissions
- Owner password allows full access regardless of permissions
