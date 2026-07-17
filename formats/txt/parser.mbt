///|
pub fn txt_parser() -> @parser.Parser {
  @parser.make_parser(
    "txt_parser",
    StreamingEvent,
    txt_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let diagnostics = @fshared.empty_parser_diagnostics(
        "txt_parser",
        StreamingEvent,
        source,
        "txt",
      )
      let prepared = @dtext.prepare_text_document_from_source(source).unwrap()
      let source = prepared.prepared_source
      let parsed = match prepared.document {
        Some(document) => document
        None => {
          let fallback = invalid_text_parse_result(
            source,
            diagnostics,
            prepared.parse_error.unwrap_or("Utf8DecodeFailed(invalid utf8)"),
            context,
          )
          return Ok(fallback)
        }
      }
      let inspect = prepared.inspect.unwrap_or(
        @dtext.inspect_text_document(parsed),
      )
      let events : Array[@core.CoreEvent] = Array::new(
        capacity=parsed.lines.length(),
      )
      let max_line_chars = context.max_line_chars.unwrap_or(4000)
      let mut long_line_count = 0
      let source_name = Some(source.source_name)
      let format_name = Some("txt")
      for line in parsed.lines {
        if line.text.length() > max_line_chars {
          long_line_count += 1
        }
        let source_ref = @core.source_ref_with_bytes(
          @core.source_ref_with_lines(
            @core.empty_source_ref(),
            source_name,
            format_name,
            Some(line.line_no),
            Some(line.line_no),
          ),
          source_name,
          format_name,
          None,
          None,
        )
        if line.text.is_blank() {
          events.push({
            kind: BlankLine,
            text: "",
            source_ref: Some(source_ref),
          })
        } else {
          events.push({
            kind: TextLine,
            text: line.text,
            source_ref: Some(source_ref),
          })
        }
      }
      diagnostics.metrics.set("parser_name", "txt_parser")
      diagnostics.metrics.set("parser_mode", "streaming_event")
      diagnostics.metrics.set(
        "input_kind",
        @fshared.input_kind_name(@input.input_kind(source)),
      )
      diagnostics.metrics.set("detected_format", "txt")
      @fshared.apply_product_metrics(diagnostics, "txt")
      diagnostics.metrics.set("table_count", "0")
      diagnostics.metrics.set("image_count", "0")
      diagnostics.metrics.set("asset_count", "0")
      diagnostics.metrics.set("block_path_kind", "event_stream")
      diagnostics.metrics.set(
        "input_line_count",
        inspect.line_count.to_string(),
      )
      diagnostics.metrics.set("line_count", inspect.line_count.to_string())
      diagnostics.metrics.set(
        "paragraph_count",
        inspect.paragraph_count.to_string(),
      )
      diagnostics.metrics.set(
        "empty_line_count",
        inspect.empty_line_count.to_string(),
      )
      diagnostics.metrics.set("char_count", inspect.char_count.to_string())
      diagnostics.metrics.set(
        "newline_style",
        text_newline_style_name(inspect.newline_style),
      )
      diagnostics.metrics.set(
        "is_empty",
        @fshared.bool_string(inspect.is_empty),
      )
      diagnostics.metrics.set("invalid_utf8_fallback", "false")
      diagnostics.metrics.set("long_line_count", long_line_count.to_string())
      diagnostics.metrics.set("max_line_chars", max_line_chars.to_string())
      diagnostics.metrics.set(
        "block_count",
        inspect.paragraph_count.to_string(),
      )
      diagnostics.metrics.set("event_granularity", "line")
      diagnostics.metrics.set("event_semantics", "line_event_stream")
      if long_line_count > 0 {
        diagnostics.warnings.push(
          "txt line length limit exceeded on " +
          long_line_count.to_string() +
          " line(s)",
        )
        diagnostics.degraded_features.push("txt_long_line_truncation")
        diagnostics.fallback_trace.push(
          "txt long lines exceeded max_line_chars -> line truncation",
        )
        let truncated_events = events.map(event => {
          truncate_text_event_lines(event, max_line_chars)
        })
        diagnostics.metrics.set(
          "requested_mode",
          @fshared.requested_mode_name(context),
        )
        diagnostics.metrics.set("effective_mode", "streaming_event")
        diagnostics.metrics.set("ir_input_kind", "event_stream")
        diagnostics.metrics.set(
          "event_count",
          truncated_events.length().to_string(),
        )
        diagnostics.metrics.set(
          "degraded_feature_count",
          diagnostics.degraded_features.length().to_string(),
        )
        diagnostics.metrics.set(
          "fallback_count",
          diagnostics.fallback_trace.length().to_string(),
        )
        diagnostics.pass_trace.push("parse:txt_parser")
        return Ok(
          @parser.parse_result_with_events_capability(
            "txt_parser",
            StreamingEvent,
            truncated_events,
            diagnostics,
            txt_parser_capability(),
          ),
        )
      }
      diagnostics.metrics.set(
        "requested_mode",
        @fshared.requested_mode_name(context),
      )
      diagnostics.metrics.set("effective_mode", "streaming_event")
      diagnostics.metrics.set("ir_input_kind", "event_stream")
      diagnostics.metrics.set("event_count", events.length().to_string())
      diagnostics.metrics.set(
        "degraded_feature_count",
        diagnostics.degraded_features.length().to_string(),
      )
      diagnostics.metrics.set(
        "fallback_count",
        diagnostics.fallback_trace.length().to_string(),
      )
      diagnostics.pass_trace.push("parse:txt_parser")
      Ok(
        @parser.parse_result_with_events_capability(
          "txt_parser",
          StreamingEvent,
          events,
          diagnostics,
          txt_parser_capability(),
        ),
      )
    },
    stream_events=Some(open_txt_event_stream),
  )
}

///|
/// Open the native line producer used by the sink path. UTF-16 sources keep
/// the established buffered parser because the shared chunk cursor is UTF-8.
fn open_txt_event_stream(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseEventStream?, String] {
  let prefix = match @input.read_input_prefix(source, 2) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if prefix.length() >= 2 &&
    (
      (prefix[0].to_int() == 0xFF && prefix[1].to_int() == 0xFE) ||
      (prefix[0].to_int() == 0xFE && prefix[1].to_int() == 0xFF)
    ) {
    return Ok(None)
  }
  let reader = match
    @sourceio.open_source_text_chunk_reader(
      source,
      max_bytes=@parser.max_input_bytes(context),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let diagnostics = @fshared.empty_parser_diagnostics(
    "txt_parser",
    StreamingEvent,
    source,
    "txt",
  )
  diagnostics.metrics.set("parser_name", "txt_parser")
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set("detected_format", "txt")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("event_granularity", "line")
  diagnostics.metrics.set("event_semantics", "line_event_stream")
  diagnostics.metrics.set("stream_parser_to_renderer", "true")
  @fshared.apply_product_metrics(diagnostics, "txt")
  let current = Ref(StringBuilder::new())
  let current_chars = Ref(0)
  let line_truncated = Ref(false)
  let line_no = Ref(1)
  let line_has_content = Ref(false)
  let pending_cr = Ref(false)
  let skip_bom = Ref(true)
  let chunk = Ref("")
  let chunk_index = Ref(0)
  let eof = Ref(false)
  let emitted_events = Ref(0)
  let line_count = Ref(0)
  let empty_line_count = Ref(0)
  let char_count = Ref(0)
  let long_line_count = Ref(0)
  let saw_lf = Ref(false)
  let saw_crlf = Ref(false)
  let saw_cr = Ref(false)
  let max_line_chars = @parser.max_line_chars(context)
  let emit_line = fn() -> @core.CoreEvent {
    let text = current.val.to_string() +
      (if line_truncated.val { " [truncated]" } else { "" })
    let is_blank = !line_has_content.val
    let source_ref = @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("txt"),
      Some(line_no.val),
      Some(line_no.val),
    )
    current.val = StringBuilder::new()
    current_chars.val = 0
    if line_truncated.val {
      long_line_count.val += 1
    }
    line_truncated.val = false
    line_has_content.val = false
    line_count.val += 1
    if is_blank {
      empty_line_count.val += 1
    }
    line_no.val += 1
    if is_blank {
      { kind: BlankLine, text: "", source_ref: Some(source_ref) }
    } else {
      { kind: TextLine, text, source_ref: Some(source_ref) }
    }
  }
  Ok(
    Some(
      @parser.make_parse_event_stream(
        fn() {
          while true {
            if chunk_index.val >= chunk.val.length() && !eof.val {
              match (reader.next)() {
                Ok(Some(next_chunk)) => {
                  chunk.val = @sourceio.source_text_chunk_text(next_chunk)
                  chunk_index.val = 0
                  continue
                }
                Ok(None) => eof.val = true
                Err(message) => return Err(message)
              }
            }
            if chunk_index.val >= chunk.val.length() {
              if pending_cr.val {
                pending_cr.val = false
                saw_cr.val = true
                emitted_events.val += 1
                return Ok(Some(emit_line()))
              }
              if line_has_content.val || current.val.to_string() != "" {
                emitted_events.val += 1
                return Ok(Some(emit_line()))
              }
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
            if pending_cr.val {
              pending_cr.val = false
              if ch == '\n' {
                saw_crlf.val = true
                emitted_events.val += 1
                return Ok(Some(emit_line()))
              }
              chunk_index.val -= 1
              saw_cr.val = true
              emitted_events.val += 1
              return Ok(Some(emit_line()))
            }
            if ch == '\r' {
              pending_cr.val = true
              continue
            }
            if ch == '\n' {
              saw_lf.val = true
              emitted_events.val += 1
              return Ok(Some(emit_line()))
            }
            char_count.val += if ch.to_int() > 0xFFFF { 2 } else { 1 }
            let normalized = stream_normalize_txt_char(ch)
            if normalized != "" {
              line_has_content.val = true
              if current_chars.val + normalized.length() <= max_line_chars {
                current.val.write_string(normalized)
                current_chars.val += normalized.length()
              } else {
                let remaining = max_line_chars - current_chars.val
                if remaining > 0 {
                  current.val.write_string(normalized[:remaining].to_owned())
                  current_chars.val += remaining
                }
                line_truncated.val = true
              }
            }
          }
          Ok(None)
        },
        fn() {
          diagnostics.metrics.set(
            "input_line_count",
            line_count.val.to_string(),
          )
          diagnostics.metrics.set("line_count", line_count.val.to_string())
          diagnostics.metrics.set(
            "empty_line_count",
            empty_line_count.val.to_string(),
          )
          diagnostics.metrics.set("char_count", char_count.val.to_string())
          diagnostics.metrics.set(
            "newline_style",
            stream_txt_newline_style(saw_lf.val, saw_crlf.val, saw_cr.val),
          )
          diagnostics.metrics.set(
            "long_line_count",
            long_line_count.val.to_string(),
          )
          diagnostics.metrics.set("max_line_chars", max_line_chars.to_string())
          diagnostics.metrics.set("paragraph_count", "0")
          diagnostics.metrics.set("block_count", line_count.val.to_string())
          diagnostics.metrics.set("event_count", emitted_events.val.to_string())
          diagnostics.metrics.set(
            "stream_event_count",
            emitted_events.val.to_string(),
          )
          diagnostics.metrics.set("effective_mode", "streaming_event")
          diagnostics.metrics.set("ir_input_kind", "event_stream")
          if long_line_count.val > 0 {
            diagnostics.warnings.push(
              "txt line length limit exceeded on " +
              long_line_count.val.to_string() +
              " line(s)",
            )
            diagnostics.degraded_features.push("txt_long_line_truncation")
            diagnostics.fallback_trace.push(
              "txt long lines exceeded max_line_chars -> line truncation",
            )
          }
          diagnostics.pass_trace.push("parse:txt_parser")
          Ok(
            @parser.parse_stream_summary(
              "txt_parser",
              StreamingEvent,
              txt_parser_capability(),
              diagnostics,
            ),
          )
        },
      ),
    ),
  )
}

///|
fn stream_normalize_txt_char(ch : Char) -> String {
  match ch {
    '\t'
    | '\u{00A0}'
    | '\u{2007}'
    | '\u{2008}'
    | '\u{2009}'
    | '\u{200A}'
    | '\u{202F}'
    | '\u{205F}'
    | '\u{3000}' => " "
    '\u{00AD}' | '\u{200B}' | '\u{FEFF}' => ""
    'ﬀ' => "ff"
    'ﬁ' => "fi"
    'ﬂ' => "fl"
    'ﬃ' => "ffi"
    'ﬄ' => "ffl"
    'ﬅ' => "st"
    'ﬆ' => "st"
    _ => String::from_array([ch])
  }
}

///|
fn stream_txt_newline_style(lf : Bool, crlf : Bool, cr : Bool) -> String {
  let kinds = (if lf { 1 } else { 0 }) +
    (if crlf { 1 } else { 0 }) +
    (if cr { 1 } else { 0 })
  if kinds > 1 {
    "mixed"
  } else if crlf {
    "crlf"
  } else if cr {
    "cr"
  } else if lf {
    "lf"
  } else {
    "none"
  }
}

///|
fn txt_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    StreamingEvent,
    true,
    Line,
    false,
    true,
    false,
    true,
    false,
    false,
    true,
    true,
    false,
    false,
    false,
    false,
    true,
    true,
    true,
    false,
  )
}

///|
fn invalid_text_parse_result(
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  err : String,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("txt"),
    None,
    None,
  )
  let event : @core.CoreEvent = {
    kind: StartBlock(Raw),
    text: "[invalid utf8 text input]",
    source_ref: Some(source_ref),
  }
  diagnostics.warnings.push("txt decode warning: " + err)
  diagnostics.degraded_features.push("invalid_utf8_text_fallback")
  diagnostics.fallback_trace.push("txt invalid utf8 -> raw placeholder block")
  diagnostics.metrics.set("parser_name", "txt_parser")
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "txt")
  @fshared.apply_product_metrics(diagnostics, "txt")
  diagnostics.metrics.set("input_line_count", "0")
  diagnostics.metrics.set("line_count", "0")
  diagnostics.metrics.set("paragraph_count", "0")
  diagnostics.metrics.set("empty_line_count", "0")
  diagnostics.metrics.set("char_count", "0")
  diagnostics.metrics.set("newline_style", "invalid_utf8")
  diagnostics.metrics.set("invalid_utf8_fallback", "true")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("event_count", "1")
  diagnostics.metrics.set("event_granularity", "line")
  diagnostics.metrics.set("event_semantics", "line_event_stream")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.pass_trace.push("parse:txt_parser")
  @parser.parse_result_with_events_capability(
    "txt_parser",
    StreamingEvent,
    [event],
    diagnostics,
    txt_parser_capability(),
  )
}

///|
fn text_newline_style_name(style : @dtext.TextNewlineStyle) -> String {
  match style {
    None => "none"
    LF => "lf"
    CRLF => "crlf"
    CR => "cr"
    Mixed => "mixed"
  }
}

///|
fn truncate_text_event_lines(
  event : @core.CoreEvent,
  max_line_chars : Int,
) -> @core.CoreEvent {
  { ..event, text: truncate_text_lines(event.text, max_line_chars) }
}

///|
fn truncate_text_lines(text : String, max_line_chars : Int) -> String {
  text
  .split("\n")
  .to_array()
  .map(line => truncate_line(line.to_owned(), max_line_chars))
  .join("\n")
}

///|
fn truncate_line(text : String, max_chars : Int) -> String {
  if text.length() <= max_chars {
    return text
  }
  text[:max_chars].to_owned() + " [truncated]"
}
