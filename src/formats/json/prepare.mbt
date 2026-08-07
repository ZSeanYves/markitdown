///|
pub struct PreparedJsonText {
  prepared_source : @input.InputSource
  original_text : String
  document : JsonDocument?
  inspect : JsonInspectReport?
  stream : JsonStreamDocument?
  parse_error : String?
}

///|
pub fn prepare_json_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedJsonText, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let stream = try
    (if text_payload.text.length() >= 8_388_608 {
      parse_json_stream_summary(text_payload.text)
    } else {
      parse_json_stream_with_pointer_policy(text_payload.text, true)
    })
    |> Ok
  catch {
    e => Err(e.to_string())
  }
  match stream {
    Ok(stream_doc) => {
      let document : Result[JsonDocument, String] = if text_payload.text.length() >
        256_000 {
        Err("json DOM preparation skipped above the streaming limit")
      } else {
        try parse_json_document(text_payload.text) |> Ok catch {
          e => Err(e.to_string())
        }
      }
      match document {
        Ok(doc) =>
          Ok({
            prepared_source: text_payload.prepared_source,
            original_text: text_payload.text,
            document: Some(doc),
            inspect: Some(inspect_json_document(doc)),
            stream: Some(stream_doc),
            parse_error: None,
          })
        Err(err) =>
          Ok({
            prepared_source: text_payload.prepared_source,
            original_text: text_payload.text,
            document: None,
            inspect: None,
            stream: Some(stream_doc),
            parse_error: Some(err),
          })
      }
    }
    Err(err) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: None,
        inspect: None,
        stream: None,
        parse_error: Some(err),
      })
  }
}
