///|
test "pipeline.docx.dvla_user_guide.stages" (b : @bench.T) {
  let row = @stage.stage_binary_row("docx_small_dvla_user_guide_v1")
  let source = @shared.bench_row_input_source(row)
  let bytes = @shared.bench_row_bytes(row)
  let detector = @stage.default_stage_detector()
  let registry = @stage.default_stage_registry()
  let parse_context = @stage.stage_parse_context(@input.DetectedFormat::Docx)
  let render_context = @stage.default_stage_render_context()
  let renderer = @stage.default_stage_renderer()

  let pkg = open_docx_package_or_abort(bytes, row.bench_id)
  let main_part = locate_docx_main_part_or_abort(pkg, row.bench_id)
  let main_xml = read_docx_part_text_or_abort(pkg, main_part, row.bench_id)
  let relationships = read_docx_relationships_or_abort(
    pkg,
    main_part,
    row.bench_id,
  )
  let styles_part = locate_docx_service_part_from_relationships(
    pkg, relationships, "styles", "word/styles.xml",
  )
  let numbering_part = locate_docx_service_part_from_relationships(
    pkg, relationships, "numbering", "word/numbering.xml",
  )
  let styles_xml_length = read_optional_docx_part_text_length(
    pkg,
    styles_part,
    row.bench_id,
  )
  let numbering_xml_length = read_optional_docx_part_text_length(
    pkg,
    numbering_part,
    row.bench_id,
  )
  let source_document = parse_docx_source_or_abort(pkg, row.bench_id)
  let normalized_document = normalize_docx_source_or_abort(
    source_document,
    row.bench_id,
  )
  let parse_result = @stage.stage_registry_parse_or_abort(
    registry,
    source,
    parse_context,
    row.bench_id,
    "docx stage bench",
  )
  let ir_input = @stage.stage_parse_to_ir_input(parse_result)
  let built_document = @stage.stage_build_document(ir_input)
  let rendered = @stage.stage_render_markdown(
    built_document, renderer, render_context,
  )
  let package_report = @ox.inspect_ooxml_package(pkg)

  let prefix = "pipeline.docx.dvla_user_guide."

  b.bench(name=prefix + "input_read", fn() {
    let payload = match @input.read_input_bytes(source) {
      Ok(value) => value
      Err(err) =>
        abort("docx stage bench read failed: " + row.bench_id + " :: " + err)
    }
    @shared.keep_bytes_len(b, payload)
  })

  b.bench(name=prefix + "format_detect", fn() {
    let detected = (detector.detect)(source)
    @shared.keep_string(b, @input.detected_format_name(detected.format))
  })

  b.bench(name=prefix + "package_open", fn() {
    let pkg = open_docx_package_or_abort(bytes, row.bench_id)
    @shared.keep_int(b, @ox.list_parts(pkg).length())
  })

  b.bench(name=prefix + "package_inspect", fn() {
    let report = @ox.inspect_ooxml_package(pkg)
    @shared.keep_int(b, report.part_count)
  })

  b.bench(name=prefix + "main_xml_read", fn() {
    let xml = read_docx_part_text_or_abort(pkg, main_part, row.bench_id)
    @shared.keep_int(b, xml.length())
  })

  b.bench(name=prefix + "relationships_read", fn() {
    let rels = read_docx_relationships_or_abort(pkg, main_part, row.bench_id)
    @shared.keep_int(b, rels.length())
  })

  b.bench(name=prefix + "styles_xml_read", fn() {
    let next = read_optional_docx_part_text_length(
      pkg,
      styles_part,
      row.bench_id,
    )
    @shared.keep_int(b, next)
  })

  b.bench(name=prefix + "numbering_xml_read", fn() {
    let next = read_optional_docx_part_text_length(
      pkg,
      numbering_part,
      row.bench_id,
    )
    @shared.keep_int(b, next)
  })

  b.bench(name=prefix + "docx_source_parse", fn() {
    let next = parse_docx_source_or_abort(pkg, row.bench_id)
    @shared.keep_int(b, next.parts.length())
  })

  b.bench(name=prefix + "docx_normalize", fn() {
    let next = normalize_docx_source_or_abort(source_document, row.bench_id)
    @shared.keep_int(b, next.body.length())
  })

  b.bench(name=prefix + "style_lookup", fn() {
    let hits = count_docx_style_lookup_hits(normalized_document)
    @shared.keep_int(b, hits)
  })

  b.bench(name=prefix + "numbering_lookup", fn() {
    let hits = count_docx_numbering_lookup_hits(normalized_document)
    @shared.keep_int(b, hits)
  })

  b.bench(name=prefix + "registry_parse", fn() {
    let next = @stage.stage_registry_parse_or_abort(
      registry,
      source,
      parse_context,
      row.bench_id,
      "docx stage bench",
    )
    @shared.keep_int(b, @stage.stage_parse_result_metric(next))
  })

  b.bench(name=prefix + "parse_to_ir_input", fn() {
    let next = @stage.stage_parse_to_ir_input(parse_result)
    @shared.keep_int(b, @stage.stage_ir_input_metric(next))
  })

  b.bench(name=prefix + "build_document", fn() {
    let next = @stage.stage_build_document(ir_input)
    @shared.keep_int(b, next.blocks.length())
  })

  b.bench(name=prefix + "render_markdown", fn() {
    let next = @stage.stage_render_markdown(
      built_document, renderer, render_context,
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
          "docx stage bench convert failed: " +
          row.bench_id +
          " :: " +
          err.to_string(),
        )
    }
    @shared.keep_string(b, result.content)
  })

  @shared.keep_int(b, package_report.part_count)
  @shared.keep_int(b, main_xml.length())
  @shared.keep_int(b, relationships.length())
  @shared.keep_int(b, styles_xml_length)
  @shared.keep_int(b, numbering_xml_length)
  @shared.keep_int(b, normalized_document.body.length())
}

///|
fn open_docx_package_or_abort(
  bytes : Bytes,
  bench_id : String,
) -> @ox.OoxmlPackage {
  match
    (try @ox.open_ooxml_package(bytes) |> Ok catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort("docx stage bench open package failed: " + bench_id + " :: " + err)
  }
}

///|
fn locate_docx_main_part_or_abort(
  pkg : @ox.OoxmlPackage,
  bench_id : String,
) -> String {
  let rels = match
    (try
      @ox.find_relationships_by_type(pkg, "", "/officeDocument") |> Ok
    catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort(
        "docx stage bench main-part relationships failed: " +
        bench_id +
        " :: " +
        err,
      )
  }
  if rels.length() > 0 {
    return rels[0].resolved_target
  }
  if @ox.has_part(pkg, "word/document.xml") {
    return "word/document.xml"
  }
  let candidates = match
    (try
      @ox.list_parts_by_content_type(
        pkg, "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
      )
      |> Ok
    catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort(
        "docx stage bench main-part content type lookup failed: " +
        bench_id +
        " :: " +
        err,
      )
  }
  if candidates.length() == 0 {
    abort("docx stage bench missing main part: " + bench_id)
  }
  candidates[0]
}

///|
fn read_docx_part_text_or_abort(
  pkg : @ox.OoxmlPackage,
  part_name : String,
  bench_id : String,
) -> String {
  match
    (try @ox.read_part_text(pkg, part_name) |> Ok catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort(
        "docx stage bench read part failed: " +
        bench_id +
        " :: " +
        part_name +
        " :: " +
        err,
      )
  }
}

///|
fn read_docx_relationships_or_abort(
  pkg : @ox.OoxmlPackage,
  part_name : String,
  bench_id : String,
) -> Array[@ox.OoxmlRelationship] {
  match
    (try @ox.read_part_relationships(pkg, part_name) |> Ok catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort(
        "docx stage bench read relationships failed: " + bench_id + " :: " + err,
      )
  }
}

///|
fn parse_docx_source_or_abort(
  pkg : @ox.OoxmlPackage,
  bench_id : String,
) -> @ddocx.DocxSourceDocument {
  match
    (try @ddocx.parse_docx_source_from_package(pkg) |> Ok catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort("docx stage bench parse source failed: " + bench_id + " :: " + err)
  }
}

///|
fn normalize_docx_source_or_abort(
  source : @ddocx.DocxSourceDocument,
  bench_id : String,
) -> @ddocx.DocxDocument {
  ignore(bench_id)
  @ddocx.normalize_docx_source(source)
}

///|
fn locate_docx_service_part_from_relationships(
  pkg : @ox.OoxmlPackage,
  relationships : Array[@ox.OoxmlRelationship],
  suffix : String,
  conventional_part : String,
) -> String? {
  for rel in relationships {
    let rel_type = rel.rel_type
    if rel_type.has_suffix(suffix) || rel_type == suffix {
      return Some(rel.resolved_target)
    }
  }
  if @ox.has_part(pkg, conventional_part) {
    Some(conventional_part)
  } else {
    None
  }
}

///|
fn read_optional_docx_part_text_length(
  pkg : @ox.OoxmlPackage,
  part_name : String?,
  bench_id : String,
) -> Int {
  match part_name {
    Some(part) => read_docx_part_text_or_abort(pkg, part, bench_id).length()
    None => 0
  }
}

///|
fn count_docx_style_lookup_hits(doc : @ddocx.DocxDocument) -> Int {
  let hits : Ref[Int] = { val: 0 }
  docx_for_each_paragraph(doc.body, fn(paragraph) {
    match @ddocx.docx_resolve_paragraph_style(doc, paragraph) {
      Some(_) => hits.val += 1
      None => ()
    }
  })
  hits.val
}

///|
fn count_docx_numbering_lookup_hits(doc : @ddocx.DocxDocument) -> Int {
  let hits : Ref[Int] = { val: 0 }
  docx_for_each_paragraph(doc.body, fn(paragraph) {
    match @ddocx.docx_resolve_paragraph_numbering_level(doc, paragraph) {
      Some(_) => hits.val += 1
      None => ()
    }
  })
  hits.val
}

///|
fn docx_for_each_paragraph(
  blocks : Array[@ddocx.DocxBlock],
  visit : (@ddocx.DocxParagraph) -> Unit,
) -> Unit {
  for block in blocks {
    match block {
      @ddocx.DocxBlock::Paragraph(paragraph) => visit(paragraph)
      @ddocx.DocxBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            docx_for_each_paragraph(cell.blocks, visit)
          }
        }
      @ddocx.DocxBlock::ContentControl(control) =>
        docx_for_each_paragraph(control.blocks, visit)
      @ddocx.DocxBlock::TablePlaceholder(_)
      | @ddocx.DocxBlock::StructuralMarker(_)
      | @ddocx.DocxBlock::Unsupported(_) => ()
    }
  }
}
