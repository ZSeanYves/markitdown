///|
pub struct PreparedDelimitedDocument {
  prepared_source : @input.InputSource
  original_text : String
  document : CsvDocument?
  inspect : CsvInspectReport?
  validation : CsvValidationReport?
  parse_error : String?
  format_name : String
  is_tsv : Bool
}

///|
fn prepare_csv_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedDelimitedDocument, String] {
  prepare_delimited_document_from_source(source, false)
}

///|
fn prepare_tsv_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedDelimitedDocument, String] {
  prepare_delimited_document_from_source(source, true)
}

///|
fn prepare_delimited_document_from_source(
  source : @input.InputSource,
  is_tsv : Bool,
) -> Result[PreparedDelimitedDocument, String] {
  let text_payload = match @sourceio.read_source_text_with_utf16_bom(source) {
    Ok(payload) => payload
    Err(_) =>
      match @sourceio.read_source_text_with_cp932_fallback(source) {
        Ok(payload) => payload
        Err(err) => return Err(err)
      }
  }
  let parsed = if is_tsv {
    try
      parse_csv_with_options(text_payload.text, csv_parse_options_for_tsv())
      |> Ok
    catch {
      e => Err(e.to_string())
    }
  } else {
    try parse_csv_document(text_payload.text) |> Ok catch {
      e => Err(e.to_string())
    }
  }
  match parsed {
    Ok(document) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: Some(document),
        inspect: Some(inspect_csv_document(document)),
        validation: Some(validate_csv_document(document)),
        parse_error: None,
        format_name: if is_tsv {
          "tsv"
        } else {
          "csv"
        },
        is_tsv,
      })
    Err(err) =>
      Ok({
        prepared_source: text_payload.prepared_source,
        original_text: text_payload.text,
        document: None,
        inspect: None,
        validation: None,
        parse_error: Some(err),
        format_name: if is_tsv {
          "tsv"
        } else {
          "csv"
        },
        is_tsv,
      })
  }
}
