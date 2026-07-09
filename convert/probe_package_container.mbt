///|
fn xlsx_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @drxlsx.prepare_xlsx_package_from_source(source) {
    Ok(value) => value
    Err(_) => return unavailable_probe("xlsx", source)
  }
  let summary = @dxlsx.xlsx_route_preflight_summary_with_package(
    prepared.opened_package,
    options.limits.max_rows,
    options.limits.max_cols,
    options.limits.max_cells,
  )
  match summary {
    Ok(probe) => {
      let signals = [
        make_probe_signal(
          ProbeSignalKind::SheetCount,
          probe.visible_sheet_count,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::RowCount,
          probe.max_sheet_rows,
          limit=Some(options.limits.max_rows),
        ),
        make_probe_signal(
          ProbeSignalKind::ColCount,
          probe.max_sheet_cols,
          limit=Some(options.limits.max_cols),
        ),
        make_probe_signal(
          ProbeSignalKind::CellEstimate,
          probe.estimated_cells,
          limit=Some(options.limits.max_cells),
        ),
      ]
      probe_outcome(
        "xlsx",
        signal_summary_lines(signals),
        prepared.prepared_source,
        probe_signals=signals,
        probe_artifacts=[RouteProbeArtifact::XlsxPrepared(prepared)],
      )
    }
    Err(_) =>
      probe_outcome("xlsx", ["probe_failed"], prepared.prepared_source, probe_failures=[
        make_probe_failure("xlsx", "probe_failed"),
      ])
  }
}

///|
fn docx_probe_block_count(blocks : Array[@ddocx.DocxBlock]) -> Int {
  let mut count = 0
  for block in blocks {
    count += 1
    match block {
      @ddocx.DocxBlock::ContentControl(control) =>
        count += docx_probe_block_count(control.blocks)
      _ => ()
    }
  }
  count
}

///|
fn docx_probe_image_count_inlines(inlines : Array[@ddocx.DocxInline]) -> Int {
  let mut count = 0
  for inline in inlines {
    match inline {
      @ddocx.DocxInline::Media(_) => count += 1
      @ddocx.DocxInline::Drawing(drawing) => {
        if drawing.media is Some(_) {
          count += 1
        }
        count += drawing.alternate_media.length()
        count += docx_probe_image_count_inlines(drawing.child_inlines)
      }
      @ddocx.DocxInline::Shape(shape) => {
        if shape.media is Some(_) {
          count += 1
        }
        count += docx_probe_image_count_inlines(shape.child_inlines)
      }
      @ddocx.DocxInline::ContentControl(control) =>
        count += docx_probe_image_count_inlines(control.inlines)
      @ddocx.DocxInline::FieldUnsupported(field) =>
        count += docx_probe_image_count_inlines(field.child_inlines)
      @ddocx.DocxInline::Math(math) =>
        count += docx_probe_image_count_inlines(math.child_inlines)
      @ddocx.DocxInline::TrackedChange(change) =>
        count += docx_probe_image_count_inlines(change.child_inlines)
      @ddocx.DocxInline::SmartTag(tag) =>
        count += docx_probe_image_count_inlines(tag.child_inlines)
      _ => ()
    }
  }
  count
}

///|
fn docx_probe_image_count_blocks(blocks : Array[@ddocx.DocxBlock]) -> Int {
  let mut count = 0
  for block in blocks {
    match block {
      @ddocx.DocxBlock::Paragraph(paragraph) =>
        for run in paragraph.runs {
          count += docx_probe_image_count_inlines(run.inlines)
        }
      @ddocx.DocxBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            count += docx_probe_image_count_blocks(cell.blocks)
          }
        }
      @ddocx.DocxBlock::ContentControl(control) =>
        count += docx_probe_image_count_blocks(control.blocks)
      _ => ()
    }
  }
  count
}

///|
fn docx_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @ddocx.prepare_docx_document_from_source(source) {
    Ok(value) => value
    Err(_) =>
      return probe_outcome("docx", ["probe_failed"], source, probe_failures=[
        make_probe_failure("docx", "probe_failed"),
      ])
  }
  let doc = prepared.document
  let artifact : DocxProbeArtifact = {
    block_count: docx_probe_block_count(doc.body),
    image_count: docx_probe_image_count_blocks(doc.body),
    comment_count: doc.comments.length(),
    textbox_count: doc.textboxes.length(),
    header_count: doc.headers.length(),
    footer_count: doc.footers.length(),
    note_count: doc.footnotes.length() + doc.endnotes.length(),
  }
  let signals = [
    make_probe_signal(
      ProbeSignalKind::BlockCount,
      artifact.block_count,
      limit=Some(options.limits.max_rows),
    ),
    make_probe_signal(ProbeSignalKind::CommentCount, artifact.comment_count),
    make_probe_signal(ProbeSignalKind::NoteCount, artifact.note_count),
    make_probe_signal(ProbeSignalKind::AssetCount, artifact.image_count),
  ]
  probe_outcome(
    "docx",
    signal_summary_lines(signals) +
    [
      probe_summary_line("textboxes", artifact.textbox_count, None),
      probe_summary_line("headers", artifact.header_count, None),
      probe_summary_line("footers", artifact.footer_count, None),
    ],
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[RouteProbeArtifact::DocxPrepared(prepared, artifact)],
  )
}

///|
fn pptx_probe_text_block_count(presentation : @pptxdoc.PptxDocument) -> Int {
  let mut count = 0
  for slide in presentation.slides {
    for obj in slide.objects {
      match obj {
        @pptxdoc.PptxObject::Shape(shape) =>
          match shape.text_body {
            Some(body) => count += body.paragraphs.length()
            None => ()
          }
        @pptxdoc.PptxObject::Table(table) =>
          for row in table.rows {
            for cell in row.cells {
              count += cell.paragraphs.length()
            }
          }
        _ => ()
      }
    }
  }
  count
}

///|
fn pptx_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @pptxdoc.prepare_pptx_document_from_source(source) {
    Ok(value) => value
    Err(_) =>
      return probe_outcome("pptx", ["probe_failed"], source, probe_failures=[
        make_probe_failure("pptx", "probe_failed"),
      ])
  }
  let presentation = prepared.document
  let inspect = @pptxdoc.inspect_pptx_document(presentation)
  let mut hidden_slide_count = 0
  for slide in presentation.slides {
    if slide.hidden {
      hidden_slide_count += 1
    }
  }
  let artifact : PptxProbeArtifact = {
    hidden_slide_count,
    text_block_count: pptx_probe_text_block_count(presentation),
    image_count: inspect.picture_count,
  }
  let signals = [
    make_probe_signal(
      ProbeSignalKind::SlideCount,
      inspect.slide_count,
      limit=Some(options.limits.max_rows),
    ),
    make_probe_signal(ProbeSignalKind::NoteCount, inspect.notes_count),
    make_probe_signal(ProbeSignalKind::CommentCount, inspect.comment_count),
    make_probe_signal(ProbeSignalKind::AssetCount, artifact.image_count),
    make_probe_signal(
      ProbeSignalKind::BlockCount,
      artifact.text_block_count,
      limit=Some(options.limits.max_cells),
    ),
  ]
  probe_outcome(
    "pptx",
    signal_summary_lines(signals) +
    [probe_summary_line("hidden_slides", artifact.hidden_slide_count, None)],
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[RouteProbeArtifact::PptxPrepared(prepared, artifact)],
  )
}

///|
fn odt_preflight_probe(
  source : @input.InputSource,
  _options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @dodf.prepare_odt_document_from_source(source) {
    Ok(value) => value
    Err(_) =>
      return probe_outcome("odt", ["probe_failed"], source, probe_failures=[
        make_probe_failure("odt", "probe_failed"),
      ])
  }
  let inspect = prepared.inspect
  let signals = [
    make_probe_signal(ProbeSignalKind::BlockCount, inspect.block_count),
    make_probe_signal(ProbeSignalKind::NoteCount, inspect.note_count),
    make_probe_signal(ProbeSignalKind::CommentCount, inspect.comment_count),
  ]
  probe_outcome(
    "odt",
    signal_summary_lines(signals) +
    [
      probe_summary_line("images", inspect.image_count, None),
      probe_summary_line("tables", inspect.table_count, None),
    ],
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[RouteProbeArtifact::OdtPrepared(prepared)],
  )
}

///|
fn ods_preflight_probe(
  source : @input.InputSource,
  _options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @dodf.prepare_ods_document_from_source(source) {
    Ok(value) => value
    Err(_) =>
      return probe_outcome("ods", ["probe_failed"], source, probe_failures=[
        make_probe_failure("ods", "probe_failed"),
      ])
  }
  let inspect = prepared.inspect
  let signals = [
    make_probe_signal(ProbeSignalKind::SheetCount, inspect.visible_sheet_count),
    make_probe_signal(
      ProbeSignalKind::HiddenSheetCount,
      inspect.hidden_sheet_count,
    ),
    make_probe_signal(ProbeSignalKind::RowCount, inspect.non_empty_row_count),
    make_probe_signal(ProbeSignalKind::CellEstimate, inspect.used_cell_count),
    make_probe_signal(ProbeSignalKind::HiddenRowCount, inspect.hidden_row_count),
    make_probe_signal(
      ProbeSignalKind::CoveredCellCount,
      inspect.covered_cell_count,
    ),
  ]
  probe_outcome(
    "ods",
    signal_summary_lines(signals) +
    [
      probe_summary_line("max_cols", inspect.max_sheet_cols, None),
      probe_summary_line("used_cols", inspect.max_used_cols, None),
    ],
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[RouteProbeArtifact::OdsPrepared(prepared)],
  )
}

///|
fn odp_preflight_probe(
  source : @input.InputSource,
  _options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @dodf.prepare_odp_document_from_source(source) {
    Ok(value) => value
    Err(_) =>
      return probe_outcome("odp", ["probe_failed"], source, probe_failures=[
        make_probe_failure("odp", "probe_failed"),
      ])
  }
  let inspect = prepared.inspect
  let signals = [
    make_probe_signal(ProbeSignalKind::SlideCount, inspect.slide_count),
    make_probe_signal(ProbeSignalKind::BlockCount, inspect.block_count),
    make_probe_signal(ProbeSignalKind::NoteCount, inspect.notes_count),
    make_probe_signal(ProbeSignalKind::AssetCount, inspect.image_count),
  ]
  probe_outcome(
    "odp",
    signal_summary_lines(signals),
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[RouteProbeArtifact::OdpPrepared(prepared)],
  )
}

///|
fn zip_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @dzipsource.prepare_zip_from_source(source) {
    Ok(value) => value
    Err(_) =>
      return probe_outcome("zip", ["probe_failed"], source, probe_failures=[
        make_probe_failure("zip", "probe_failed"),
      ])
  }
  let report = prepared.inspect
  let signals = [
    make_probe_signal(
      ProbeSignalKind::EntryCount,
      report.file_entry_count,
      limit=Some(options.limits.max_rows),
    ),
    make_probe_signal(
      ProbeSignalKind::AssetCount,
      report.inventory.entries.length(),
    ),
  ]
  probe_outcome(
    "zip",
    signal_summary_lines(signals) +
    [probe_summary_line("decoded_bytes", report.total_uncompressed_size, None)],
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[RouteProbeArtifact::ZipPrepared(prepared)],
  )
}

///|
fn epub_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared = match @depub.prepare_epub_package_from_source(source) {
    Ok(value) => value
    Err(_) =>
      return probe_outcome("epub", ["probe_failed"], source, probe_failures=[
        make_probe_failure("epub", "probe_failed"),
      ])
  }
  let inventory = prepared.inspect.inventory
  let signals = [
    make_probe_signal(
      ProbeSignalKind::EntryCount,
      inventory.part_count,
      limit=Some(options.limits.max_rows),
    ),
    make_probe_signal(
      ProbeSignalKind::BlockCount,
      inventory.spine_linear_count,
      limit=Some(options.limits.max_rows),
    ),
    make_probe_signal(
      ProbeSignalKind::AssetCount,
      inventory.cover_candidate_count,
    ),
  ]
  probe_outcome(
    "epub",
    signal_summary_lines(signals) +
    [
      probe_summary_line("manifest", inventory.manifest_count, None),
      probe_summary_line("spine", inventory.spine_count, None),
    ],
    prepared.prepared_source,
    probe_signals=signals,
    probe_artifacts=[RouteProbeArtifact::EpubPrepared(prepared)],
  )
}
