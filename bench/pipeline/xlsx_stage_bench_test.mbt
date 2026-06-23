///|
test "pipeline.xlsx.multi_sheet_mixed.stages" (b : @bench.T) {
  let rows = [
    @stage.stage_binary_row("xlsx_tiny_sheet_names_v1"),
    @stage.stage_binary_row("xlsx_small_multi_sheet_mixed_v1"),
  ]
  let detector = @stage.default_stage_detector()
  let registry = @stage.default_stage_registry()
  let render_context = @stage.default_stage_render_context()
  let renderer = @stage.default_stage_renderer()

  for row in rows {
    let source = @shared.bench_row_input_source(row)
    let bytes = @shared.bench_row_bytes(row)
    let parse_context = @stage.stage_parse_context(@input.DetectedFormat::Xlsx)

    let pkg = open_xlsx_package_or_abort(bytes, row.bench_id)
    let workbook_part = locate_xlsx_workbook_part_or_abort(pkg, row.bench_id)
    let workbook_xml = read_xlsx_part_text_or_abort(
      pkg,
      workbook_part,
      row.bench_id,
    )
    let workbook_relationships = read_xlsx_relationships_or_abort(
      pkg,
      workbook_part,
      row.bench_id,
    )
    let shared_strings_xml_length = read_optional_xlsx_part_text_length(
      pkg,
      "xl/sharedStrings.xml",
      row.bench_id,
    )
    let styles_xml_length = read_optional_xlsx_part_text_length(
      pkg,
      "xl/styles.xml",
      row.bench_id,
    )
    let first_sheet_part = locate_xlsx_first_sheet_part_or_abort(
      pkg,
      workbook_part,
      row.bench_id,
    )
    let first_sheet_xml_length = read_optional_xlsx_part_text_length(
      pkg,
      first_sheet_part,
      row.bench_id,
    )
    let first_sheet_relationship_count = read_optional_xlsx_relationship_count(
      pkg,
      first_sheet_part,
      row.bench_id,
    )
    let package_report = @ox.inspect_ooxml_package(pkg)
    let package_validation = @ox.validate_ooxml_package(pkg)
    let workbook_metric = match @fxlsx.xlsx_workbook_metric(source) {
      Ok(value) => value
      Err(err) =>
        abort(
          "xlsx stage bench workbook metric failed: " +
          row.bench_id +
          " :: " +
          err,
        )
    }
    let sheet_metric = match @fxlsx.xlsx_first_sheet_metric(source) {
      Ok(value) => value
      Err(err) =>
        abort(
          "xlsx stage bench sheet metric failed: " + row.bench_id + " :: " + err,
        )
    }
    let parse_result = @stage.stage_registry_parse_or_abort(
      registry,
      source,
      parse_context,
      row.bench_id,
      "xlsx stage bench",
    )
    let ir_input = @stage.stage_parse_to_ir_input(parse_result)
    let built_document = @stage.stage_build_document(ir_input)
    let rendered = @stage.stage_render_markdown(
      built_document, renderer, render_context,
    )
    let prefix = "pipeline.xlsx." + row.bench_id + "."

    b.bench(name=prefix + "input_read", fn() {
      let payload = match @input.read_input_bytes(source) {
        Ok(value) => value
        Err(err) =>
          abort("xlsx stage bench read failed: " + row.bench_id + " :: " + err)
      }
      @shared.keep_bytes_len(b, payload)
    })

    b.bench(name=prefix + "format_detect", fn() {
      let detected = (detector.detect)(source)
      @shared.keep_string(b, @input.detected_format_name(detected.format))
    })

    b.bench(name=prefix + "package_open", fn() {
      let next = open_xlsx_package_or_abort(bytes, row.bench_id)
      @shared.keep_int(b, @ox.list_parts(next).length())
    })

    b.bench(name=prefix + "package_inspect", fn() {
      let report = @ox.inspect_ooxml_package(pkg)
      @shared.keep_int(b, report.part_count)
    })

    b.bench(name=prefix + "package_validate", fn() {
      let report = @ox.validate_ooxml_package(pkg)
      @shared.keep_int(b, report.issue_count)
    })

    b.bench(name=prefix + "workbook_xml_read", fn() {
      let xml = read_xlsx_part_text_or_abort(pkg, workbook_part, row.bench_id)
      @shared.keep_int(b, xml.length())
    })

    b.bench(name=prefix + "workbook_relationships_read", fn() {
      let rels = read_xlsx_relationships_or_abort(
        pkg,
        workbook_part,
        row.bench_id,
      )
      @shared.keep_int(b, rels.length())
    })

    b.bench(name=prefix + "shared_strings_xml_read", fn() {
      let next = read_optional_xlsx_part_text_length(
        pkg,
        "xl/sharedStrings.xml",
        row.bench_id,
      )
      @shared.keep_int(b, next)
    })

    b.bench(name=prefix + "styles_xml_read", fn() {
      let next = read_optional_xlsx_part_text_length(
        pkg,
        "xl/styles.xml",
        row.bench_id,
      )
      @shared.keep_int(b, next)
    })

    b.bench(name=prefix + "first_sheet_xml_read", fn() {
      let next = read_optional_xlsx_part_text_length(
        pkg,
        first_sheet_part,
        row.bench_id,
      )
      @shared.keep_int(b, next)
    })

    b.bench(name=prefix + "first_sheet_relationships_read", fn() {
      let next = read_optional_xlsx_relationship_count(
        pkg,
        first_sheet_part,
        row.bench_id,
      )
      @shared.keep_int(b, next)
    })

    b.bench(name=prefix + "workbook_parse", fn() {
      let next = match @fxlsx.xlsx_workbook_metric(source) {
        Ok(value) => value
        Err(err) =>
          abort(
            "xlsx stage bench workbook metric failed: " +
            row.bench_id +
            " :: " +
            err,
          )
      }
      @shared.keep_int(b, next)
    })

    b.bench(name=prefix + "first_sheet_parse", fn() {
      let next = match @fxlsx.xlsx_first_sheet_metric(source) {
        Ok(value) => value
        Err(err) =>
          abort(
            "xlsx stage bench sheet metric failed: " +
            row.bench_id +
            " :: " +
            err,
          )
      }
      @shared.keep_int(b, next)
    })

    b.bench(name=prefix + "registry_parse", fn() {
      let next = @stage.stage_registry_parse_or_abort(
        registry,
        source,
        parse_context,
        row.bench_id,
        "xlsx stage bench",
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
            "xlsx stage bench convert failed: " +
            row.bench_id +
            " :: " +
            err.to_string(),
          )
      }
      @shared.keep_string(b, result.content)
    })

    @shared.keep_int(b, package_report.part_count)
    @shared.keep_int(b, package_validation.issue_count)
    @shared.keep_int(b, workbook_xml.length())
    @shared.keep_int(b, workbook_relationships.length())
    @shared.keep_int(b, shared_strings_xml_length)
    @shared.keep_int(b, styles_xml_length)
    @shared.keep_int(b, first_sheet_xml_length)
    @shared.keep_int(b, first_sheet_relationship_count)
    @shared.keep_int(b, workbook_metric)
    @shared.keep_int(b, sheet_metric)
  }
}

///|
fn open_xlsx_package_or_abort(
  bytes : Bytes,
  bench_id : String,
) -> @ox.OoxmlPackage {
  match
    (try @ox.open_ooxml_package(bytes) |> Ok catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort("xlsx stage bench open package failed: " + bench_id + " :: " + err)
  }
}

///|
fn locate_xlsx_workbook_part_or_abort(
  pkg : @ox.OoxmlPackage,
  bench_id : String,
) -> String {
  if @ox.has_part(pkg, "xl/workbook.xml") {
    return "xl/workbook.xml"
  }
  let rels = match
    (try
      @ox.find_relationships_by_type(pkg, "", "/officeDocument") |> Ok
    catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort(
        "xlsx stage bench workbook relationships failed: " +
        bench_id +
        " :: " +
        err,
      )
  }
  if rels.length() > 0 {
    return rels[0].resolved_target
  }
  let candidates = match
    (try
      @ox.list_parts_by_content_type(
        pkg, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
      )
      |> Ok
    catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort(
        "xlsx stage bench workbook content type lookup failed: " +
        bench_id +
        " :: " +
        err,
      )
  }
  if candidates.length() == 0 {
    abort("xlsx stage bench missing workbook part: " + bench_id)
  }
  candidates[0]
}

///|
fn locate_xlsx_first_sheet_part_or_abort(
  pkg : @ox.OoxmlPackage,
  workbook_part : String,
  bench_id : String,
) -> String {
  let rels = match
    (try
      @ox.find_relationships_by_type(pkg, workbook_part, "/worksheet") |> Ok
    catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort(
        "xlsx stage bench worksheet relationships failed: " +
        bench_id +
        " :: " +
        err,
      )
  }
  if rels.length() == 0 {
    abort("xlsx stage bench missing worksheet part: " + bench_id)
  }
  rels[0].resolved_target
}

///|
fn read_xlsx_part_text_or_abort(
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
      abort("xlsx stage bench read part failed: " + bench_id + " :: " + err)
  }
}

///|
fn read_xlsx_relationships_or_abort(
  pkg : @ox.OoxmlPackage,
  source_part : String,
  bench_id : String,
) -> Array[@ox.OoxmlRelationship] {
  match
    (try @ox.read_part_relationships(pkg, source_part) |> Ok catch {
      e => Err(e.to_string())
    }) {
    Ok(value) => value
    Err(err) =>
      abort(
        "xlsx stage bench read relationships failed: " + bench_id + " :: " + err,
      )
  }
}

///|
fn read_optional_xlsx_part_text_length(
  pkg : @ox.OoxmlPackage,
  part_name : String,
  bench_id : String,
) -> Int {
  if !@ox.has_part(pkg, part_name) {
    return 0
  }
  read_xlsx_part_text_or_abort(pkg, part_name, bench_id).length()
}

///|
fn read_optional_xlsx_relationship_count(
  pkg : @ox.OoxmlPackage,
  source_part : String,
  bench_id : String,
) -> Int {
  if !@ox.has_relationships_part(pkg, source_part) {
    return 0
  }
  read_xlsx_relationships_or_abort(pkg, source_part, bench_id).length()
}
