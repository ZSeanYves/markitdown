///|
pub type PdfNativeError = @dpdfnative.PdfNativeError

///|
pub fn extract_pdf_native_document_from_path(
  path : String,
) -> Result[PdfNativeDocument, PdfNativeError] {
  @dpdfnative.extract_pdf_native_document_from_path(path)
}

///|
pub fn extract_pdf_native_document(
  source : @input.InputSource,
) -> Result[PdfNativeDocument, PdfNativeError] {
  @dpdfnative.extract_pdf_native_document(source)
}
