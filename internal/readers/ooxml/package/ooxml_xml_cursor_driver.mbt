///|
fn ooxml_cursor_hard_failure(
  archive : @zip.ZipArchive,
  error : OoxmlError,
) -> OoxmlError {
  match error {
    InvalidEncoding(_) | BudgetExceeded(_) =>
      @zip.record_hard_failure(archive, error.to_string())
    _ => ()
  }
  error
}

///|
fn ooxml_cursor_error(part : String, error : @xml.XmlCursorError) -> OoxmlError {
  match error {
    Budget(error) => BudgetExceeded(error)
    InvalidEncoding(message, position) =>
      InvalidEncoding(
        part + ": " + message + "; utf8_byte=" + position.utf8_byte.to_string(),
      )
    Syntax(_, detail, span) =>
      InvalidXml(
        part + ": " + detail + "; utf8_byte=" + span.start.utf8_byte.to_string(),
      )
    Limit(_, observed~, limit~) =>
      InvalidXml(
        part +
        ": unexpected configured cursor cap; observed=" +
        observed.to_string() +
        "; limit=" +
        limit.to_string(),
      )
    InvalidState(detail) => InvalidXml(part + ": cursor protocol: " + detail)
  }
}

///|
// Both package metadata consumers drain every delivered chunk before the next
// ZIP pull. This driver publishes no consumer state; its caller publishes only
// after ZIP size/CRC and final cursor EOF validation have succeeded.
async fn visit_ooxml_xml_tokens(
  archive : @zip.ZipArchive,
  part : String,
  consume : (@xml.XmlCursorToken) -> Unit raise OoxmlError,
  chunk_size~ : Int32 = 64 * 1024,
  allow_syntax_recovery~ : Bool = false,
) -> @xml.XmlCursorStats raise OoxmlError {
  let context = @zip.archive_budget_context(archive)
  if context is Some(context) && context.account.failure() is Some(error) {
    raise ooxml_cursor_hard_failure(archive, BudgetExceeded(error))
  }
  if @zip.archive_hard_failure(archive) is Some(message) {
    raise ZipError(message)
  }
  if !@zip.has_entry(archive, part) {
    raise MissingPart(part)
  }
  if chunk_size <= 0 {
    raise InvalidXml(part + ": nonpositive chunk size")
  }
  let limits = match
    @xml.XmlCursorLimits::new(
      @budget.MeasurementOnly,
      max_depth=None,
      max_token_bytes=None,
      max_attributes=None,
      max_tokens=None,
      text_fragment_bytes=chunk_size.max(4),
    ) {
    Ok(value) => value
    Err(error) => raise ooxml_cursor_error(part, error)
  }
  let budget_context = context
  let cursor = match @xml.new_xml_cursor(limits, budget_context?) {
    Ok(value) => value
    Err(error) =>
      raise ooxml_cursor_hard_failure(archive, ooxml_cursor_error(part, error))
  }
  defer cursor.close()
  let callback_failure : Ref[OoxmlError?] = Ref(None)
  let visited = @zip.visit_inflated_entry_chunks(
    archive,
    part,
    chunk_size~,
    max_output_size=128 * 1024 * 1024,
    chunk => {
      let result = try {
        match cursor.feed(chunk, eof=false) {
          Err(error) => raise ooxml_cursor_error(part, error)
          Ok(_) => ()
        }
        Ok(drain_ooxml_xml_tokens(cursor, part, consume))
      } catch {
        error => Err(error)
      }
      match result {
        Ok(false) => Ok(())
        Ok(true) => {
          callback_failure.val = Some(
            InvalidXml(part + ": cursor ended before final input"),
          )
          Err("OOXML XML consumer stopped")
        }
        Err(error) => {
          callback_failure.val = Some(ooxml_cursor_hard_failure(archive, error))
          Err("OOXML XML consumer stopped")
        }
      }
    },
  )
  if visited is Err(message) {
    if context is Some(context) && context.account.failure() is Some(error) {
      raise ooxml_cursor_hard_failure(archive, BudgetExceeded(error))
    }
    if callback_failure.val is Some(error) {
      if allow_syntax_recovery && error is InvalidXml(_) {
        // A recoverable early grammar error must not hide hard failures in
        // unread tail bytes. Replay validates UTF8 and ZIP integrity only.
        cursor.close()
        verify_ooxml_xml_entry_integrity(archive, part, chunk_size~)
      }
      raise error
    }
    raise ZipError(message)
  }
  match cursor.feed(b"", eof=true) {
    Err(error) =>
      raise ooxml_cursor_hard_failure(archive, ooxml_cursor_error(part, error))
    Ok(_) => ()
  }
  let ended = drain_ooxml_xml_tokens(cursor, part, consume) catch {
    error => raise ooxml_cursor_hard_failure(archive, error)
  }
  if !ended {
    raise InvalidXml(part + ": missing final cursor End")
  }
  if @zip.archive_hard_failure(archive) is Some(message) {
    raise ZipError(message)
  }
  cursor.stats()
}

///|
fn drain_ooxml_xml_tokens(
  cursor : @xml.XmlCursor,
  part : String,
  consume : (@xml.XmlCursorToken) -> Unit raise OoxmlError,
) -> Bool raise OoxmlError {
  while true {
    match cursor.next() {
      Err(error) => raise ooxml_cursor_error(part, error)
      Ok(NeedInput) => return false
      Ok(End) => return true
      Ok(Token(token)) => consume(token)
    }
  }
  false
}
