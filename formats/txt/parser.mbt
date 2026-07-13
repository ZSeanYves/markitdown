///|
pub fn txt_parser() -> @parser.Parser {
  @parser.make_parser(
    "txt_parser",
    @parser.ParserMode::StreamingEvent,
    txt_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let diagnostics = @fshared.empty_parser_diagnostics(
        "txt_parser",
        @parser.ParserMode::StreamingEvent,
        source,
        "txt",
      )
      let prepared = match @dtext.prepare_text_document_from_source(source) {
        Ok(document) => document
        Err(err) => {
          let fallback = invalid_text_parse_result(
            source, diagnostics, err, context,
          )
          return Ok(fallback)
        }
      }
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
            kind: @core.EventKind::BlankLine,
            text: "",
            source_ref: Some(source_ref),
          })
        } else {
          events.push({
            kind: @core.EventKind::TextLine,
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
            @parser.ParserMode::StreamingEvent,
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
          @parser.ParserMode::StreamingEvent,
          events,
          diagnostics,
          txt_parser_capability(),
        ),
      )
    },
  )
}

///|
fn txt_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::StreamingEvent,
    true,
    @parser.StreamingGranularity::Line,
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
    kind: @core.EventKind::StartBlock(@core.BlockKind::Raw),
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
    @parser.ParserMode::StreamingEvent,
    [event],
    diagnostics,
    txt_parser_capability(),
  )
}

///|
fn text_newline_style_name(style : @dtext.TextNewlineStyle) -> String {
  match style {
    @dtext.TextNewlineStyle::None => "none"
    @dtext.TextNewlineStyle::LF => "lf"
    @dtext.TextNewlineStyle::CRLF => "crlf"
    @dtext.TextNewlineStyle::CR => "cr"
    @dtext.TextNewlineStyle::Mixed => "mixed"
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
