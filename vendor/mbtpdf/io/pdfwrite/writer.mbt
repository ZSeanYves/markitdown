///|
pub struct PdfWrite {
  // Where warnings/debug output go during writing. Default is @pdfe.logger.val.
  logger : (String) -> Unit
}

///|
pub fn PdfWrite::new(logger? : (String) -> Unit = @pdfe.logger.val) -> PdfWrite {
  { logger, }
}

///|
type PdfObject = @pdf.PdfObject
