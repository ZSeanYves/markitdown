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

///|
fn pdf_ocr_finalize_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  config : PdfOcrExecutionConfig,
  raster_result : PdfRasterResult,
  state : PdfOcrAccumulationState,
  stats : PdfOcrExecutionStats,
) -> Result[@parser.ParseResult, String] {
  if state.blocks.length() == 0 {
    return Err(pdf_ocr_empty_result_error(state))
  }
  let ocr_success_count = state.ocr_success_count.val
  let ocr_failure_count = state.ocr_failure_count.val
  let raster_failure_count = state.raster_failure_count.val
  let native_text_page_count = stats.native_page_count
  let provider_invoked = stats.ocr_process_invocation_count > 0
  let diagnostics = @focr.ocr_base_diagnostics(
    pdf_ocr_parser_name(),
    source,
    @input.DetectedFormat::Pdf,
    context.ocr_options,
    Some(@parser.ParserMode::LayoutTwoStage),
    config.provider_target,
  )
  diagnostics.dependency_diagnostics.append(
    state.fatal_dependency_diagnostics[:],
  )
  diagnostics.metrics.set("input_kind", pdf_native_input_kind_name(source.kind))
  diagnostics.metrics.set("ocr_provider_wired", "true")
  diagnostics.metrics.set(
    "provider_invoked",
    if provider_invoked {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "ocr_provider_status",
    if !provider_invoked {
      "skipped_native_text_only"
    } else if ocr_failure_count == 0 {
      "success"
    } else if ocr_success_count > 0 {
      "partial_success"
    } else {
      "execution_failed"
    },
  )
  diagnostics.metrics.set(
    "ocr_provider_selection_target",
    @focr.ocr_provider_selection_target_name(config.provider_target),
  )
  diagnostics.metrics.set(
    "ocr_provider_requested_kind",
    @focr.ocr_provider_kind_name(
      @focr.default_ocr_provider_kind_for_target(config.provider_target),
    ),
  )
  match stats.provider_name {
    Some(value) => diagnostics.metrics.set("ocr_provider_name", value)
    None => ()
  }
  match stats.provider_version {
    Some(value) => diagnostics.metrics.set("ocr_provider_version", value)
    None => ()
  }
  if provider_invoked {
    diagnostics.metrics.set(
      "ocr_provider_kind",
      @focr.ocr_provider_kind_name(config.provider_kind),
    )
  } else {
    diagnostics.metrics.set("ocr_provider_kind", "none")
  }
  diagnostics.metrics.set("block_count", state.blocks.length().to_string())
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("page_count", stats.page_count.to_string())
  diagnostics.metrics.set("pdf_page_count", stats.page_count.to_string())
  diagnostics.metrics.set("ocr_page_count", ocr_success_count.to_string())
  diagnostics.metrics.set("ocr_used_pages", ocr_success_count.to_string())
  diagnostics.metrics.set(
    "scanned_page_ratio",
    if stats.page_count == 0 {
      "0"
    } else {
      (stats.ocr_page_count.to_double() / stats.page_count.to_double()).to_string()
    },
  )
  diagnostics.metrics.set(
    "native_text_page_count",
    native_text_page_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_page_count",
    native_text_page_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_ocr_page_count",
    stats.ocr_page_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_region_hybrid_candidate_count",
    stats.region_hybrid_candidate_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_region_hybrid_used",
    if stats.hybrid_region_page_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_native_low_confidence_text_count",
    stats.native_low_confidence_text_count.to_string(),
  )
  diagnostics.metrics.set("pdf_page_route_summary", stats.page_route_summary)
  diagnostics.metrics.set(
    "pdf_page_hybrid_used",
    if stats.page_route_hybrid_used {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_rasterized_page_count",
    stats.rasterized_page_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_backend",
    if stats.native_detected_page_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_native_text_baseline",
    if stats.native_detected_page_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_ocr_used",
    if provider_invoked {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("pdf_ocr_route_contract", "accurate_layout_only")
  diagnostics.metrics.set("pdf_ocr_trigger", "accurate_layout")
  diagnostics.metrics.set(
    "mixed_page_route",
    if stats.page_route_hybrid_used {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("pdf_canonical_pipeline_used", "false")
  diagnostics.metrics.set(
    "pdf_empty_text_layer",
    if stats.native_detected_page_count == 0 && ocr_success_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set("format_contract", "pdf")
  diagnostics.metrics.set("native_impl_location", "format_readers/pdf")
  diagnostics.metrics.set("pdf_reader_impl", "format_readers/pdf")
  diagnostics.metrics.set(
    "pdf_raster_backend",
    if stats.raster_invoked {
      raster_result.backend_name
    } else {
      "none"
    },
  )
  diagnostics.metrics.set(
    "pdf_raster_page_success_count",
    stats.raster_page_success_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_raster_page_failure_count",
    raster_failure_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_ocr_page_failure_count",
    ocr_failure_count.to_string(),
  )
  diagnostics.metrics.set(
    "ocr_provider_batch_job_count",
    stats.ocr_batch_job_count.to_string(),
  )
  diagnostics.metrics.set(
    "ocr_provider_process_invocation_count",
    stats.ocr_process_invocation_count.to_string(),
  )
  diagnostics.metrics.set(
    "ocr_provider_batch_mode",
    if stats.ocr_batch_mode {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "external_process_invocation_count",
    stats.external_process_invocation_count.to_string(),
  )
  diagnostics.metrics.set("external_process_kind", stats.external_process_kind)
  diagnostics.metrics.set(
    "external_process_wall_ms",
    stats.external_process_wall_ms.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_raster_wall_ms",
    stats.pdf_raster_wall_ms.to_string(),
  )
  diagnostics.metrics.set(
    "ocr_provider_wall_ms",
    stats.ocr_provider_wall_ms.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_runtime_policy",
    @parser.pdf_native_runtime_policy_name(context.pdf_native_runtime_policy),
  )
  diagnostics.metrics.set(
    "pdf_header_footer_filter_policy",
    @parser.pdf_header_footer_filter_policy_name(
      context.pdf_header_footer_filter_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_table_reconstruction_policy",
    @parser.pdf_table_reconstruction_policy_name(
      context.pdf_table_reconstruction_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_header_footer_filter_enabled",
    if context.pdf_header_footer_filter_policy ==
      @parser.PdfHeaderFooterFilterPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set(
    "pdf_table_reconstruction_enabled",
    if context.pdf_table_reconstruction_policy ==
      @parser.PdfTableReconstructionPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  if raster_failure_count > 0 {
    diagnostics.degraded_features.push("pdf_raster_partial_failure")
  }
  if ocr_failure_count > 0 {
    diagnostics.degraded_features.push("pdf_ocr_partial_page_failure")
  }
  for item in raster_result.diagnostics {
    diagnostics.warnings.push("pdf_raster_diagnostic: " + item)
  }
  for item in state.warnings {
    diagnostics.warnings.push(item)
  }
  diagnostics.pass_trace.push("parse:pdf_ocr_parser")
  diagnostics.pass_trace.push("pdf_ocr:layout_two_stage")
  diagnostics.pass_trace.push("pdf_ocr:hybrid_pages")
  if stats.hybrid_region_page_count > 0 {
    diagnostics.pass_trace.push("pdf_ocr:hybrid_regions")
  }

  let document = @core.document_from_blocks(state.blocks)
  document.metadata.set("pdf_ocr_used", @core.JsonValue::Bool(provider_invoked))
  document.metadata.set(
    "pdf_native_text_baseline",
    @core.JsonValue::Bool(stats.native_detected_page_count > 0),
  )
  document.metadata.set(
    "pdf_canonical_pipeline_used",
    @core.JsonValue::Bool(false),
  )
  document.metadata.set(
    "pdf_raster_backend",
    @core.JsonValue::String(
      if stats.raster_invoked {
        raster_result.backend_name
      } else {
        "none"
      },
    ),
  )
  document.metadata.set(
    "page_count",
    @core.JsonValue::Number(stats.page_count.to_string()),
  )
  document.metadata.set(
    "pdf_page_count",
    @core.JsonValue::Number(stats.page_count.to_string()),
  )
  document.metadata.set(
    "ocr_used_pages",
    @core.JsonValue::Number(ocr_success_count.to_string()),
  )
  document.metadata.set(
    "native_text_page_count",
    @core.JsonValue::Number(native_text_page_count.to_string()),
  )
  document.metadata.set(
    "pdf_raster_page_success_count",
    @core.JsonValue::Number(stats.raster_page_success_count.to_string()),
  )
  document.metadata.set(
    "pdf_raster_page_failure_count",
    @core.JsonValue::Number(raster_failure_count.to_string()),
  )
  document.metadata.set(
    "pdf_native_page_count",
    @core.JsonValue::Number(stats.native_page_count.to_string()),
  )
  document.metadata.set(
    "pdf_region_hybrid_candidate_count",
    @core.JsonValue::Number(stats.region_hybrid_candidate_count.to_string()),
  )
  document.metadata.set(
    "pdf_region_hybrid_used",
    @core.JsonValue::Bool(stats.hybrid_region_page_count > 0),
  )
  document.metadata.set(
    "pdf_native_low_confidence_text_count",
    @core.JsonValue::Number(stats.native_low_confidence_text_count.to_string()),
  )
  document.metadata.set(
    "pdf_ocr_page_count",
    @core.JsonValue::Number(stats.ocr_page_count.to_string()),
  )
  document.metadata.set(
    "pdf_rasterized_page_count",
    @core.JsonValue::Number(stats.rasterized_page_count.to_string()),
  )
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  Ok(
    @parser.parse_result_with_document_capability(
      pdf_ocr_parser_name(),
      @parser.ParserMode::LayoutTwoStage,
      final_document,
      diagnostics,
      pdf_ocr_parser_capability(),
    ),
  )
}

///|
/// Produce diagnostics for the native PDF route when policy intentionally
/// blocks text restore.
pub fn pdf_native_fail_closed_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @core.Diagnostics {
  let diagnostics = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      @core.empty_diagnostics(),
      Some(pdf_native_parser_name()),
      Some(@parser.mode_name(@parser.ParserMode::PageSinglePass)),
    ),
    Some(pdf_native_input_kind_name(source.kind)),
    Some("pdf"),
  )
  diagnostics.warnings.push(pdf_native_fail_closed_message())
  diagnostics.degraded_features.push("pdf_native_policy_gate")
  diagnostics.fallback_trace.push(
    "pdf native parser policy gate -> fail closed until text restore is enabled",
  )
  diagnostics.pass_trace.push("parse:pdf_native_parser")
  diagnostics.metrics.set("parser_name", pdf_native_parser_name())
  diagnostics.metrics.set("parser_mode", "page_single_pass")
  diagnostics.metrics.set("input_kind", pdf_native_input_kind_name(source.kind))
  diagnostics.metrics.set("detected_format", "pdf")
  diagnostics.metrics.set(
    "requested_mode",
    pdf_native_requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "page_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "page")
  diagnostics.metrics.set("page_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("scanned_page_ratio", "0")
  diagnostics.metrics.set("ocr_used_pages", "0")
  diagnostics.metrics.set("model_used", "none")
  diagnostics.metrics.set("model_confidence", "0")
  diagnostics.metrics.set("pdf_native_backend", "false")
  diagnostics.metrics.set("pdf_native_text_baseline", "false")
  diagnostics.metrics.set("pdf_ocr_used", "false")
  diagnostics.metrics.set("pdf_canonical_pipeline_used", "false")
  diagnostics.metrics.set("pdf_empty_text_layer", "false")
  diagnostics.metrics.set(
    "pdf_header_footer_filter_policy",
    @parser.pdf_header_footer_filter_policy_name(
      context.pdf_header_footer_filter_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_header_footer_filter_enabled",
    if context.pdf_header_footer_filter_policy ==
      @parser.PdfHeaderFooterFilterPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set("pdf_header_footer_removed_count", "0")
  diagnostics.metrics.set(
    "pdf_table_reconstruction_policy",
    @parser.pdf_table_reconstruction_policy_name(
      context.pdf_table_reconstruction_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_table_reconstruction_enabled",
    if context.pdf_table_reconstruction_policy ==
      @parser.PdfTableReconstructionPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set("pdf_table_reconstruction_table_count", "0")
  diagnostics.metrics.set("fallback_reason", "pdf_native_restore_not_enabled")
  diagnostics.metrics.set("fallback_reason_kind", "parser_policy_gate")
  diagnostics.metrics.set("warning_count", "1")
  diagnostics.metrics.set("error_count", "0")
  diagnostics.metrics.set("fallback_count", "1")
  diagnostics.metrics.set("product_path_enabled", "false")
  diagnostics.metrics.set("format_contract", "pdf")
  diagnostics.metrics.set("native_impl_location", "format_readers/pdf")
  diagnostics.metrics.set("pdf_reader_impl", "format_readers/pdf")
  diagnostics.metrics.set("pdf_native_parser_gate", "disabled")
  diagnostics.metrics.set(
    "pdf_native_runtime_policy",
    @parser.pdf_native_runtime_policy_name(context.pdf_native_runtime_policy),
  )
  diagnostics
}

///|
/// Return the native PDF parser result, including fail-closed diagnostics when
/// the runtime gate is disabled.
pub fn pdf_native_parser_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  match pdf_native_parser_result_with_gate(source, context) {
    Ok(result) => result
    Err(result) => result
  }
}

///|
fn pdf_native_parser_result_with_gate(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, @parser.ParseResult] {
  let capability = pdf_native_parser_capability()
  match context.pdf_native_runtime_policy {
    @parser.PdfNativeRuntimePolicy::EnableTextRestore =>
      pdf_native_parser_enabled_result(source, context, capability)
    @parser.PdfNativeRuntimePolicy::DisableTextRestore => {
      let diagnostics = pdf_native_fail_closed_diagnostics(source, context)
      Err(
        @parser.parse_result_with_document_capability(
          pdf_native_parser_name(),
          @parser.ParserMode::PageSinglePass,
          @core.document_with_diagnostics(
            @core.empty_document_ir(),
            diagnostics,
          ),
          diagnostics,
          capability,
        ),
      )
    }
  }
}

///|
/// Construct the native-text PDF parser entrypoint.
pub fn pdf_native_parser() -> @parser.Parser {
  let capability = pdf_native_parser_capability()
  @parser.make_parser(
    pdf_native_parser_name(),
    @parser.ParserMode::PageSinglePass,
    capability,
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      match pdf_native_parser_result_with_gate(source, context) {
        Ok(result) => Ok(result)
        Err(result) =>
          match context.pdf_native_runtime_policy {
            @parser.PdfNativeRuntimePolicy::EnableTextRestore =>
              Err(pdf_native_parser_error_message(result.diagnostics))
            @parser.PdfNativeRuntimePolicy::DisableTextRestore => {
              ignore(result)
              Err(pdf_native_fail_closed_message())
            }
          }
      }
    },
  )
}

///|
pub fn pdf_ocr_parser_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  image_ocr_provider? : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ] = @focr.run_ocr_provider,
  rasterizer? : (@input.InputSource) -> Result[
    (PdfRasterResult, String),
    PdfRasterizerError,
  ] = rasterize_pdf_with_pdftoppm_default,
) -> Result[@parser.ParseResult, String] {
  let config = match pdf_ocr_execution_config(source, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let native_document_result = extract_pdf_native_document(source)
  let native_document = match native_document_result {
    Ok(value) => Some(value)
    Err(PdfNativeError::EmptyTextLayer(_)) => None
    Err(error) =>
      return Err(
        pdf_native_enabled_error_diagnostics(source, context, error).errors[0],
      )
  }
  let native_document_ir = match native_document {
    Some(value) =>
      pdf_native_document_to_ir_with_policies(
        value,
        context.pdf_header_footer_filter_policy,
        context.pdf_table_reconstruction_policy,
      )
    None => @core.empty_document_ir()
  }
  let native_page_routes = match native_document {
    Some(value) => pdf_page_routes_from_native_document(value)
    None => []
  }
  let mut needs_raster = match native_document {
    Some(_) => false
    None => true
  }
  if !needs_raster {
    needs_raster = native_page_routes.any(route => {
      pdf_page_route_uses_ocr(route)
    })
  }
  let pdf_raster_wall_ms : Ref[UInt64] = { val: 0 }
  let rasterized = if needs_raster {
    let started = @env.now()
    match rasterizer(source) {
      Ok(value) => {
        pdf_raster_wall_ms.val = @env.now() - started
        Some(value)
      }
      Err(error) => return Err(pdf_raster_provider_error_message(error))
    }
  } else {
    None
  }
  let raster_result = match rasterized {
    Some(value) => value.0
    None =>
      {
        backend_name: "pdftoppm",
        page_count: match native_document {
          Some(value) => value.pages.length()
          None => 0
        },
        pages: [],
        diagnostics: [],
      }
  }
  let temp_dir = match rasterized {
    Some(value) => value.1
    None => ""
  }
  let raster_invoked = needs_raster
  defer (if raster_invoked { cleanup_pdf_ocr_temp_dir(temp_dir) })
  let page_routes = if native_page_routes.length() > 0 {
    native_page_routes
  } else {
    pdf_page_routes_from_raster_result(raster_result)
  }
  let ocr_page_numbers = page_routes
    .filter(pdf_page_route_uses_ocr)
    .map(route => route.page_index)
  let state = pdf_ocr_accumulation_state()
  state.native_text_page_count.val = pdf_page_route_native_output_count(
    page_routes,
  )
  let ocr_image_paths : Array[String] = []
  let page_image_paths : Map[Int, String] = Map([])
  let ocr_blocks_by_page : Map[Int, Array[@core.CoreBlock]] = Map([])
  let ocr_provider_wall_ms : Ref[UInt64] = { val: 0 }
  let ocr_process_invocation_count : Ref[Int] = { val: 0 }
  let ocr_batch_job_count : Ref[Int] = { val: 0 }
  let raster_page_success_count : Ref[Int] = { val: 0 }
  let provider_name : Ref[String?] = { val: None }
  let provider_version : Ref[String?] = { val: None }
  if needs_raster {
    for page in raster_result.pages {
      let page_index = page.page_index + 1
      if !ocr_page_numbers.contains(page_index) {
        continue
      }
      if !page.success {
        pdf_ocr_record_raster_failure(
          state,
          "pdf_raster_page_failed:index=" + page_index.to_string(),
        )
        continue
      }
      let image_path = match page.image_path {
        Some(path) => pdf_runtime_absolute_path(path)
        None => {
          pdf_ocr_record_raster_failure(
            state,
            "pdf_raster_page_missing_image:index=" + page_index.to_string(),
          )
          continue
        }
      }
      page_image_paths.set(page_index, image_path)
      raster_page_success_count.val = raster_page_success_count.val + 1
      ocr_image_paths.push(image_path)
    }
    if ocr_image_paths.length() > 0 {
      ocr_process_invocation_count.val = 1
      ocr_batch_job_count.val = ocr_image_paths.length()
      let request = pdf_ocr_provider_batch_request(
        ocr_image_paths,
        config.provider_kind,
        context.ocr_options.language,
      )
      let started = @env.now()
      match image_ocr_provider(request) {
        Ok(result) => {
          ocr_provider_wall_ms.val = @env.now() - started
          provider_name.val = Some(result.provider_name)
          provider_version.val = result.provider_version
          for job in result.jobs {
            let page_number = match
              pdf_page_number_for_image_path(page_image_paths, job.image_path) {
              Some(value) => value
              None => {
                state.ocr_failure_count.val = state.ocr_failure_count.val + 1
                state.warnings.push(
                  "pdf_ocr_page_failed:index=unknown provider=" +
                  @focr.ocr_provider_kind_name(config.provider_kind) +
                  " reason=unmapped image path",
                )
                continue
              }
            }
            if job.status == "ok" {
              let job_blocks : Array[@core.CoreBlock] = []
              for model in job.pages {
                let model_blocks = @focr.ocr_page_blocks_from_page(
                  source,
                  @input.DetectedFormat::Pdf,
                  page_number,
                  model,
                )
                let scaled_blocks = match
                  pdf_native_page_geometry_for_index(
                    native_document, page_number,
                  ) {
                  Some(geometry) =>
                    pdf_scale_ocr_blocks_to_pdf_geometry(
                      model_blocks, model, geometry,
                    )
                  None => model_blocks
                }
                job_blocks.append(scaled_blocks[:])
              }
              ocr_blocks_by_page.set(page_number, job_blocks)
              state.ocr_success_count.val = state.ocr_success_count.val + 1
            } else if job.status == "empty" {
              pdf_ocr_record_empty_provider_result(state, page_number)
            } else {
              state.ocr_failure_count.val = state.ocr_failure_count.val + 1
              state.warnings.push(
                "pdf_ocr_page_failed:index=" +
                page_number.to_string() +
                " provider=" +
                @focr.ocr_provider_kind_name(config.provider_kind) +
                " reason=" +
                job.error_message.unwrap_or("unknown error"),
              )
            }
          }
        }
        Err(error) =>
          return Err(
            pdf_native_parser_error_message(
              pdf_native_enabled_error_diagnostics(
                source,
                context,
                PdfNativeError::ParseFailed(error.to_string()),
              ),
            ),
          )
      }
    }
  }
  for route in page_routes {
    let native_blocks = pdf_blocks_for_page(
      native_document_ir.blocks,
      route.page_index,
    )
    if route.route_kind == "native_text_page" {
      state.blocks.append(native_blocks[:])
    } else if route.route_kind == "hybrid_region_page" {
      match ocr_blocks_by_page.get(route.page_index) {
        Some(blocks) =>
          state.blocks.append(
            pdf_region_hybrid_page_blocks(native_blocks, blocks, route)[:],
          )
        None => state.blocks.append(native_blocks[:])
      }
    } else {
      match ocr_blocks_by_page.get(route.page_index) {
        Some(blocks) => state.blocks.append(blocks[:])
        None => ()
      }
    }
  }
  let external_process_kinds : Array[String] = []
  if raster_invoked {
    external_process_kinds.push(raster_result.backend_name)
  }
  if ocr_process_invocation_count.val > 0 {
    external_process_kinds.push(
      provider_name.val.unwrap_or(
        @focr.ocr_provider_kind_name(config.provider_kind),
      ),
    )
  }
  let stats : PdfOcrExecutionStats = {
    page_count: page_routes.length(),
    native_page_count: pdf_page_route_native_output_count(page_routes),
    native_detected_page_count: pdf_page_route_native_detected_count(
      page_routes,
    ),
    ocr_page_count: pdf_page_route_ocr_page_count(page_routes),
    hybrid_region_page_count: pdf_page_route_hybrid_region_count(page_routes),
    region_hybrid_candidate_count: pdf_page_route_total_candidate_count(
      page_routes,
    ),
    native_low_confidence_text_count: pdf_page_route_total_low_confidence_count(
      page_routes,
    ),
    raster_invoked,
    rasterized_page_count: if raster_invoked {
      raster_result.pages.length()
    } else {
      0
    },
    raster_page_success_count: raster_page_success_count.val,
    ocr_batch_job_count: ocr_batch_job_count.val,
    ocr_process_invocation_count: ocr_process_invocation_count.val,
    ocr_batch_mode: ocr_process_invocation_count.val > 0,
    page_route_hybrid_used: pdf_page_route_hybrid_used(page_routes),
    page_route_summary: pdf_page_route_summary(page_routes),
    provider_name: provider_name.val,
    provider_version: provider_version.val,
    pdf_raster_wall_ms: pdf_raster_wall_ms.val,
    ocr_provider_wall_ms: ocr_provider_wall_ms.val,
    external_process_invocation_count: (if raster_invoked { 1 } else { 0 }) +
    ocr_process_invocation_count.val,
    external_process_kind: if external_process_kinds.length() == 0 {
      "none"
    } else {
      external_process_kinds.join(",")
    },
    external_process_wall_ms: pdf_raster_wall_ms.val + ocr_provider_wall_ms.val,
  }
  pdf_ocr_finalize_result(source, context, config, raster_result, state, stats)
}

///|
pub async fn pdf_ocr_parser_result_async(
  source : @input.InputSource,
  context : @parser.ParseContext,
  image_ocr_provider? : async (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ] = @focr.run_ocr_provider_async,
  rasterizer? : async (@input.InputSource) -> Result[
    (PdfRasterResult, String),
    PdfRasterizerError,
  ] = rasterize_pdf_with_pdftoppm_default_async,
) -> Result[@parser.ParseResult, String] {
  let config = match pdf_ocr_execution_config(source, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let native_document_result = extract_pdf_native_document(source)
  let native_document = match native_document_result {
    Ok(value) => Some(value)
    Err(PdfNativeError::EmptyTextLayer(_)) => None
    Err(error) =>
      return Err(
        pdf_native_enabled_error_diagnostics(source, context, error).errors[0],
      )
  }
  let native_document_ir = match native_document {
    Some(value) =>
      pdf_native_document_to_ir_with_policies(
        value,
        context.pdf_header_footer_filter_policy,
        context.pdf_table_reconstruction_policy,
      )
    None => @core.empty_document_ir()
  }
  let native_page_routes = match native_document {
    Some(value) => pdf_page_routes_from_native_document(value)
    None => []
  }
  let mut needs_raster = match native_document {
    Some(_) => false
    None => true
  }
  if !needs_raster {
    needs_raster = native_page_routes.any(route => {
      pdf_page_route_uses_ocr(route)
    })
  }
  let pdf_raster_wall_ms : Ref[UInt64] = { val: 0 }
  let rasterized = if needs_raster {
    let started = @env.now()
    match rasterizer(source) {
      Ok(value) => {
        pdf_raster_wall_ms.val = @env.now() - started
        Some(value)
      }
      Err(error) => return Err(pdf_raster_provider_error_message(error))
    }
  } else {
    None
  }
  let raster_result = match rasterized {
    Some(value) => value.0
    None =>
      {
        backend_name: "pdftoppm",
        page_count: match native_document {
          Some(value) => value.pages.length()
          None => 0
        },
        pages: [],
        diagnostics: [],
      }
  }
  let temp_dir = match rasterized {
    Some(value) => value.1
    None => ""
  }
  let raster_invoked = needs_raster
  defer (if raster_invoked { cleanup_pdf_ocr_temp_dir(temp_dir) })
  let page_routes = if native_page_routes.length() > 0 {
    native_page_routes
  } else {
    pdf_page_routes_from_raster_result(raster_result)
  }
  let ocr_page_numbers = page_routes
    .filter(pdf_page_route_uses_ocr)
    .map(route => route.page_index)
  let state = pdf_ocr_accumulation_state()
  state.native_text_page_count.val = pdf_page_route_native_output_count(
    page_routes,
  )
  let ocr_image_paths : Array[String] = []
  let page_image_paths : Map[Int, String] = Map([])
  let ocr_blocks_by_page : Map[Int, Array[@core.CoreBlock]] = Map([])
  let ocr_provider_wall_ms : Ref[UInt64] = { val: 0 }
  let ocr_process_invocation_count : Ref[Int] = { val: 0 }
  let ocr_batch_job_count : Ref[Int] = { val: 0 }
  let raster_page_success_count : Ref[Int] = { val: 0 }
  let provider_name : Ref[String?] = { val: None }
  let provider_version : Ref[String?] = { val: None }
  if needs_raster {
    for page in raster_result.pages {
      let page_index = page.page_index + 1
      if !ocr_page_numbers.contains(page_index) {
        continue
      }
      if !page.success {
        pdf_ocr_record_raster_failure(
          state,
          "pdf_raster_page_failed:index=" + page_index.to_string(),
        )
        continue
      }
      let image_path = match page.image_path {
        Some(path) => pdf_runtime_absolute_path(path)
        None => {
          pdf_ocr_record_raster_failure(
            state,
            "pdf_raster_page_missing_image:index=" + page_index.to_string(),
          )
          continue
        }
      }
      page_image_paths.set(page_index, image_path)
      raster_page_success_count.val = raster_page_success_count.val + 1
      ocr_image_paths.push(image_path)
    }
    if ocr_image_paths.length() > 0 {
      ocr_process_invocation_count.val = 1
      ocr_batch_job_count.val = ocr_image_paths.length()
      let request = pdf_ocr_provider_batch_request(
        ocr_image_paths,
        config.provider_kind,
        context.ocr_options.language,
      )
      let started = @env.now()
      match image_ocr_provider(request) {
        Ok(result) => {
          ocr_provider_wall_ms.val = @env.now() - started
          provider_name.val = Some(result.provider_name)
          provider_version.val = result.provider_version
          for job in result.jobs {
            let page_number = match
              pdf_page_number_for_image_path(page_image_paths, job.image_path) {
              Some(value) => value
              None => {
                state.ocr_failure_count.val = state.ocr_failure_count.val + 1
                state.warnings.push(
                  "pdf_ocr_page_failed:index=unknown provider=" +
                  @focr.ocr_provider_kind_name(config.provider_kind) +
                  " reason=unmapped image path",
                )
                continue
              }
            }
            if job.status == "ok" {
              let job_blocks : Array[@core.CoreBlock] = []
              for model in job.pages {
                let model_blocks = @focr.ocr_page_blocks_from_page(
                  source,
                  @input.DetectedFormat::Pdf,
                  page_number,
                  model,
                )
                let scaled_blocks = match
                  pdf_native_page_geometry_for_index(
                    native_document, page_number,
                  ) {
                  Some(geometry) =>
                    pdf_scale_ocr_blocks_to_pdf_geometry(
                      model_blocks, model, geometry,
                    )
                  None => model_blocks
                }
                job_blocks.append(scaled_blocks[:])
              }
              ocr_blocks_by_page.set(page_number, job_blocks)
              state.ocr_success_count.val = state.ocr_success_count.val + 1
            } else if job.status == "empty" {
              pdf_ocr_record_empty_provider_result(state, page_number)
            } else {
              state.ocr_failure_count.val = state.ocr_failure_count.val + 1
              state.warnings.push(
                "pdf_ocr_page_failed:index=" +
                page_number.to_string() +
                " provider=" +
                @focr.ocr_provider_kind_name(config.provider_kind) +
                " reason=" +
                job.error_message.unwrap_or("unknown error"),
              )
            }
          }
        }
        Err(error) =>
          return Err(
            pdf_native_parser_error_message(
              pdf_native_enabled_error_diagnostics(
                source,
                context,
                PdfNativeError::ParseFailed(error.to_string()),
              ),
            ),
          )
      }
    }
  }
  for route in page_routes {
    let native_blocks = pdf_blocks_for_page(
      native_document_ir.blocks,
      route.page_index,
    )
    if route.route_kind == "native_text_page" {
      state.blocks.append(native_blocks[:])
    } else if route.route_kind == "hybrid_region_page" {
      match ocr_blocks_by_page.get(route.page_index) {
        Some(blocks) =>
          state.blocks.append(
            pdf_region_hybrid_page_blocks(native_blocks, blocks, route)[:],
          )
        None => state.blocks.append(native_blocks[:])
      }
    } else {
      match ocr_blocks_by_page.get(route.page_index) {
        Some(blocks) => state.blocks.append(blocks[:])
        None => ()
      }
    }
  }
  let external_process_kinds : Array[String] = []
  if raster_invoked {
    external_process_kinds.push(raster_result.backend_name)
  }
  if ocr_process_invocation_count.val > 0 {
    external_process_kinds.push(
      provider_name.val.unwrap_or(
        @focr.ocr_provider_kind_name(config.provider_kind),
      ),
    )
  }
  let stats : PdfOcrExecutionStats = {
    page_count: page_routes.length(),
    native_page_count: pdf_page_route_native_output_count(page_routes),
    native_detected_page_count: pdf_page_route_native_detected_count(
      page_routes,
    ),
    ocr_page_count: pdf_page_route_ocr_page_count(page_routes),
    hybrid_region_page_count: pdf_page_route_hybrid_region_count(page_routes),
    region_hybrid_candidate_count: pdf_page_route_total_candidate_count(
      page_routes,
    ),
    native_low_confidence_text_count: pdf_page_route_total_low_confidence_count(
      page_routes,
    ),
    raster_invoked,
    rasterized_page_count: if raster_invoked {
      raster_result.pages.length()
    } else {
      0
    },
    raster_page_success_count: raster_page_success_count.val,
    ocr_batch_job_count: ocr_batch_job_count.val,
    ocr_process_invocation_count: ocr_process_invocation_count.val,
    ocr_batch_mode: ocr_process_invocation_count.val > 0,
    page_route_hybrid_used: pdf_page_route_hybrid_used(page_routes),
    page_route_summary: pdf_page_route_summary(page_routes),
    provider_name: provider_name.val,
    provider_version: provider_version.val,
    pdf_raster_wall_ms: pdf_raster_wall_ms.val,
    ocr_provider_wall_ms: ocr_provider_wall_ms.val,
    external_process_invocation_count: (if raster_invoked { 1 } else { 0 }) +
    ocr_process_invocation_count.val,
    external_process_kind: if external_process_kinds.length() == 0 {
      "none"
    } else {
      external_process_kinds.join(",")
    },
    external_process_wall_ms: pdf_raster_wall_ms.val + ocr_provider_wall_ms.val,
  }
  pdf_ocr_finalize_result(source, context, config, raster_result, state, stats)
}

///|
pub fn pdf_ocr_parser() -> @parser.Parser {
  @parser.make_parser(
    pdf_ocr_parser_name(),
    @parser.ParserMode::LayoutTwoStage,
    pdf_ocr_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      pdf_ocr_parser_result(source, context)
    },
  )
}

///|
fn pdf_native_parser_enabled_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, @parser.ParseResult] {
  match extract_pdf_native_document(source) {
    Ok(native_document) =>
      pdf_native_parser_enabled_result_from_document(
        source, context, capability, native_document,
      )
    Err(error) => {
      let diagnostics = pdf_native_enabled_error_diagnostics(
        source, context, error,
      )
      Err(
        @parser.parse_result_with_document_capability(
          pdf_native_parser_name(),
          @parser.ParserMode::PageSinglePass,
          @core.document_with_diagnostics(
            @core.empty_document_ir(),
            diagnostics,
          ),
          diagnostics,
          capability,
        ),
      )
    }
  }
}

///|
fn pdf_native_parser_enabled_result_from_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
  native_document : @dpdfnative.PdfNativeDocument,
) -> Result[@parser.ParseResult, @parser.ParseResult] {
  let document = pdf_native_document_to_ir_with_policies(
    native_document,
    context.pdf_header_footer_filter_policy,
    context.pdf_table_reconstruction_policy,
  )
  let diagnostics = document.diagnostics
  @fshared.mark_structured_document_profile(diagnostics)
  let diagnostics = pdf_native_enabled_success_diagnostics(
    source, context, diagnostics,
  )
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  Ok(
    @parser.parse_result_with_document_capability(
      pdf_native_parser_name(),
      @parser.ParserMode::PageSinglePass,
      final_document,
      diagnostics,
      capability,
    ),
  )
}

///|
fn pdf_native_enabled_success_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
  diagnostics : @core.Diagnostics,
) -> @core.Diagnostics {
  let next = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      diagnostics,
      Some(pdf_native_parser_name()),
      Some(@parser.mode_name(@parser.ParserMode::PageSinglePass)),
    ),
    Some(pdf_native_input_kind_name(source.kind)),
    Some("pdf"),
  )
  next.pass_trace.push("parse:pdf_native_parser")
  next.pass_trace.push("pdf_native:parser_success_path")
  next.metrics.set("parser_name", pdf_native_parser_name())
  next.metrics.set("parser_mode", "page_single_pass")
  next.metrics.set("input_kind", pdf_native_input_kind_name(source.kind))
  next.metrics.set("detected_format", "pdf")
  next.metrics.set("requested_mode", pdf_native_requested_mode_name(context))
  next.metrics.set("effective_mode", "page_single_pass")
  next.metrics.set("ir_input_kind", "document")
  next.metrics.set("event_granularity", "page")
  next.metrics.set("event_semantics", "page_single_pass")
  next.metrics.set("product_path_enabled", "true")
  next.metrics.set("format_contract", "pdf")
  next.metrics.set("native_impl_location", "format_readers/pdf")
  next.metrics.set("pdf_reader_impl", "format_readers/pdf")
  next.metrics.set("pdf_native_backend", "true")
  next.metrics.set("pdf_native_text_baseline", "true")
  next.metrics.set("pdf_ocr_used", "false")
  next.metrics.set("pdf_canonical_pipeline_used", "false")
  next.metrics.set(
    "probe_artifact_reused",
    if diagnostics.metrics.get("probe_artifact_reused") == Some("true") {
      "true"
    } else {
      "false"
    },
  )
  next.metrics.set(
    "process_cache_hit",
    if diagnostics.metrics.get("process_cache_hit") == Some("true") {
      "true"
    } else {
      "false"
    },
  )
  next.metrics.set(
    "child_parse_fast_path_used",
    if diagnostics.metrics.get("structured_document_profile") ==
      Some("pipeline_ready") {
      "true"
    } else {
      "false"
    },
  )
  if next.metrics.get("pdf_empty_text_layer") == None {
    next.metrics.set("pdf_empty_text_layer", "false")
  }
  next.metrics.set(
    "pdf_header_footer_filter_policy",
    @parser.pdf_header_footer_filter_policy_name(
      context.pdf_header_footer_filter_policy,
    ),
  )
  next.metrics.set(
    "pdf_header_footer_filter_enabled",
    if context.pdf_header_footer_filter_policy ==
      @parser.PdfHeaderFooterFilterPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  if next.metrics.get("pdf_header_footer_removed_count") == None {
    next.metrics.set("pdf_header_footer_removed_count", "0")
  }
  next.metrics.set(
    "pdf_table_reconstruction_policy",
    @parser.pdf_table_reconstruction_policy_name(
      context.pdf_table_reconstruction_policy,
    ),
  )
  next.metrics.set(
    "pdf_table_reconstruction_enabled",
    if context.pdf_table_reconstruction_policy ==
      @parser.PdfTableReconstructionPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  if next.metrics.get("pdf_table_reconstruction_table_count") == None {
    next.metrics.set("pdf_table_reconstruction_table_count", "0")
  }
  next.metrics.set(
    "pdf_native_runtime_policy",
    @parser.pdf_native_runtime_policy_name(context.pdf_native_runtime_policy),
  )
  next.metrics.set("pdf_native_parser_gate", "enabled")
  next.metrics.set("fallback_reason", "none")
  next.metrics.set("fallback_reason_kind", "none")
  next.metrics.set("warning_count", next.warnings.length().to_string())
  next.metrics.set("error_count", next.errors.length().to_string())
  next.metrics.set("fallback_count", next.fallback_trace.length().to_string())
  next
}

///|
fn pdf_native_enabled_error_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
  error : PdfNativeError,
) -> @core.Diagnostics {
  let taxonomy = pdf_native_error_taxonomy(error)
  let diagnostics = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      @core.empty_diagnostics(),
      Some(pdf_native_parser_name()),
      Some(@parser.mode_name(@parser.ParserMode::PageSinglePass)),
    ),
    Some(pdf_native_input_kind_name(source.kind)),
    Some("pdf"),
  )
  diagnostics.errors.push(error.to_string())
  diagnostics.degraded_features.push("pdf_native_internal_gate_failed")
  diagnostics.fallback_trace.push(
    "pdf native parser native text baseline -> " + taxonomy.1,
  )
  diagnostics.pass_trace.push("parse:pdf_native_parser")
  diagnostics.pass_trace.push("pdf_native:parser_error_path")
  diagnostics.metrics.set("parser_name", pdf_native_parser_name())
  diagnostics.metrics.set("parser_mode", "page_single_pass")
  diagnostics.metrics.set("input_kind", pdf_native_input_kind_name(source.kind))
  diagnostics.metrics.set("detected_format", "pdf")
  diagnostics.metrics.set(
    "requested_mode",
    pdf_native_requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "page_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "page")
  diagnostics.metrics.set("event_semantics", "page_single_pass")
  diagnostics.metrics.set("page_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("scanned_page_ratio", "0")
  diagnostics.metrics.set("ocr_used_pages", "0")
  diagnostics.metrics.set("model_used", "none")
  diagnostics.metrics.set("model_confidence", "0")
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set("format_contract", "pdf")
  diagnostics.metrics.set("native_impl_location", "format_readers/pdf")
  diagnostics.metrics.set("pdf_reader_impl", "format_readers/pdf")
  diagnostics.metrics.set("pdf_native_backend", "true")
  diagnostics.metrics.set("pdf_native_text_baseline", "true")
  diagnostics.metrics.set("pdf_ocr_used", "false")
  diagnostics.metrics.set("pdf_canonical_pipeline_used", "false")
  diagnostics.metrics.set("probe_artifact_reused", "false")
  diagnostics.metrics.set("process_cache_hit", "false")
  diagnostics.metrics.set(
    "pdf_header_footer_filter_policy",
    @parser.pdf_header_footer_filter_policy_name(
      context.pdf_header_footer_filter_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_header_footer_filter_enabled",
    if context.pdf_header_footer_filter_policy ==
      @parser.PdfHeaderFooterFilterPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set("pdf_header_footer_removed_count", "0")
  diagnostics.metrics.set(
    "pdf_table_reconstruction_policy",
    @parser.pdf_table_reconstruction_policy_name(
      context.pdf_table_reconstruction_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_table_reconstruction_enabled",
    if context.pdf_table_reconstruction_policy ==
      @parser.PdfTableReconstructionPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set("pdf_table_reconstruction_table_count", "0")
  diagnostics.metrics.set(
    "pdf_empty_text_layer",
    if taxonomy.0 == "empty_text_layer" {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("pdf_native_parser_gate", "enabled")
  diagnostics.metrics.set("fallback_reason", taxonomy.1)
  diagnostics.metrics.set("fallback_reason_kind", taxonomy.0)
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_runtime_policy",
    @parser.pdf_native_runtime_policy_name(context.pdf_native_runtime_policy),
  )
  diagnostics
}

///|
fn pdf_native_error_taxonomy(error : PdfNativeError) -> (String, String) {
  match error {
    PdfNativeError::BackendUnavailable(_) =>
      ("backend_unavailable", "pdf_native_backend_unavailable")
    PdfNativeError::ReadFailed(_) => ("read_failed", "pdf_native_read_failed")
    PdfNativeError::ParseFailed(_) =>
      ("parse_failed", "pdf_native_parse_failed")
    PdfNativeError::EncryptedUnsupported(_) =>
      ("encrypted_unsupported", "pdf_native_encrypted_unsupported")
    PdfNativeError::EmptyTextLayer(_) =>
      ("empty_text_layer", "pdf_native_empty_text_layer")
    PdfNativeError::UnsupportedFeature(_) =>
      ("unsupported_feature", "pdf_native_unsupported_feature")
  }
}

///|
fn pdf_native_parser_error_message(diagnostics : @core.Diagnostics) -> String {
  if diagnostics.errors.length() > 0 {
    diagnostics.errors[0]
  } else {
    "pdf native parser failed under native text baseline"
  }
}

///|
fn pdf_native_input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
  }
}

///|
fn pdf_native_requested_mode_name(context : @parser.ParseContext) -> String {
  match context.requested_mode {
    Some(mode) => @parser.mode_name(mode)
    None => "default"
  }
}
