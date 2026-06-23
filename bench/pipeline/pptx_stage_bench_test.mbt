///|
test "pipeline.pptx.speaker_notes.stages" (b : @bench.T) {
  let row = @stage.stage_binary_row("pptx_small_speaker_notes_basic_v1")
  let source = @shared.bench_row_input_source(row)
  let bytes = @shared.bench_row_bytes(row)
  let detector = @stage.default_stage_detector()
  let registry = @stage.default_stage_registry()
  let parse_context = @stage.stage_parse_context(@input.DetectedFormat::Pptx)
  let render_context = @stage.default_stage_render_context()
  let renderer = @stage.default_stage_renderer()

  let pkg = open_pptx_package_or_abort(bytes, row.bench_id)
  let presentation_part = locate_pptx_presentation_part_or_abort(
    pkg,
    row.bench_id,
  )
  let presentation_xml = read_pptx_part_text_or_abort(
    pkg,
    presentation_part,
    row.bench_id,
  )
  let presentation_relationships = read_pptx_relationships_or_abort(
    pkg,
    presentation_part,
    row.bench_id,
  )
  let slide_part = locate_pptx_first_slide_part_or_abort(
    pkg,
    presentation_relationships,
    row.bench_id,
  )
  let slide_xml = read_pptx_part_text_or_abort(pkg, slide_part, row.bench_id)
  let slide_relationships = read_pptx_relationships_or_abort(
    pkg,
    slide_part,
    row.bench_id,
  )
  let notes_part = locate_pptx_notes_part_from_relationships(
    pkg, slide_relationships,
  )
  let notes_xml_length = read_optional_pptx_part_text_length(
    pkg,
    notes_part,
    row.bench_id,
  )
  let source_document = parse_pptx_source_or_abort(pkg, row.bench_id)
  let normalized_document = normalize_pptx_source_or_abort(
    source_document,
    row.bench_id,
  )
  let inspect_report = @dpptx.inspect_pptx_document(normalized_document)
  let parse_result = @stage.stage_registry_parse_or_abort(
    registry,
    source,
    parse_context,
    row.bench_id,
    "pptx stage bench",
  )
  let ir_input = @stage.stage_parse_to_ir_input(parse_result)
  let built_document = @stage.stage_build_document(ir_input)
  let rendered = @stage.stage_render_markdown(
    built_document,
    renderer,
    render_context,
  )
  let package_report = @ox.inspect_ooxml_package(pkg)
  let package_validation = @ox.validate_ooxml_package(pkg)

  let prefix = "pipeline.pptx.speaker_notes."

  b.bench(name=prefix + "input_read", fn() {
    let payload = match @input.read_input_bytes(source) {
      Ok(value) => value
      Err(err) =>
        abort("pptx stage bench read failed: " + row.bench_id + " :: " + err)
    }
    @shared.keep_bytes_len(b, payload)
  })

  b.bench(name=prefix + "format_detect", fn() {
    let detected = (detector.detect)(source)
    @shared.keep_string(b, @input.detected_format_name(detected.format))
  })

  b.bench(name=prefix + "package_open", fn() {
    let next = open_pptx_package_or_abort(bytes, row.bench_id)
    @shared.keep_int(b, @ox.list_parts(next).length())
  })

  b.bench(name=prefix + "package_inspect", fn() {
    let report = @ox.inspect_ooxml_package(pkg)
    @shared.keep_int(b, report.part_count)
  })

  b.bench(name=prefix + "package_validate", fn() {
    let report = @ox.validate_ooxml_package(pkg)
    @shared.keep_int(b, report.issues.length())
  })

  b.bench(name=prefix + "presentation_xml_read", fn() {
    let xml = read_pptx_part_text_or_abort(pkg, presentation_part, row.bench_id)
    @shared.keep_int(b, xml.length())
  })

  b.bench(name=prefix + "presentation_relationships_read", fn() {
    let rels = read_pptx_relationships_or_abort(
      pkg,
      presentation_part,
      row.bench_id,
    )
    @shared.keep_int(b, rels.length())
  })

  b.bench(name=prefix + "slide_xml_read", fn() {
    let xml = read_pptx_part_text_or_abort(pkg, slide_part, row.bench_id)
    @shared.keep_int(b, xml.length())
  })

  b.bench(name=prefix + "slide_relationships_read", fn() {
    let rels = read_pptx_relationships_or_abort(pkg, slide_part, row.bench_id)
    @shared.keep_int(b, rels.length())
  })

  b.bench(name=prefix + "notes_xml_read", fn() {
    let next = read_optional_pptx_part_text_length(
      pkg,
      notes_part,
      row.bench_id,
    )
    @shared.keep_int(b, next)
  })

  b.bench(name=prefix + "pptx_source_parse", fn() {
    let next = parse_pptx_source_or_abort(pkg, row.bench_id)
    @shared.keep_int(b, next.slides.length())
  })

  b.bench(name=prefix + "pptx_normalize", fn() {
    let next = normalize_pptx_source_or_abort(source_document, row.bench_id)
    @shared.keep_int(b, next.slides.length())
  })

  b.bench(name=prefix + "pptx_inspect", fn() {
    let next = @dpptx.inspect_pptx_document(normalized_document)
    @shared.keep_int(b, next.object_count)
  })

  b.bench(name=prefix + "shape_text_scan", fn() {
    let next = count_pptx_shape_text_items(normalized_document)
    @shared.keep_int(b, next)
  })

  b.bench(name=prefix + "hyperlink_scan", fn() {
    let next = count_pptx_hyperlinks(normalized_document)
    @shared.keep_int(b, next)
  })

  b.bench(name=prefix + "notes_scan", fn() {
    let next = count_pptx_notes_paragraphs(normalized_document)
    @shared.keep_int(b, next)
  })

  b.bench(name=prefix + "registry_parse", fn() {
    let next = @stage.stage_registry_parse_or_abort(
      registry,
      source,
      parse_context,
      row.bench_id,
      "pptx stage bench",
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
          "pptx stage bench convert failed: " +
          row.bench_id +
          " :: " +
          err.to_string(),
        )
    }
    @shared.keep_string(b, result.content)
  })

  @shared.keep_int(b, package_report.part_count)
  @shared.keep_int(b, package_validation.issues.length())
  @shared.keep_int(b, presentation_xml.length())
  @shared.keep_int(b, presentation_relationships.length())
  @shared.keep_int(b, slide_xml.length())
  @shared.keep_int(b, slide_relationships.length())
  @shared.keep_int(b, notes_xml_length)
  @shared.keep_int(b, inspect_report.object_count)
}

fn open_pptx_package_or_abort(
  bytes : Bytes,
  bench_id : String,
) -> @ox.OoxmlPackage {
  match
    (try @ox.open_ooxml_package(bytes) |> Ok catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort("pptx stage bench open package failed: " + bench_id + " :: " + err)
  }
}

///|
fn locate_pptx_presentation_part_or_abort(
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
        "pptx stage bench presentation-part relationships failed: " +
        bench_id +
        " :: " +
        err,
      )
  }
  if rels.length() > 0 {
    return rels[0].resolved_target
  }
  if @ox.has_part(pkg, "ppt/presentation.xml") {
    return "ppt/presentation.xml"
  }
  abort("pptx stage bench missing presentation part: " + bench_id)
}

///|
fn locate_pptx_first_slide_part_or_abort(
  pkg : @ox.OoxmlPackage,
  relationships : Array[@ox.OoxmlRelationship],
  bench_id : String,
) -> String {
  for rel in relationships {
    if rel.rel_type.has_suffix("/slide") &&
      rel.resolved_target.has_prefix("ppt/slides/") &&
      rel.resolved_target.has_suffix(".xml") {
      return rel.resolved_target
    }
  }
  if @ox.has_part(pkg, "ppt/slides/slide1.xml") {
    return "ppt/slides/slide1.xml"
  }
  abort("pptx stage bench missing slide part: " + bench_id)
}

///|
fn locate_pptx_notes_part_from_relationships(
  pkg : @ox.OoxmlPackage,
  relationships : Array[@ox.OoxmlRelationship],
) -> String? {
  for rel in relationships {
    if rel.rel_type.has_suffix("/notesSlide") &&
      rel.resolved_target.has_prefix("ppt/notesSlides/") &&
      rel.resolved_target.has_suffix(".xml") {
      return Some(rel.resolved_target)
    }
  }
  if @ox.has_part(pkg, "ppt/notesSlides/notesSlide1.xml") {
    Some("ppt/notesSlides/notesSlide1.xml")
  } else {
    None
  }
}

///|
fn read_pptx_part_text_or_abort(
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
        "pptx stage bench read part failed: " +
        bench_id +
        " :: " +
        part_name +
        " :: " +
        err,
      )
  }
}

///|
fn read_pptx_relationships_or_abort(
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
        "pptx stage bench read relationships failed: " + bench_id + " :: " + err,
      )
  }
}

///|
fn read_optional_pptx_part_text_length(
  pkg : @ox.OoxmlPackage,
  part_name : String?,
  bench_id : String,
) -> Int {
  match part_name {
    Some(part) => read_pptx_part_text_or_abort(pkg, part, bench_id).length()
    None => 0
  }
}

///|
fn parse_pptx_source_or_abort(
  pkg : @ox.OoxmlPackage,
  bench_id : String,
) -> @dpptx.PptxSourceDocument {
  match
    (try @dpptx.parse_pptx_source(pkg) |> Ok catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort("pptx stage bench parse source failed: " + bench_id + " :: " + err)
  }
}

///|
fn normalize_pptx_source_or_abort(
  source : @dpptx.PptxSourceDocument,
  bench_id : String,
) -> @dpptx.PptxDocument {
  ignore(bench_id)
  @dpptx.normalize_pptx_source(source)
}

fn count_pptx_shape_text_items(doc : @dpptx.PptxDocument) -> Int {
  let total : Ref[Int] = { val: 0 }
  for slide in doc.slides {
    pptx_count_object_text_items(slide.objects, total)
  }
  total.val
}

///|
fn pptx_count_object_text_items(
  objects : Array[@dpptx.PptxObject],
  total : Ref[Int],
) -> Unit {
  for obj in objects {
    match obj {
      @dpptx.PptxObject::Shape(shape) =>
        match shape.text_body {
          Some(body) =>
            for para in body.paragraphs {
              total.val += 1
              for run in para.runs {
                total.val += run.inlines.length()
              }
            }
          None => ()
        }
      @dpptx.PptxObject::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            for para in cell.paragraphs {
              total.val += 1
              for run in para.runs {
                total.val += run.inlines.length()
              }
            }
          }
        }
      @dpptx.PptxObject::Group(group) =>
        pptx_count_object_text_items(group.children, total)
      _ => ()
    }
  }
}

///|
fn count_pptx_hyperlinks(doc : @dpptx.PptxDocument) -> Int {
  let total : Ref[Int] = { val: 0 }
  for slide in doc.slides {
    pptx_count_object_hyperlinks(slide.objects, total)
  }
  total.val
}

///|
fn pptx_count_object_hyperlinks(
  objects : Array[@dpptx.PptxObject],
  total : Ref[Int],
) -> Unit {
  for obj in objects {
    match obj {
      @dpptx.PptxObject::Shape(shape) => {
        total.val += shape.hyperlinks.length()
        match shape.text_body {
          Some(body) =>
            for para in body.paragraphs {
              for run in para.runs {
                for inline in run.inlines {
                  match inline {
                    @dpptx.PptxInline::Hyperlink(_, _) => total.val += 1
                    _ => ()
                  }
                }
              }
            }
          None => ()
        }
      }
      @dpptx.PptxObject::Group(group) =>
        pptx_count_object_hyperlinks(group.children, total)
      _ => ()
    }
  }
}

///|
fn count_pptx_notes_paragraphs(doc : @dpptx.PptxDocument) -> Int {
  let total : Ref[Int] = { val: 0 }
  for slide in doc.slides {
    match slide.notes {
      Some(notes) => total.val += notes.paragraphs.length()
      None => ()
    }
  }
  total.val
}
