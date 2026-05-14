///|
/// Get page object number for a 1-based page index.
pub fn PdfPageDoc::page_object_number(
  self : PdfPageDoc,
  destpage : Int,
) -> Int? raise {
  let pdf = self.pdf
  let refs = pdf.page_reference_numbers()
  if destpage < 1 {
    return None
  }
  refs.get(destpage - 1)
}
