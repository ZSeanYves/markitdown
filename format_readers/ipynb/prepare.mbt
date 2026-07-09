///|
pub struct PreparedIpynbNotebook {
  prepared_source : @input.InputSource
  original_text : String
  notebook : IpynbNotebook?
  inspect : IpynbInspectReport?
  parse_error : String?
}

///|
pub fn prepare_ipynb_notebook_from_source(
  source : @input.InputSource,
) -> Result[PreparedIpynbNotebook, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let parsed = try parse_ipynb_notebook(text_payload.text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(notebook) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        notebook: Some(notebook),
        inspect: Some(inspect_ipynb_notebook(notebook)),
        parse_error: None,
      })
    Err(err) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        notebook: None,
        inspect: None,
        parse_error: Some(err),
      })
  }
}
