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
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let prepared_source = if @input.input_bytes(source) is Some(_) {
    source
  } else {
    @input.with_bytes_payload(source, bytes)
  }
  let pkg = try
    open_epub_package(bytes, epub_container_path(source)) |> Ok
  catch {
    err => Err(err.to_string())
  }
  match pkg {
    Ok(value) =>
      Ok({
        prepared_source,
        opened_package: value,
        inspect: inspect_epub_package(value),
      })
    Err(err) => Err(err)
  }
}
