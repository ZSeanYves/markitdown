///|
const PDF_NATIVE_PARSER_NAME : String = "pdf_native_parser"

///|
const PDF_NATIVE_FAIL_CLOSED_MESSAGE : String = "PDF native text restore is disabled by parser policy"

///|
const PDF_OCR_PARSER_NAME : String = "pdf_accurate_layout_parser"

///|
type PdfNativeError = @dpdfnative.PdfNativeError

///|
fn extract_pdf_native_document(
  source : @input.InputSource,
) -> Result[@dpdfnative.PdfNativeDocument, PdfNativeError] {
  @dpdfnative.extract_pdf_native_document(source)
}

///|
/// Stable parser name for the native-text PDF route.
pub fn pdf_native_parser_name() -> String {
  PDF_NATIVE_PARSER_NAME
}

///|
/// Fail-closed message emitted when native-text restore is intentionally gated
/// off.
pub fn pdf_native_fail_closed_message() -> String {
  PDF_NATIVE_FAIL_CLOSED_MESSAGE
}

///|
/// Stable parser name for the OCR-backed PDF route.
pub fn pdf_ocr_parser_name() -> String {
  PDF_OCR_PARSER_NAME
}

///|
/// Capability for the native-text PDF route.
pub fn pdf_native_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::PageSinglePass,
    false,
    @parser.StreamingGranularity::Page,
    true,
    true,
    false,
    false,
    false,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
/// Capability for the OCR-backed PDF route.
pub fn pdf_ocr_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::LayoutTwoStage,
    false,
    @parser.StreamingGranularity::Page,
    true,
    false,
    false,
    false,
    false,
    true,
    false,
    true,
    true,
    false,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
priv struct PdfOcrExecutionConfig {
  provider_target : @focr.OcrProviderSelectionTarget
  provider_kind : @focr.OcrProviderKind
}

///|
priv struct PdfOcrAccumulationState {
  blocks : Array[@core.CoreBlock]
  warnings : Array[String]
  fatal_dependency_errors : Array[String]
  fatal_dependency_diagnostics : Array[@core.DependencyDiagnostic]
  raster_failure_count : Ref[Int]
  ocr_failure_count : Ref[Int]
  ocr_success_count : Ref[Int]
  native_text_page_count : Ref[Int]
}

///|
priv struct PdfPageRoute {
  page_index : Int
  route_kind : String
  candidate_regions : Array[@core.BBox]
  low_confidence_text_count : Int
  native_text_detected : Bool
}

///|
priv struct PdfOcrExecutionStats {
  page_count : Int
  native_page_count : Int
  native_detected_page_count : Int
  ocr_page_count : Int
  hybrid_region_page_count : Int
  region_hybrid_candidate_count : Int
  native_low_confidence_text_count : Int
  raster_invoked : Bool
  rasterized_page_count : Int
  raster_page_success_count : Int
  ocr_batch_job_count : Int
  ocr_process_invocation_count : Int
  ocr_batch_mode : Bool
  page_route_hybrid_used : Bool
  page_route_summary : String
  provider_name : String?
  provider_version : String?
  pdf_raster_wall_ms : UInt64
  ocr_provider_wall_ms : UInt64
  external_process_invocation_count : Int
  external_process_kind : String
  external_process_wall_ms : UInt64
}

///|
fn pdf_ocr_execution_config(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[PdfOcrExecutionConfig, String] {
  ignore(source)
  let provider_target = @focr.OcrProviderSelectionTarget::PdfAccurate
  let provider_kind = @focr.resolved_ocr_provider_kind_for_target(
    provider_target,
  )
  if context.fidelity_mode != @product.FidelityMode::Accurate {
    return Err(
      "PDF accurate layout parsing requires accurate fidelity mode on this runtime",
    )
  }
  Ok({ provider_target, provider_kind })
}

///|
fn pdf_ocr_accumulation_state() -> PdfOcrAccumulationState {
  {
    blocks: [],
    warnings: [],
    fatal_dependency_errors: [],
    fatal_dependency_diagnostics: [],
    raster_failure_count: { val: 0 },
    ocr_failure_count: { val: 0 },
    ocr_success_count: { val: 0 },
    native_text_page_count: { val: 0 },
  }
}

///|
fn pdf_ocr_record_raster_failure(
  state : PdfOcrAccumulationState,
  warning : String,
) -> Unit {
  state.raster_failure_count.val = state.raster_failure_count.val + 1
  state.warnings.push(warning)
}

///|
fn pdf_ocr_record_empty_provider_result(
  state : PdfOcrAccumulationState,
  page_index : Int,
) -> Unit {
  state.ocr_failure_count.val = state.ocr_failure_count.val + 1
  state.warnings.push("pdf_ocr_page_empty:index=" + page_index.to_string())
}

///|
fn pdf_ocr_empty_result_error(state : PdfOcrAccumulationState) -> String {
  if state.fatal_dependency_errors.length() > 0 {
    state.fatal_dependency_errors[0]
  } else {
    "PDF OCR produced no successful pages on this runtime. " +
    pdf_raster_backend_install_hint()
  }
}

///|
fn pdf_ocr_provider_batch_request(
  image_paths : Array[String],
  provider_kind : @focr.OcrProviderKind,
  language : String?,
) -> @focr.OcrProviderRequest {
  @focr.make_ocr_provider_batch_request(image_paths, provider_kind, language~)
}

///|
fn pdf_native_page_has_text(page : @dpdfnative.PdfNativePage) -> Bool {
  for block in page.text_blocks {
    for line in block.lines {
      if line.spans.length() > 0 {
        return true
      }
    }
  }
  false
}

///|
fn pdf_block_page_number(block : @core.CoreBlock) -> Int? {
  match block.source_ref {
    Some(source_ref) => source_ref.page
    None => None
  }
}

///|
fn pdf_blocks_for_page(
  blocks : Array[@core.CoreBlock],
  page_number : Int,
) -> Array[@core.CoreBlock] {
  let filtered : Array[@core.CoreBlock] = []
  for block in blocks {
    if pdf_block_page_number(block) == Some(page_number) {
      filtered.push(block)
    }
  }
  filtered
}

///|
fn pdf_blocks_without_page_number(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let filtered : Array[@core.CoreBlock] = []
  for block in blocks {
    if pdf_block_page_number(block) == None {
      filtered.push(block)
    }
  }
  filtered
}

///|
fn pdf_non_paragraph_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let filtered : Array[@core.CoreBlock] = []
  for block in blocks {
    if block.kind != @core.BlockKind::Paragraph {
      filtered.push(block)
    }
  }
  filtered
}

///|
fn pdf_ocr_page_blocks_with_native_facts(
  native_blocks : Array[@core.CoreBlock],
  ocr_blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let merged : Array[@core.CoreBlock] = []
  merged.append(pdf_non_paragraph_blocks(native_blocks)[:])
  merged.append(ocr_blocks[:])
  merged.sort_by(pdf_core_block_order_compare)
  merged
}

///|
fn pdf_document_has_native_facts(document : @core.DocumentIR) -> Bool {
  document.blocks.length() > 0 ||
  document.assets.length() > 0 ||
  document.metadata.length() > 0 ||
  document.signals.length() > 0 ||
  document.source_map is Some(_) ||
  document.assembly is Some(_)
}

///|
fn pdf_document_block_kind_count(
  blocks : Array[@core.CoreBlock],
  kind : @core.BlockKind,
) -> Int {
  let mut count = 0
  for block in blocks {
    if block.kind == kind {
      count += 1
    }
    count += pdf_document_block_kind_count(block.children, kind)
  }
  count
}

///|
fn pdf_append_unique_strings(
  target : Array[String],
  values : Array[String],
) -> Unit {
  for value in values {
    if !target.contains(value) {
      target.push(value)
    }
  }
}

///|
fn pdf_ocr_merge_native_diagnostics(
  diagnostics : @core.Diagnostics,
  native_diagnostics : @core.Diagnostics,
) -> @core.Diagnostics {
  let next = { ..diagnostics }
  pdf_append_unique_strings(next.warnings, native_diagnostics.warnings)
  pdf_append_unique_strings(next.errors, native_diagnostics.errors)
  pdf_append_unique_strings(
    next.degraded_features,
    native_diagnostics.degraded_features,
  )
  pdf_append_unique_strings(
    next.fallback_trace,
    native_diagnostics.fallback_trace,
  )
  pdf_append_unique_strings(next.pass_trace, native_diagnostics.pass_trace)
  next.dependency_diagnostics.append(
    native_diagnostics.dependency_diagnostics[:],
  )
  next
}

///|
fn pdf_ocr_inherit_native_metric(
  diagnostics : @core.Diagnostics,
  native_diagnostics : @core.Diagnostics,
  key : String,
) -> Unit {
  match native_diagnostics.metrics.get(key) {
    Some(value) => diagnostics.metrics.set(key, value)
    None => ()
  }
}

///|
fn pdf_ocr_inherit_native_projection_metrics(
  diagnostics : @core.Diagnostics,
  native_diagnostics : @core.Diagnostics,
) -> Unit {
  for
    key in [
      "paragraph_count", "link_count", "pdf_link_candidate_count", "pdf_link_productized_count",
      "pdf_native_annotation_count", "pdf_native_form_field_count", "pdf_native_outline_count",
      "pdf_native_destination_count", "pdf_grouping_strategy", "pdf_grouping_paragraph_count",
      "pdf_header_footer_candidate_strategy", "pdf_header_candidate_count", "pdf_footer_candidate_count",
      "pdf_header_footer_candidate_count", "pdf_table_candidate_strategy", "pdf_table_candidate_count",
      "pdf_table_row_candidate_count", "image_candidate_count", "table_candidate_count",
      "artifact_candidate_count", "pdf_native_ir_projection", "pdf_header_footer_removed_count",
      "pdf_header_footer_removed_candidates", "pdf_header_footer_removed_source_refs",
      "pdf_table_reconstruction_table_count", "pdf_table_reconstruction_skipped_count",
      "pdf_table_reconstruction_skipped_reasons", "pdf_table_reconstruction_source_refs",
      "pdf_header_footer_candidate_skipped", "pdf_table_candidate_skipped",
    ] {
    pdf_ocr_inherit_native_metric(diagnostics, native_diagnostics, key)
  }
}

///|
fn pdf_native_text_line_text(line : @dpdfnative.PdfNativeTextLine) -> String {
  let parts : Array[String] = []
  for span in line.spans {
    if span.text != "" {
      parts.push(span.text)
    }
  }
  parts.join("")
}

///|
fn pdf_native_text_block_text(block : @dpdfnative.PdfNativeTextBlock) -> String {
  let parts : Array[String] = []
  for line in block.lines {
    let text = pdf_native_text_line_text(line).trim().to_owned()
    if text != "" {
      parts.push(text)
    }
  }
  parts.join(" ")
}

///|
fn pdf_core_bbox_from_pdf_bbox(bbox : @dpdfnative.PdfBBox) -> @core.BBox {
  { x0: bbox.x, y0: bbox.y, x1: bbox.x + bbox.width, y1: bbox.y + bbox.height }
}

///|
fn pdf_bbox_width(bbox : @core.BBox) -> Double {
  bbox.x1 - bbox.x0
}

///|
fn pdf_bbox_height(bbox : @core.BBox) -> Double {
  bbox.y1 - bbox.y0
}

///|
fn pdf_bbox_area(bbox : @core.BBox) -> Double {
  let width = pdf_bbox_width(bbox)
  let height = pdf_bbox_height(bbox)
  if width <= 0.0 || height <= 0.0 {
    0.0
  } else {
    width * height
  }
}

///|
fn pdf_bbox_intersection_area(left : @core.BBox, right : @core.BBox) -> Double {
  let x0 = if left.x0 > right.x0 { left.x0 } else { right.x0 }
  let y0 = if left.y0 > right.y0 { left.y0 } else { right.y0 }
  let x1 = if left.x1 < right.x1 { left.x1 } else { right.x1 }
  let y1 = if left.y1 < right.y1 { left.y1 } else { right.y1 }
  let width = x1 - x0
  let height = y1 - y0
  if width <= 0.0 || height <= 0.0 {
    0.0
  } else {
    width * height
  }
}

///|
fn pdf_bboxes_overlap(left : @core.BBox, right : @core.BBox) -> Bool {
  pdf_bbox_intersection_area(left, right) > 0.0
}

///|
fn pdf_block_bbox(block : @core.CoreBlock) -> @core.BBox? {
  match block.source_ref {
    Some(source_ref) => source_ref.bbox
    None => None
  }
}

///|
fn pdf_normalized_text_for_dedupe(text : String) -> String {
  let parts : Array[String] = []
  let mut current : Array[Char] = []
  for ch in text.to_array() {
    if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
      if current.length() > 0 {
        parts.push(String::from_array(current))
        current = []
      }
    } else {
      current.push(pdf_ascii_lower_char(ch))
    }
  }
  if current.length() > 0 {
    parts.push(String::from_array(current))
  }
  parts.join(" ")
}

///|
fn pdf_ascii_lower_char(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    Int::unsafe_to_char(ch.to_int() + 32)
  } else {
    ch
  }
}

///|
fn pdf_is_control_or_noncharacter(code : Int) -> Bool {
  code == 0 ||
  (
    code < 0x20 &&
    code != '\t'.to_int() &&
    code != '\n'.to_int() &&
    code != '\r'.to_int()
  ) ||
  (code >= 0xFDD0 && code <= 0xFDEF) ||
  (code & 0xFFFE) == 0xFFFE
}

///|
fn pdf_is_private_use_codepoint(code : Int) -> Bool {
  (code >= 0xE000 && code <= 0xF8FF) ||
  (code >= 0xF0000 && code <= 0xFFFFD) ||
  (code >= 0x100000 && code <= 0x10FFFD)
}

///|
fn pdf_is_cjk_or_kana_codepoint(code : Int) -> Bool {
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0x3040 && code <= 0x30FF) ||
  (code >= 0x31F0 && code <= 0x31FF) ||
  (code >= 0xAC00 && code <= 0xD7AF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn pdf_is_combining_mark(code : Int) -> Bool {
  (code >= 0x0300 && code <= 0x036F) ||
  (code >= 0x1AB0 && code <= 0x1AFF) ||
  (code >= 0x1DC0 && code <= 0x1DFF) ||
  (code >= 0x20D0 && code <= 0x20FF) ||
  (code >= 0xFE20 && code <= 0xFE2F)
}

///|
fn pdf_is_latin1_supplement_letter(code : Int) -> Bool {
  (code >= 0x00C0 && code <= 0x00FF) && code != 0x00D7 && code != 0x00F7
}

///|
fn pdf_text_is_low_confidence(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let chars = trimmed.to_array()
  let mut suspicious = 0
  let mut latin1_letters = 0
  let mut visible = 0
  let mut cjk_like = 0
  for ch in chars {
    let code = ch.to_int()
    if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
      continue
    }
    visible += 1
    if pdf_is_cjk_or_kana_codepoint(code) {
      cjk_like += 1
      continue
    }
    if pdf_is_control_or_noncharacter(code) ||
      pdf_is_private_use_codepoint(code) ||
      pdf_is_combining_mark(code) {
      suspicious += 1
    }
    if pdf_is_latin1_supplement_letter(code) {
      latin1_letters += 1
    }
  }
  if visible == 0 {
    return false
  }
  suspicious > 0 ||
  (latin1_letters >= 3 && latin1_letters * 10 >= visible * 4 && cjk_like == 0)
}

///|
fn pdf_native_page_low_confidence_text_count(
  page : @dpdfnative.PdfNativePage,
) -> Int {
  let mut count = 0
  for block in page.text_blocks {
    if pdf_text_is_low_confidence(pdf_native_text_block_text(block)) {
      count += 1
    }
  }
  count
}

///|
fn pdf_native_page_text_bbox_area(page : @dpdfnative.PdfNativePage) -> Double {
  let mut total = 0.0
  for block in page.text_blocks {
    total += pdf_bbox_area(pdf_core_bbox_from_pdf_bbox(block.bbox))
  }
  total
}

///|
fn pdf_native_page_region_hybrid_candidates(
  page : @dpdfnative.PdfNativePage,
  low_confidence_text_count : Int,
) -> Array[@core.BBox] {
  let candidates : Array[@core.BBox] = []
  let page_area = page.geometry.width * page.geometry.height
  if page_area <= 0.0 {
    return candidates
  }
  let text_area = pdf_native_page_text_bbox_area(page)
  let mut total_image_area = 0.0
  for image in page.image_candidates {
    let bbox = pdf_core_bbox_from_pdf_bbox(image.bbox)
    let area = pdf_bbox_area(bbox)
    total_image_area += area
    let large_area = area >= page_area * 0.12
    let large_region = pdf_bbox_width(bbox) >= page.geometry.width * 0.35 &&
      pdf_bbox_height(bbox) >= page.geometry.height * 0.18
    let image_dominant = total_image_area >= text_area * 1.5 &&
      total_image_area >= page_area * 0.08
    if large_area ||
      large_region ||
      (low_confidence_text_count > 0 && image_dominant) {
      candidates.push(bbox)
    }
  }
  candidates
}

///|
fn pdf_page_route_uses_ocr(route : PdfPageRoute) -> Bool {
  route.route_kind == "ocr_page" || route.route_kind == "hybrid_region_page"
}

///|
fn pdf_page_route_uses_native_text(route : PdfPageRoute) -> Bool {
  route.route_kind == "native_text_page" ||
  route.route_kind == "hybrid_region_page"
}

///|
fn pdf_page_route_native_detected(route : PdfPageRoute) -> Bool {
  route.native_text_detected
}

///|
fn pdf_page_route_total_candidate_count(
  page_routes : Array[PdfPageRoute],
) -> Int {
  let mut count = 0
  for route in page_routes {
    count += route.candidate_regions.length()
  }
  count
}

///|
fn pdf_page_route_total_low_confidence_count(
  page_routes : Array[PdfPageRoute],
) -> Int {
  let mut count = 0
  for route in page_routes {
    count += route.low_confidence_text_count
  }
  count
}

///|
fn pdf_page_route_native_detected_count(
  page_routes : Array[PdfPageRoute],
) -> Int {
  let mut count = 0
  for route in page_routes {
    if pdf_page_route_native_detected(route) {
      count += 1
    }
  }
  count
}

///|
fn pdf_page_route_hybrid_region_count(page_routes : Array[PdfPageRoute]) -> Int {
  pdf_page_route_count(page_routes, "hybrid_region_page")
}

///|
fn pdf_page_route_ocr_page_count(page_routes : Array[PdfPageRoute]) -> Int {
  let mut count = 0
  for route in page_routes {
    if pdf_page_route_uses_ocr(route) {
      count += 1
    }
  }
  count
}

///|
fn pdf_page_route_native_output_count(page_routes : Array[PdfPageRoute]) -> Int {
  let mut count = 0
  for route in page_routes {
    if pdf_page_route_uses_native_text(route) {
      count += 1
    }
  }
  count
}

///|
fn pdf_scale_ocr_bbox_to_pdf_geometry(
  bbox : @core.BBox,
  page_model : @focr.OcrPageModel,
  geometry : @dpdfnative.PdfPageGeometry,
) -> @core.BBox? {
  match (page_model.width, page_model.height) {
    (Some(width), Some(height)) =>
      if width > 0.0 && height > 0.0 {
        let scale_x = geometry.width / width
        let scale_y = geometry.height / height
        Some({
          x0: bbox.x0 * scale_x,
          y0: geometry.height - bbox.y1 * scale_y,
          x1: bbox.x1 * scale_x,
          y1: geometry.height - bbox.y0 * scale_y,
        })
      } else {
        None
      }
    _ => None
  }
}

///|
fn pdf_block_with_bbox(
  block : @core.CoreBlock,
  bbox : @core.BBox,
) -> @core.CoreBlock {
  let next_source_ref = match block.source_ref {
    Some(source_ref) => Some({ ..source_ref, bbox: Some(bbox) })
    None => Some({ ..@core.empty_source_ref(), bbox: Some(bbox) })
  }
  { ..block, source_ref: next_source_ref }
}

///|
fn pdf_scale_ocr_blocks_to_pdf_geometry(
  blocks : Array[@core.CoreBlock],
  page_model : @focr.OcrPageModel,
  geometry : @dpdfnative.PdfPageGeometry,
) -> Array[@core.CoreBlock] {
  let scaled : Array[@core.CoreBlock] = []
  for block in blocks {
    match pdf_block_bbox(block) {
      Some(bbox) =>
        match pdf_scale_ocr_bbox_to_pdf_geometry(bbox, page_model, geometry) {
          Some(scaled_bbox) =>
            scaled.push(pdf_block_with_bbox(block, scaled_bbox))
          None => scaled.push(block)
        }
      None => scaled.push(block)
    }
  }
  scaled
}

///|
fn pdf_blocks_overlap_significantly(
  left : @core.CoreBlock,
  right : @core.CoreBlock,
) -> Bool {
  match (pdf_block_bbox(left), pdf_block_bbox(right)) {
    (Some(left_bbox), Some(right_bbox)) => {
      let overlap = pdf_bbox_intersection_area(left_bbox, right_bbox)
      if overlap <= 0.0 {
        false
      } else {
        let left_area = pdf_bbox_area(left_bbox)
        let right_area = pdf_bbox_area(right_bbox)
        let smaller = if left_area < right_area {
          left_area
        } else {
          right_area
        }
        smaller > 0.0 && overlap >= smaller * 0.30
      }
    }
    _ => false
  }
}

///|
fn pdf_block_intersects_any_region(
  block : @core.CoreBlock,
  regions : Array[@core.BBox],
) -> Bool {
  match pdf_block_bbox(block) {
    Some(bbox) => {
      for region in regions {
        if pdf_bboxes_overlap(bbox, region) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn pdf_core_block_order_compare(
  left : @core.CoreBlock,
  right : @core.CoreBlock,
) -> Int {
  match (pdf_block_bbox(left), pdf_block_bbox(right)) {
    (Some(left_bbox), Some(right_bbox)) => {
      let y_gap = if left_bbox.y0 > right_bbox.y0 {
        left_bbox.y0 - right_bbox.y0
      } else {
        right_bbox.y0 - left_bbox.y0
      }
      let max_height = {
        let left_height = pdf_bbox_height(left_bbox)
        let right_height = pdf_bbox_height(right_bbox)
        if left_height > right_height {
          left_height
        } else {
          right_height
        }
      }
      if y_gap > max_height * 0.6 && y_gap > 4.0 {
        if left_bbox.y0 > right_bbox.y0 {
          -1
        } else {
          1
        }
      } else if left_bbox.x0 < right_bbox.x0 {
        -1
      } else if left_bbox.x0 > right_bbox.x0 {
        1
      } else {
        0
      }
    }
    _ => 0
  }
}

///|
fn pdf_region_hybrid_page_blocks(
  native_blocks : Array[@core.CoreBlock],
  ocr_blocks : Array[@core.CoreBlock],
  route : PdfPageRoute,
) -> Array[@core.CoreBlock] {
  let kept : Array[@core.CoreBlock] = []
  let native_texts : Map[String, Bool] = Map([])
  for block in native_blocks {
    let normalized = pdf_normalized_text_for_dedupe(block.text)
    if normalized != "" {
      native_texts.set(normalized, true)
    }
  }
  for block in ocr_blocks {
    let normalized = pdf_normalized_text_for_dedupe(block.text)
    if normalized == "" {
      continue
    }
    if !pdf_block_intersects_any_region(block, route.candidate_regions) {
      continue
    }
    if native_texts.contains(normalized) {
      continue
    }
    let mut overlaps_native = false
    for native_block in native_blocks {
      if native_block.kind == @core.BlockKind::Image ||
        native_block.text.trim().to_owned() == "" {
        continue
      }
      if pdf_blocks_overlap_significantly(block, native_block) {
        overlaps_native = true
        break
      }
    }
    if overlaps_native {
      continue
    }
    kept.push(@core.block_with_attr(block, "pdf_region_hybrid", "true"))
  }
  let merged : Array[@core.CoreBlock] = []
  merged.append(native_blocks[:])
  merged.append(kept[:])
  merged.sort_by(pdf_core_block_order_compare)
  merged
}

///|
fn pdf_runtime_absolute_path(path : String) -> String {
  let trimmed = path.trim().to_owned()
  if trimmed == "" || trimmed.has_prefix("/") {
    trimmed
  } else {
    match @env.get_env_var("PWD") {
      Some(cwd) => {
        let base = cwd.trim().to_owned()
        if base == "" {
          trimmed
        } else {
          base + "/" + trimmed
        }
      }
      None => trimmed
    }
  }
}

///|
fn pdf_page_routes_from_native_document(
  native_document : @dpdfnative.PdfNativeDocument,
) -> Array[PdfPageRoute] {
  let routes : Array[PdfPageRoute] = []
  for i in 0..<native_document.pages.length() {
    let page = native_document.pages[i]
    let native_text_detected = pdf_native_page_has_text(page)
    let low_confidence_text_count = if native_text_detected {
      pdf_native_page_low_confidence_text_count(page)
    } else {
      0
    }
    let candidate_regions = if native_text_detected {
      pdf_native_page_region_hybrid_candidates(page, low_confidence_text_count)
    } else {
      []
    }
    routes.push({
      page_index: i + 1,
      route_kind: if native_text_detected && candidate_regions.length() > 0 {
        "hybrid_region_page"
      } else if native_text_detected {
        "native_text_page"
      } else {
        "ocr_page"
      },
      candidate_regions,
      low_confidence_text_count,
      native_text_detected,
    })
  }
  routes
}

///|
fn pdf_page_routes_from_raster_result(
  raster_result : PdfRasterResult,
) -> Array[PdfPageRoute] {
  let routes : Array[PdfPageRoute] = []
  for page in raster_result.pages {
    routes.push({
      page_index: page.page_index + 1,
      route_kind: "ocr_page",
      candidate_regions: [],
      low_confidence_text_count: 0,
      native_text_detected: false,
    })
  }
  routes
}

///|
fn pdf_page_route_count(
  page_routes : Array[PdfPageRoute],
  route_kind : String,
) -> Int {
  page_routes.filter(route => route.route_kind == route_kind).length()
}

///|
fn pdf_page_route_summary(page_routes : Array[PdfPageRoute]) -> String {
  "native_text_page=" +
  pdf_page_route_count(page_routes, "native_text_page").to_string() +
  ",hybrid_region_page=" +
  pdf_page_route_count(page_routes, "hybrid_region_page").to_string() +
  ",ocr_page=" +
  pdf_page_route_count(page_routes, "ocr_page").to_string()
}

///|
fn pdf_page_route_hybrid_used(page_routes : Array[PdfPageRoute]) -> Bool {
  pdf_page_route_hybrid_region_count(page_routes) > 0 ||
  (
    pdf_page_route_native_output_count(page_routes) > 0 &&
    pdf_page_route_ocr_page_count(page_routes) > 0
  )
}

///|
fn pdf_page_number_for_image_path(
  page_image_paths : Map[Int, String],
  image_path : String,
) -> Int? {
  for entry in page_image_paths.to_array() {
    if entry.1 == image_path {
      return Some(entry.0)
    }
  }
  None
}

///|
fn pdf_native_page_geometry_for_index(
  native_document : @dpdfnative.PdfNativeDocument?,
  page_index : Int,
) -> @dpdfnative.PdfPageGeometry? {
  match native_document {
    Some(document) =>
      if page_index > 0 && page_index <= document.pages.length() {
        Some(document.pages[page_index - 1].geometry)
      } else {
        None
      }
    None => None
  }
}
