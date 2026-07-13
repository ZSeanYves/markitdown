///|
pub struct PreparedXlsxPackage {
  prepared_source : @input.InputSource
  opened_package : @ox.OoxmlPackage
}

///|
pub fn prepare_xlsx_package_from_source(
  source : @input.InputSource,
) -> Result[PreparedXlsxPackage, String] {
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
  match pkg {
    Ok(value) => Ok({ prepared_source, opened_package: value })
    Err(err) => Err(err)
  }
}
