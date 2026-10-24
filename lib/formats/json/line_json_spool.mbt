///|
/// Optional JSONL spool route. It parses/inspects each admitted record once,
/// writes table and non-table event frames into two sequential owners sharing
/// one finite account, then replays table before code without a record index.
async fn open_spooled_line_json_event_stream(
  parser_name : String,
  format_name : String,
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
  collected_contract~ : Bool = false,
) -> Result[@parser.ParseEventStream?, String] {
  guard context.limits.max_temporary_bytes is Some(requested) else {
    return Err("JSONL spool requires an explicit temporary capacity")
  }
  guard @input.input_source_budget_context(source) is Some(budget) else {
    return Err(
      line_json_spool_invalid(source, "JSONL spool requires an input session"),
    )
  }
  match budget.account.tighten_resident_limit(TemporaryBytes, requested) {
    Ok(_) => ()
    Err(error) => return Err(line_json_spool_budget_failure(source, error))
  }
  let capacity = budget.account.snapshot().limits.temporary_bytes.unwrap()
  let table = match
    create_line_json_spool_owner(source, budget.account, capacity) {
    Ok(owner) => owner
    Err(error) => return Err(error)
  }
  let handed_off = Ref(false)
  defer (if !handed_off.val { ignore(table.close()) })
  let code = match
    create_line_json_spool_owner(source, budget.account, capacity) {
    Ok(owner) => owner
    Err(error) => return Err(error)
  }
  defer (if !handed_off.val { ignore(code.close()) })
  let scan = match
    scan_line_json_to_spools(
      format_name,
      source,
      context,
      budget,
      table,
      code,
      collected_contract~,
    ) {
    Ok(scan) => scan
    Err(RecoverableSyntax) => {
      // Ordinary grammar recovery remains the old raw-content contract. This
      // exceptional route may collect text and is explicitly not bounded yet.
      ignore(table.close())
      ignore(code.close())
      return match @input.input_source_error(source) {
        Some(message) => Err(message)
        None => Ok(None)
      }
    }
    Err(InputFailure(message) | RecordLimit(message)) => return Err(message)
  }
  for owner in [table, code] {
    match owner.seal() {
      Ok(_) => ()
      Err(error) => return Err(line_json_spool_failure(source, error))
    }
  }
  let table_cursor : LineJsonSpoolCursor = {
    owner: table,
    range: table.range(0L, table.length()).unwrap(),
    offset: 0L,
  }
  let code_cursor : LineJsonSpoolCursor = {
    owner: code,
    range: code.range(0L, code.length()).unwrap(),
    offset: 0L,
  }
  let phase = Ref(0)
  let closed = Ref(false)
  let table_row = Ref(0L)
  let table_column = Ref(0)
  let event_count = Ref(0L)
  let diagnostics = @fshared.empty_parser_diagnostics(
    parser_name,
    StreamingEvent,
    source,
    format_name,
  )
  handed_off.val = true
  Ok(
    Some(
      @parser.make_parse_event_stream(
        async fn() {
          if closed.val {
            return Ok(None)
          }
          while phase.val < 2 {
            let cursor = if phase.val == 0 { table_cursor } else { code_cursor }
            let frame = match
              next_line_json_spool_frame(cursor, source, budget) {
              Ok(Some(frame)) => frame
              Ok(None) => {
                phase.val += 1
                continue
              }
              Err(error) => return Err(error)
            }
            let event : @core.CoreEvent = match frame.tag {
              b'\x00' | b'\x01' => {
                let reference = if collected_contract {
                  line_json_spool_table_ref(
                    source,
                    format_name,
                    frame,
                    table_row.val,
                    table_column.val,
                  )
                } else {
                  @core.source_ref_with_lines(
                    @core.empty_source_ref(),
                    Some(source.source_name),
                    Some(format_name),
                    Some(frame.line),
                    Some(frame.line),
                  )
                }
                if frame.tag == b'\x00' {
                  table_column.val += 1
                } else {
                  table_column.val = 0
                  table_row.val += 1L
                }
                {
                  kind: if frame.tag == b'\x00' {
                    Cell
                  } else {
                    RowBreak
                  },
                  text: frame.text,
                  source_ref: Some(reference),
                }
              }
              _ =>
                {
                  kind: StartBlock(Code),
                  text: frame.text,
                  source_ref: Some(
                    line_delimited_code_event_source_ref(
                      source,
                      format_name,
                      "/" + frame.record.to_string(),
                      frame.line,
                    ),
                  ),
                }
            }
            event_count.val += 1L
            return Ok(Some(event))
          }
          Ok(None)
        },
        async fn() {
          match close_line_json_spools(source, table, code, closed) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          let summary = if collected_contract {
            collected_line_json_spool_summary(
              parser_name,
              format_name,
              source,
              context,
              capability,
              diagnostics,
              scan,
              event_count.val,
              table.length() > 0L,
            )
          } else {
            line_json_event_summary(
              parser_name,
              format_name,
              source,
              context,
              capability,
              diagnostics,
              scan,
              event_count.val,
            )
          }
          diagnostics.metrics.set("jsonl_spool", "two_sequential_event_files")
          diagnostics.metrics.set(
            "jsonl_spool_records_parsed",
            scan.record_count.to_string(),
          )
          diagnostics.metrics.set(
            "jsonl_spool_table_bytes",
            table.length().to_string(),
          )
          diagnostics.metrics.set(
            "jsonl_spool_code_bytes",
            code.length().to_string(),
          )
          Ok(summary)
        },
        close=async fn() { close_line_json_spools(source, table, code, closed) },
      ),
    ),
  )
}

///|
/// Preserve collected parser diagnostics while sharing the spool's one input
/// scan. Pull-only route metrics and its trace do not describe this collector.
fn collected_line_json_spool_summary(
  parser_name : String,
  format_name : String,
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
  diagnostics : @core.Diagnostics,
  scan : LineJsonPullScan,
  event_count : Int64,
  has_table : Bool,
) -> @parser.ParseStreamSummary {
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
  diagnostics.metrics.set("max_depth_observed", scan.max_depth.to_string())
  diagnostics.metrics.set("blank_line_count", scan.blank_line_count.to_string())
  diagnostics.metrics.set("invalid_record_count", "0")
  diagnostics.metrics.set("table_count", if has_table { "1" } else { "0" })
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", scan.record_count.to_string())
  diagnostics.metrics.set("event_count", event_count.to_string())
  diagnostics.metrics.set("record_count_emitted", scan.record_count.to_string())
  if scan.blank_line_count > 0 {
    diagnostics.warnings.push(
      "blank " +
      format_name +
      " line(s) skipped: " +
      scan.blank_line_count.to_string(),
    )
    diagnostics.degraded_features.push(format_name + "_blank_line_skipped")
    diagnostics.fallback_trace.push(
      format_name + " blank line -> skip empty record",
    )
  }
  @fshared.refresh_parser_count_metrics(diagnostics, "event_stream")
  diagnostics.pass_trace.push("parse:" + parser_name)
  @parser.parse_stream_summary(
    parser_name,
    StreamingEvent,
    capability,
    diagnostics,
  )
}

///|
async fn close_line_json_spools(
  source : @input.InputSource,
  table : @temp.TempOwner,
  code : @temp.TempOwner,
  closed : Ref[Bool],
) -> Result[Unit, String] noraise + nocancel {
  closed.val = true
  ignore(table.close())
  ignore(code.close())
  match @input.input_source_error(source) {
    Some(message) => Err(message)
    None => Ok(())
  }
}

///|
fn line_json_spool_table_ref(
  source : @input.InputSource,
  format_name : String,
  frame : LineJsonSpoolFrame,
  row : Int64,
  column : Int32,
) -> @core.SourceRef {
  let pointer = if row == 0 {
    "/header"
  } else {
    "/" + frame.record.to_string()
  }
  let reference = @core.source_ref_with_lines(
    json_pointer_source_ref(source, format_name, pointer),
    Some(source.source_name),
    Some(format_name),
    Some(frame.line),
    Some(frame.line),
  )
  let row_number = (row + 1L).to_string()
  let cell_range = if frame.tag == b'\x00' {
    "R" + row_number + "C" + (column + 1).to_string()
  } else {
    "R" + row_number + "C1:R" + row_number + "C" + column.to_string()
  }
  let reference = @core.source_ref_with_cell_range(
    reference,
    Some(source.source_name),
    Some(format_name),
    Some(cell_range),
  )
  if row == 0 {
    reference.extra.set("synthetic_header", "true")
  } else {
    reference.extra.set("record_index", frame.record.to_string())
  }
  reference
}

///|
async fn spool_line_json_row(
  table : @temp.TempOwner,
  source : @input.InputSource,
  account : @budget.Budget,
  values : Array[String],
  line : Int32,
  record : Int32,
) -> Result[Unit, String] {
  for value in values {
    match
      append_line_json_spool_frame(
        table, source, account, b'\x00', line, record, value,
      ) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  if !values.is_empty() {
    match
      append_line_json_spool_frame(
        table, source, account, b'\x01', line, record, "",
      ) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  Ok(())
}

///|
async fn scan_line_json_to_spools(
  format_name : String,
  source : @input.InputSource,
  context : @parser.ParseContext,
  budget : @budget.BudgetContext,
  table : @temp.TempOwner,
  code : @temp.TempOwner,
  collected_contract~ : Bool,
) -> Result[LineJsonPullScan, LineJsonPullScanError] {
  let reader = match
    (if collected_contract {
      // The collected legacy route splits only LF and normalizes one record BOM
      // itself. Default physical-line pull semantics remain unchanged.
      @sourceio.open_source_text_line_reader(
        source,
        max_bytes=@parser.max_input_bytes(context),
        max_line_chars=@parser.max_line_chars(context),
        split_cr=false,
        skip_leading_bom=false,
        blank_prefix=['\u{001E}', '\u{FEFF}'],
      )
    } else {
      open_line_json_reader(source, context)
    }) {
    Ok(reader) => reader
    Err(message) => return Err(InputFailure(message))
  }
  defer (reader.close)()
  let mut columns : LineJsonColumns? = None
  let schema_leases : Array[@budget.BudgetLease] = []
  defer (for lease in schema_leases {
    lease.release()
  })
  let mut count = 0
  let mut object_count = 0
  let mut array_count = 0
  let mut scalar_count = 0
  let mut max_depth = 0
  let mut blank_line_count = 0
  let mut mismatch_count = 0
  let max_rows = context.max_rows.unwrap_or(200)
  let mut collect_stats = true
  while collected_contract || count < max_rows {
    let line = match (reader.next)() {
      Ok(Some(line)) => line
      Ok(None) => {
        if collected_contract && collect_stats && (reader.eof_has_empty_line)() {
          blank_line_count += 1
        }
        break
      }
      Err(message) =>
        return Err(InputFailure(line_json_spool_invalid(source, message)))
    }
    // The original collector validates the whole source before applying its
    // row projection. Continue bounded UTF8/IO validation without parse/inspect
    // or spool writes after the first omitted nonblank record.
    if !collect_stats {
      continue
    }
    let raw = normalize_line_delimited_json_record(line.text).trim().to_owned()
    if raw == "" && (!line.truncated || line.is_blank) {
      blank_line_count += 1
      continue
    }
    if count >= max_rows {
      collect_stats = false
      continue
    }
    if line.truncated {
      return Err(
        RecordLimit(
          line_json_spool_invalid(
            source,
            format_name + " record exceeds max_line_chars",
          ),
        ),
      )
    }
    let document = parse_json_document(raw) catch {
      _ => return Err(RecoverableSyntax)
    }
    let inspect = inspect_json_document(document)
    object_count += inspect.object_count
    array_count += inspect.array_count
    scalar_count += inspect.scalar_count
    max_depth = max_depth.max(inspect.max_depth)
    let mut matched = false
    match document.root {
      Object(members) => {
        if columns is None {
          // The schema dies when scan returns. Its string payload has a
          // scan-owned lease, not a fictitious scope-retained output cache.
          for entry in members {
            match
              line_json_spool_working(
                source,
                budget.account,
                2L * entry.key.length().to_int64(),
              ) {
              Ok(lease) => schema_leases.push(lease)
              Err(error) => return Err(InputFailure(error))
            }
          }
          let schema = LineJsonColumns::new(members)
          match
            spool_line_json_row(
              table,
              source,
              budget.account,
              schema.keys,
              1,
              0,
            ) {
            Ok(_) => ()
            Err(error) => return Err(InputFailure(error))
          }
          columns = Some(schema)
        }
        let schema = columns.unwrap()
        matched = schema.matches(members)
        if matched {
          match
            spool_line_json_row(
              table,
              source,
              budget.account,
              json_members_to_row(members, schema.keys),
              line.line_no,
              count,
            ) {
            Ok(_) => ()
            Err(error) => return Err(InputFailure(error))
          }
        }
      }
      _ => ()
    }
    if !matched {
      mismatch_count += 1
      // Legacy collected and pull paths differ for per-record RS/BOM markers.
      // Retain each existing contract explicitly; neither path decodes twice.
      let text = if collected_contract {
        raw
      } else {
        line.text.trim().to_owned()
      }
      match
        append_line_json_spool_frame(
          code,
          source,
          budget.account,
          b'\x02',
          line.line_no,
          count,
          text,
        ) {
        Ok(_) => ()
        Err(error) => return Err(InputFailure(error))
      }
    }
    count += 1
  }
  Ok({
    columns: None,
    record_count: count,
    object_count,
    array_count,
    scalar_count,
    max_depth,
    blank_line_count,
    mismatch_count,
  })
}
