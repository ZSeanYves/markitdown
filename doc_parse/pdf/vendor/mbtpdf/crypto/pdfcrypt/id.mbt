///|
fn get_or_add_id(pdf : @pdf.Pdf) -> (String, @pdf.Pdf) raise {
  match pdf.lookup_direct("/ID", pdf.trailerdict) {
    Some(@pdf.PdfObject::Array([@pdf.PdfObject::String(s), _])) => (s, pdf)
    _ => {
      let stamp = @env.now().to_string()
      let id = stamp
      let idobj = @pdf.PdfObject::Array([
        @pdf.PdfObject::String(id),
        @pdf.PdfObject::String(id),
      ])
      pdf.trailerdict = pdf.trailerdict.add_entry("/ID", idobj)
      (id, pdf)
    }
  }
}
