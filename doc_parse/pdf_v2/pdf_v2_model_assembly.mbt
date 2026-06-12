///|
pub(all) enum PdfV2ModelAssemblyResult {
  ModelAssemblyOk(PdfV2DocumentModel)
  ModelAssemblyErr(Array[PdfV2Warning], Array[PdfV2Risk], String)
}

///|
fn pdf_v2_model_empty_layout(
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2LayoutRecoveryResult {
  {
    regions: [],
    reading_order: {
      region_indices: [],
      confidence: 0.0,
      source_refs,
      reason_tags: ["layout_recovery_not_run", "parser_model_assembly"],
    },
    cross_page_boundaries: [],
    hints: [],
    risks: [],
    warnings: [],
    confidence: 0.0,
  }
}

///|
fn pdf_v2_model_source_refs_or_document(
  source_refs : Array[PdfV2SourceRef],
) -> Array[PdfV2SourceRef] {
  if source_refs.length() == 0 {
    [pdf_v2_document_source_ref()]
  } else {
    source_refs
  }
}

///|
fn pdf_v2_model_page_index_valid(page_index : Int?, page_count : Int) -> Bool {
  match page_index {
    Some(index) => index >= 0 && index < page_count
    None => false
  }
}

///|
fn pdf_v2_model_invalid_page_warning(
  candidate_kind : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::InternalInvariant,
    PdfV2Severity::Error,
    "PDF v2 model assembly found \{candidate_kind} candidate with invalid page_index",
    pdf_v2_model_source_refs_or_document(source_refs),
    ["model_assembly", "invalid_candidate_page_index", candidate_kind],
  )
}

///|
fn pdf_v2_model_invalid_page_risk(
  candidate_kind : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::ObjectGraphIssue,
    severity: PdfV2Severity::Error,
    message: "PDF v2 model assembly found \{candidate_kind} candidate with invalid page_index",
    source_refs: pdf_v2_model_source_refs_or_document(source_refs),
    reason_tags: [
      "model_assembly", "invalid_candidate_page_index", candidate_kind,
    ],
  }
}

///|
fn pdf_v2_model_append_invalid_page(
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  candidate_kind : String,
  source_refs : Array[PdfV2SourceRef],
) -> Unit {
  warnings.push(pdf_v2_model_invalid_page_warning(candidate_kind, source_refs))
  risks.push(pdf_v2_model_invalid_page_risk(candidate_kind, source_refs))
}

///|
fn pdf_v2_model_validate_char_pages(
  chars : Array[PdfV2CharCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for ch in chars {
    if !pdf_v2_model_page_index_valid(ch.page_index, page_count) {
      pdf_v2_model_append_invalid_page(warnings, risks, "char", [ch.source_ref])
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_span_pages(
  spans : Array[PdfV2SpanCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for span in spans {
    if !pdf_v2_model_page_index_valid(span.page_index, page_count) {
      pdf_v2_model_append_invalid_page(
        warnings,
        risks,
        "span",
        span.source_refs,
      )
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_line_pages(
  lines : Array[PdfV2LineCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for line in lines {
    if !pdf_v2_model_page_index_valid(line.page_index, page_count) {
      pdf_v2_model_append_invalid_page(
        warnings,
        risks,
        "line",
        line.source_refs,
      )
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_block_pages(
  blocks : Array[PdfV2BlockCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for block in blocks {
    if !pdf_v2_model_page_index_valid(block.page_index, page_count) {
      pdf_v2_model_append_invalid_page(
        warnings,
        risks,
        "block",
        block.source_refs,
      )
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_table_pages(
  tables : Array[PdfV2TableCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for table in tables {
    if !pdf_v2_model_page_index_valid(table.page_index, page_count) {
      pdf_v2_model_append_invalid_page(
        warnings,
        risks,
        "table",
        table.source_refs,
      )
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_image_pages(
  images : Array[PdfV2ImageCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for image in images {
    if !pdf_v2_model_page_index_valid(image.page_index, page_count) {
      pdf_v2_model_append_invalid_page(warnings, risks, "image", [
        image.source_ref,
      ])
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_inline_image_pages(
  images : Array[PdfV2InlineImageCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for image in images {
    if !pdf_v2_model_page_index_valid(image.page_index, page_count) {
      pdf_v2_model_append_invalid_page(warnings, risks, "inline_image", [
        image.source_ref,
      ])
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_annotation_pages(
  annotations : Array[PdfV2AnnotationCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for annotation in annotations {
    if !pdf_v2_model_page_index_valid(annotation.page_index, page_count) {
      pdf_v2_model_append_invalid_page(warnings, risks, "annotation", [
        annotation.source_ref,
      ])
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_link_pages(
  links : Array[PdfV2LinkCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for link in links {
    if !pdf_v2_model_page_index_valid(link.page_index, page_count) {
      pdf_v2_model_append_invalid_page(warnings, risks, "link", [
        link.source_ref,
      ])
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_form_pages(
  forms : Array[PdfV2FormCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for form in forms {
    match form.page_index {
      Some(_) =>
        if !pdf_v2_model_page_index_valid(form.page_index, page_count) {
          pdf_v2_model_append_invalid_page(warnings, risks, "form", [
            form.source_ref,
          ])
          ok = false
        }
      None => ()
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_resource_pages(
  resources : Array[PdfV2ResourceCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for resource in resources {
    if !pdf_v2_model_page_index_valid(resource.page_index, page_count) {
      pdf_v2_model_append_invalid_page(warnings, risks, "resource", [
        resource.source_ref,
      ])
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_page_facts(
  pages : Array[PdfV2Page],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  let page_count = pages.length()
  for page in pages {
    if page.page_index < 0 || page.page_index >= page_count {
      pdf_v2_model_append_invalid_page(warnings, risks, "page", [
        page.source_ref,
      ])
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_page_count_warning() -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::InternalInvariant,
    PdfV2Severity::Warning,
    "PDF v2 source summary page_count differs from page facts",
    [pdf_v2_document_source_ref()],
    ["model_assembly", "page_count_mismatch"],
  )
}

///|
fn pdf_v2_model_page_count_risk() -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::ObjectGraphIssue,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 source summary page_count differs from page facts",
    source_refs: [pdf_v2_document_source_ref()],
    reason_tags: ["model_assembly", "page_count_mismatch"],
  }
}

///|
fn pdf_v2_model_chars_for_page(
  chars : Array[PdfV2CharCandidate],
  page_index : Int,
) -> Array[PdfV2CharCandidate] {
  let out : Array[PdfV2CharCandidate] = []
  for ch in chars {
    if ch.page_index == Some(page_index) {
      out.push(ch)
    }
  }
  out
}

///|
fn pdf_v2_model_spans_for_page(
  spans : Array[PdfV2SpanCandidate],
  page_index : Int,
) -> Array[PdfV2SpanCandidate] {
  let out : Array[PdfV2SpanCandidate] = []
  for span in spans {
    if span.page_index == Some(page_index) {
      out.push(span)
    }
  }
  out
}

///|
fn pdf_v2_model_lines_for_page(
  lines : Array[PdfV2LineCandidate],
  page_index : Int,
) -> Array[PdfV2LineCandidate] {
  let out : Array[PdfV2LineCandidate] = []
  for line in lines {
    if line.page_index == Some(page_index) {
      out.push(line)
    }
  }
  out
}

///|
fn pdf_v2_model_blocks_for_page(
  blocks : Array[PdfV2BlockCandidate],
  page_index : Int,
) -> Array[PdfV2BlockCandidate] {
  let out : Array[PdfV2BlockCandidate] = []
  for block in blocks {
    if block.page_index == Some(page_index) {
      out.push(block)
    }
  }
  out
}

///|
fn pdf_v2_model_images_for_page(
  images : Array[PdfV2ImageCandidate],
  page_index : Int,
) -> Array[PdfV2ImageCandidate] {
  let out : Array[PdfV2ImageCandidate] = []
  for image in images {
    if image.page_index == Some(page_index) {
      out.push(image)
    }
  }
  out
}

///|
fn pdf_v2_model_tables_for_page(
  tables : Array[PdfV2TableCandidate],
  page_index : Int,
) -> Array[PdfV2TableCandidate] {
  let out : Array[PdfV2TableCandidate] = []
  for table in tables {
    if table.page_index == Some(page_index) {
      out.push(table)
    }
  }
  out
}

///|
fn pdf_v2_model_inline_images_for_page(
  images : Array[PdfV2InlineImageCandidate],
  page_index : Int,
) -> Array[PdfV2InlineImageCandidate] {
  let out : Array[PdfV2InlineImageCandidate] = []
  for image in images {
    if image.page_index == Some(page_index) {
      out.push(image)
    }
  }
  out
}

///|
fn pdf_v2_model_annotations_for_page(
  annotations : Array[PdfV2AnnotationCandidate],
  page_index : Int,
) -> Array[PdfV2AnnotationCandidate] {
  let out : Array[PdfV2AnnotationCandidate] = []
  for annotation in annotations {
    if annotation.page_index == Some(page_index) {
      out.push(annotation)
    }
  }
  out
}

///|
fn pdf_v2_model_links_for_page(
  links : Array[PdfV2LinkCandidate],
  page_index : Int,
) -> Array[PdfV2LinkCandidate] {
  let out : Array[PdfV2LinkCandidate] = []
  for link in links {
    if link.page_index == Some(page_index) {
      out.push(link)
    }
  }
  out
}

///|
fn pdf_v2_model_forms_for_page(
  forms : Array[PdfV2FormCandidate],
  page_index : Int,
) -> Array[PdfV2FormCandidate] {
  let out : Array[PdfV2FormCandidate] = []
  for form in forms {
    if form.page_index == Some(page_index) {
      out.push(form)
    }
  }
  out
}

///|
fn pdf_v2_model_resources_for_page(
  resources : Array[PdfV2ResourceCandidate],
  page_index : Int,
) -> Array[PdfV2ResourceCandidate] {
  let out : Array[PdfV2ResourceCandidate] = []
  for resource in resources {
    if resource.page_index == Some(page_index) {
      out.push(resource)
    }
  }
  out
}

///|
fn pdf_v2_model_metadata_for_page(
  metadata : Array[PdfV2MetadataCandidate],
  page_index : Int,
) -> Array[PdfV2MetadataCandidate] {
  let out : Array[PdfV2MetadataCandidate] = []
  for item in metadata {
    if item.source_ref.page_index == Some(page_index) {
      out.push(item)
    }
  }
  out
}

///|
fn pdf_v2_model_source_order(refs : Array[PdfV2SourceRef]) -> Int? {
  let mut out : Int? = None
  for source_ref in refs {
    match source_ref.content_order_index {
      Some(order) =>
        match out {
          Some(current) if current <= order => ()
          _ => out = Some(order)
        }
      None => ()
    }
  }
  out
}

///|
fn pdf_v2_model_image_source_order(image : PdfV2ImageCandidate) -> Int? {
  match image.placement {
    Some(placement) =>
      match placement.source_order {
        Some(_) => placement.source_order
        None => image.source_ref.content_order_index
      }
    None => image.source_ref.content_order_index
  }
}

///|
fn pdf_v2_model_text_is_image_caption(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  let lower = t.to_lower()
  if lower.has_prefix("table ") ||
    lower.has_prefix("chart ") ||
    lower.has_prefix("表") {
    return false
  }
  lower.has_prefix("figure ") ||
  lower.has_prefix("fig. ") ||
  lower.has_prefix("fig ") ||
  lower.has_prefix("图 ")
}

///|
fn pdf_v2_model_block_caption_candidate(
  block : PdfV2BlockCandidate,
  image_order : Int?,
) -> Bool {
  if !pdf_v2_model_text_is_image_caption(block.text) {
    return false
  }
  match (image_order, pdf_v2_model_source_order(block.source_refs)) {
    (Some(img_order), Some(block_order)) => block_order >= img_order
    _ => true
  }
}

///|
fn pdf_v2_model_images_for_caption_page(
  images : Array[PdfV2ImageCandidate],
  page_index : Int?,
) -> Array[PdfV2ImageCandidate] {
  let out : Array[PdfV2ImageCandidate] = []
  for image in images {
    if image.page_index == page_index &&
      image.decode_status == PdfV2ImageDecodeStatus::DecodeAvailable {
      out.push(image)
    }
  }
  out
}

///|
fn pdf_v2_model_blocks_for_caption_page(
  blocks : Array[PdfV2BlockCandidate],
  page_index : Int?,
  image_order : Int?,
) -> Array[PdfV2BlockCandidate] {
  let out : Array[PdfV2BlockCandidate] = []
  for block in blocks {
    if block.page_index == page_index &&
      pdf_v2_model_block_caption_candidate(block, image_order) {
      out.push(block)
    }
  }
  out
}

///|
fn pdf_v2_model_caption_relation(
  image_order : Int?,
  block_order : Int?,
) -> PdfV2ImageCaptionRelation {
  match (image_order, block_order) {
    (Some(i), Some(b)) if b >= i => PdfV2ImageCaptionRelation::Below
    (Some(_), Some(_)) => PdfV2ImageCaptionRelation::Above
    _ => PdfV2ImageCaptionRelation::Nearby
  }
}

///|
fn pdf_v2_model_caption_for_image(
  image : PdfV2ImageCandidate,
  images : Array[PdfV2ImageCandidate],
  blocks : Array[PdfV2BlockCandidate],
) -> PdfV2ImageCaptionCandidate? {
  let page_images = pdf_v2_model_images_for_caption_page(
    images,
    image.page_index,
  )
  if page_images.length() != 1 {
    return None
  }
  let image_order = pdf_v2_model_image_source_order(image)
  let caption_blocks = pdf_v2_model_blocks_for_caption_page(
    blocks,
    image.page_index,
    image_order,
  )
  if caption_blocks.length() != 1 {
    return None
  }
  let caption_block = caption_blocks[0]
  let text = caption_block.text.trim().to_owned()
  if text == "" {
    return None
  }
  let block_order = pdf_v2_model_source_order(caption_block.source_refs)
  Some({
    image_object_ref: image.object_ref,
    asset_ref: None,
    caption_text: text,
    page_index: image.page_index,
    line_source_refs: caption_block.source_refs,
    relation: pdf_v2_model_caption_relation(image_order, block_order),
    confidence: 0.85,
    reason_tags: [
      "image_caption_candidate", "single_image_single_caption_marker", "parser_side_fact",
    ],
  })
}

///|
fn pdf_v2_model_attach_image_captions(
  images : Array[PdfV2ImageCandidate],
  blocks : Array[PdfV2BlockCandidate],
) -> Array[PdfV2ImageCandidate] {
  let out : Array[PdfV2ImageCandidate] = []
  for image in images {
    match pdf_v2_model_caption_for_image(image, images, blocks) {
      Some(caption) => out.push({ ..image, caption: Some(caption) })
      None => out.push(image)
    }
  }
  out
}

///|
fn pdf_v2_model_source_with_image_captions(
  source : PdfV2SourceDocument,
) -> PdfV2SourceDocument {
  {
    ..source,
    image_candidates: pdf_v2_model_attach_image_captions(
      source.image_candidates,
      source.block_candidates,
    ),
  }
}

///|
fn pdf_v2_model_page_from_source(
  page : PdfV2Page,
  source : PdfV2SourceDocument,
) -> PdfV2PageModel {
  {
    page_index: page.page_index,
    page_label: page.page_label,
    media_box: page.media_box,
    crop_box: page.crop_box,
    rotate: page.rotate,
    user_unit: page.user_unit,
    resources_present: page.resources_present,
    source_ref: page.source_ref,
    blocks: pdf_v2_model_blocks_for_page(
      source.block_candidates,
      page.page_index,
    ),
    lines: pdf_v2_model_lines_for_page(source.line_candidates, page.page_index),
    spans: pdf_v2_model_spans_for_page(source.span_candidates, page.page_index),
    chars: pdf_v2_model_chars_for_page(source.char_candidates, page.page_index),
    images: pdf_v2_model_images_for_page(
      source.image_candidates,
      page.page_index,
    ),
    inline_images: pdf_v2_model_inline_images_for_page(
      source.inline_image_candidates,
      page.page_index,
    ),
    annotations: pdf_v2_model_annotations_for_page(
      source.annotation_candidates,
      page.page_index,
    ),
    links: pdf_v2_model_links_for_page(source.link_candidates, page.page_index),
    tables: pdf_v2_model_tables_for_page(
      source.table_candidates,
      page.page_index,
    ),
    forms: pdf_v2_model_forms_for_page(source.form_candidates, page.page_index),
    resources: pdf_v2_model_resources_for_page(
      source.resource_candidates,
      page.page_index,
    ),
    metadata_refs: pdf_v2_model_metadata_for_page(
      source.metadata_candidates,
      page.page_index,
    ),
    page_warnings: page.warnings,
    page_risks: page.risks,
    text_blocks: [],
    layout_regions: [],
  }
}

///|
fn pdf_v2_model_pages_from_source(
  source : PdfV2SourceDocument,
) -> Array[PdfV2PageModel] {
  source.pages.map(fn(page) { pdf_v2_model_page_from_source(page, source) })
}

///|
fn pdf_v2_model_source_refs(
  source : PdfV2SourceDocument,
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for page in source.pages {
    refs.push(page.source_ref)
  }
  if refs.length() == 0 {
    refs.push(pdf_v2_document_source_ref())
  }
  refs
}

///|
fn pdf_v2_model_metadata_key_name(key : String?) -> String {
  match key {
    None => ""
    Some(value) => {
      let trimmed = value.trim().to_owned()
      let without_slash = if trimmed.has_prefix("/") {
        trimmed[1:].to_owned()
      } else {
        trimmed
      }
      without_slash.to_lower()
    }
  }
}

///|
fn pdf_v2_model_metadata_value(
  metadata : Array[PdfV2MetadataCandidate],
  key : String,
) -> String? {
  let expected = key.to_lower()
  for item in metadata {
    if item.kind != PdfV2MetadataKind::Info {
      continue
    }
    if pdf_v2_model_metadata_key_name(item.key) != expected {
      continue
    }
    match item.value {
      Some(value) => {
        let trimmed = value.trim().to_owned()
        if trimmed != "" {
          return Some(trimmed)
        }
      }
      None => ()
    }
  }
  None
}

///|
fn pdf_v2_model_metadata_refs(
  source : PdfV2SourceDocument,
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for item in source.metadata_candidates {
    refs.push(item.source_ref)
  }
  if refs.length() == 0 {
    pdf_v2_model_source_refs(source)
  } else {
    refs
  }
}

///|
fn pdf_v2_model_metadata(source : PdfV2SourceDocument) -> PdfV2DocumentMetadata {
  let metadata = source.metadata_candidates
  {
    title: pdf_v2_model_metadata_value(metadata, "title"),
    author: pdf_v2_model_metadata_value(metadata, "author"),
    subject: pdf_v2_model_metadata_value(metadata, "subject"),
    creator: pdf_v2_model_metadata_value(metadata, "creator"),
    producer: pdf_v2_model_metadata_value(metadata, "producer"),
    keywords: pdf_v2_model_metadata_value(metadata, "keywords"),
    created: pdf_v2_model_metadata_value(metadata, "creationdate"),
    modified: pdf_v2_model_metadata_value(metadata, "moddate"),
    source_refs: pdf_v2_model_metadata_refs(source),
  }
}

///|
pub fn pdf_v2_document_model_from_source(
  source : PdfV2SourceDocument,
) -> PdfV2ModelAssemblyResult {
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  warnings.append(source.warnings)
  risks.append(source.risks)
  let page_count = source.pages.length()

  let mut valid = pdf_v2_model_validate_page_facts(
    source.pages,
    warnings,
    risks,
  )
  valid = pdf_v2_model_validate_char_pages(
      source.char_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_span_pages(
      source.span_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_line_pages(
      source.line_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_block_pages(
      source.block_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_table_pages(
      source.table_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_image_pages(
      source.image_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_inline_image_pages(
      source.inline_image_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_annotation_pages(
      source.annotation_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_link_pages(
      source.link_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_form_pages(
      source.form_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_resource_pages(
      source.resource_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid

  if source.summary.page_count != page_count {
    warnings.push(pdf_v2_model_page_count_warning())
    risks.push(pdf_v2_model_page_count_risk())
  }

  if !valid {
    return PdfV2ModelAssemblyResult::ModelAssemblyErr(
      warnings, risks, "PDF v2 model assembly failed: invalid candidate page_index",
    )
  }

  let source = pdf_v2_model_source_with_image_captions(source)
  let layout = pdf_v2_model_empty_layout(pdf_v2_model_source_refs(source))
  let pages = pdf_v2_model_pages_from_source(source)
  PdfV2ModelAssemblyResult::ModelAssemblyOk({
    document_id: None,
    page_count,
    metadata: pdf_v2_model_metadata(source),
    pages,
    source_events: source.source_events,
    outlines: source.outline_candidates,
    destinations: source.destination_candidates,
    metadata_candidates: source.metadata_candidates,
    unsupported_capabilities: source.unsupported_capabilities,
    partial_fact_reports: source.partial_fact_reports,
    object_summary: source.object_summary,
    layout,
    warnings,
    risks,
    source_summary: source.summary,
    reconstruction_summary: source.reconstruction_summary,
    capabilities: pdf_v2_core_supported_capabilities(),
    one_pass: source.summary.one_pass_scan,
    no_fallback: !source.summary.fallback_used,
    model_version: "pdf-v2-phase9",
  })
}

///|
pub fn pdf_v2_open_document_model_from_path(
  path : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2ModelAssemblyResult {
  match pdf_v2_open_source_document_from_path(path, options) {
    SourceOpenOk(source) => pdf_v2_document_model_from_source(source)
    SourceOpenErr(warnings, risks, message) =>
      PdfV2ModelAssemblyResult::ModelAssemblyErr(warnings, risks, message)
  }
}
