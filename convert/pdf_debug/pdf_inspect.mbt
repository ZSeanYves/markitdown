///|
pub fn build_pdf_debug_sections(
  model : @model.PdfDocumentModel,
  max_heading : Int,
) -> Array[@cor.DebugSection] {
  let doc0 = @pdfcore.build_convert_lines(model, "")
  let doc1 = @pdfcore.build_convert_blocks(doc0)
  let doc2 = @pdfcore.classify_convert_blocks(doc1, max_heading)
  let doc3 = @pdfcore.filter_noise_blocks(doc2)
  let doc4 = @pdfcore.merge_convert_blocks(doc3)
  let doc5 = @pdfcore.attach_high_confidence_uri_links(doc4)

  [
    pdf_backend_section(model),
    pdf_pages_section(model),
    pdf_text_model_section(model),
    pdf_layout_assist_section(doc1, doc2),
    pdf_images_section(model),
    pdf_annotations_section(model),
    pdf_links_section(doc1),
    pdf_pipeline_section(doc1, doc2, doc3, doc4, doc5, max_heading),
  ]
}

///|
pub fn build_pdf_layout_assist_summary(
  model : @model.PdfDocumentModel,
  max_heading : Int,
) -> LayoutAssistSummary {
  let doc0 = @pdfcore.build_convert_lines(model, "")
  let doc1 = @pdfcore.build_convert_blocks(doc0)
  let doc2 = @pdfcore.classify_convert_blocks(doc1, max_heading)
  let features = build_layout_assist_features(doc1, doc2)
  let predictions = predict_with_heuristic_layout_assist(features)
  summarize_layout_assist_predictions(features, predictions)
}

///|
fn pdf_backend_section(model : @model.PdfDocumentModel) -> @cor.DebugSection {
  let report = @pdfinspect.inspect_pdf_document(model)
  @cor.debug_section(
    "pdf_backend",
    "pdf",
    true,
    Some("PDF backend, OCR boundary, and document-level flags"),
    @cor.object_json([
      @cor.json_string("backend") + ": " + @cor.json_string("mbtpdf"),
      @cor.json_string("ocr_mode") + ": " + @cor.json_string("native"),
      @cor.json_string("ocr_used") + ": " + @cor.bool_json(false),
      @cor.json_string("text_signal_level") +
      ": " +
      @cor.json_string(report.text_signal_level),
      @cor.json_string("native_text_char_count") +
      ": " +
      report.native_text_char_count.to_string(),
      @cor.json_string("page_image_count") +
      ": " +
      report.page_image_count.to_string(),
      @cor.json_string("has_embedded_text") +
      ": " +
      @cor.bool_json(report.has_embedded_text),
      @cor.json_string("has_page_images") +
      ": " +
      @cor.bool_json(report.has_page_images),
      @cor.json_string("image_only") + ": " + @cor.bool_json(report.image_only),
      @cor.json_string("ocr_recommended") +
      ": " +
      @cor.bool_json(report.ocr_recommended),
      @cor.json_string("native_signal_empty") +
      ": " +
      @cor.bool_json(is_effectively_empty_pdf_doc(model)),
      @cor.json_string("page_count") + ": " + model.page_count.to_string(),
      @cor.json_string("outline_count") +
      ": " +
      model.outlines.length().to_string(),
      @cor.json_string("is_encrypted") +
      ": " +
      @cor.bool_json(model.is_encrypted),
      @cor.json_string("has_xref_stream") +
      ": " +
      @cor.bool_json(model.has_xref_stream),
      @cor.json_string("has_object_stream") +
      ": " +
      @cor.bool_json(model.has_object_stream),
    ]),
  )
}

///|
fn pdf_pages_section(model : @model.PdfDocumentModel) -> @cor.DebugSection {
  let page_items : Array[String] = []
  let mut raw_content_stream_ref_total = 0
  let report = @pdfinspect.inspect_pdf_document(model)

  for i = 0; i < model.pages.length(); i = i + 1 {
    let page = model.pages[i]
    let page_report = report.pages[i]
    raw_content_stream_ref_total += page.raw_content_stream_refs.length()
    page_items.push(
      @cor.object_json([
        @cor.json_string("page_number") +
        ": " +
        (page.page_index + 1).to_string(),
        @cor.json_string("page_label") +
        ": " +
        @cor.json_string_opt(page.page_label),
        @cor.json_string("rotation") + ": " + page.rotation.to_string(),
        @cor.json_string("media_box") +
        ": " +
        pdf_rect_json(page.boxes.media_box),
        @cor.json_string("crop_box") +
        ": " +
        pdf_rect_opt_json(page.boxes.crop_box),
        @cor.json_string("raw_content_stream_ref_count") +
        ": " +
        page.raw_content_stream_refs.length().to_string(),
        @cor.json_string("raw_content_stream_refs") +
        ": " +
        @cor.string_array_json(page.raw_content_stream_refs),
        @cor.json_string("text_block_count") +
        ": " +
        @model.page_text_block_count(page).to_string(),
        @cor.json_string("line_count") +
        ": " +
        @model.page_line_count(page).to_string(),
        @cor.json_string("span_count") +
        ": " +
        @model.page_span_count(page).to_string(),
        @cor.json_string("char_count") +
        ": " +
        @model.page_char_count(page).to_string(),
        @cor.json_string("text_signal_level") +
        ": " +
        @cor.json_string(page_report.text_signal_level),
        @cor.json_string("has_text_signal") +
        ": " +
        @cor.bool_json(page_report.has_text_signal),
        @cor.json_string("has_image_signal") +
        ": " +
        @cor.bool_json(page_report.has_image_signal),
        @cor.json_string("image_only") +
        ": " +
        @cor.bool_json(page_report.image_only),
        @cor.json_string("ocr_recommended") +
        ": " +
        @cor.bool_json(page_report.ocr_recommended),
        @cor.json_string("image_count") +
        ": " +
        page.images.length().to_string(),
        @cor.json_string("vector_count") +
        ": " +
        page.vectors.length().to_string(),
        @cor.json_string("annotation_count") +
        ": " +
        page.annotations.length().to_string(),
        @cor.json_string("form_field_count") +
        ": " +
        page.forms.length().to_string(),
        @cor.json_string("object_count") +
        ": " +
        @model.page_object_count(page).to_string(),
        @cor.json_string("header_footer_candidate_count") +
        ": " +
        @model.page_header_footer_candidate_count(page).to_string(),
        @cor.json_string("page_number_candidate_count") +
        ": " +
        @model.page_page_number_candidate_count(page).to_string(),
        @cor.json_string("artifact_candidate_count") +
        ": " +
        @model.page_artifact_candidate_count(page).to_string(),
      ]),
    )
  }

  @cor.debug_section(
    "pdf_pages",
    "pdf",
    true,
    Some("PDF page geometry, content stream refs, and per-page object counts"),
    @cor.object_json([
      @cor.json_string("page_count") + ": " + model.page_count.to_string(),
      @cor.json_string("raw_content_stream_ref_total") +
      ": " +
      raw_content_stream_ref_total.to_string(),
      @cor.json_string("pages") + ": " + @cor.array_json(page_items),
    ]),
  )
}

///|
fn pdf_text_model_section(model : @model.PdfDocumentModel) -> @cor.DebugSection {
  let mut block_count = 0
  let mut line_count = 0
  let mut span_count = 0
  let mut char_count = 0
  let mut heading_candidate_count = 0
  let mut page_number_candidate_count = 0
  let mut header_footer_candidate_count = 0
  let mut artifact_candidate_count = 0
  let mut caption_candidate_count = 0
  let mut table_cell_candidate_count = 0
  let writing_direction_counts = Map([])
  let source_kind_counts = Map([])

  for page in model.pages {
    block_count += page.text_blocks.length()
    line_count += @model.page_line_count(page)
    span_count += @model.page_span_count(page)
    char_count += @model.page_char_count(page)

    for block in page.text_blocks {
      if block.is_heading_candidate {
        heading_candidate_count += 1
      }
      if block.is_page_number_candidate {
        page_number_candidate_count += 1
      }
      if block.is_header_footer_candidate {
        header_footer_candidate_count += 1
      }
      if block.is_artifact_candidate {
        artifact_candidate_count += 1
      }
      if block.is_caption_candidate {
        caption_candidate_count += 1
      }
      if block.is_table_cell_candidate {
        table_cell_candidate_count += 1
      }

      bump_string_count(
        writing_direction_counts,
        pdf_writing_direction_name(block.writing_direction),
      )
      bump_string_count(
        source_kind_counts,
        pdf_source_block_kind_name(block.kind),
      )
    }
  }

  @cor.debug_section(
    "pdf_text_model",
    "pdf",
    true,
    Some("PDF lower-layer text model counts and candidate signals"),
    @cor.object_json([
      @cor.json_string("text_block_count") + ": " + block_count.to_string(),
      @cor.json_string("line_count") + ": " + line_count.to_string(),
      @cor.json_string("span_count") + ": " + span_count.to_string(),
      @cor.json_string("char_count") + ": " + char_count.to_string(),
      @cor.json_string("heading_candidate_count") +
      ": " +
      heading_candidate_count.to_string(),
      @cor.json_string("page_number_candidate_count") +
      ": " +
      page_number_candidate_count.to_string(),
      @cor.json_string("header_footer_candidate_count") +
      ": " +
      header_footer_candidate_count.to_string(),
      @cor.json_string("artifact_candidate_count") +
      ": " +
      artifact_candidate_count.to_string(),
      @cor.json_string("caption_candidate_count") +
      ": " +
      caption_candidate_count.to_string(),
      @cor.json_string("table_cell_candidate_count") +
      ": " +
      table_cell_candidate_count.to_string(),
      @cor.json_string("writing_direction_counts") +
      ": " +
      map_string_int_json(writing_direction_counts),
      @cor.json_string("source_block_kind_counts") +
      ": " +
      map_string_int_json(source_kind_counts),
    ]),
  )
}

///|
fn pdf_layout_assist_section(
  raw_doc : @pdfcore.PdfConvertDocument,
  classified_doc : @pdfcore.PdfConvertDocument,
) -> @cor.DebugSection {
  let features = build_layout_assist_features(raw_doc, classified_doc)
  let predictions = predict_with_heuristic_layout_assist(features)
  let summary = summarize_layout_assist_predictions(features, predictions)
  let provider_items : Array[String] = []
  for info in summary.providers {
    provider_items.push(
      @cor.object_json([
        @cor.json_string("name") + ": " + @cor.json_string(info.name),
        @cor.json_string("mode") +
        ": " +
        @cor.json_string(layout_assist_mode_name(info.mode)),
        @cor.json_string("version") + ": " + @cor.json_string_opt(info.version),
        @cor.json_string("available") + ": " + @cor.bool_json(info.available),
      ]),
    )
  }
  let label_counts_json = map_string_int_json(summary.label_counts)
  let reason_counts_json = map_string_int_json(summary.reason_counts)
  let preview = take_layout_assist_predictions(summary.predictions, 12)
  let prediction_items : Array[String] = []
  for prediction in preview {
    prediction_items.push(layout_assist_prediction_json(prediction))
  }

  @cor.debug_section(
    "layout_assist",
    "pdf",
    true,
    Some(
      "advisory/report-only layout-assist provider summary and conservative candidate predictions",
    ),
    @cor.object_json([
      @cor.json_string("provider_count") +
      ": " +
      summary.provider_count.to_string(),
      @cor.json_string("providers") + ": " + @cor.array_json(provider_items),
      @cor.json_string("feature_count") +
      ": " +
      summary.feature_count.to_string(),
      @cor.json_string("prediction_count") +
      ": " +
      summary.prediction_count.to_string(),
      @cor.json_string("label_counts") + ": " + label_counts_json,
      @cor.json_string("reason_counts") + ": " + reason_counts_json,
      @cor.json_string("warning_count") +
      ": " +
      summary.warning_count.to_string(),
      @cor.json_string("predictions_truncated") +
      ": " +
      @cor.bool_json(summary.prediction_count > preview.length()),
      @cor.json_string("predictions") + ": " + @cor.array_json(prediction_items),
    ]),
  )
}

///|
fn build_layout_assist_features(
  raw_doc : @pdfcore.PdfConvertDocument,
  classified_doc : @pdfcore.PdfConvertDocument,
) -> Array[LayoutAssistFeature] {
  let out : Array[LayoutAssistFeature] = []
  let page_count = min_layout_assist_int(
    raw_doc.pages.length(),
    classified_doc.pages.length(),
  )
  for page_index = 0; page_index < page_count; page_index = page_index + 1 {
    let raw_page = raw_doc.pages[page_index]
    let classified_page = classified_doc.pages[page_index]
    let block_count = min_layout_assist_int(
      raw_page.blocks.length(),
      classified_page.blocks.length(),
    )
    for block_index = 0
        block_index < block_count
        block_index = block_index + 1 {
      let raw_block = raw_page.blocks[block_index]
      let classified_block = classified_page.blocks[block_index]
      let hint = classify_layout_assist_block_hint(raw_block, classified_block)
      let metrics = layout_assist_metrics_json(
        raw_page, raw_block, classified_block,
      )
      out.push({
        target_id: "p" +
        (raw_block._page_index + 1).to_string() +
        ".b" +
        raw_block.block_index.to_string(),
        text: raw_block.text,
        page_index: raw_block._page_index,
        block_kind_hint: hint,
        metrics_json: Some(metrics),
      })
    }
  }
  out
}

///|
fn classify_layout_assist_block_hint(
  raw_block : @pdfcore.PdfConvertBlock,
  classified_block : @pdfcore.PdfConvertBlock,
) -> String? {
  if raw_block.is_caption_candidate {
    return Some("caption")
  }
  if raw_block.is_table_cell_candidate {
    return Some("table")
  }
  if raw_block.is_artifact_candidate || raw_block.is_noise_candidate {
    return Some("noise")
  }
  match classified_block.kind {
    @pdfcore.PdfConvertBlockKind::Heading => Some("heading")
    @pdfcore.PdfConvertBlockKind::Paragraph => None
    @pdfcore.PdfConvertBlockKind::Noise => Some("noise")
  }
}

///|
fn layout_assist_metrics_json(
  page : @pdfcore.PdfConvertPage,
  raw_block : @pdfcore.PdfConvertBlock,
  classified_block : @pdfcore.PdfConvertBlock,
) -> String {
  let near_image = block_near_any_image(page.images, raw_block, 18.0)
  @cor.object_json([
    @cor.json_string("line_count") + ": " + raw_block.line_count.to_string(),
    @cor.json_string("text_length") + ": " + raw_block.text.length().to_string(),
    @cor.json_string("near_image") + ": " + @cor.bool_json(near_image),
    @cor.json_string("is_heading_candidate") +
    ": " +
    @cor.bool_json(raw_block.is_heading_candidate),
    @cor.json_string("is_caption_candidate") +
    ": " +
    @cor.bool_json(raw_block.is_caption_candidate),
    @cor.json_string("is_table_cell_candidate") +
    ": " +
    @cor.bool_json(raw_block.is_table_cell_candidate),
    @cor.json_string("final_kind") +
    ": " +
    @cor.json_string(layout_assist_block_kind_name(classified_block.kind)),
  ])
}

///|
fn block_near_any_image(
  images : Array[@pdfcore.PdfConvertImage],
  block : @pdfcore.PdfConvertBlock,
  threshold : Double,
) -> Bool {
  for image in images {
    if layout_assist_rects_overlap_or_near(block._bbox, image._bbox, threshold) {
      return true
    }
  }
  false
}

///|
fn layout_assist_rects_overlap_or_near(
  a : @model.PdfRect,
  b : @model.PdfRect,
  threshold : Double,
) -> Bool {
  let horizontal_gap = if a.x1 < b.x0 {
    b.x0 - a.x1
  } else if b.x1 < a.x0 {
    a.x0 - b.x1
  } else {
    0.0
  }
  let vertical_gap = if a.y1 < b.y0 {
    b.y0 - a.y1
  } else if b.y1 < a.y0 {
    a.y0 - b.y1
  } else {
    0.0
  }
  horizontal_gap <= threshold && vertical_gap <= threshold
}

///|
fn layout_assist_prediction_json(prediction : LayoutAssistPrediction) -> String {
  @cor.object_json([
    @cor.json_string("target_id") +
    ": " +
    @cor.json_string(prediction.target_id),
    @cor.json_string("page_index") + ": " + prediction.page_index.to_string(),
    @cor.json_string("suggested_label") +
    ": " +
    @cor.json_string(prediction.suggested_label),
    @cor.json_string("confidence") +
    ": " +
    double_opt_json(prediction.confidence),
    @cor.json_string("provider") + ": " + @cor.json_string(prediction.provider),
    @cor.json_string("mode") +
    ": " +
    @cor.json_string(layout_assist_mode_name(prediction.mode)),
    @cor.json_string("reasons") +
    ": " +
    @cor.string_array_json(prediction.reasons),
  ])
}

///|
fn layout_assist_mode_name(mode : LayoutAssistMode) -> String {
  match mode {
    LayoutAssistMode::ReportOnly => "report_only"
    LayoutAssistMode::Advisory => "advisory"
    LayoutAssistMode::GatedNormal => "gated_normal"
  }
}

///|
fn layout_assist_block_kind_name(kind : @pdfcore.PdfConvertBlockKind) -> String {
  match kind {
    @pdfcore.PdfConvertBlockKind::Heading => "heading"
    @pdfcore.PdfConvertBlockKind::Paragraph => "paragraph"
    @pdfcore.PdfConvertBlockKind::Noise => "noise"
  }
}

///|
fn take_layout_assist_predictions(
  predictions : Array[LayoutAssistPrediction],
  limit : Int,
) -> Array[LayoutAssistPrediction] {
  let out : Array[LayoutAssistPrediction] = []
  let capped = min_layout_assist_int(predictions.length(), limit)
  for i = 0; i < capped; i = i + 1 {
    out.push(predictions[i])
  }
  out
}

///|
fn min_layout_assist_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn double_opt_json(v : Double?) -> String {
  match v {
    Some(x) => x.to_string()
    None => "null"
  }
}

///|
fn pdf_images_section(model : @model.PdfDocumentModel) -> @cor.DebugSection {
  let filter_counts = Map([])
  let colorspace_counts = Map([])
  let mut image_count = 0
  let mut inline_image_count = 0
  let mut with_object_ref_count = 0
  let mut with_alt_text_count = 0

  for page in model.pages {
    for image in page.images {
      image_count += 1
      if image.inline_image {
        inline_image_count += 1
      }
      if image.object_ref is Some(_) {
        with_object_ref_count += 1
      }
      if image.alt_text is Some(_) {
        with_alt_text_count += 1
      }

      match image.image_filter {
        Some(name) => bump_string_count(filter_counts, name)
        None => bump_string_count(filter_counts, "None")
      }
      match image.colorspace {
        Some(name) => bump_string_count(colorspace_counts, name)
        None => bump_string_count(colorspace_counts, "None")
      }
    }
  }

  @cor.debug_section(
    "pdf_images",
    "pdf",
    true,
    Some("PDF image object summary"),
    @cor.object_json([
      @cor.json_string("image_count") + ": " + image_count.to_string(),
      @cor.json_string("inline_image_count") +
      ": " +
      inline_image_count.to_string(),
      @cor.json_string("with_object_ref_count") +
      ": " +
      with_object_ref_count.to_string(),
      @cor.json_string("with_alt_text_count") +
      ": " +
      with_alt_text_count.to_string(),
      @cor.json_string("image_filter_counts") +
      ": " +
      map_string_int_json(filter_counts),
      @cor.json_string("colorspace_counts") +
      ": " +
      map_string_int_json(colorspace_counts),
    ]),
  )
}

///|
fn pdf_annotations_section(
  model : @model.PdfDocumentModel,
) -> @cor.DebugSection {
  let subtype_counts = Map([])
  let mut annotation_count = 0
  let mut uri_count = 0
  let mut dest_count = 0
  let mut target_page_count = 0
  let mut object_ref_count = 0

  for page in model.pages {
    for annotation in page.annotations {
      annotation_count += 1
      bump_string_count(subtype_counts, annotation.subtype)
      if annotation.uri is Some(_) {
        uri_count += 1
      }
      if annotation.dest is Some(_) {
        dest_count += 1
      }
      if annotation.target_page is Some(_) {
        target_page_count += 1
      }
      if annotation.object_ref is Some(_) {
        object_ref_count += 1
      }
    }
  }

  @cor.debug_section(
    "pdf_annotations",
    "pdf",
    true,
    Some("PDF annotation object summary"),
    @cor.object_json([
      @cor.json_string("annotation_count") + ": " + annotation_count.to_string(),
      @cor.json_string("subtype_counts") +
      ": " +
      map_string_int_json(subtype_counts),
      @cor.json_string("uri_count") + ": " + uri_count.to_string(),
      @cor.json_string("dest_count") + ": " + dest_count.to_string(),
      @cor.json_string("target_page_count") +
      ": " +
      target_page_count.to_string(),
      @cor.json_string("object_ref_count") + ": " + object_ref_count.to_string(),
    ]),
  )
}

///|
fn pdf_links_section(doc : @pdfcore.PdfConvertDocument) -> @cor.DebugSection {
  let match_status_counts = Map([])
  let mut matched_link_count = 0
  let mut visible_text_total = 0

  for page in doc.pages {
    for result in @pdfcore.match_page_uri_links(page) {
      let status_name = pdf_uri_link_match_status_name(result.status)
      bump_string_count(match_status_counts, status_name)

      match result.status {
        @pdfcore.PdfUriLinkMatchStatus::Matched => matched_link_count += 1
        @pdfcore.PdfUriLinkMatchStatus::NoVisibleText => visible_text_total += 0
        _ => ()
      }

      visible_text_total += result.matched_line_count
    }
  }

  @cor.debug_section(
    "pdf_links",
    "pdf",
    true,
    Some("PDF URI-link matching summary"),
    @cor.object_json([
      @cor.json_string("match_status_counts") +
      ": " +
      map_string_int_json(match_status_counts),
      @cor.json_string("matched_link_count") +
      ": " +
      matched_link_count.to_string(),
      @cor.json_string("matched_line_total") +
      ": " +
      visible_text_total.to_string(),
    ]),
  )
}

///|
fn pdf_pipeline_section(
  doc1 : @pdfcore.PdfConvertDocument,
  doc2 : @pdfcore.PdfConvertDocument,
  doc3 : @pdfcore.PdfConvertDocument,
  doc4 : @pdfcore.PdfConvertDocument,
  doc5 : @pdfcore.PdfConvertDocument,
  max_heading : Int,
) -> @cor.DebugSection {
  let heading_status_counts = Map([])
  let heading_reason_counts = Map([])
  let noise_status_counts = Map([])
  let noise_reason_counts = Map([])
  let merge_status_counts = Map([])
  let merge_reason_counts = Map([])

  for page in doc1.pages {
    for i = 0; i < page.blocks.length(); i = i + 1 {
      let prev = if i > 0 { Some(page.blocks[i - 1]) } else { None }
      let next = if i + 1 < page.blocks.length() {
        Some(page.blocks[i + 1])
      } else {
        None
      }
      let decision = @pdfcore.decide_heading_classification(
        prev,
        page.blocks[i],
        next,
        max_heading,
      )
      bump_string_count(
        heading_status_counts,
        pdf_heading_decision_status_name(decision.status),
      )
      bump_reason_tags(heading_reason_counts, decision.reason_tags)
    }
  }

  let repeated = @pdfcore.build_repeated_edge_noise_index(doc2)
  for page in doc2.pages {
    for i = 0; i < page.blocks.length(); i = i + 1 {
      let block = page.blocks[i]
      let decision = @pdfcore.decide_noise_block(page, i, block, repeated)
      bump_string_count(
        noise_status_counts,
        pdf_noise_decision_status_name(decision.status),
      )
      bump_reason_tags(noise_reason_counts, decision.reason_tags)
    }
  }

  for i = 1; i < doc3.pages.length(); i = i + 1 {
    let decision = @pdfcore.decide_page_boundary_merge(
      doc3.pages[i - 1],
      doc3.pages[i],
    )
    bump_string_count(
      merge_status_counts,
      pdf_merge_decision_status_name(decision.status),
    )
    bump_reason_tags(merge_reason_counts, decision.reason_tags)
  }

  let mut table_candidate_count = 0
  let mut attached_image_caption_count = 0
  let mut image_count = 0
  let mut linked_block_count = 0
  for page in doc5.pages {
    table_candidate_count += @pdfcore.detect_pdf_tables(page, false).length()
    let (captions, _) = @pdfcore.infer_page_image_captions(page, false)
    image_count += page.images.length()
    for caption in captions {
      if caption is Some(_) {
        attached_image_caption_count += 1
      }
    }
    for block in page.blocks {
      if block.rich_inlines is Some(_) {
        linked_block_count += 1
      }
    }
  }

  @cor.debug_section(
    "pdf_pipeline",
    "pdf",
    true,
    Some("PDF convert-stage aggregate decision summary"),
    @cor.object_json([
      @cor.json_string("stage_counts") +
      ": " +
      @cor.object_json([
        @cor.json_string("convert_line_count") +
        ": " +
        convert_line_count(doc1).to_string(),
        @cor.json_string("initial_block_count") +
        ": " +
        convert_block_count(doc1).to_string(),
        @cor.json_string("classified_block_count") +
        ": " +
        convert_block_count(doc2).to_string(),
        @cor.json_string("noise_filtered_block_count") +
        ": " +
        convert_block_count(doc3).to_string(),
        @cor.json_string("merged_block_count") +
        ": " +
        convert_block_count(doc4).to_string(),
        @cor.json_string("linked_block_count") +
        ": " +
        linked_block_count.to_string(),
      ]),
      @cor.json_string("heading_status_counts") +
      ": " +
      map_string_int_json(heading_status_counts),
      @cor.json_string("heading_reason_counts") +
      ": " +
      map_string_int_json(heading_reason_counts),
      @cor.json_string("noise_status_counts") +
      ": " +
      map_string_int_json(noise_status_counts),
      @cor.json_string("noise_reason_counts") +
      ": " +
      map_string_int_json(noise_reason_counts),
      @cor.json_string("merge_status_counts") +
      ": " +
      map_string_int_json(merge_status_counts),
      @cor.json_string("merge_reason_counts") +
      ": " +
      map_string_int_json(merge_reason_counts),
      @cor.json_string("repeated_edge_summary") +
      ": " +
      @cor.object_json([
        @cor.json_string("repeated_head_count") +
        ": " +
        repeated.repeated_heads.length().to_string(),
        @cor.json_string("repeated_tail_count") +
        ": " +
        repeated.repeated_tails.length().to_string(),
        @cor.json_string("repeated_head_prefix_count") +
        ": " +
        repeated.repeated_head_prefixes.length().to_string(),
        @cor.json_string("repeated_tail_prefix_count") +
        ": " +
        repeated.repeated_tail_prefixes.length().to_string(),
      ]),
      @cor.json_string("table_candidate_count") +
      ": " +
      table_candidate_count.to_string(),
      @cor.json_string("image_count") + ": " + image_count.to_string(),
      @cor.json_string("attached_image_caption_count") +
      ": " +
      attached_image_caption_count.to_string(),
      @cor.json_string("image_without_caption_count") +
      ": " +
      (image_count - attached_image_caption_count).to_string(),
    ]),
  )
}

///|
fn convert_line_count(doc : @pdfcore.PdfConvertDocument) -> Int {
  let mut total = 0
  for page in doc.pages {
    total += page.lines.length()
  }
  total
}

///|
fn convert_block_count(doc : @pdfcore.PdfConvertDocument) -> Int {
  let mut total = 0
  for page in doc.pages {
    total += page.blocks.length()
  }
  total
}

///|
fn bump_reason_tags(counts : Map[String, Int], tags : Array[String]) -> Unit {
  for tag in tags {
    bump_string_count(counts, tag)
  }
}

///|
fn bump_string_count(counts : Map[String, Int], key : String) -> Unit {
  let prev = counts.get(key).unwrap_or(0)
  counts.set(key, prev + 1)
}

///|
fn map_string_int_json(counts : Map[String, Int]) -> String {
  @cor.string_int_kv_json(sorted_string_int_entries(counts))
}

///|
fn sorted_string_int_entries(counts : Map[String, Int]) -> Array[(String, Int)] {
  let keys : Array[String] = []
  for entry in counts {
    let (key, _) = entry
    keys.push(key)
  }
  keys.sort()

  let out : Array[(String, Int)] = []
  for key in keys {
    out.push((key, counts.get(key).unwrap_or(0)))
  }
  out
}

///|
fn pdf_rect_json(rect : @model.PdfRect) -> String {
  @cor.object_json([
    @cor.json_string("x0") + ": " + rect.x0.to_string(),
    @cor.json_string("y0") + ": " + rect.y0.to_string(),
    @cor.json_string("x1") + ": " + rect.x1.to_string(),
    @cor.json_string("y1") + ": " + rect.y1.to_string(),
  ])
}

///|
fn pdf_rect_opt_json(rect : @model.PdfRect?) -> String {
  match rect {
    Some(v) => pdf_rect_json(v)
    None => "null"
  }
}

///|
fn pdf_source_block_kind_name(kind : @model.PdfTextBlockKind) -> String {
  match kind {
    @model.PdfTextBlockKind::Text => "Text"
    @model.PdfTextBlockKind::HeadingCandidate => "HeadingCandidate"
    @model.PdfTextBlockKind::ListCandidate => "ListCandidate"
    @model.PdfTextBlockKind::CaptionCandidate => "CaptionCandidate"
    @model.PdfTextBlockKind::HeaderFooterCandidate => "HeaderFooterCandidate"
    @model.PdfTextBlockKind::TableCellCandidate => "TableCellCandidate"
    @model.PdfTextBlockKind::FormulaCandidate => "FormulaCandidate"
    @model.PdfTextBlockKind::Unknown => "Unknown"
  }
}

///|
fn pdf_writing_direction_name(dir : @model.PdfWritingDirection) -> String {
  match dir {
    @model.PdfWritingDirection::LeftToRight => "LeftToRight"
    @model.PdfWritingDirection::RightToLeft => "RightToLeft"
    @model.PdfWritingDirection::TopToBottom => "TopToBottom"
    @model.PdfWritingDirection::BottomToTop => "BottomToTop"
    @model.PdfWritingDirection::Unknown => "Unknown"
  }
}

///|
fn pdf_heading_decision_status_name(
  status : @pdfcore.PdfHeadingDecisionStatus,
) -> String {
  match status {
    @pdfcore.PdfHeadingDecisionStatus::PromoteHeading => "PromoteHeading"
    @pdfcore.PdfHeadingDecisionStatus::KeepHeading => "KeepHeading"
    @pdfcore.PdfHeadingDecisionStatus::DemoteToParagraph => "DemoteToParagraph"
    @pdfcore.PdfHeadingDecisionStatus::ToNoise => "ToNoise"
    @pdfcore.PdfHeadingDecisionStatus::KeepParagraph => "KeepParagraph"
    @pdfcore.PdfHeadingDecisionStatus::KeepNoise => "KeepNoise"
  }
}

///|
fn pdf_noise_decision_status_name(
  status : @pdfcore.PdfNoiseDecisionStatus,
) -> String {
  match status {
    @pdfcore.PdfNoiseDecisionStatus::Drop => "Drop"
    @pdfcore.PdfNoiseDecisionStatus::Keep => "Keep"
  }
}

///|
fn pdf_merge_decision_status_name(
  status : @pdfcore.PdfMergeDecisionStatus,
) -> String {
  match status {
    @pdfcore.PdfMergeDecisionStatus::Merge => "Merge"
    @pdfcore.PdfMergeDecisionStatus::KeepSplit => "KeepSplit"
  }
}

///|
fn pdf_uri_link_match_status_name(
  status : @pdfcore.PdfUriLinkMatchStatus,
) -> String {
  match status {
    @pdfcore.PdfUriLinkMatchStatus::Matched => "Matched"
    @pdfcore.PdfUriLinkMatchStatus::RejectedEmptyUri => "RejectedEmptyUri"
    @pdfcore.PdfUriLinkMatchStatus::RejectedUnsupportedScheme =>
      "RejectedUnsupportedScheme"
    @pdfcore.PdfUriLinkMatchStatus::RejectedDestOnly => "RejectedDestOnly"
    @pdfcore.PdfUriLinkMatchStatus::RejectedNoBbox => "RejectedNoBbox"
    @pdfcore.PdfUriLinkMatchStatus::RejectedNonLink => "RejectedNonLink"
    @pdfcore.PdfUriLinkMatchStatus::NoVisibleText => "NoVisibleText"
    @pdfcore.PdfUriLinkMatchStatus::Ambiguous => "Ambiguous"
    @pdfcore.PdfUriLinkMatchStatus::TooLarge => "TooLarge"
    @pdfcore.PdfUriLinkMatchStatus::OverlappingAnnotations =>
      "OverlappingAnnotations"
  }
}

///|
fn is_effectively_empty_pdf_doc(doc : @model.PdfDocumentModel) -> Bool {
  let mut signal_chars = 0

  for page in doc.pages {
    for block in page.text_blocks {
      let text = @model.block_text(block).trim().to_owned()
      if text == "" {
        continue
      }

      for ch in text.to_array() {
        if ch != ' ' && ch != '\t' && ch != '\n' && ch != '\r' {
          signal_chars += 1
          if signal_chars >= 24 {
            return false
          }
        }
      }
    }
  }

  true
}
