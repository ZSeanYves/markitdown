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
  let use_native_json = text_payload.text.length() >= 1_048_576 &&
    !text_payload.text.has_prefix("\u{FEFF}") &&
    !text_payload.text.contains("\r")
  let parsed = try
    ({
      let root = if use_native_json {
        @djson.parse_json_document_native(
          text_payload.text,
          preserve_number_lexemes=false,
        )
      } else {
        @djson.parse_json_document(text_payload.text)
      }
      lower_ipynb_notebook(root)
    })
    |> Ok
  catch {
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
