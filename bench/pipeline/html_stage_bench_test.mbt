///|
test "pipeline.html.synthetic_articles.stages" (b : @bench.T) {
  let row = @stage.stage_textlike_row("html_small_synthetic_articles_v1")
  let source = @shared.bench_row_input_source(row)
  let text = @shared.bench_row_text(row)
  let detector = @stage.default_stage_detector()
  let registry = @stage.default_stage_registry()
  let parse_context = @stage.stage_parse_context(@input.DetectedFormat::Html)
  let render_context = @stage.default_stage_render_context()
  let renderer = @stage.default_stage_renderer()

  let parsed_document = parse_html_document_or_abort(text, row.bench_id)
  let semantic_document = @dhtml.collect_html_semantic_document(parsed_document)
  let lowered_document = match @fhtml.html_document_to_ir(source, text) {
    Ok((document, _)) => document
    Err(err) =>
      abort("html stage bench lower failed: " + row.bench_id + " :: " + err)
  }
  let parse_result = @stage.stage_registry_parse_or_abort(
    registry,
    source,
    parse_context,
    row.bench_id,
    "html stage bench",
  )
  let ir_input = @stage.stage_parse_to_ir_input(parse_result)
  let built_document = @stage.stage_build_document(ir_input)
  let rendered = @stage.stage_render_markdown(
    built_document,
    renderer,
    render_context,
  )

  b.bench(name="pipeline.html.synthetic_articles.input_read", fn() {
    let payload = match @input.read_input_text(source) {
      Ok(value) => value
      Err(err) =>
        abort("html stage bench read failed: " + row.bench_id + " :: " + err)
    }
    @shared.keep_int(b, payload.length())
  })

  b.bench(name="pipeline.html.synthetic_articles.format_detect", fn() {
    let detected = (detector.detect)(source)
    @shared.keep_string(b, @input.detected_format_name(detected.format))
  })

  b.bench(name="pipeline.html.synthetic_articles.html_parse", fn() {
    let document = parse_html_document_or_abort(text, row.bench_id)
    @shared.keep_int(b, document.nodes.length())
  })

  b.bench(name="pipeline.html.synthetic_articles.html_inspect", fn() {
    let report = @dhtml.inspect_html_document(parsed_document)
    @shared.keep_int(b, report.node_count)
  })

  b.bench(name="pipeline.html.synthetic_articles.html_validate", fn() {
    let report = @dhtml.validate_html_document(parsed_document)
    @shared.keep_int(b, report.issue_count)
  })

  b.bench(name="pipeline.html.synthetic_articles.html_semantic_collect", fn() {
    let semantic = @dhtml.collect_html_semantic_document(parsed_document)
    @shared.keep_int(b, semantic.blocks.length())
  })

  b.bench(name="pipeline.html.synthetic_articles.html_semantic_inspect", fn() {
    let report = @dhtml.inspect_html_semantic_document(semantic_document)
    @shared.keep_int(b, report.block_count)
  })

  b.bench(name="pipeline.html.synthetic_articles.html_document_to_ir", fn() {
    let document = match @fhtml.html_document_to_ir(source, text) {
      Ok((value, _)) => value
      Err(err) =>
        abort("html stage bench lower failed: " + row.bench_id + " :: " + err)
    }
    @shared.keep_int(b, document.blocks.length())
  })

  b.bench(name="pipeline.html.synthetic_articles.html_lower_prepare", fn() {
    let next = @fhtml.html_lowering_prepare_metric(
      parsed_document, semantic_document,
    )
    @shared.keep_int(b, next)
  })

  b.bench(name="pipeline.html.synthetic_articles.html_top_level_blocks", fn() {
    let next = @fhtml.html_lowering_top_level_block_metric(
      parsed_document, semantic_document,
    )
    @shared.keep_int(b, next)
  })

  b.bench(name="pipeline.html.synthetic_articles.html_lower_blocks", fn() {
    let next = @fhtml.html_lowering_block_metric(
      source, parsed_document, semantic_document,
    )
    @shared.keep_int(b, next)
  })

  b.bench(name="pipeline.html.synthetic_articles.registry_parse", fn() {
    let result = @stage.stage_registry_parse_or_abort(
      registry,
      source,
      parse_context,
      row.bench_id,
      "html stage bench",
    )
    @shared.keep_int(b, @stage.stage_parse_result_metric(result))
  })

  b.bench(name="pipeline.html.synthetic_articles.parse_to_ir_input", fn() {
    let next = @stage.stage_parse_to_ir_input(parse_result)
    @shared.keep_int(b, @stage.stage_ir_input_metric(next))
  })

  b.bench(name="pipeline.html.synthetic_articles.build_document", fn() {
    let document = @stage.stage_build_document(ir_input)
    @shared.keep_int(b, document.blocks.length())
  })

  b.bench(name="pipeline.html.synthetic_articles.render_markdown", fn() {
    let next = @stage.stage_render_markdown(
      built_document,
      renderer,
      render_context,
    )
    @shared.keep_int(b, next.content.length())
  })

  b.bench(name="pipeline.html.synthetic_articles.output_bytes", fn() {
    @shared.keep_bytes_len(b, @stage.stage_output_bytes(rendered))
  })

  b.bench(name="pipeline.html.synthetic_articles.convert_total", fn() {
    let result = match
      @convert.convert_input(
        source,
        @shared.bench_row_default_convert_options(row),
      ) {
      Ok(value) => value
      Err(err) =>
        abort(
          "html stage bench convert failed: " +
          row.bench_id +
          " :: " +
          err.to_string(),
        )
    }
    @shared.keep_string(b, result.content)
  })

  @shared.keep_int(b, lowered_document.blocks.length())
}

fn parse_html_document_or_abort(
  text : String,
  bench_id : String,
) -> @dhtml.HtmlDocument {
  match
    (try @dhtml.parse_html_document(text) |> Ok catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort("html stage bench parse failed: " + bench_id + " :: " + err)
  }
}
