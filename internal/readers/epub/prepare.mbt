///|
pub struct PreparedEpubPackage {
  prepared_source : @input.InputSource
  opened_package : EpubPackage
  inspect : EpubInspectReport
}

///|
fn epub_container_path(source : @input.InputSource) -> String {
  match @input.input_path(source) {
    Some(path) => {
      let parts = path.replace(old="\\", new="/").split("/").to_array()
      parts.last().unwrap_or(source.source_name).to_owned()
    }
    None => source.source_name
  }
}

///|
pub fn prepare_epub_package_from_source(
  source : @input.InputSource,
) -> Result[PreparedEpubPackage, String] {
  let prepared = match @zsource.prepare_zip_from_source(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let pkg = try
    open_epub_archive(prepared.archive, epub_container_path(source)) |> Ok
  catch {
    err => Err(err.to_string())
  }
  match pkg {
    Ok(value) =>
      Ok({
        prepared_source: prepared.prepared_source,
        opened_package: value,
        inspect: inspect_epub_package(value),
      })
    Err(err) => Err(err)
  }
}
