///|
priv struct PullDelimitedRow {
  fields : Array[String]
  line_start : Int
  line_end : Int
}

///|
priv struct PullDelimitedReader {
  next : () -> Result[PullDelimitedRow?, String]
}

///|
fn open_pull_delimited_reader(
  source : @input.InputSource,
  context : @parser.ParseContext,
  delimiter : Char,
) -> Result[PullDelimitedReader, String] {
  let chunks = match
    @sourceio.open_source_text_chunk_reader(
      source,
      max_bytes=@parser.max_input_bytes(context),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let chunk = Ref("")
  let chunk_index = Ref(0)
  let eof = Ref(false)
  let replay : Ref[Char?] = { val: None }
  let skip_lf = Ref(false)
  let skip_bom = Ref(true)
  let row_fields : Array[String] = []
  let field = Ref(StringBuilder::new())
  let field_chars = Ref(0)
  let in_quotes = Ref(false)
  let pending_quote = Ref(false)
  let field_started = Ref(false)
  let line_no = Ref(1)
  let row_start = Ref(1)
  let last_record_break = Ref(false)
  let next_char = fn() -> Result[Char?, String] {
    while true {
      match replay.val {
        Some(ch) => {
          replay.val = None
          return Ok(Some(ch))
        }
        None => ()
      }
      if chunk_index.val >= chunk.val.length() && !eof.val {
        match (chunks.next)() {
          Ok(Some(value)) => {
            chunk.val = value.text
            chunk_index.val = 0
            continue
          }
          Ok(None) => eof.val = true
          Err(message) => return Err(message)
        }
      }
      if chunk_index.val >= chunk.val.length() {
        return Ok(None)
      }
      let ch = chunk.val[chunk_index.val].unsafe_to_char()
      chunk_index.val += 1
      if skip_bom.val {
        skip_bom.val = false
        if ch == '\u{FEFF}' {
          continue
        }
      }
      if skip_lf.val {
        skip_lf.val = false
        if ch == '\n' {
          continue
        }
      }
      if ch == '\r' {
        skip_lf.val = true
        return Ok(Some('\n'))
      }
      return Ok(Some(ch))
    }
    Ok(None)
  }
  let finish_field = fn() {
    row_fields.push(field.val.to_string())
    field.val = StringBuilder::new()
    field_chars.val = 0
    field_started.val = false
  }
  let finish_row = fn(line_end : Int) -> PullDelimitedRow? {
    finish_field()
    let values = row_fields.copy()
    row_fields.clear()
    let blank = values.all(value => value == "")
    let result = if blank {
      None
    } else {
      Some({ fields: values, line_start: row_start.val, line_end })
    }
    row_start.val = line_end + 1
    result
  }
  Ok({
    next: fn() {
      while true {
        let next = match next_char() {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        match next {
          None => {
            if pending_quote.val {
              pending_quote.val = false
              in_quotes.val = false
            }
            if in_quotes.val {
              return Err("unterminated quoted field")
            }
            if field_chars.val > 0 ||
              row_fields.length() > 0 ||
              !last_record_break.val {
              return Ok(finish_row(line_no.val))
            }
            return Ok(None)
          }
          Some(ch) => {
            if pending_quote.val {
              pending_quote.val = false
              if ch == '"' {
                field.val.write_char('"')
                field_chars.val += 1
                last_record_break.val = false
                continue
              }
              in_quotes.val = false
              replay.val = Some(ch)
              continue
            }
            if in_quotes.val {
              if ch == '"' {
                pending_quote.val = true
                continue
              }
              if ch == '\n' {
                line_no.val += 1
              }
              if field_chars.val >= context.max_line_chars.unwrap_or(4000) {
                return Err("delimited field exceeds max_line_chars")
              }
              field.val.write_char(ch)
              field_chars.val += 1
              last_record_break.val = false
              continue
            }
            if ch == '"' && !field_started.val && field_chars.val == 0 {
              in_quotes.val = true
              field_started.val = true
              last_record_break.val = false
              continue
            }
            if ch == delimiter {
              finish_field()
              last_record_break.val = false
              continue
            }
            if ch == '\n' {
              let end = line_no.val
              line_no.val += 1
              last_record_break.val = true
              match finish_row(end) {
                Some(row) => return Ok(Some(row))
                None => continue
              }
            }
            if field_chars.val >= context.max_line_chars.unwrap_or(4000) {
              return Err("delimited field exceeds max_line_chars")
            }
            field.val.write_char(ch)
            field_chars.val += 1
            field_started.val = true
            last_record_break.val = false
          }
        }
      }
      Ok(None)
    },
  })
}

///|
fn open_delimited_event_stream(
  parser_name : String,
  format : @input.DetectedFormat,
  is_tsv : Bool,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseEventStream?, String] {
  let delimiter = if is_tsv { '\t' } else { ',' }
  let scan_reader = match
    open_pull_delimited_reader(source, context, delimiter) {
    Ok(value) => value
    Err(_) => return Ok(None)
  }
  let mut raw_rows = 0
  let mut raw_cols = 0
  let mut ragged_rows = 0
  let mut first_width : Int? = None
  while true {
    match (scan_reader.next)() {
      Ok(Some(row)) => {
        raw_rows += 1
        raw_cols = raw_cols.max(row.fields.length())
        match first_width {
          Some(width) => if width != row.fields.length() { ragged_rows += 1 }
          None => first_width = Some(row.fields.length())
        }
      }
      Ok(None) => break
      Err(_) => return Ok(None)
    }
  }
  let max_rows = context.max_rows.unwrap_or(200)
  let max_cols = context.max_cols.unwrap_or(50)
  let max_cells = context.max_cells.unwrap_or(10000)
  let effective_cols = raw_cols.min(max_cols)
  let allowed_rows = if effective_cols == 0 {
    0
  } else {
    raw_rows.min(max_rows).min(max_cells / effective_cols)
  }
  let rows = match open_pull_delimited_reader(source, context, delimiter) {
    Ok(value) => value
    Err(_) => return Ok(None)
  }
  let emitted_rows = Ref(0)
  let event_count = Ref(0)
  let queued : Array[@core.CoreEvent] = []
  let queued_index = Ref(0)
  let format_name = @input.detected_format_name(format)
  let diagnostics = empty_parser_diagnostics(
    parser_name,
    StreamingEvent,
    source,
    format_name,
  )
  Ok(
    Some(
      @parser.make_parse_event_stream(
        fn() {
          while true {
            if queued_index.val < queued.length() {
              let event = queued[queued_index.val]
              queued_index.val += 1
              event_count.val += 1
              return Ok(Some(event))
            }
            queued.clear()
            queued_index.val = 0
            if emitted_rows.val >= allowed_rows {
              return Ok(None)
            }
            match (rows.next)() {
              Ok(Some(row)) => {
                let source_ref = @core.source_ref_with_lines(
                  @core.empty_source_ref(),
                  Some(source.source_name),
                  Some(format_name),
                  Some(row.line_start),
                  Some(row.line_end),
                )
                for column in 0..<effective_cols {
                  queued.push({
                    kind: Cell,
                    text: row.fields.get(column).unwrap_or(""),
                    source_ref: Some(source_ref),
                  })
                }
                if effective_cols > 0 {
                  queued.push({
                    kind: RowBreak,
                    text: "",
                    source_ref: Some(source_ref),
                  })
                }
                emitted_rows.val += 1
              }
              Ok(None) => return Ok(None)
              Err(message) => return Err(message)
            }
          }
          Ok(None)
        },
        fn() {
          diagnostics.metrics.set("parser_name", parser_name)
          diagnostics.metrics.set("parser_mode", "streaming_event")
          diagnostics.metrics.set("detected_format", format_name)
          diagnostics.metrics.set(
            "delimiter",
            if is_tsv {
              "tab"
            } else {
              "comma"
            },
          )
          diagnostics.metrics.set("raw_row_count", raw_rows.to_string())
          diagnostics.metrics.set("raw_column_count", raw_cols.to_string())
          diagnostics.metrics.set(
            "raw_cell_count",
            (raw_rows * raw_cols).to_string(),
          )
          diagnostics.metrics.set("row_count", allowed_rows.to_string())
          diagnostics.metrics.set("column_count", effective_cols.to_string())
          diagnostics.metrics.set(
            "cell_count",
            (allowed_rows * effective_cols).to_string(),
          )
          diagnostics.metrics.set("ragged_row_count", ragged_rows.to_string())
          diagnostics.metrics.set("event_count", event_count.val.to_string())
          diagnostics.metrics.set("event_granularity", "row")
          diagnostics.metrics.set("event_semantics", "row_cell_event_stream")
          diagnostics.metrics.set("ir_input_kind", "event_stream")
          diagnostics.metrics.set("stream_parser_to_renderer", "true")
          if ragged_rows > 0 {
            diagnostics.degraded_features.push("ragged_rows_normalized")
            diagnostics.fallback_trace.push(
              "ragged row normalization -> widest row width",
            )
          }
          if allowed_rows < raw_rows {
            diagnostics.warnings.push(
              "delimited row/cell resource limit applied",
            )
            diagnostics.degraded_features.push("max_rows_truncation")
          }
          apply_product_metrics(diagnostics, format_name)
          diagnostics.pass_trace.push("parse:" + parser_name + ":pull_stream")
          diagnostics.pass_trace.push("parse:" + parser_name)
          Ok(
            @parser.parse_stream_summary(
              parser_name,
              StreamingEvent,
              csv_parser_capability(),
              diagnostics,
            ),
          )
        },
      ),
    ),
  )
}
