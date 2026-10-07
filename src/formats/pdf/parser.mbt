///|
const PDF_NATIVE_PARSER_NAME : String = "pdf_native_parser"

///|
const PDF_NATIVE_FAIL_CLOSED_MESSAGE : String = "PDF native text restore is disabled by parser policy"

///|
type PdfNativeError = @dpdfnative.PdfNativeError

///|
fn extract_pdf_native_document(
  source : @input.InputSource,
) -> Result[@dpdfnative.PdfNativeDocument, PdfNativeError] {
  @dpdfnative.extract_pdf_native_document(source)
}

///|
/// Stable parser name for the native-text PDF route.
pub fn pdf_native_parser_name() -> String {
  PDF_NATIVE_PARSER_NAME
}

///|
/// Fail-closed message emitted when native-text restore is intentionally gated
/// off.
pub fn pdf_native_fail_closed_message() -> String {
  PDF_NATIVE_FAIL_CLOSED_MESSAGE
}

///|
/// Capability for the native-text PDF route.
pub fn pdf_native_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    PageSinglePass,
    false,
    Page,
    true,
    true,
    false,
    false,
    false,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}
