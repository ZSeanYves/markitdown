///|
pub struct PreparedPptxDocument {
  prepared_source : @input.InputSource
  opened_package : @ox.OoxmlPackage
  document : PptxDocument
}

///|
pub fn prepare_pptx_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedPptxDocument, String] {
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let prepared_source = if @input.input_bytes(source) is Some(_) {
    source
  } else {
    @input.with_bytes_payload(source, bytes)
  }
  let pkg = try @ox.open_ooxml_package(bytes) |> Ok catch {
    err => Err(err.to_string())
  }
  let pkg = match pkg {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let document = try parse_pptx_document_from_package(pkg) |> Ok catch {
    err => Err(err.to_string())
  }
  match document {
    Ok(value) => Ok({ prepared_source, opened_package: pkg, document: value })
    Err(err) => Err(err)
  }
}
