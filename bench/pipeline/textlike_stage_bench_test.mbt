///|
test "pipeline.txt.stages" (b : @bench.T) {
  let rows = [
    @stage.stage_textlike_row("txt_tiny_plain_v1"),
    @stage.stage_textlike_row("txt_small_rfc8259_v1"),
  ]
  let detector = @stage.default_stage_detector()
  let registry = @stage.default_stage_registry()
  let render_context = @stage.default_stage_render_context()
  let renderer = @stage.default_stage_renderer()

  for row in rows {
    let source = @shared.bench_row_input_source(row)
    let text = @shared.bench_row_text(row)
    let bytes = @shared.bench_row_bytes(row)
    let parse_context = @stage.stage_parse_context(@input.DetectedFormat::Txt)
    let profiled_document = @dtext.profile_text_document(text)
    let parsed_document = profiled_document.document
    let inspected_document = @dtext.inspect_text_document(parsed_document)
    let lowered_document = match
      @convert.convert_input(
        source,
        @shared.bench_row_default_convert_options(row),
      ) {
      Ok(value) => value
      Err(err) =>
        abort(
          "txt stage bench convert failed: " +
          row.bench_id +
          " :: " +
          err.to_string(),
        )
    }
    let parse_result = @stage.stage_registry_parse_or_abort(
      registry,
      source,
      parse_context,
      row.bench_id,
      "txt stage bench",
    )
    let ir_input = @stage.stage_parse_to_ir_input(parse_result)
    let built_document = @stage.stage_build_document(ir_input)
    let rendered = @stage.stage_render_markdown(
      built_document,
      renderer,
      render_context,
    )
    let prefix = "pipeline.txt." + row.bench_id + "."

    b.bench(name=prefix + "input_read", fn() {
      let payload = match @input.read_input_text(source) {
        Ok(value) => value
        Err(err) =>
          abort("txt stage bench read failed: " + row.bench_id + " :: " + err)
      }
      @shared.keep_int(b, payload.length())
    })

    b.bench(name=prefix + "format_detect", fn() {
      let detected = (detector.detect)(source)
      @shared.keep_string(b, @input.detected_format_name(detected.format))
    })

    b.bench(name=prefix + "utf8_decode", fn() {
      let decoded = match
        (try @utf8.decode(bytes, ignore_bom=false) |> Ok catch {
          _ => Err("Utf8DecodeFailed(invalid utf8)")
        }) {
        Ok(value) => value
        Err(err) =>
          abort("txt stage bench decode failed: " + row.bench_id + " :: " + err)
      }
      @shared.keep_int(b, decoded.length())
    })

    b.bench(name=prefix + "normalize_and_parse_text", fn() {
      let next = @dtext.profile_text_document(text)
      @shared.keep_int(b, next.document.lines.length())
    })

    b.bench(name=prefix + "parse_text_document", fn() {
      let next = @dtext.parse_text_document(text)
      @shared.keep_int(b, next.lines.length())
    })

    b.bench(name=prefix + "inspect_text_document", fn() {
      let report = @dtext.inspect_text_document(parsed_document)
      @shared.keep_int(b, report.line_count)
    })

    b.bench(name=prefix + "registry_parse", fn() {
      let result = @stage.stage_registry_parse_or_abort(
        registry,
        source,
        parse_context,
        row.bench_id,
        "txt stage bench",
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

    b.bench(name=prefix + "render_markdown", fn() {
      let next = @stage.stage_render_markdown(
        built_document,
        renderer,
        render_context,
      )
      @shared.keep_int(b, next.content.length())
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
            "txt stage bench convert failed: " +
            row.bench_id +
            " :: " +
            err.to_string(),
          )
      }
      @shared.keep_string(b, result.content)
    })

    @shared.keep_int(b, lowered_document.content.length())
    @shared.keep_int(b, inspected_document.line_count)
  }
}
