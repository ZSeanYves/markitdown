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
pub type PreparedOdpDocument = @odp.PreparedOdpDocument

///|
pub type PreparedOdsDocument = @ods.PreparedOdsDocument

///|
pub type PreparedOdtDocument = @odt.PreparedOdtDocument

///|
pub fn inspect_odp_document(document : OdpDocument) -> OdpInspectReport {
  @odp.inspect_odp_document(document)
}

///|
pub fn inspect_ods_document(document : OdsDocument) -> OdsInspectReport {
  @ods.inspect_ods_document(document)
}

///|
pub fn inspect_odt_document(document : OdtDocument) -> OdtInspectReport {
  @odt.inspect_odt_document(document)
}

///|
pub fn inspect_odt_package(bytes : Bytes) -> OdfPackageInfo raise {
  @odt.inspect_odt_package(bytes)
}

///|
pub fn open_odp_document(bytes : Bytes) -> OdpDocument raise {
  @odp.open_odp_document(bytes)
}

///|
pub fn open_ods_document(bytes : Bytes) -> OdsDocument raise {
  @ods.open_ods_document(bytes)
}

///|
pub fn open_odt_document(bytes : Bytes) -> OdtDocument raise {
  @odt.open_odt_document(bytes)
}

///|
pub fn prepare_odp_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedOdpDocument, String] {
  @odp.prepare_odp_document_from_source(source)
}

///|
pub fn prepare_ods_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedOdsDocument, String] {
  @ods.prepare_ods_document_from_source(source)
}

///|
pub fn prepare_odt_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedOdtDocument, String] {
  @odt.prepare_odt_document_from_source(source)
}
