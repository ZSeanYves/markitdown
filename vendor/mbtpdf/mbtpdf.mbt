///|
/// Root facade for the mbtpdf module.
///
/// Most functionality lives in subpackages (e.g. `@pdfread`, `@pdfwrite`,
/// `@pdfpage`, `@pdftext`). This package re-exports a small set of common
/// entry points and provides a couple of convenience helpers.
pub using @pdf {type Pdf, type PdfObject, type Stream}

///|
pub using @pdfread {type PdfRead}

///|
pub using @pdfreadfs {type PdfReadFs}

///|
pub using @pdfwrite {type PdfWrite, type Encryption}

///|
pub using @pdfwritefs {type PdfWriteFs}

///|
pub using @pdfcrypt {type EncryptionMethod, type Permission}

///|
/// Read a PDF from a file.
pub async fn read_file(
  filename : String,
  revision? : Int,
  user_password? : String,
  owner_password? : String,
) -> @pdf.Pdf {
  @pdfreadfs.PdfReadFs::new().pdf_of_file(
    revision?,
    user_password,
    owner_password,
    filename,
  )
}

///|
/// Write a PDF to a file.
pub async fn write_file(pdf : @pdf.Pdf, filename : String) -> Unit {
  @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, filename)
}
