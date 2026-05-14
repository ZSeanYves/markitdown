///|
fn get_or_add_id(pdf : @pdf.Pdf) -> (String, @pdf.Pdf) raise {
  match pdf.lookup_direct("/ID", pdf.trailerdict) {
    Some(@pdf.PdfObject::Array([@pdf.PdfObject::String(s), _])) => (s, pdf)
    _ => raise @pdf.PdfError::Msg("missing /ID element")
  }
}
