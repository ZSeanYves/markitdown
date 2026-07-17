///|
priv struct LineJsonPullScan {
  header_keys : Array[String]?
  record_count : Int
  object_count : Int
  array_count : Int
  scalar_count : Int
  max_depth : Int
  blank_line_count : Int
  mismatch_count : Int
}

///|
fn open_line_json_event_stream(
  parser_name : String,
  format_name : String,
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseEventStream?, String] {
  let scan = match scan_line_json_source(format_name, source, context) {
    Ok(value) => value
    Err(_) => return Ok(None)
  }
  let table_reader = match open_line_json_reader(source, context) {
    Ok(value) => value
    Err(_) => return Ok(None)
  }
  let code_reader : Ref[@sourceio.SourceTextLineReader?] = { val: None }
  let phase = Ref(if scan.header_keys is Some(_) { 0 } else { 1 })
  let header_emitted = Ref(false)
  let table_records = Ref(0)
  let code_records = Ref(0)
  let queued : Array[@core.CoreEvent] = []
  let queued_index = Ref(0)
  let event_count = Ref(0)
  let diagnostics = @fshared.empty_parser_diagnostics(
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
            if phase.val == 0 {
              let header = scan.header_keys.unwrap_or([])
              if !header_emitted.val {
                append_line_json_row_events(
                  queued, header, source, format_name, 1,
                )
                header_emitted.val = true
                continue
              }
              match
                next_line_json_record(
                  table_reader, format_name, context, table_records,
                ) {
                Ok(Some(record)) => {
                  let root = record.1.root
                  match root {
                    Object(members) => {
                      let keys = members.map(entry => entry.key)
                      if @fshared.keys_match_position_index(
                          header,
                          @fshared.key_position_index(header),
                          keys,
                        ) {
                        append_line_json_row_events(
                          queued,
                          json_members_to_row(members, header),
                          source,
                          format_name,
                          record.0.line_no,
                        )
                      }
                    }
                    _ => ()
                  }
                }
                Ok(None) => {
                  phase.val = 1
                  continue
                }
                Err(message) => return Err(message)
              }
            } else {
              let reader = match code_reader.val {
                Some(value) => value
                None => {
                  let value = match open_line_json_reader(source, context) {
                    Ok(opened) => opened
                    Err(message) => return Err(message)
                  }
                  code_reader.val = Some(value)
                  value
                }
              }
              match
                next_line_json_record(
                  reader, format_name, context, code_records,
                ) {
                Ok(Some(record)) => {
                  let raw = record.0.text.trim().to_owned()
                  let mismatch = match (scan.header_keys, record.1.root) {
                    (Some(header), Object(members)) => {
                      let keys = members.map(entry => entry.key)
                      !@fshared.keys_match_position_index(
                        header,
                        @fshared.key_position_index(header),
                        keys,
                      )
                    }
                    (Some(_), _) => true
                    (None, _) => true
                  }
                  if mismatch {
                    let pointer = "/" + (code_records.val - 1).to_string()
                    queued.push({
                      kind: StartBlock(Code),
                      text: raw,
                      source_ref: Some(
                        line_delimited_code_event_source_ref(
                          source,
                          format_name,
                          pointer,
                          record.0.line_no,
                        ),
                      ),
                    })
                  }
                }
                Ok(None) => return Ok(None)
                Err(message) => return Err(message)
              }
            }
          }
          Ok(None)
        },
        fn() {
          @fshared.init_parser_route_metrics_with_granularity(
            diagnostics,
            source,
            context,
            format_name,
            parser_name,
            StreamingEvent,
            StreamingEvent,
            "event_stream",
            Record,
            "record_event_stream",
          )
          @fshared.apply_product_metrics(diagnostics, format_name)
          diagnostics.metrics.set("record_count", scan.record_count.to_string())
          diagnostics.metrics.set("row_count", scan.record_count.to_string())
          diagnostics.metrics.set("object_count", scan.object_count.to_string())
          diagnostics.metrics.set("array_count", scan.array_count.to_string())
          diagnostics.metrics.set("scalar_count", scan.scalar_count.to_string())
          diagnostics.metrics.set(
            "max_depth_observed",
            scan.max_depth.to_string(),
          )
          diagnostics.metrics.set(
            "blank_line_count",
            scan.blank_line_count.to_string(),
          )
          diagnostics.metrics.set("invalid_record_count", "0")
          diagnostics.metrics.set(
            "non_table_record_count",
            scan.mismatch_count.to_string(),
          )
          diagnostics.metrics.set("event_count", event_count.val.to_string())
          diagnostics.metrics.set(
            "record_count_emitted",
            scan.record_count.to_string(),
          )
          diagnostics.metrics.set("stream_parser_to_renderer", "true")
          if scan.blank_line_count > 0 {
            diagnostics.warnings.push(
              "blank " +
              format_name +
              " line(s) skipped: " +
              scan.blank_line_count.to_string(),
            )
            diagnostics.degraded_features.push(
              format_name + "_blank_line_skipped",
            )
            diagnostics.fallback_trace.push(
              format_name + " blank line -> skip empty record",
            )
          }
          @fshared.refresh_parser_count_metrics(diagnostics, "event_stream")
          diagnostics.pass_trace.push("parse:" + parser_name + ":pull_stream")
          diagnostics.pass_trace.push("parse:" + parser_name)
          Ok(
            @parser.parse_stream_summary(
              parser_name,
              StreamingEvent,
              capability,
              diagnostics,
            ),
          )
        },
      ),
    ),
  )
}

///|
fn open_line_json_reader(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@sourceio.SourceTextLineReader, String] {
  @sourceio.open_source_text_line_reader(
    source,
    max_bytes=@parser.max_input_bytes(context),
    max_line_chars=@parser.max_line_chars(context),
  )
}

///|
fn next_line_json_record(
  reader : @sourceio.SourceTextLineReader,
  format_name : String,
  context : @parser.ParseContext,
  count : Ref[Int],
) -> Result[(@sourceio.SourceTextLine, @djson.JsonDocument)?, String] {
  let max_rows = context.max_rows.unwrap_or(200)
  while count.val < max_rows {
    let line = match (reader.next)() {
      Ok(Some(value)) => value
      Ok(None) => return Ok(None)
      Err(message) => return Err(message)
    }
    let raw = normalize_line_delimited_json_record(line.text).trim().to_owned()
    if raw == "" {
      continue
    }
    if line.truncated {
      return Err(format_name + " record exceeds max_line_chars")
    }
    let document = @djson.parse_json_document(raw) catch {
      error =>
        return Err(
          "invalid " +
          format_name +
          " record at line " +
          line.line_no.to_string() +
          ": " +
          error.to_string(),
        )
    }
    count.val += 1
    return Ok(Some((line, document)))
  }
  Ok(None)
}

///|
fn scan_line_json_source(
  format_name : String,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[LineJsonPullScan, String] {
  let reader = match open_line_json_reader(source, context) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let count = Ref(0)
  let mut header_keys : Array[String]? = None
  let mut object_count = 0
  let mut array_count = 0
  let mut scalar_count = 0
  let mut max_depth = 0
  let mut blank_line_count = 0
  let mut mismatch_count = 0
  while count.val < context.max_rows.unwrap_or(200) {
    let line = match (reader.next)() {
      Ok(Some(value)) => value
      Ok(None) => break
      Err(message) => return Err(message)
    }
    let raw = normalize_line_delimited_json_record(line.text).trim().to_owned()
    if raw == "" {
      blank_line_count += 1
      continue
    }
    if line.truncated {
      return Err(format_name + " record exceeds max_line_chars")
    }
    let document = @djson.parse_json_document(raw) catch {
      error =>
        return Err(
          "invalid " +
          format_name +
          " record at line " +
          line.line_no.to_string() +
          ": " +
          error.to_string(),
        )
    }
    let inspect = @djson.inspect_json_document(document)
    object_count += inspect.object_count
    array_count += inspect.array_count
    scalar_count += inspect.scalar_count
    max_depth = max_depth.max(inspect.max_depth)
    match document.root {
      Object(members) => {
        let keys = members.map(entry => entry.key)
        match header_keys {
          Some(header) =>
            if !@fshared.keys_match_position_index(
                header,
                @fshared.key_position_index(header),
                keys,
              ) {
              mismatch_count += 1
            }
          None => header_keys = Some(keys)
        }
      }
      _ => mismatch_count += 1
    }
    count.val += 1
  }
  Ok({
    header_keys,
    record_count: count.val,
    object_count,
    array_count,
    scalar_count,
    max_depth,
    blank_line_count,
    mismatch_count,
  })
}

///|
fn append_line_json_row_events(
  events : Array[@core.CoreEvent],
  values : Array[String],
  source : @input.InputSource,
  format_name : String,
  line_no : Int,
) -> Unit {
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some(format_name),
    Some(line_no),
    Some(line_no),
  )
  for value in values {
    events.push({ kind: Cell, text: value, source_ref: Some(source_ref) })
  }
  if values.length() > 0 {
    events.push({ kind: RowBreak, text: "", source_ref: Some(source_ref) })
  }
}
