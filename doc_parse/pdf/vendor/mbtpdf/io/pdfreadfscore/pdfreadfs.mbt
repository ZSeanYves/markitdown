///|
/// Filesystem/channel helpers for `@pdfread`.
///
/// `@pdfread` itself is intentionally in-memory: it reads from `@pdfio.Input`.
/// This package concentrates native-only `@fs.File` and filename helpers.

///|
pub struct PdfReadFs {
  reader : @pdfreadcore.PdfRead
}

///|
pub fn PdfReadFs::new() -> PdfReadFs {
  { reader: @pdfreadcore.PdfRead::new() }
}

///|
pub async fn PdfReadFs::pdf_of_channel(
  self : PdfReadFs,
  revision? : Int,
  source? : String = "channel",
  user_password : String?,
  owner_password : String?,
  channel : @fs.File,
) -> @pdf.Pdf {
  let input = @pdfiofs.input_of_channel(channel, source~)
  self.reader.pdf_of_input(revision?, user_password, owner_password, input)
}

///|
pub async fn PdfReadFs::pdf_of_file(
  self : PdfReadFs,
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  filename : String,
) -> @pdf.Pdf {
  let input = @pdfiofs.input_of_file(filename, source=filename)
  self.reader.pdf_of_input(revision?, user_password, owner_password, input)
}
