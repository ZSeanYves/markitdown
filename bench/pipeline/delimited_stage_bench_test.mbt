///|
test "pipeline.delimited.stages" (b : @bench.T) {
  let rows = [
    delimited_stage_case(
      "csv_small_usgs_all_day_v1",
      @input.DetectedFormat::Csv,
      false,
    ),
    delimited_stage_case(
      "tsv_small_uniprot_reviewed_v1",
      @input.DetectedFormat::Tsv,
      true,
    ),
  ]
  let detector = @stage.default_stage_detector()
  let registry = @stage.default_stage_registry()
  let render_context = @stage.default_stage_render_context()
  let renderer = @stage.default_stage_renderer()

  for case in rows {
    let row = case.row
    let source = @shared.bench_row_input_source(row)
    let text = @shared.bench_row_text(row)
    let parse_context = @stage.stage_parse_context(case.detected_format)
    let parsed_document = parse_delimited_document_or_abort(
      text,
      case.is_tsv,
      row.bench_id,
    )
    let inspect = @dcsv.inspect_csv_document(parsed_document)
    let validation = @dcsv.validate_csv_document(parsed_document)
    let parse_result = @stage.stage_registry_parse_or_abort(
      registry,
      source,
      parse_context,
      row.bench_id,
      "delimited stage bench",
    )
    let ir_input = @stage.stage_parse_to_ir_input(parse_result)
    let event_stream = delimited_event_stream_or_abort(
      parse_result,
      row.bench_id,
    )
    let event_built_document = @mdpipeline.ir_input_to_document(
      @core.IRInput::EventStream(event_stream),
    )
    let built_document = @stage.stage_build_document(ir_input)
    let rendered = @stage.stage_render_markdown(
      built_document, renderer, render_context,
    )
    let prefix = "pipeline.delimited." + row.bench_id + "."

    b.bench(name=prefix + "input_read", fn() {
      let payload = match @input.read_input_text(source) {
        Ok(value) => value
        Err(err) =>
          abort(
            "delimited stage bench read failed: " + row.bench_id + " :: " + err,
          )
      }
      @shared.keep_int(b, payload.length())
    })

    b.bench(name=prefix + "format_detect", fn() {
      let detected = (detector.detect)(source)
      @shared.keep_string(b, @input.detected_format_name(detected.format))
    })

    b.bench(name=prefix + "parse_delimited", fn() {
      let next = parse_delimited_document_or_abort(
        text,
        case.is_tsv,
        row.bench_id,
      )
      @shared.keep_int(b, next.rows.length())
    })

    b.bench(name=prefix + "inspect_delimited", fn() {
      let report = @dcsv.inspect_csv_document(parsed_document)
      @shared.keep_int(b, report.row_count)
    })

    b.bench(name=prefix + "validate_delimited", fn() {
      let report = @dcsv.validate_csv_document(parsed_document)
      @shared.keep_int(b, report.issue_count)
    })

    b.bench(name=prefix + "event_stream_build", fn() {
      let document = @mdpipeline.ir_input_to_document(
        @core.IRInput::EventStream(event_stream),
      )
      @shared.keep_int(b, document.blocks.length())
    })

    b.bench(name=prefix + "registry_parse", fn() {
      let result = @stage.stage_registry_parse_or_abort(
        registry,
        source,
        parse_context,
        row.bench_id,
        "delimited stage bench",
      )
      @shared.keep_int(b, @stage.stage_parse_result_metric(result))
    })

    b.bench(name=prefix + "parse_to_ir_input", fn() {
      let next = @stage.stage_parse_to_ir_input(parse_result)
      @shared.keep_int(b, @stage.stage_ir_input_metric(next))
    })

    b.bench(name=prefix + "build_document", fn() {
      let document = @stage.stage_build_document(ir_input)
      @shared.keep_int(b, document.blocks.length())
    })

    b.bench(name=prefix + "pipeline_passes", fn() {
      let document = @mdpipeline.run_pipeline(
        @mdpipeline.default_pass_pipeline(),
        event_built_document,
        @stage.default_stage_pass_context(),
      )
      @shared.keep_int(b, document.blocks.length())
    })

    b.bench(name=prefix + "render_markdown", fn() {
      let next = @stage.stage_render_markdown(
        built_document, renderer, render_context,
      )
      @shared.keep_int(b, next.content.length())
    })

    b.bench(name=prefix + "table_render_only", fn() {
      let content = @render.render_markdown_document(
        @core.document_from_blocks(built_document.blocks),
      )
      @shared.keep_int(b, content.length())
    })

    b.bench(name=prefix + "output_bytes", fn() {
      @shared.keep_bytes_len(b, @stage.stage_output_bytes(rendered))
    })

    b.bench(name=prefix + "convert_total", fn() {
      let result = match
        @convert.convert_input(
          source,
          @shared.bench_row_default_convert_options(row),
        ) {
        Ok(value) => value
        Err(err) =>
          abort(
            "delimited stage bench convert failed: " +
            row.bench_id +
            " :: " +
            err.to_string(),
          )
      }
      @shared.keep_string(b, result.content)
    })

    @shared.keep_int(b, inspect.row_count)
    @shared.keep_int(b, validation.issue_count)
  }
}

///|
priv struct DelimitedStageCase {
  row : @shared.BenchManifestRow
  detected_format : @input.DetectedFormat
  is_tsv : Bool
}

///|
fn delimited_stage_case(
  bench_id : String,
  detected_format : @input.DetectedFormat,
  is_tsv : Bool,
) -> DelimitedStageCase {
  { row: @stage.stage_textlike_row(bench_id), detected_format, is_tsv }
}

///|
fn parse_delimited_document_or_abort(
  text : String,
  is_tsv : Bool,
  bench_id : String,
) -> @dcsv.CsvDocument {
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
  match parsed {
    Ok(value) => value
    Err(err) =>
      abort("delimited stage bench parse failed: " + bench_id + " :: " + err)
  }
}

///|
fn delimited_event_stream_or_abort(
  result : @parser.ParseResult,
  bench_id : String,
) -> Array[@core.CoreEvent] {
  match result.event_stream {
    Some(events) => events
    None => abort("delimited stage bench expected event stream: " + bench_id)
  }
}
