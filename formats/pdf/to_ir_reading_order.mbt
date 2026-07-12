///|
priv enum PdfNativeLoweringItem {
  Paragraph(PdfNativeLoweredParagraph)
  Table(@core.CoreBlock)
}

///|
priv struct PdfNativeLoweredParagraph {
  text : String
  source_ref : @core.SourceRef
  rich_inlines : Array[@core.CoreInline]?
  consumed_link_indexes : Array[Int]
}

///|
priv struct PdfNativePageLoweringPlan {
  items : Array[PdfNativeLoweringItem]
  consumed_link_indexes : Array[Int]
}

///|
priv struct PdfNativeLoweringPlan {
  page_plans : Array[PdfNativePageLoweringPlan]
  header_footer_removed_count : Int
  header_footer_removed_candidates : Array[String]
  header_footer_removed_source_refs : Array[String]
  table_reconstruction_table_count : Int
  table_reconstruction_skipped_count : Int
  table_reconstruction_skipped_reasons : Array[String]
  table_reconstruction_source_refs : Array[String]
  link_productized_count : Int
}

///|
fn pdf_native_lowering_plan(
  doc : PdfNativeDocument,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
  table_candidates : PdfNativeTableCandidateSummary,
  header_footer_filter_policy : @parser.PdfHeaderFooterFilterPolicy,
  table_reconstruction_policy : @parser.PdfTableReconstructionPolicy,
) -> PdfNativeLoweringPlan {
  let page_plans : Array[PdfNativePageLoweringPlan] = []
  let mut header_footer_removed_count = 0
  let header_footer_removed_candidates : Array[String] = []
  let header_footer_removed_source_refs : Array[String] = []
  let mut table_reconstruction_table_count = 0
  let mut table_reconstruction_skipped_count = 0
  let mut link_productized_count = 0
  let table_reconstruction_skipped_reasons : Array[String] = []
  let table_reconstruction_source_refs : Array[String] = []
  let removal_candidates = pdf_native_header_footer_removal_candidates(
    header_footer_candidates, header_footer_filter_policy,
  )
  let table_regions = pdf_native_table_region_candidates_from_summary(
    table_candidates, table_reconstruction_policy,
  )
  for page in doc.pages {
    let items : Array[PdfNativeLoweringItem] = []
    let consumed_link_indexes : Array[Int] = []
    let removed_block_indexes : Array[Int] = []
    let consumed_table_block_indexes : Array[Int] = []
    let page_table_regions = table_regions.filter(region => {
      region.page_no == page.geometry.page_no
    })
    for text_block_index in 0..<page.text_blocks.length() {
      let block_index = text_block_index + 1
      let text_block = page.text_blocks[text_block_index]
      if pdf_native_should_remove_text_block(
          page, text_block, block_index, removal_candidates,
        ) {
        removed_block_indexes.push(block_index)
        header_footer_removed_count += 1
        let paragraph = pdf_native_lowered_paragraph(
          page, text_block, block_index,
        )
        match paragraph {
          Some(paragraph) => {
            header_footer_removed_candidates.push(paragraph.text)
            header_footer_removed_source_refs.push(
              pdf_native_source_ref_metric_string(paragraph.source_ref),
            )
          }
          None => ()
        }
        continue
      }
      let paragraph = pdf_native_lowered_paragraph(
        page, text_block, block_index,
      )
      match paragraph {
        Some(paragraph) =>
          match
            pdf_native_matching_table_region(
              page,
              text_block,
              block_index,
              paragraph.source_ref,
              page_table_regions,
            ) {
            Some(region) =>
              if !consumed_table_block_indexes.contains(block_index) {
                let table_result = pdf_native_table_block_from_region(
                  page,
                  region,
                  page.text_blocks,
                )
                match table_result {
                  PdfNativeTableLoweringResult::Lowered(
                    table_block,
                    block_indexes,
                    source_ref_metric
                  ) => {
                    items.push(PdfNativeLoweringItem::Table(table_block))
                    table_reconstruction_table_count += 1
                    table_reconstruction_source_refs.push(source_ref_metric)
                    for lowered_block_index in block_indexes {
                      if !consumed_table_block_indexes.contains(
                          lowered_block_index,
                        ) {
                        consumed_table_block_indexes.push(lowered_block_index)
                      }
                    }
                  }
                  PdfNativeTableLoweringResult::Skipped(reason) => {
                    table_reconstruction_skipped_count += 1
                    table_reconstruction_skipped_reasons.push(reason)
                    items.push(PdfNativeLoweringItem::Paragraph(paragraph))
                    for link_index in paragraph.consumed_link_indexes {
                      if !consumed_link_indexes.contains(link_index) {
                        consumed_link_indexes.push(link_index)
                        link_productized_count += 1
                      }
                    }
                  }
                }
              }
            None => {
              items.push(PdfNativeLoweringItem::Paragraph(paragraph))
              for link_index in paragraph.consumed_link_indexes {
                if !consumed_link_indexes.contains(link_index) {
                  consumed_link_indexes.push(link_index)
                  link_productized_count += 1
                }
              }
            }
          }
        None => ()
      }
    }
    page_plans.push({ items, consumed_link_indexes })
  }
  {
    page_plans,
    header_footer_removed_count,
    header_footer_removed_candidates,
    header_footer_removed_source_refs,
    table_reconstruction_table_count,
    table_reconstruction_skipped_count,
    table_reconstruction_skipped_reasons,
    table_reconstruction_source_refs,
    link_productized_count,
  }
}

///|
fn pdf_native_page_blocks(
  page : PdfNativePage,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
  header_footer_filter_policy : @parser.PdfHeaderFooterFilterPolicy,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  let removal_candidates = pdf_native_header_footer_removal_candidates(
    header_footer_candidates, header_footer_filter_policy,
  )
  for text_block_index in 0..<page.text_blocks.length() {
    let block_index = text_block_index + 1
    let text_block = page.text_blocks[text_block_index]
    let merge_group = "page:" +
      page.geometry.page_no.to_string() +
      ":block:" +
      block_index.to_string()
    for line_index in 0..<text_block.lines.length() {
      let line = text_block.lines[line_index]
      let text = pdf_native_line_text(line)
      if text == "" {
        continue
      }
      let source_ref = pdf_native_line_candidate_source_ref(
        page, text_block, block_index, line, line_index, merge_group,
      )
      let paragraph = @core.make_block(
        @core.BlockKind::Paragraph,
        text,
        source_ref~,
      )
      if pdf_native_should_remove_text_block(
          page, text_block, block_index, removal_candidates,
        ) {
        paragraph.signals.push(
          @core.make_signal(@core.SignalType::HeaderFooterCandidate, 95),
        )
      }
      blocks.push(paragraph)
    }
  }
  blocks
}

///|
priv struct PdfNativeHeaderFooterRemovalCandidate {
  kind : String
  normalized_text : String
  pages : Array[Int]
  bbox : PdfBBox
}

///|
fn pdf_native_header_footer_removal_candidates(
  summary : PdfNativeHeaderFooterCandidateSummary,
  policy : @parser.PdfHeaderFooterFilterPolicy,
) -> Array[PdfNativeHeaderFooterRemovalCandidate] {
  if policy != @parser.PdfHeaderFooterFilterPolicy::InternalHighConfidenceOnly {
    return []
  }
  let candidates : Array[PdfNativeHeaderFooterRemovalCandidate] = []
  for item in summary.candidates {
    match item {
      @core.JsonValue::Object(payload) => {
        if payload.get("confidence") != Some(@core.JsonValue::String("high")) {
          continue
        }
        let kind = match payload.get("kind") {
          Some(@core.JsonValue::String(value)) => value
          _ => continue
        }
        let normalized_text = match payload.get("normalized_text") {
          Some(@core.JsonValue::String(value)) => value
          _ => continue
        }
        let page_count = match payload.get("page_count") {
          Some(@core.JsonValue::Number(value)) =>
            @string.parse_int(value) catch {
              _ => 0
            }
          _ => 0
        }
        if page_count < 2 {
          continue
        }
        let bbox = match payload.get("bbox") {
          Some(@core.JsonValue::Object(bbox)) =>
            pdf_native_bbox_from_json_object(bbox)
          _ => None
        }
        let pages = match payload.get("pages") {
          Some(@core.JsonValue::Array(values)) =>
            values
            .map(item => {
              match item {
                @core.JsonValue::Number(value) =>
                  @string.parse_int(value) catch {
                    _ => -1
                  }
                _ => -1
              }
            })
            .filter(page => page > 0)
          _ => []
        }
        match bbox {
          Some(candidate_bbox) =>
            candidates.push({
              kind,
              normalized_text,
              pages,
              bbox: candidate_bbox,
            })
          None => ()
        }
      }
      _ => ()
    }
  }
  candidates
}

///|
fn pdf_native_parse_json_double(value : String) -> Double? {
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    return None
  }
  Some(@string.parse_double(trimmed) catch { _ => return None })
}

///|
fn pdf_native_bbox_from_json_object(
  payload : Map[String, @core.JsonValue],
) -> PdfBBox? {
  let x = match payload.get("x") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  let y = match payload.get("y") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  let width = match payload.get("width") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  let height = match payload.get("height") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  Some(make_pdf_bbox(x, y, width, height))
}

///|
priv enum PdfNativeTableLoweringResult {
  Lowered(@core.CoreBlock, Array[Int], String)
  Skipped(String)
}

///|
priv struct PdfNativeTableCellLowering {
  text : String
  rich_inlines : Array[@core.CoreInline]?
}

///|
fn pdf_native_projection_diagnostics(
  diagnostics : @core.Diagnostics,
  block_count : Int,
  paragraph_count : Int,
  link_count : Int,
  annotation_count : Int,
  form_field_count : Int,
  outline_count : Int,
  destination_count : Int,
  page_count : Int,
  image_count : Int,
  asset_count : Int,
  image_candidate_count : Int,
  table_candidate_count : Int,
  artifact_candidate_count : Int,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
  table_candidates : PdfNativeTableCandidateSummary,
  lowering : PdfNativeLoweringPlan,
) -> @core.Diagnostics {
  let next = { ..diagnostics }
  next.pass_trace.push("pdf_native:to_document_ir")
  next.metrics.set("ir_input_kind", "document")
  next.metrics.set("block_count", block_count.to_string())
  next.metrics.set("paragraph_count", paragraph_count.to_string())
  next.metrics.set(
    "table_count",
    lowering.table_reconstruction_table_count.to_string(),
  )
  next.metrics.set("image_count", image_count.to_string())
  next.metrics.set("asset_count", asset_count.to_string())
  next.metrics.set("signal_count", "0")
  next.metrics.set("page_count", page_count.to_string())
  next.metrics.set("link_count", link_count.to_string())
  next.metrics.set("pdf_link_candidate_count", link_count.to_string())
  next.metrics.set(
    "pdf_link_productized_count",
    lowering.link_productized_count.to_string(),
  )
  next.metrics.set("pdf_native_annotation_count", annotation_count.to_string())
  next.metrics.set("pdf_native_form_field_count", form_field_count.to_string())
  next.metrics.set("pdf_native_outline_count", outline_count.to_string())
  next.metrics.set(
    "pdf_native_destination_count",
    destination_count.to_string(),
  )
  next.metrics.set("pdf_grouping_strategy", "conservative_v1")
  next.metrics.set("pdf_grouping_paragraph_count", paragraph_count.to_string())
  next.metrics.set(
    "pdf_header_footer_candidate_strategy",
    header_footer_candidates.strategy,
  )
  next.metrics.set(
    "pdf_header_candidate_count",
    header_footer_candidates.header_count.to_string(),
  )
  next.metrics.set(
    "pdf_footer_candidate_count",
    header_footer_candidates.footer_count.to_string(),
  )
  next.metrics.set(
    "pdf_header_footer_candidate_count",
    header_footer_candidates.candidates.length().to_string(),
  )
  next.metrics.set("pdf_table_candidate_strategy", table_candidates.strategy)
  next.metrics.set(
    "pdf_table_candidate_count",
    table_candidates.candidates.length().to_string(),
  )
  next.metrics.set(
    "pdf_table_row_candidate_count",
    table_candidates.row_count.to_string(),
  )
  next.metrics.set("image_candidate_count", image_candidate_count.to_string())
  next.metrics.set("table_candidate_count", table_candidate_count.to_string())
  next.metrics.set(
    "artifact_candidate_count",
    artifact_candidate_count.to_string(),
  )
  next.metrics.set("pdf_native_ir_projection", "unit_path")
  next.metrics.set("product_path_enabled", "false")
  next.metrics.set(
    "pdf_header_footer_removed_count",
    lowering.header_footer_removed_count.to_string(),
  )
  if lowering.header_footer_removed_candidates.length() > 0 {
    next.metrics.set(
      "pdf_header_footer_removed_candidates",
      lowering.header_footer_removed_candidates.join(" || "),
    )
  }
  if lowering.header_footer_removed_source_refs.length() > 0 {
    next.metrics.set(
      "pdf_header_footer_removed_source_refs",
      lowering.header_footer_removed_source_refs.join(" || "),
    )
  }
  next.metrics.set(
    "pdf_table_reconstruction_table_count",
    lowering.table_reconstruction_table_count.to_string(),
  )
  next.metrics.set(
    "pdf_table_reconstruction_skipped_count",
    lowering.table_reconstruction_skipped_count.to_string(),
  )
  if lowering.table_reconstruction_skipped_reasons.length() > 0 {
    next.metrics.set(
      "pdf_table_reconstruction_skipped_reasons",
      lowering.table_reconstruction_skipped_reasons.join(" || "),
    )
  }
  if lowering.table_reconstruction_source_refs.length() > 0 {
    next.metrics.set(
      "pdf_table_reconstruction_source_refs",
      lowering.table_reconstruction_source_refs.join(" || "),
    )
  }
  match header_footer_candidates.skipped_reason {
    Some(reason) =>
      next.metrics.set("pdf_header_footer_candidate_skipped", reason)
    None => ()
  }
  match table_candidates.skipped_reason {
    Some(reason) => next.metrics.set("pdf_table_candidate_skipped", reason)
    None => ()
  }
  if link_count > 0 {
    next.degraded_features.push("pdf_link_candidates_metadata_only")
    next.fallback_trace.push(
      "pdf native link annotations preserved as metadata only in unit-path bridge",
    )
  }
  if annotation_count > 0 {
    next.degraded_features.push("pdf_annotation_candidates_metadata_only")
  }
  if form_field_count > 0 {
    next.degraded_features.push("pdf_form_field_candidates_metadata_only")
  }
  if outline_count > 0 {
    next.degraded_features.push("pdf_outline_candidates_metadata_only")
  }
  if destination_count > 0 {
    next.degraded_features.push("pdf_destination_candidates_metadata_only")
  }
  if image_count < image_candidate_count {
    next.degraded_features.push("pdf_image_candidates_not_lowered")
  }
  if table_candidate_count > 0 {
    if lowering.table_reconstruction_table_count <
      table_candidates.candidates.length() {
      next.degraded_features.push("pdf_table_candidates_not_lowered")
    }
  }
  if artifact_candidate_count > 0 {
    next.degraded_features.push("pdf_artifact_candidates_not_lowered")
  }
  next
}

///|
fn pdf_native_stream_bridge_diagnostics(
  diagnostics : @core.Diagnostics,
  block_count : Int,
  paragraph_count : Int,
  link_count : Int,
  annotation_count : Int,
  form_field_count : Int,
  outline_count : Int,
  destination_count : Int,
  page_count : Int,
  image_candidate_count : Int,
  table_candidate_count : Int,
  artifact_candidate_count : Int,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
  table_candidates : PdfNativeTableCandidateSummary,
) -> @core.Diagnostics {
  let next = { ..diagnostics }
  next.pass_trace.push("pdf_native:to_block_stream")
  next.metrics.set("ir_input_kind", "block_stream")
  next.metrics.set("block_count", block_count.to_string())
  next.metrics.set("paragraph_count", paragraph_count.to_string())
  next.metrics.set("table_count", "0")
  next.metrics.set("asset_count", "0")
  next.metrics.set("signal_count", "0")
  next.metrics.set("page_count", page_count.to_string())
  next.metrics.set("link_count", link_count.to_string())
  next.metrics.set("pdf_link_candidate_count", link_count.to_string())
  next.metrics.set("pdf_native_annotation_count", annotation_count.to_string())
  next.metrics.set("pdf_native_form_field_count", form_field_count.to_string())
  next.metrics.set("pdf_native_outline_count", outline_count.to_string())
  next.metrics.set(
    "pdf_native_destination_count",
    destination_count.to_string(),
  )
  next.metrics.set("pdf_grouping_strategy", "conservative_v1")
  next.metrics.set("pdf_grouping_paragraph_count", paragraph_count.to_string())
  next.metrics.set(
    "pdf_header_footer_candidate_strategy",
    header_footer_candidates.strategy,
  )
  next.metrics.set(
    "pdf_header_candidate_count",
    header_footer_candidates.header_count.to_string(),
  )
  next.metrics.set(
    "pdf_footer_candidate_count",
    header_footer_candidates.footer_count.to_string(),
  )
  next.metrics.set(
    "pdf_header_footer_candidate_count",
    header_footer_candidates.candidates.length().to_string(),
  )
  next.metrics.set("pdf_table_candidate_strategy", table_candidates.strategy)
  next.metrics.set(
    "pdf_table_candidate_count",
    table_candidates.candidates.length().to_string(),
  )
  next.metrics.set(
    "pdf_table_row_candidate_count",
    table_candidates.row_count.to_string(),
  )
  next.metrics.set("image_candidate_count", image_candidate_count.to_string())
  next.metrics.set("table_candidate_count", table_candidate_count.to_string())
  next.metrics.set(
    "artifact_candidate_count",
    artifact_candidate_count.to_string(),
  )
  next.metrics.set("pdf_native_ir_projection", "product_block_stream")
  next.metrics.set("product_path_enabled", "true")
  next.metrics.set("pdf_header_footer_removed_count", "0")
  next.metrics.set("pdf_table_reconstruction_table_count", "0")
  next.metrics.set("pdf_table_reconstruction_skipped_count", "0")
  match header_footer_candidates.skipped_reason {
    Some(reason) =>
      next.metrics.set("pdf_header_footer_candidate_skipped", reason)
    None => ()
  }
  match table_candidates.skipped_reason {
    Some(reason) => next.metrics.set("pdf_table_candidate_skipped", reason)
    None => ()
  }
  if link_count > 0 {
    next.degraded_features.push("pdf_link_candidates_metadata_only")
    next.fallback_trace.push(
      "pdf native link annotations preserved as metadata only in product block stream",
    )
  }
  if annotation_count > 0 {
    next.degraded_features.push("pdf_annotation_candidates_metadata_only")
  }
  if form_field_count > 0 {
    next.degraded_features.push("pdf_form_field_candidates_metadata_only")
  }
  if outline_count > 0 {
    next.degraded_features.push("pdf_outline_candidates_metadata_only")
  }
  if destination_count > 0 {
    next.degraded_features.push("pdf_destination_candidates_metadata_only")
  }
  if image_candidate_count > 0 {
    next.degraded_features.push("pdf_image_candidates_not_lowered")
  }
  if table_candidate_count > 0 {
    next.degraded_features.push("pdf_table_candidates_not_lowered")
  }
  if artifact_candidate_count > 0 {
    next.degraded_features.push("pdf_artifact_candidates_not_lowered")
  }
  next
}

///|
fn pdf_native_line_text(line : PdfNativeTextLine) -> String {
  line.spans.map(span => span.text).join("").trim().to_owned()
}
