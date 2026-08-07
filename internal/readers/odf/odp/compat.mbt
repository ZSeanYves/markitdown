///|
pub type OdfDocumentKind = @shared.OdfDocumentKind

///|
pub type OdfError = @shared.OdfError

///|
pub type OdfMetadataSummary = @shared.OdfMetadataSummary

///|
pub type OdfPackageInfo = @shared.OdfPackageInfo

///|
pub type OdpBlockKind = @shared.OdpBlockKind

///|
pub type OdpDocument = @shared.OdpDocument

///|
pub type OdpImageRef = @shared.OdpImageRef

///|
pub type OdpInspectReport = @shared.OdpInspectReport

///|
pub type OdpSlide = @shared.OdpSlide

///|
pub type OdpSlideBlock = @shared.OdpSlideBlock

///|
pub type OdpTableCell = @shared.OdpTableCell

///|
pub type OdpTableRow = @shared.OdpTableRow

///|
pub fn inspect_odp_document(document : OdpDocument) -> OdpInspectReport {
  @shared.inspect_odp_document(document)
}

///|
pub fn open_odp_document(bytes : Bytes) -> OdpDocument raise {
  @shared.open_odp_document(bytes)
}
