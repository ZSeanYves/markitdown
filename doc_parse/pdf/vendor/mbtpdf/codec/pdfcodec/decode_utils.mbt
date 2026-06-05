///|
fn[T] map_pdf_error(
  context : String,
  action : () -> T raise,
) -> T raise CodecError {
  action() catch {
    @pdf.PdfError::Msg(msg) =>
      raise CodecError::CouldntDecodeStream("\{context}: \{msg}")
    _ => raise CodecError::CouldntDecodeStream("\{context}: unknown error")
  }
}

///|
fn set_dict_entry(
  dict : @pdf.PdfObject,
  key : String,
  value : @pdf.PdfObject,
) -> @pdf.PdfObject raise CodecError {
  match dict.lookup_immediate(key) {
    Some(_) =>
      map_pdf_error("replace dict entry", fn() raise {
        dict.replace_entry(key, value)
      })
    None =>
      map_pdf_error("add dict entry", fn() raise { dict.add_entry(key, value) })
  }
}

///|
fn get_int_param(
  pdf : @pdf.Pdf,
  parms : @pdf.PdfObject?,
  key : String,
  default_value : Int,
) -> Int {
  match parms {
    Some(obj) =>
      match pdf.lookup_direct(key, obj) {
        Some(Integer(i)) => i
        Some(Real(r)) => r.to_int()
        _ => default_value
      }
    None => default_value
  }
}

///|
fn get_bool_param(
  pdf : @pdf.Pdf,
  parms : @pdf.PdfObject?,
  key : String,
  default_value : Bool,
) -> Bool {
  match parms {
    Some(obj) =>
      match pdf.lookup_direct(key, obj) {
        Some(Boolean(b)) => b
        _ => default_value
      }
    None => default_value
  }
}
