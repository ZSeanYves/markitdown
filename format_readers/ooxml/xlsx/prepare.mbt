///|
pub struct PreparedXlsxPackage {
  prepared_source : @input.InputSource
  opened_package : @ox.OoxmlPackage
}

///|
pub fn prepare_xlsx_package_from_source(
  source : @input.InputSource,
) -> Result[PreparedXlsxPackage, String] {
  let prepared = match @zsource.prepare_zip_from_source(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let pkg = try @ox.open_ooxml_archive(prepared.archive) |> Ok catch {
    err => Err(err.to_string())
  }
  match pkg {
    Ok(value) =>
      Ok({ prepared_source: prepared.prepared_source, opened_package: value })
    Err(err) => Err(err)
  }
}
