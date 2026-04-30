///|
pub struct PdfWrite {
  // Where warnings/debug output go during writing. Default is @pdfe.logger.val.
  logger : (String) -> Unit
}

///|
pub fn PdfWrite::new(logger? : (String) -> Unit = @pdfe.logger.val) -> PdfWrite {
  let _ = @pdfcryptprimitives.Encryption::AESV2
  let _ = @pdfread.PdfRead::new()
  let _ = @pdfpage.Rotation::Rotate0
  let _ = @pdfiofs.output_of_channel
  let _ = @async.now()
  let _ = @fs.exists
  { logger, }
}

///|
type PdfObject = @pdf.PdfObject
