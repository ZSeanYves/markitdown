///|
pub type OdfDocumentKind = @shared.OdfDocumentKind

///|
pub type OdfError = @shared.OdfError

///|
pub type OdfMetadataSummary = @shared.OdfMetadataSummary

///|
pub type OdfPackageInfo = @shared.OdfPackageInfo

///|
pub type OdtBlock = @shared.OdtBlock

///|
pub type OdtBlockKind = @shared.OdtBlockKind

///|
pub type OdtDocument = @shared.OdtDocument

///|
pub type OdtImageRef = @shared.OdtImageRef

///|
pub type OdtInline = @shared.OdtInline

///|
pub type OdtInspectReport = @shared.OdtInspectReport

///|
pub type OdtNote = @shared.OdtNote

///|
pub type OdtTableCell = @shared.OdtTableCell

///|
pub type OdtTableRow = @shared.OdtTableRow

///|
pub fn inspect_odt_document(document : OdtDocument) -> OdtInspectReport {
  @shared.inspect_odt_document(document)
}

///|
pub fn inspect_odt_package(bytes : Bytes) -> OdfPackageInfo raise {
  @shared.inspect_odt_package(bytes)
}

///|
pub fn open_odt_document(bytes : Bytes) -> OdtDocument raise {
  @shared.open_odt_document(bytes)
}
