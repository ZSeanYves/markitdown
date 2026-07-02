///|
fn csv_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::StreamingEvent,
    true,
    @parser.StreamingGranularity::Row,
    false,
    true,
    false,
    true,
    false,
    false,
    true,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
pub fn csv_parser() -> @parser.Parser {
  delimited_parser("csv_parser", @input.DetectedFormat::Csv, false)
}

///|
pub fn tsv_parser() -> @parser.Parser {
  delimited_parser("tsv_parser", @input.DetectedFormat::Tsv, true)
}

///|
fn delimited_parser(
  name : String,
  format : @input.DetectedFormat,
  is_tsv : Bool,
) -> @parser.Parser {
  @parser.make_parser(
    name,
    @parser.ParserMode::StreamingEvent,
    csv_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let format_name = @input.detected_format_name(format)
      let text = match read_delimited_input_text(source) {
        Ok(payload) => payload
        Err(err) => return Err(err)
      }
      let diagnostics = @parser_common.empty_parser_diagnostics(
        name,
        @parser.ParserMode::StreamingEvent,
        source,
        format_name,
      )
      let parsed = if is_tsv {
        try
          @dcsv.parse_csv_with_options(text, @dcsv.csv_parse_options_for_tsv())
          |> Ok
        catch {
          e => Err(e.to_string())
        }
      } else {
        try @dcsv.parse_csv_document(text) |> Ok catch {
          e => Err(e.to_string())
        }
      }
      let table_doc = match parsed {
        Ok(doc) => doc
        Err(err) => {
          let fallback = malformed_delimited_parse_result(
            name, source, format, text, diagnostics, err, context,
          )
          return Ok(fallback)
        }
      }
      let inspect = @dcsv.inspect_csv_document(table_doc)
      let validation = @dcsv.validate_csv_document(table_doc)
      let max_rows = context.max_rows.unwrap_or(200)
      let max_cols = context.max_cols.unwrap_or(50)
      let max_cells = context.max_cells.unwrap_or(10000)
      let raw_row_count = table_doc.rows.length()
      let raw_col_count = table_doc.column_count
      let raw_cell_count = raw_row_count * raw_col_count
      let effective_row_count = @parser_common.min_int(raw_row_count, max_rows)
      let effective_col_count = @parser_common.min_int(raw_col_count, max_cols)
      let delimiter_name = if is_tsv { "tab" } else { "comma" }
      diagnostics.metrics.set("parser_name", name)
      diagnostics.metrics.set("parser_mode", "streaming_event")
      diagnostics.metrics.set(
        "input_kind",
        @parser_common.input_kind_name(source.kind),
      )
      diagnostics.metrics.set("detected_format", format_name)
      @parser_common.apply_product_metrics(diagnostics, format_name)
      diagnostics.metrics.set("delimiter", delimiter_name)
      diagnostics.metrics.set("raw_row_count", raw_row_count.to_string())
      diagnostics.metrics.set("raw_column_count", raw_col_count.to_string())
      diagnostics.metrics.set("raw_cell_count", raw_cell_count.to_string())
      diagnostics.metrics.set("line_count", inspect.line_count.to_string())
      diagnostics.metrics.set(
        "header_rows",
        if raw_row_count > 0 {
          "1"
        } else {
          "0"
        },
      )
      diagnostics.metrics.set(
        "empty_cell_count",
        inspect.empty_cell_count.to_string(),
      )
      diagnostics.metrics.set(
        "blank_row_count",
        inspect.blank_row_count.to_string(),
      )
      diagnostics.metrics.set(
        "ragged_row_count",
        inspect.ragged_row_count.to_string(),
      )
      diagnostics.metrics.set(
        "multiline_row_count",
        inspect.multiline_row_count.to_string(),
      )
      diagnostics.metrics.set(
        "multiline_field_count",
        inspect.multiline_field_count.to_string(),
      )
      diagnostics.metrics.set(
        "validation_issue_count",
        validation.issue_count.to_string(),
      )
      diagnostics.metrics.set("quoted_field_support", "true")
      diagnostics.metrics.set("escaped_quote_support", "true")
      diagnostics.metrics.set("quoted_newline_capability", "true")
      diagnostics.metrics.set("row_count", effective_row_count.to_string())
      diagnostics.metrics.set("column_count", effective_col_count.to_string())
      diagnostics.metrics.set(
        "cell_count",
        (effective_row_count * effective_col_count).to_string(),
      )
      diagnostics.metrics.set("table_count", "1")
      diagnostics.metrics.set("image_count", "0")
      diagnostics.metrics.set("asset_count", "0")
      diagnostics.metrics.set(
        "requested_mode",
        @parser_common.requested_mode_name(context),
      )
      diagnostics.metrics.set("effective_mode", "streaming_event")
      diagnostics.metrics.set("ir_input_kind", "event_stream")
      diagnostics.metrics.set("event_granularity", "row")
      diagnostics.metrics.set("event_semantics", "row_cell_event_stream")
      for issue in validation.issues {
        diagnostics.warnings.push(delimited_validation_issue_message(issue))
      }
      if inspect.ragged_row_count > 0 {
        diagnostics.degraded_features.push("ragged_rows_normalized")
        diagnostics.fallback_trace.push(
          "ragged row normalization -> widest row width",
        )
      }
      diagnostics.metrics.set(
        "quoted_newline_observed",
        @parser_common.bool_string(inspect.multiline_field_count > 0),
      )
      diagnostics.metrics.set(
        "quoted_delimiter_support",
        if is_tsv {
          "quoted_tab"
        } else {
          "quoted_comma"
        },
      )
      if raw_row_count > max_rows {
        diagnostics.warnings.push(
          "row limit applied: kept " +
          effective_row_count.to_string() +
          " of " +
          raw_row_count.to_string(),
        )
        diagnostics.degraded_features.push("max_rows_truncation")
        diagnostics.fallback_trace.push("row limit applied to delimited table")
      }
      if raw_col_count > max_cols {
        diagnostics.warnings.push(
          "column limit applied: kept " +
          effective_col_count.to_string() +
          " of " +
          raw_col_count.to_string(),
        )
        diagnostics.degraded_features.push("max_cols_truncation")
        diagnostics.fallback_trace.push(
          "column limit applied to delimited table",
        )
      }
      if raw_cell_count > max_cells {
        diagnostics.warnings.push(
          "cell limit applied: source had " + raw_cell_count.to_string(),
        )
        diagnostics.degraded_features.push("max_cells_truncation")
        diagnostics.fallback_trace.push("cell limit applied to delimited table")
      }
      let max_rows_by_cells = if effective_col_count == 0 {
        0
      } else {
        max_cells / effective_col_count
      }
      let allowed_rows = @parser_common.min_int(
        effective_row_count, max_rows_by_cells,
      )
      let truncated_row_count = raw_row_count - allowed_rows
      let truncated_col_count = raw_col_count - effective_col_count
      let truncated_cell_count = raw_cell_count -
        allowed_rows * effective_col_count
      diagnostics.metrics.set(
        "truncated_row_count",
        @parser_common.max_int(truncated_row_count, 0).to_string(),
      )
      diagnostics.metrics.set(
        "truncated_column_count",
        @parser_common.max_int(truncated_col_count, 0).to_string(),
      )
      diagnostics.metrics.set(
        "truncated_cell_count",
        @parser_common.max_int(truncated_cell_count, 0).to_string(),
      )
      if allowed_rows < effective_row_count {
        diagnostics.warnings.push(
          "cell budget reduced rows to " + allowed_rows.to_string(),
        )
        diagnostics.degraded_features.push("cell_budget_row_trim")
        diagnostics.fallback_trace.push("cell budget trimmed row count")
      }
      let row_event_width = if effective_col_count > 0 {
        effective_col_count + 1
      } else {
        0
      }
      let events : Array[@core.CoreEvent] = Array::new(
        capacity=allowed_rows * row_event_width,
      )
      let source_name = Some(source.source_name)
      let format_value = Some(format_name)
      let cell_suffixes : Array[String] = Array::new(
        capacity=effective_col_count,
      )
      for col_index in 0..<effective_col_count {
        cell_suffixes.push((col_index + 1).to_string())
      }
      let last_cell_suffix = if effective_col_count > 0 {
        cell_suffixes[effective_col_count - 1]
      } else {
        ""
      }
      for row_index in 0..<allowed_rows {
        let row = table_doc.rows[row_index]
        let row_number = row_index + 1
        let row_prefix = "R" + row_number.to_string() + "C"
        let row_ref = @core.source_ref_with_cell_range(
          @core.source_ref_with_lines(
            @core.empty_source_ref(),
            source_name,
            format_value,
            Some(row.line_start),
            Some(row.line_end),
          ),
          source_name,
          format_value,
          Some(row_prefix + "1:" + row_prefix + last_cell_suffix),
        )
        for col_index in 0..<effective_col_count {
          events.push({
            kind: @core.EventKind::Cell,
            text: row.fields[col_index],
            source_ref: Some(
              @core.source_ref_with_cell_range(
                row_ref,
                source_name,
                format_value,
                Some(row_prefix + cell_suffixes[col_index]),
              ),
            ),
          })
        }
        if effective_col_count > 0 {
          events.push({
            kind: @core.EventKind::RowBreak,
            text: "",
            source_ref: Some(row_ref),
          })
        }
      }
      diagnostics.metrics.set("event_count", events.length().to_string())
      diagnostics.metrics.set("row_count", allowed_rows.to_string())
      diagnostics.metrics.set(
        "cell_count",
        (allowed_rows * effective_col_count).to_string(),
      )
      diagnostics.metrics.set(
        "degraded_feature_count",
        diagnostics.degraded_features.length().to_string(),
      )
      if diagnostics.degraded_features.length() > 0 {
        diagnostics.fallback_trace.push("table degraded due to resource limits")
      }
      diagnostics.metrics.set(
        "fallback_count",
        diagnostics.fallback_trace.length().to_string(),
      )
      diagnostics.pass_trace.push("parse:" + name)
      Ok(
        @parser.parse_result_with_events_capability(
          name,
          @parser.ParserMode::StreamingEvent,
          events,
          diagnostics,
          csv_parser_capability(),
        ),
      )
    },
  )
}

///|
fn read_delimited_input_text(
  source : @input.InputSource,
) -> Result[String, String] {
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  match decode_utf16_text_bytes(bytes) {
    Some(text) => Ok(text)
    None => @input.read_input_text(source)
  }
}

///|
fn decode_utf16_text_bytes(bytes : Bytes) -> String? {
  let arr = bytes.to_array()
  if arr.length() < 2 {
    return None
  }
  let first = arr[0].to_int()
  let second = arr[1].to_int()
  if first == 0xFF && second == 0xFE {
    let decoded = @encoding.decode(bytes, encoding=@encoding.UTF16LE) catch {
      _ => return None
    }
    return Some(strip_leading_bom(decoded))
  }
  if first == 0xFE && second == 0xFF {
    let decoded = @encoding.decode(bytes, encoding=@encoding.UTF16BE) catch {
      _ => return None
    }
    return Some(strip_leading_bom(decoded))
  }
  None
}

///|
fn strip_leading_bom(text : String) -> String {
  let chars = text.to_array()
  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    String::from_array(chars[1:])
  } else {
    text
  }
}

///|
fn malformed_delimited_parse_result(
  name : String,
  source : @input.InputSource,
  format : @input.DetectedFormat,
  text : String,
  diagnostics : @core.Diagnostics,
  err : String,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  let format_name = @input.detected_format_name(format)
  let error_kind = delimited_parse_error_kind_name(err)
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some(format_name),
    Some(1),
    Some(@parser_common.count_physical_lines(text)),
  )
  let block = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  block.attrs.set("raw_kind", format_name + "_fallback")
  block.attrs.set("info", format_name)
  diagnostics.warnings.push(format_name + " parse warning: " + err)
  diagnostics.degraded_features.push(format_name + "_raw_fallback")
  diagnostics.fallback_trace.push(
    format_name + " parse failed -> raw block fallback",
  )
  diagnostics.metrics.set("parser_name", name)
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set(
    "input_kind",
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", format_name)
  @parser_common.apply_product_metrics(diagnostics, format_name)
  diagnostics.metrics.set(
    "delimiter",
    if format == @input.DetectedFormat::Tsv {
      "tab"
    } else {
      "comma"
    },
  )
  diagnostics.metrics.set("fallback_reason_kind", error_kind)
  diagnostics.metrics.set("quoted_field_support", "true")
  diagnostics.metrics.set("escaped_quote_support", "true")
  diagnostics.metrics.set("quoted_newline_capability", "true")
  diagnostics.metrics.set("quoted_newline_observed", "false")
  diagnostics.metrics.set(
    "quoted_delimiter_support",
    if format == @input.DetectedFormat::Tsv {
      "quoted_tab"
    } else {
      "quoted_comma"
    },
  )
  diagnostics.metrics.set(
    "line_count",
    @parser_common.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("raw_row_count", "0")
  diagnostics.metrics.set("raw_column_count", "0")
  diagnostics.metrics.set("raw_cell_count", "0")
  diagnostics.metrics.set("row_count", "0")
  diagnostics.metrics.set("column_count", "0")
  diagnostics.metrics.set("cell_count", "0")
  diagnostics.metrics.set("truncated_row_count", "0")
  diagnostics.metrics.set("truncated_column_count", "0")
  diagnostics.metrics.set("truncated_cell_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set(
    "requested_mode",
    @parser_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set("event_granularity", "row")
  diagnostics.metrics.set(
    "event_semantics", "row_cell_event_stream_deferred_on_error",
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.pass_trace.push("parse:" + name)
  let document = @core.empty_document_ir()
  document.blocks.push(block)
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    name,
    @parser.ParserMode::StreamingEvent,
    final_document,
    diagnostics,
    csv_parser_capability(),
  )
}

///|
fn delimited_validation_issue_message(
  issue : @dcsv.CsvValidationIssue,
) -> String {
  "ragged row warning: row " +
  issue.row_index.to_string() +
  " has " +
  issue.actual_field_count.to_string() +
  " field(s); expected " +
  issue.expected_field_count.to_string()
}

///|
fn delimited_parse_error_kind_name(err : String) -> String {
  let lowered = err.to_lower()
  if lowered.contains("unterminated quoted field") {
    "unterminated_quoted_field"
  } else {
    "unknown"
  }
}
