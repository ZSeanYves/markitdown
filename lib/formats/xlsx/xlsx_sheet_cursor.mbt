///|
// Select original UTF8 intervals. The shared cursor identifies boundaries;
// downstream cell parsing still receives its original lexical representation.
priv struct XlsxSheetXmlWindow {
  output : Buffer
  mut pending : Bytes
  mut head : Int32
  mut base : Int64
  mut phase : Int32
  mut depth : Int32
  mut sheet_depth : Int32
  mut row_depth : Int32?
  mut rows : Int32
  row_limit : Int32
}

///|
fn XlsxSheetXmlWindow::consume(
  self : XlsxSheetXmlWindow,
  end : Int64,
  keep : Bool,
) -> Result[Unit, XlsxSheetStreamError] {
  if end <= self.base + self.head.to_int64() {
    return Ok(())
  }
  if end > self.base + self.pending.length().to_int64() {
    return Err(
      ReadFailed("worksheet cursor returned an unavailable raw interval"),
    )
  }
  let next = (end - self.base).to_int()
  if keep {
    self.output.write_bytes(self.pending[self.head:next])
  }
  self.head = next
  Ok(())
}

///|
fn XlsxSheetXmlWindow::token(
  self : XlsxSheetXmlWindow,
  token : @xml.XmlCursorToken,
) -> Result[Unit, XlsxSheetStreamError] {
  let span = match token {
    StartElement(_, _, _, span)
    | EndElement(_, span)
    | Comment(_, span)
    | ProcessingInstruction(_, _, span)
    | Declaration(_, span)
    | Doctype(_, span) => span
    TextFragment(text) | CDataFragment(text) => text.span
  }
  match token {
    StartElement(name, _, self_closing, _) => {
      if self.phase == 0 && self.depth == 1 && name.raw == "sheetData" {
        if self_closing {
          return Err(UnsupportedShape("worksheet has self-closing sheetData"))
        }
        match self.consume(span.end.utf8_byte, true) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        self.phase = 1
        self.sheet_depth = self.depth + 1
      } else if self.phase == 1 &&
        self.row_depth is None &&
        self.depth == self.sheet_depth &&
        name.raw == "row" &&
        self.rows < self.row_limit {
        match self.consume(span.start.utf8_byte, false) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        match self.consume(span.end.utf8_byte, true) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        self.rows += 1
        if !self_closing {
          self.row_depth = Some(self.depth + 1)
        }
      } else {
        match
          self.consume(
            span.end.utf8_byte,
            self.phase != 1 || self.row_depth is Some(_),
          ) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      if !self_closing {
        self.depth += 1
      }
    }
    EndElement(name, _) => {
      if self.phase == 1 &&
        self.depth == self.sheet_depth &&
        name.raw == "sheetData" {
        match self.consume(span.start.utf8_byte, false) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        self.phase = 2
      }
      match
        self.consume(
          span.end.utf8_byte,
          self.phase != 1 || self.row_depth is Some(_),
        ) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      if self.row_depth == Some(self.depth) {
        self.row_depth = None
      }
      self.depth -= 1
    }
    _ =>
      return self.consume(
        span.end.utf8_byte,
        self.phase != 1 || self.row_depth is Some(_),
      )
  }
  Ok(())
}

///|
fn xlsx_sheet_cursor_error(error : @xml.XmlCursorError) -> XlsxSheetStreamError {
  match error {
    Budget(error) => BudgetExceeded(error)
    InvalidEncoding(message, _) => InvalidEncoding(message)
    Syntax(_, message, _) => UnsupportedShape(message)
    Limit(_, observed~, limit~) =>
      ReadFailed(
        "worksheet cursor limit: " +
        observed.to_string() +
        "/" +
        limit.to_string(),
      )
    InvalidState(message) => ReadFailed("worksheet cursor protocol: " + message)
  }
}

///|
fn xlsx_drain_sheet_cursor(
  cursor : @xml.XmlCursor,
  window : XlsxSheetXmlWindow,
) -> Result[Bool, XlsxSheetStreamError] {
  while true {
    match cursor.next() {
      Err(error) => return Err(xlsx_sheet_cursor_error(error))
      Ok(NeedInput) => return Ok(false)
      Ok(End) => return Ok(true)
      Ok(Token(token)) =>
        match window.token(token) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
    }
  }
  Ok(false)
}

///|
async fn xlsx_compact_sheet_xml_stream(
  pkg : @ox.OoxmlPackage,
  part_name : String,
  max_rows : Int32,
) -> Result[Bytes, XlsxSheetStreamError] noraise {
  let limits = match
    @xml.XmlCursorLimits::new(
      MeasurementOnly,
      max_depth=None,
      max_token_bytes=None,
      max_attributes=None,
      max_tokens=None,
      text_fragment_bytes=64 * 1024,
    ) {
    Ok(limits) => limits
    Err(error) => return Err(xlsx_sheet_cursor_error(error))
  }
  let budget_context = @dzip.archive_budget_context(pkg.archive)
  let cursor = match
    @xml.new_xml_cursor(limits, budget_context?, allow_unbound_prefixes=true) {
    Err(error) => return Err(xlsx_sheet_cursor_error(error))
    Ok(cursor) => cursor
  }
  defer cursor.close()
  let window : XlsxSheetXmlWindow = {
    output: Buffer(),
    pending: b"",
    head: 0,
    base: 0L,
    phase: 0,
    depth: 0,
    sheet_depth: 0,
    row_depth: None,
    rows: 0,
    row_limit: max_rows.max(1),
  }
  let carry = Ref(b"")
  let failure : Ref[XlsxSheetStreamError?] = Ref(None)
  let result = @ox.visit_part_inflated_chunks(pkg, part_name, fn(chunk) {
    // Continue full UTF8/CRC validation after a recoverable XML shape error.
    // Only typed hard failures terminate the visit early.
    match @sourceio.decode_utf8_source_chunk(carry.val + chunk, false) {
      Err(message) => {
        @dzip.record_hard_failure(pkg.archive, part_name + ": " + message)
        failure.val = Some(InvalidEncoding(message))
        return Err(message)
      }
      Ok((_, remaining)) => carry.val = remaining
    }
    if failure.val is Some(_) {
      return Ok(())
    }
    window.base += window.head.to_int64()
    window.pending = window.pending[window.head:].to_owned() + chunk
    window.head = 0
    let drained = match cursor.feed(chunk, eof=false) {
      Err(error) => Err(xlsx_sheet_cursor_error(error))
      Ok(_) => xlsx_drain_sheet_cursor(cursor, window)
    }
    match drained {
      Err(UnsupportedShape(_) as error) => {
        failure.val = Some(error)
        cursor.close()
        window.pending = b""
        window.head = 0
        Ok(())
      }
      Err(error) => {
        failure.val = Some(error)
        @dzip.record_hard_failure(pkg.archive, "worksheet cursor hard failure")
        Err("worksheet cursor hard failure")
      }
      Ok(_) =>
        if window.phase != 1 || window.row_depth is Some(_) {
          window
          .consume(window.base + window.pending.length().to_int64(), true)
          .map_err(fn(_) { "worksheet raw interval failure" })
        } else {
          Ok(())
        }
    }
  })
  if result is Err(message) {
    if budget_context is Some(context) &&
      context.account.failure() is Some(error) {
      return Err(BudgetExceeded(error))
    }
    // An earlier recoverable grammar error cannot hide later ZIP CRC/I/O.
    return match failure.val {
      Some(UnsupportedShape(_)) | None => Err(ReadFailed(message))
      Some(error) => Err(error)
    }
  }
  match @sourceio.decode_utf8_source_chunk(carry.val, true) {
    Err(message) => {
      @dzip.record_hard_failure(pkg.archive, part_name + ": " + message)
      return Err(InvalidEncoding(message))
    }
    Ok(_) => ()
  }
  if failure.val is Some(error) {
    return Err(error)
  }
  match cursor.feed(b"", eof=true) {
    Err(error) => return Err(xlsx_sheet_cursor_error(error))
    Ok(_) => ()
  }
  match xlsx_drain_sheet_cursor(cursor, window) {
    Err(error) => Err(error)
    Ok(true) if window.phase == 2 => Ok(window.output.to_bytes())
    _ => Err(UnsupportedShape("worksheet stream ended before </sheetData>"))
  }
}
