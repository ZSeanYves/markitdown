///|
pub type OdfDocumentKind = @shared.OdfDocumentKind

///|
pub type OdfError = @shared.OdfError

///|
pub type OdfMetadataSummary = @shared.OdfMetadataSummary

///|
pub type OdfPackageInfo = @shared.OdfPackageInfo

///|
pub type OdsCell = @shared.OdsCell

///|
pub type OdsDocument = @shared.OdsDocument

///|
pub type OdsInspectReport = @shared.OdsInspectReport

///|
pub type OdsRow = @shared.OdsRow

///|
pub type OdsSheet = @shared.OdsSheet

///|
pub fn inspect_ods_document(document : OdsDocument) -> OdsInspectReport {
  @shared.inspect_ods_document(document)
}

///|
pub fn open_ods_document(bytes : Bytes) -> OdsDocument raise {
  @shared.open_ods_document(bytes)
}
