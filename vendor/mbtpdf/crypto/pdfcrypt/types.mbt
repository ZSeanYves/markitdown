///|
pub struct PdfCrypt {
  unit : Unit
}

///|
pub fn PdfCrypt::new() -> PdfCrypt {
  { unit: () }
}

///|
/// Is a PDF encrypted?
pub fn PdfCrypt::is_encrypted(_self : PdfCrypt, pdf : @pdf.Pdf) -> Bool {
  pdf.lookup_direct("/Encrypt", pdf.trailerdict) is Some(_)
}
