///|
pub struct PreparedEmlMessage {
  prepared_source : @input.InputSource
  original_text : String
  message : EmlMessage?
  inspect : EmlInspectReport?
  parse_error : String?
}

///|
pub async fn prepare_eml_message_from_source(
  source : @input.InputSource,
) -> Result[PreparedEmlMessage, String] noraise {
  let bytes_payload = match @sourceio.read_source_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let (text, owner) : (String, EmlWireOwner) = match @input.input_text(source) {
    Some(value) => (value, { bytes: bytes_payload.bytes, mode: Utf8, })
    None => eml_wire_text_and_owner(bytes_payload.bytes)
  }
  let prepared_source = if @input.input_text(bytes_payload.prepared_source)
    is Some(_) {
    bytes_payload.prepared_source
  } else {
    @input.with_prepared_text_payload(
      bytes_payload.prepared_source,
      text,
      physical_bytes=bytes_payload.bytes.length().to_int64(),
    )
  }
  let parsed = try
    eml_parse_wire_message(owner, eml_normalize_newlines(text)) |> Ok
  catch {
    LimitExceeded(kind, observed~, limit~) => {
      let failure_kind : @input.ResourceLimitKind = match kind {
        NestingDepth => MimeNestingDepth
        MultipartParts => MimeMultipartParts
      }
      @input.record_input_resource_failure(
        prepared_source,
        @input.make_resource_limit_failure(failure_kind, observed, limit),
      )
      return Err(LimitExceeded(kind, observed~, limit~).to_string())
    }
    InvalidEncoding(message) => return Err("eml encoding error: " + message)
    e => Err(e.to_string())
  }
  match parsed {
    Ok(message) =>
      Ok({
        prepared_source,
        original_text: text,
        message: Some(message),
        inspect: Some(inspect_eml_message(message)),
        parse_error: None,
      })
    Err(err) =>
      Ok({
        prepared_source,
        original_text: text,
        message: None,
        inspect: None,
        parse_error: Some(err),
      })
  }
}
