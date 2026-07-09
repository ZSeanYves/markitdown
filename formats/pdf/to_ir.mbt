///|
type PdfBBox = @dpdfnative.PdfBBox

///|
type PdfPageGeometry = @dpdfnative.PdfPageGeometry

///|
type PdfNativeTextSpan = @dpdfnative.PdfNativeTextSpan

///|
type PdfNativeTextLine = @dpdfnative.PdfNativeTextLine

///|
type PdfNativeTextBlock = @dpdfnative.PdfNativeTextBlock

///|
type PdfNativeLinkCandidate = @dpdfnative.PdfNativeLinkCandidate

///|
type PdfNativeAnnotation = @dpdfnative.PdfNativeAnnotation

///|
type PdfNativeFormField = @dpdfnative.PdfNativeFormField

///|
type PdfNativeOutlineItem = @dpdfnative.PdfNativeOutlineItem

///|
type PdfNativeDestination = @dpdfnative.PdfNativeDestination

///|
type PdfNativePage = @dpdfnative.PdfNativePage

///|
type PdfNativeDocument = @dpdfnative.PdfNativeDocument

///|
fn make_pdf_bbox(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> PdfBBox {
  @dpdfnative.make_pdf_bbox(x, y, width, height)
}

///|
fn pdf_bbox_right(bbox : PdfBBox) -> Double {
  @dpdfnative.pdf_bbox_right(bbox)
}

///|
fn pdf_bbox_bottom(bbox : PdfBBox) -> Double {
  @dpdfnative.pdf_bbox_bottom(bbox)
}

///|
fn pdf_bbox_is_empty(bbox : PdfBBox) -> Bool {
  @dpdfnative.pdf_bbox_is_empty(bbox)
}

///|
fn pdf_union_bbox(left : PdfBBox, right : PdfBBox) -> PdfBBox {
  @dpdfnative.pdf_union_bbox(left, right)
}

///|
fn pdf_abs_double(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
pub fn pdf_native_document_to_ir(doc : PdfNativeDocument) -> @core.DocumentIR {
  pdf_native_document_to_ir_with_policies(
    doc,
    @parser.PdfHeaderFooterFilterPolicy::Disabled,
    @parser.PdfTableReconstructionPolicy::Disabled,
  )
}

///|
pub fn pdf_native_document_to_ir_with_policies(
  doc : PdfNativeDocument,
  header_footer_filter_policy : @parser.PdfHeaderFooterFilterPolicy,
  table_reconstruction_policy : @parser.PdfTableReconstructionPolicy,
) -> @core.DocumentIR {
  let blocks : Array[@core.CoreBlock] = []
  let assets : Array[@core.AssetRef] = []
  let asset_paths : Map[String, String] = Map([])
  let link_candidates : Array[@core.JsonValue] = []
  let annotation_items : Array[@core.JsonValue] = []
  let form_field_items : Array[@core.JsonValue] = []
  let outline_items : Array[@core.JsonValue] = []
  let header_footer_candidates = pdf_native_header_footer_candidates(doc)
  let table_candidates = pdf_native_table_candidates(
    doc, header_footer_candidates,
  )
  let lowering = pdf_native_lowering_plan(
    doc, header_footer_candidates, table_candidates, header_footer_filter_policy,
    table_reconstruction_policy,
  )
  let mut paragraph_count = 0
  let mut lowered_image_count = 0
  let mut image_candidate_count = 0
  let mut table_candidate_count = 0
  let mut artifact_candidate_count = 0
  let mut annotation_count = 0
  let mut destination_count = 0
  for page_index in 0..<doc.pages.length() {
    let page = doc.pages[page_index]
    image_candidate_count += page.image_candidates.length()
    table_candidate_count += page.table_candidates.length()
    artifact_candidate_count += page.artifact_candidates.length()
    annotation_count += page.annotations.length()
    destination_count += page.destinations.length()
    let page_plan = lowering.page_plans[page_index]
    for item in page_plan.items {
      match item {
        PdfNativeLoweringItem::Paragraph(text, source_ref) => {
          blocks.push(
            @core.make_block(@core.BlockKind::Paragraph, text, source_ref~),
          )
          paragraph_count += 1
        }
        PdfNativeLoweringItem::Table(table) => blocks.push(table)
      }
    }
    let lowered_images = pdf_native_lower_page_images(page, assets, asset_paths)
    blocks.append(lowered_images.0[:])
    lowered_image_count += lowered_images.1
    for link in page.link_candidates {
      link_candidates.push(
        pdf_native_link_candidate_json(link, page.geometry.page_no),
      )
    }
    for annotation in page.annotations {
      annotation_items.push(pdf_native_annotation_json(annotation))
    }
  }
  for form_field in doc.form_fields {
    form_field_items.push(pdf_native_form_field_json(form_field))
  }
  for outline_item in doc.outline_items {
    outline_items.push(pdf_native_outline_item_json(outline_item))
  }
  let document = @core.document_from_blocks(blocks)
  document.assets.append(assets[:])
  for entry in doc.metadata.to_array() {
    document.metadata.set(entry.0, entry.1)
  }
  document.metadata.set("format", @core.JsonValue::String("pdf"))
  document.metadata.set(
    "page_count",
    @core.JsonValue::Number(doc.pages.length().to_string()),
  )
  document.metadata.set(
    "pdf_native_projection",
    @core.JsonValue::String("unit_path"),
  )
  document.metadata.set(
    "pdf_grouping_strategy",
    @core.JsonValue::String("conservative_v1"),
  )
  document.metadata.set(
    "pdf_grouping_paragraph_count",
    @core.JsonValue::Number(paragraph_count.to_string()),
  )
  document.metadata.set(
    "pdf_header_footer_candidate_strategy",
    @core.JsonValue::String(header_footer_candidates.strategy),
  )
  document.metadata.set(
    "pdf_header_candidate_count",
    @core.JsonValue::Number(header_footer_candidates.header_count.to_string()),
  )
  document.metadata.set(
    "pdf_footer_candidate_count",
    @core.JsonValue::Number(header_footer_candidates.footer_count.to_string()),
  )
  document.metadata.set(
    "pdf_header_footer_candidate_count",
    @core.JsonValue::Number(
      header_footer_candidates.candidates.length().to_string(),
    ),
  )
  document.metadata.set(
    "pdf_table_candidate_strategy",
    @core.JsonValue::String(table_candidates.strategy),
  )
  document.metadata.set(
    "pdf_table_candidate_count",
    @core.JsonValue::Number(table_candidates.candidates.length().to_string()),
  )
  document.metadata.set(
    "pdf_table_row_candidate_count",
    @core.JsonValue::Number(table_candidates.row_count.to_string()),
  )
  document.metadata.set(
    "pdf_link_candidate_count",
    @core.JsonValue::Number(link_candidates.length().to_string()),
  )
  document.metadata.set(
    "image_count",
    @core.JsonValue::Number(lowered_image_count.to_string()),
  )
  document.metadata.set(
    "pdf_image_candidate_count",
    @core.JsonValue::Number(image_candidate_count.to_string()),
  )
  document.metadata.set(
    "pdf_native_annotation_count",
    @core.JsonValue::Number(annotation_count.to_string()),
  )
  document.metadata.set(
    "pdf_native_form_field_count",
    @core.JsonValue::Number(doc.form_fields.length().to_string()),
  )
  document.metadata.set(
    "pdf_native_outline_count",
    @core.JsonValue::Number(doc.outline_items.length().to_string()),
  )
  document.metadata.set(
    "pdf_native_destination_count",
    @core.JsonValue::Number(
      (destination_count + doc.named_destinations.length()).to_string(),
    ),
  )
  if header_footer_candidates.candidates.length() > 0 {
    document.metadata.set(
      "pdf_header_footer_candidates",
      @core.JsonValue::Array(header_footer_candidates.candidates),
    )
  }
  if table_candidates.candidates.length() > 0 {
    document.metadata.set(
      "pdf_table_candidates",
      @core.JsonValue::Array(table_candidates.candidates),
    )
  }
  if link_candidates.length() > 0 {
    document.metadata.set(
      "pdf_link_candidates",
      @core.JsonValue::Array(link_candidates),
    )
  }
  if annotation_items.length() > 0 &&
    document.metadata.get("pdf_native_annotations") == None {
    document.metadata.set(
      "pdf_native_annotations",
      @core.JsonValue::Array(annotation_items),
    )
  }
  if form_field_items.length() > 0 {
    document.metadata.set(
      "pdf_native_form_fields",
      @core.JsonValue::Array(form_field_items),
    )
  }
  if outline_items.length() > 0 {
    document.metadata.set(
      "pdf_native_outline_items",
      @core.JsonValue::Array(outline_items),
    )
  }
  document.blocks.append(pdf_native_appendix_blocks(document.metadata)[:])
  let diagnostics = pdf_native_projection_diagnostics(
    doc.diagnostics,
    document.blocks.length(),
    paragraph_count,
    link_candidates.length(),
    annotation_count,
    doc.form_fields.length(),
    doc.outline_items.length(),
    destination_count + doc.named_destinations.length(),
    doc.pages.length(),
    lowered_image_count,
    assets.length(),
    image_candidate_count,
    table_candidate_count,
    artifact_candidate_count,
    header_footer_candidates,
    table_candidates,
    lowering,
  )
  @core.document_with_diagnostics(document, diagnostics)
}

///|
pub fn pdf_native_document_to_blocks_with_policies(
  doc : PdfNativeDocument,
  header_footer_filter_policy : @parser.PdfHeaderFooterFilterPolicy,
) -> (@core.DocumentMetadata, Array[@core.CoreBlock], @core.Diagnostics) {
  let blocks : Array[@core.CoreBlock] = []
  let link_candidates : Array[@core.JsonValue] = []
  let annotation_items : Array[@core.JsonValue] = []
  let form_field_items : Array[@core.JsonValue] = []
  let outline_items : Array[@core.JsonValue] = []
  let header_footer_candidates = pdf_native_header_footer_candidates(doc)
  let table_candidates = pdf_native_table_candidates(
    doc, header_footer_candidates,
  )
  let mut paragraph_count = 0
  let mut image_candidate_count = 0
  let mut table_candidate_count = 0
  let mut artifact_candidate_count = 0
  let mut annotation_count = 0
  let mut destination_count = 0
  for page in doc.pages {
    image_candidate_count += page.image_candidates.length()
    table_candidate_count += page.table_candidates.length()
    artifact_candidate_count += page.artifact_candidates.length()
    annotation_count += page.annotations.length()
    destination_count += page.destinations.length()
    let page_lines = pdf_native_page_blocks(
      page, header_footer_candidates, header_footer_filter_policy,
    )
    blocks.append(page_lines[:])
    paragraph_count += page_lines.length()
    for link in page.link_candidates {
      link_candidates.push(
        pdf_native_link_candidate_json(link, page.geometry.page_no),
      )
    }
    for annotation in page.annotations {
      annotation_items.push(pdf_native_annotation_json(annotation))
    }
  }
  for form_field in doc.form_fields {
    form_field_items.push(pdf_native_form_field_json(form_field))
  }
  for outline_item in doc.outline_items {
    outline_items.push(pdf_native_outline_item_json(outline_item))
  }
  let metadata : @core.DocumentMetadata = Map([])
  for entry in doc.metadata.to_array() {
    metadata.set(entry.0, entry.1)
  }
  metadata.set("format", @core.JsonValue::String("pdf"))
  metadata.set(
    "page_count",
    @core.JsonValue::Number(doc.pages.length().to_string()),
  )
  metadata.set(
    "pdf_native_projection",
    @core.JsonValue::String("product_block_stream"),
  )
  metadata.set(
    "pdf_grouping_strategy",
    @core.JsonValue::String("conservative_v1"),
  )
  metadata.set(
    "pdf_grouping_paragraph_count",
    @core.JsonValue::Number(paragraph_count.to_string()),
  )
  metadata.set(
    "pdf_header_footer_candidate_strategy",
    @core.JsonValue::String(header_footer_candidates.strategy),
  )
  metadata.set(
    "pdf_header_candidate_count",
    @core.JsonValue::Number(header_footer_candidates.header_count.to_string()),
  )
  metadata.set(
    "pdf_footer_candidate_count",
    @core.JsonValue::Number(header_footer_candidates.footer_count.to_string()),
  )
  metadata.set(
    "pdf_header_footer_candidate_count",
    @core.JsonValue::Number(
      header_footer_candidates.candidates.length().to_string(),
    ),
  )
  metadata.set(
    "pdf_table_candidate_strategy",
    @core.JsonValue::String(table_candidates.strategy),
  )
  metadata.set(
    "pdf_table_candidate_count",
    @core.JsonValue::Number(table_candidates.candidates.length().to_string()),
  )
  metadata.set(
    "pdf_table_row_candidate_count",
    @core.JsonValue::Number(table_candidates.row_count.to_string()),
  )
  metadata.set(
    "pdf_link_candidate_count",
    @core.JsonValue::Number(link_candidates.length().to_string()),
  )
  metadata.set(
    "pdf_native_annotation_count",
    @core.JsonValue::Number(annotation_count.to_string()),
  )
  metadata.set(
    "pdf_native_form_field_count",
    @core.JsonValue::Number(doc.form_fields.length().to_string()),
  )
  metadata.set(
    "pdf_native_outline_count",
    @core.JsonValue::Number(doc.outline_items.length().to_string()),
  )
  metadata.set(
    "pdf_native_destination_count",
    @core.JsonValue::Number(
      (destination_count + doc.named_destinations.length()).to_string(),
    ),
  )
  if header_footer_candidates.candidates.length() > 0 {
    metadata.set(
      "pdf_header_footer_candidates",
      @core.JsonValue::Array(header_footer_candidates.candidates),
    )
  }
  if table_candidates.candidates.length() > 0 {
    metadata.set(
      "pdf_table_candidates",
      @core.JsonValue::Array(table_candidates.candidates),
    )
  }
  if link_candidates.length() > 0 {
    metadata.set("pdf_link_candidates", @core.JsonValue::Array(link_candidates))
  }
  if annotation_items.length() > 0 {
    metadata.set(
      "pdf_native_annotations",
      @core.JsonValue::Array(annotation_items),
    )
  }
  if form_field_items.length() > 0 {
    metadata.set(
      "pdf_native_form_fields",
      @core.JsonValue::Array(form_field_items),
    )
  }
  if outline_items.length() > 0 {
    metadata.set(
      "pdf_native_outline_items",
      @core.JsonValue::Array(outline_items),
    )
  }
  let diagnostics = pdf_native_stream_bridge_diagnostics(
    doc.diagnostics,
    blocks.length(),
    paragraph_count,
    link_candidates.length(),
    annotation_count,
    doc.form_fields.length(),
    doc.outline_items.length(),
    destination_count + doc.named_destinations.length(),
    doc.pages.length(),
    image_candidate_count,
    table_candidate_count,
    artifact_candidate_count,
    header_footer_candidates,
    table_candidates,
  )
  (metadata, blocks, diagnostics)
}

///|
pub fn pdf_native_page_to_paragraph_blocks(
  page : PdfNativePage,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  for text_block_index in 0..<page.text_blocks.length() {
    let block_index = text_block_index + 1
    let text_block = page.text_blocks[text_block_index]
    let paragraph = pdf_native_text_block_paragraph(
      page, text_block, block_index,
    )
    match paragraph {
      Some((text, source_ref)) =>
        blocks.push(
          @core.make_block(@core.BlockKind::Paragraph, text, source_ref~),
        )
      None => ()
    }
  }
  blocks
}

///|
fn pdf_native_lower_page_images(
  page : PdfNativePage,
  assets : Array[@core.AssetRef],
  asset_paths : Map[String, String],
) -> (Array[@core.CoreBlock], Int) {
  let blocks : Array[@core.CoreBlock] = []
  let mut lowered_count = 0
  for image_index in 0..<page.image_candidates.length() {
    match
      pdf_native_lower_image_candidate(
        page,
        page.image_candidates[image_index],
        image_index + 1,
        assets,
        asset_paths,
      ) {
      Some(block) => {
        blocks.push(block)
        lowered_count += 1
      }
      None => ()
    }
  }
  (blocks, lowered_count)
}

///|
fn pdf_native_lower_image_candidate(
  page : PdfNativePage,
  candidate : @dpdfnative.PdfNativeImageCandidate,
  image_index : Int,
  assets : Array[@core.AssetRef],
  asset_paths : Map[String, String],
) -> @core.CoreBlock? {
  let asset = match candidate.asset_ref {
    Some(value) => value
    None => return None
  }
  let materialized_asset = pdf_native_materialize_image_asset(
    asset, assets, asset_paths,
  )
  let source_ref = match candidate.source_ref {
    Some(value) => value
    None => materialized_asset.source_ref.unwrap_or(@core.empty_source_ref())
  }
  let block = @core.make_block(@core.BlockKind::Image, "", source_ref~)
  block.attrs.set("asset_id", materialized_asset.asset_id)
  block.attrs.set("path", materialized_asset.path.unwrap_or("#"))
  block.attrs.set(
    "alt",
    pdf_native_image_alt_text(
      page.geometry.page_no,
      image_index,
      materialized_asset,
    ),
  )
  match materialized_asset.mime_type {
    Some(value) => block.attrs.set("mime_type", value)
    None => ()
  }
  match materialized_asset.attrs.get("source_path") {
    Some(value) => block.attrs.set("source_path", value)
    None => ()
  }
  match materialized_asset.attrs.get("title") {
    Some(value) if value.trim() != "" => block.attrs.set("title", value)
    _ => ()
  }
  Some(block)
}

///|
fn pdf_native_materialize_image_asset(
  asset : @core.AssetRef,
  assets : Array[@core.AssetRef],
  asset_paths : Map[String, String],
) -> @core.AssetRef {
  match asset_paths.get(asset.asset_id) {
    Some(_) =>
      for existing in assets {
        if existing.asset_id == asset.asset_id {
          return existing
        }
      }
    None => ()
  }
  let path = match asset.path {
    Some(value) if value.trim() != "" => value.trim().to_owned()
    _ =>
      "assets/image" +
      pdf_native_two_digits(assets.length() + 1) +
      "." +
      pdf_native_asset_ext(asset)
  }
  let next_asset = { ..asset, path: Some(path) }
  asset_paths.set(asset.asset_id, path)
  assets.push(next_asset)
  next_asset
}

///|
fn pdf_native_image_alt_text(
  page_no : Int,
  image_index : Int,
  asset : @core.AssetRef,
) -> String {
  match asset.attrs.get("alt") {
    Some(value) if value.trim() != "" && value.trim() != "image" =>
      value.trim().to_owned()
    _ => "page-" + page_no.to_string() + "-image-" + image_index.to_string()
  }
}

///|
fn pdf_native_asset_ext(asset : @core.AssetRef) -> String {
  match asset.attrs.get("file_ext") {
    Some(value) if value.trim() != "" => value.trim().to_owned()
    _ =>
      match asset.mime_type {
        Some("image/jpeg") => "jpg"
        Some("image/png") => "png"
        Some("image/gif") => "gif"
        Some("image/bmp") => "bmp"
        Some("image/webp") => "webp"
        Some("image/jp2") => "jp2"
        _ => "bin"
      }
  }
}

///|
fn pdf_native_two_digits(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
priv enum PdfNativeLoweringItem {
  Paragraph(String, @core.SourceRef)
  Table(@core.CoreBlock)
}

///|
priv struct PdfNativePageLoweringPlan {
  items : Array[PdfNativeLoweringItem]
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
        let paragraph = pdf_native_text_block_paragraph(
          page, text_block, block_index,
        )
        match paragraph {
          Some((text, source_ref)) => {
            header_footer_removed_candidates.push(text)
            header_footer_removed_source_refs.push(
              pdf_native_source_ref_metric_string(source_ref),
            )
          }
          None => ()
        }
        continue
      }
      let paragraph = pdf_native_text_block_paragraph(
        page, text_block, block_index,
      )
      match paragraph {
        Some((text, source_ref)) =>
          match
            pdf_native_matching_table_region(
              page, text_block, block_index, source_ref, page_table_regions,
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
                    items.push(
                      PdfNativeLoweringItem::Paragraph(text, source_ref),
                    )
                  }
                }
              }
            None =>
              items.push(PdfNativeLoweringItem::Paragraph(text, source_ref))
          }
        None => ()
      }
    }
    page_plans.push({ items, })
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
    if lowering.table_reconstruction_table_count == 0 {
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

///|
priv struct PdfNativeHeaderFooterCandidateSummary {
  strategy : String
  header_count : Int
  footer_count : Int
  candidates : Array[@core.JsonValue]
  skipped_reason : String?
}

///|
priv struct PdfNativeHeaderFooterLineCandidate {
  kind : String
  normalized_text : String
  text : String
  pages : Array[Int]
  page_count : Int
  representative_bbox : PdfBBox
  representative_source_ref : @core.SourceRef?
  confidence : String
  reason : String
}

///|
priv struct PdfNativeHeaderFooterBucket {
  kind : String
  normalized_text : String
  text : String
  pages : Array[Int]
  representative_bbox : PdfBBox
  representative_source_ref : @core.SourceRef?
  match_count : Int
  min_x : Double
  max_x : Double
}

///|
priv struct PdfNativeTableCandidateSummary {
  strategy : String
  row_count : Int
  candidates : Array[@core.JsonValue]
  skipped_reason : String?
}

///|
priv struct PdfNativeTableRowCandidate {
  page_no : Int
  text : String
  bbox : PdfBBox
  source_ref : @core.SourceRef?
  reading_order_index : Int?
  line_start : Int?
  line_end : Int?
  aligned_xs : Array[Double]
}

///|
priv struct PdfNativeTableRegionCandidate {
  page_no : Int
  bbox : PdfBBox
  row_count : Int
  column_alignment_count : Int
  source_refs : Array[@core.SourceRef]
  reading_order_indices : Array[Int]
  line_start : Int?
  line_end : Int?
  confidence : String
  reason : String
}

///|
fn pdf_native_header_footer_candidates(
  doc : PdfNativeDocument,
) -> PdfNativeHeaderFooterCandidateSummary {
  let strategy = "conservative_v1"
  if doc.pages.length() < 2 {
    return {
      strategy,
      header_count: 0,
      footer_count: 0,
      candidates: [],
      skipped_reason: None,
    }
  }
  let geometry_missing = doc.pages.any(page => {
    page.geometry.width <= 0.0 || page.geometry.height <= 0.0
  })
  if geometry_missing {
    return {
      strategy,
      header_count: 0,
      footer_count: 0,
      candidates: [],
      skipped_reason: Some("no_page_geometry"),
    }
  }
  let buckets : Map[String, PdfNativeHeaderFooterBucket] = Map([])
  for page in doc.pages {
    for line in pdf_native_page_header_footer_line_candidates(page) {
      let text = pdf_native_line_text(line)
      let normalized_text = pdf_native_header_footer_normalized_text(text)
      if normalized_text == "" {
        continue
      }
      let kind = match pdf_native_line_band_kind(page.geometry, line.bbox) {
        Some(value) => value
        None => continue
      }
      let key = kind + "\n" + normalized_text
      match buckets.get(key) {
        Some(bucket) => {
          if bucket.pages.contains(page.geometry.page_no) {
            continue
          }
          let next_bucket = {
            ..bucket,
            pages: bucket.pages + [page.geometry.page_no],
            match_count: bucket.match_count + 1,
            min_x: pdf_native_double_min(bucket.min_x, line.bbox.x),
            max_x: pdf_native_double_max(bucket.max_x, line.bbox.x),
          }
          buckets.set(key, next_bucket)
        }
        None =>
          buckets.set(key, {
            kind,
            normalized_text,
            text,
            pages: [page.geometry.page_no],
            representative_bbox: line.bbox,
            representative_source_ref: pdf_native_line_preferred_source_ref(
              line,
            ),
            match_count: 1,
            min_x: line.bbox.x,
            max_x: line.bbox.x,
          })
      }
    }
  }
  let candidate_structs : Array[PdfNativeHeaderFooterLineCandidate] = []
  for entry in buckets.to_array() {
    let bucket = entry.1
    if !pdf_native_header_footer_bucket_is_candidate(bucket, doc.pages.length()) {
      continue
    }
    let sorted_pages : Array[Int] = []
    sorted_pages.append(bucket.pages[:])
    sorted_pages.sort()
    candidate_structs.push({
      kind: bucket.kind,
      normalized_text: bucket.normalized_text,
      text: bucket.text,
      pages: sorted_pages,
      page_count: sorted_pages.length(),
      representative_bbox: bucket.representative_bbox,
      representative_source_ref: bucket.representative_source_ref,
      confidence: pdf_native_header_footer_candidate_confidence(
        sorted_pages.length(),
        doc.pages.length(),
      ),
      reason: if bucket.kind == "header" {
        "repeated_top_band"
      } else {
        "repeated_bottom_band"
      },
    })
  }
  candidate_structs.sort_by(fn(left, right) {
    if left.kind < right.kind {
      -1
    } else if left.kind > right.kind {
      1
    } else if left.normalized_text < right.normalized_text {
      -1
    } else if left.normalized_text > right.normalized_text {
      1
    } else {
      0
    }
  })
  let candidate_json = candidate_structs.map(candidate => {
    pdf_native_header_footer_candidate_json(candidate)
  })
  let header_count = candidate_structs
    .filter(fn(candidate) { candidate.kind == "header" })
    .length()
  let footer_count = candidate_structs.length() - header_count
  {
    strategy,
    header_count,
    footer_count,
    candidates: candidate_json,
    skipped_reason: None,
  }
}

///|
fn pdf_native_table_candidates(
  doc : PdfNativeDocument,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
) -> PdfNativeTableCandidateSummary {
  let strategy = "conservative_v1"
  let table_row_candidates : Array[PdfNativeTableRowCandidate] = []
  for page in doc.pages {
    table_row_candidates.append(
      pdf_native_page_table_row_candidates(page, header_footer_candidates)[:],
    )
  }
  if table_row_candidates.length() == 0 {
    return { strategy, row_count: 0, candidates: [], skipped_reason: None }
  }
  let region_candidates : Array[PdfNativeTableRegionCandidate] = []
  let page_nos : Array[Int] = []
  for row in table_row_candidates {
    if !page_nos.contains(row.page_no) {
      page_nos.push(row.page_no)
    }
  }
  page_nos.sort()
  for page_no in page_nos {
    let page_rows : Array[PdfNativeTableRowCandidate] = []
    for row in table_row_candidates {
      if row.page_no == page_no {
        page_rows.push(row)
      }
    }
    page_rows.sort_by(fn(left, right) {
      if left.reading_order_index.unwrap_or(1_000_000) <
        right.reading_order_index.unwrap_or(1_000_000) {
        -1
      } else if left.reading_order_index.unwrap_or(1_000_000) >
        right.reading_order_index.unwrap_or(1_000_000) {
        1
      } else if left.bbox.y > right.bbox.y {
        -1
      } else if left.bbox.y < right.bbox.y {
        1
      } else {
        0
      }
    })
    let current_rows : Array[PdfNativeTableRowCandidate] = []
    for row in page_rows {
      if current_rows.length() == 0 {
        current_rows.push(row)
        continue
      }
      if pdf_native_table_row_should_join_region(current_rows, row) {
        current_rows.push(row)
      } else {
        match pdf_native_table_region_candidate(current_rows) {
          Some(region) => region_candidates.push(region)
          None => ()
        }
        current_rows.clear()
        current_rows.push(row)
      }
    }
    if current_rows.length() > 0 {
      match pdf_native_table_region_candidate(current_rows) {
        Some(region) => region_candidates.push(region)
        None => ()
      }
    }
  }
  region_candidates.sort_by(fn(left, right) {
    if left.page_no < right.page_no {
      -1
    } else if left.page_no > right.page_no {
      1
    } else if left.line_start.unwrap_or(1_000_000) <
      right.line_start.unwrap_or(1_000_000) {
      -1
    } else if left.line_start.unwrap_or(1_000_000) >
      right.line_start.unwrap_or(1_000_000) {
      1
    } else {
      0
    }
  })
  {
    strategy,
    row_count: table_row_candidates.length(),
    candidates: region_candidates.map(region => {
      pdf_native_table_region_candidate_json(region)
    }),
    skipped_reason: None,
  }
}

///|
fn pdf_native_page_header_footer_line_candidates(
  page : PdfNativePage,
) -> Array[PdfNativeTextLine] {
  let lines : Array[PdfNativeTextLine] = []
  for text_block in page.text_blocks {
    for line in text_block.lines {
      let text = pdf_native_line_text(line)
      if text == "" {
        continue
      }
      if pdf_bbox_is_empty(line.bbox) {
        continue
      }
      if pdf_native_line_band_kind(page.geometry, line.bbox) == None {
        continue
      }
      if !pdf_native_header_footer_text_is_eligible(text) {
        continue
      }
      lines.push(line)
    }
  }
  lines
}

///|
fn pdf_native_line_band_kind(
  geometry : PdfPageGeometry,
  bbox : PdfBBox,
) -> String? {
  if geometry.height <= 0.0 {
    return None
  }
  let top_threshold = geometry.height * 0.85
  let bottom_threshold = geometry.height * 0.15
  let y0 = bbox.y
  let y1 = pdf_bbox_bottom(bbox)
  if y1 >= top_threshold {
    Some("header")
  } else if y0 <= bottom_threshold {
    Some("footer")
  } else {
    None
  }
}

///|
fn pdf_native_header_footer_text_is_eligible(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if trimmed.length() > 120 {
    return false
  }
  if pdf_native_line_looks_like_list_boundary_text(trimmed) {
    return false
  }
  if pdf_native_line_looks_table_like(trimmed) {
    return false
  }
  true
}

///|
fn pdf_native_header_footer_normalized_text(text : String) -> String {
  let chars : Array[Char] = []
  let mut previous_space = false
  for ch in text.trim().to_owned().to_array() {
    let lowered = pdf_native_ascii_lower_char(ch)
    let is_space = lowered == ' ' ||
      lowered == '\n' ||
      lowered == '\r' ||
      lowered == '\t'
    if is_space {
      if !previous_space {
        chars.push(' ')
      }
      previous_space = true
    } else {
      chars.push(lowered)
      previous_space = false
    }
  }
  String::from_array(chars).trim().to_owned()
}

///|
fn pdf_native_ascii_lower_char(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    Int::unsafe_to_char(ch.to_int() + 32)
  } else {
    ch
  }
}

///|
fn pdf_native_header_footer_bucket_is_candidate(
  bucket : PdfNativeHeaderFooterBucket,
  total_pages : Int,
) -> Bool {
  if bucket.pages.length() < 2 {
    return false
  }
  if bucket.max_x - bucket.min_x > 24.0 {
    return false
  }
  if total_pages >= 4 {
    bucket.pages.length() * 2 >= total_pages
  } else {
    true
  }
}

///|
fn pdf_native_header_footer_candidate_confidence(
  page_count : Int,
  total_pages : Int,
) -> String {
  if total_pages > 0 && page_count == total_pages {
    "high"
  } else if total_pages > 0 && page_count * 2 >= total_pages {
    "medium"
  } else {
    "low"
  }
}

///|
fn pdf_native_header_footer_candidate_json(
  candidate : PdfNativeHeaderFooterLineCandidate,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("kind", @core.JsonValue::String(candidate.kind))
  payload.set(
    "normalized_text",
    @core.JsonValue::String(candidate.normalized_text),
  )
  payload.set("text", @core.JsonValue::String(candidate.text))
  payload.set(
    "page_count",
    @core.JsonValue::Number(candidate.page_count.to_string()),
  )
  payload.set("pages", pdf_native_int_array_json(candidate.pages))
  payload.set("bbox", pdf_native_bbox_json(candidate.representative_bbox))
  payload.set("confidence", @core.JsonValue::String(candidate.confidence))
  payload.set("reason", @core.JsonValue::String(candidate.reason))
  match candidate.representative_source_ref {
    Some(source_ref) =>
      payload.set("source_ref", pdf_native_source_ref_json(source_ref))
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_line_preferred_source_ref(
  line : PdfNativeTextLine,
) -> @core.SourceRef? {
  match line.source_ref {
    Some(source_ref) => Some(source_ref)
    None => {
      for span in line.spans {
        match span.source_ref {
          Some(source_ref) => return Some(source_ref)
          None => ()
        }
      }
      None
    }
  }
}

///|
fn pdf_native_line_candidate_source_ref(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  text_block_index : Int,
  line : PdfNativeTextLine,
  line_index : Int,
  merge_group : String,
) -> @core.SourceRef {
  let base = match pdf_native_line_preferred_source_ref(line) {
    Some(source_ref) => source_ref
    None => pdf_native_line_base_source_ref(line)
  }
  let line_no = base.line_start.unwrap_or(line_index + 1)
  let next = {
    ..base,
    format: Some(base.format.unwrap_or("pdf")),
    page: Some(base.page.unwrap_or(page.geometry.page_no)),
    bbox: pdf_native_effective_bbox(base.bbox, line.bbox),
    line_start: Some(line_no),
    line_end: Some(base.line_end.unwrap_or(line_no)),
  }
  if next.extra.get("page_no") == None {
    next.extra.set("page_no", page.geometry.page_no.to_string())
  }
  next.extra.set("pdf_text_block_index", text_block_index.to_string())
  next.extra.set("pdf_merge_group", merge_group)
  next.extra.set("pdf_line_index", line_no.to_string())
  next.extra.set(
    "pdf_line_end_index",
    next.line_end.unwrap_or(line_no).to_string(),
  )
  match text_block.reading_order_index {
    Some(value) => next.extra.set("reading_order_index", value.to_string())
    None =>
      match line.reading_order_index {
        Some(value) => next.extra.set("reading_order_index", value.to_string())
        None => ()
      }
  }
  next
}

///|
fn pdf_native_source_ref_json(source_ref : @core.SourceRef) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  match source_ref.file_id {
    Some(file_id) => payload.set("file_id", @core.JsonValue::String(file_id))
    None => ()
  }
  match source_ref.format {
    Some(format) => payload.set("format", @core.JsonValue::String(format))
    None => ()
  }
  match source_ref.page {
    Some(page_no) =>
      payload.set("page", @core.JsonValue::Number(page_no.to_string()))
    None => ()
  }
  match source_ref.line_start {
    Some(line_start) =>
      payload.set("line_start", @core.JsonValue::Number(line_start.to_string()))
    None => ()
  }
  match source_ref.line_end {
    Some(line_end) =>
      payload.set("line_end", @core.JsonValue::Number(line_end.to_string()))
    None => ()
  }
  match source_ref.bbox {
    Some(bbox) => payload.set("bbox", pdf_native_core_bbox_json(bbox))
    None => ()
  }
  let extra_entries : Map[String, @core.JsonValue] = Map([])
  for entry in source_ref.extra.to_array() {
    extra_entries.set(entry.0, @core.JsonValue::String(entry.1))
  }
  if extra_entries.length() > 0 {
    payload.set("extra", @core.JsonValue::Object(extra_entries))
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_int_array_json(values : Array[Int]) -> @core.JsonValue {
  @core.JsonValue::Array(
    values.map(value => @core.JsonValue::Number(value.to_string())),
  )
}

///|
fn pdf_native_line_looks_like_list_boundary_text(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let chars = trimmed.to_array()
  let first = chars[0]
  if first == '-' || first == '*' || first == '\u{2022}' {
    return true
  }
  let mut index = 0
  while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
    index += 1
  }
  index > 0 &&
  index < chars.length() &&
  (chars[index] == '.' || chars[index] == ')')
}

///|
fn pdf_native_line_looks_table_like(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.contains(" | ") || trimmed.contains("\t")
}

///|
fn pdf_native_double_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn pdf_native_double_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn pdf_native_page_table_row_candidates(
  page : PdfNativePage,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
) -> Array[PdfNativeTableRowCandidate] {
  let rows : Array[PdfNativeTableRowCandidate] = []
  for text_block in page.text_blocks {
    for line in text_block.lines {
      match
        pdf_native_table_row_candidate_from_line(
          page, line, header_footer_candidates,
        ) {
        Some(row) => rows.push(row)
        None => ()
      }
    }
  }
  rows
}

///|
fn pdf_native_table_row_candidate_from_line(
  page : PdfNativePage,
  line : PdfNativeTextLine,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
) -> PdfNativeTableRowCandidate? {
  if pdf_bbox_is_empty(line.bbox) {
    return None
  }
  let text = pdf_native_line_text(line)
  if !pdf_native_table_row_text_is_eligible(text) {
    return None
  }
  if pdf_native_line_band_kind(page.geometry, line.bbox) is Some(_) {
    return None
  }
  let source_ref = pdf_native_line_preferred_source_ref(line)
  if pdf_native_line_matches_header_footer_candidate(
      line, text, source_ref, header_footer_candidates,
    ) {
    return None
  }
  let aligned_xs = pdf_native_table_row_alignment_positions(line, text)
  if aligned_xs.length() < 2 {
    return None
  }
  let base = pdf_native_line_base_source_ref(line)
  Some({
    page_no: base.page.unwrap_or(page.geometry.page_no),
    text,
    bbox: line.bbox,
    source_ref,
    reading_order_index: line.reading_order_index,
    line_start: base.line_start,
    line_end: Some(base.line_end.unwrap_or(base.line_start.unwrap_or(1))),
    aligned_xs,
  })
}

///|
fn pdf_native_table_row_text_is_eligible(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if trimmed.length() > 160 {
    return false
  }
  if pdf_native_line_looks_like_list_boundary_text(trimmed) {
    return false
  }
  if pdf_native_line_looks_table_like(trimmed) {
    return true
  }
  let tokens = pdf_native_table_text_tokens(trimmed)
  if tokens.length() < 3 {
    return false
  }
  let mut alpha_count = 0
  for token in tokens {
    if pdf_native_table_token_has_letter(token) {
      alpha_count += 1
    }
  }
  alpha_count >= 2
}

///|
fn pdf_native_line_matches_header_footer_candidate(
  line : PdfNativeTextLine,
  text : String,
  source_ref : @core.SourceRef?,
  summary : PdfNativeHeaderFooterCandidateSummary,
) -> Bool {
  let normalized_text = pdf_native_header_footer_normalized_text(text)
  for candidate in summary.candidates {
    match candidate {
      @core.JsonValue::Object(payload) => {
        let same_text = payload.get("normalized_text") ==
          Some(@core.JsonValue::String(normalized_text))
        let same_bbox = payload.get("bbox") ==
          Some(pdf_native_bbox_json(line.bbox))
        let same_line = match (payload.get("source_ref"), source_ref) {
          (Some(@core.JsonValue::Object(candidate_ref)), Some(current_ref)) =>
            candidate_ref.get("page") ==
            current_ref.page.map(page => {
              @core.JsonValue::Number(page.to_string())
            }) &&
            candidate_ref.get("line_start") ==
            current_ref.line_start.map(line_start => {
              @core.JsonValue::Number(line_start.to_string())
            })
          _ => false
        }
        if same_text && (same_bbox || same_line) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn pdf_native_table_row_alignment_positions(
  line : PdfNativeTextLine,
  text : String,
) -> Array[Double] {
  let xs : Array[Double] = []
  for span in line.spans {
    let trimmed = span.text.trim().to_owned()
    if trimmed == "" {
      continue
    }
    xs.push(span.bbox.x)
  }
  if xs.length() >= 2 {
    return pdf_native_distinct_sorted_xs(xs)
  }
  if !text.contains("  ") {
    return []
  }
  let tokens = pdf_native_table_text_tokens(text)
  if tokens.length() < 3 {
    return []
  }
  let fallback_xs : Array[Double] = []
  let mut index = 0
  for _token in tokens {
    fallback_xs.push(line.bbox.x + index.to_double() * 24.0)
    index += 1
  }
  pdf_native_distinct_sorted_xs(fallback_xs)
}

///|
fn pdf_native_distinct_sorted_xs(values : Array[Double]) -> Array[Double] {
  let xs : Array[Double] = []
  xs.append(values[:])
  xs.sort_by(fn(left, right) {
    if left < right {
      -1
    } else if left > right {
      1
    } else {
      0
    }
  })
  let distinct : Array[Double] = []
  for value in xs {
    if distinct.length() == 0 ||
      pdf_abs_double(value - distinct[distinct.length() - 1]) > 6.0 {
      distinct.push(value)
    }
  }
  distinct
}

///|
fn pdf_native_table_text_tokens(text : String) -> Array[String] {
  let tokens : Array[String] = []
  for token in text.split(" ") {
    let trimmed = token.trim().to_owned()
    if trimmed != "" {
      tokens.push(trimmed)
    }
  }
  tokens
}

///|
fn pdf_native_table_token_has_letter(token : String) -> Bool {
  for ch in token.to_array() {
    if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
      return true
    }
  }
  false
}

///|
fn pdf_native_table_row_should_join_region(
  current_rows : Array[PdfNativeTableRowCandidate],
  next_row : PdfNativeTableRowCandidate,
) -> Bool {
  let previous = current_rows[current_rows.length() - 1]
  let previous_index = previous.reading_order_index.unwrap_or(-1)
  let next_index = next_row.reading_order_index.unwrap_or(-1)
  if previous_index >= 0 && next_index >= 0 && next_index - previous_index > 2 {
    return false
  }
  let gap = previous.bbox.y - pdf_bbox_bottom(next_row.bbox)
  if gap < -4.0 || gap > 32.0 {
    return false
  }
  let current_alignment = pdf_native_table_region_alignment_positions(
    current_rows,
  )
  let overlap = pdf_native_table_alignment_overlap_count(
    current_alignment,
    next_row.aligned_xs,
  )
  overlap >= 2
}

///|
fn pdf_native_table_region_candidate(
  rows : Array[PdfNativeTableRowCandidate],
) -> PdfNativeTableRegionCandidate? {
  if rows.length() < 2 {
    return None
  }
  let alignment_positions = pdf_native_table_region_alignment_positions(rows)
  if alignment_positions.length() < 2 {
    return None
  }
  let mut bbox = make_pdf_bbox(0.0, 0.0, 0.0, 0.0)
  let source_refs : Array[@core.SourceRef] = []
  let reading_order_indices : Array[Int] = []
  for row in rows {
    bbox = if pdf_bbox_is_empty(bbox) {
      row.bbox
    } else {
      pdf_union_bbox(bbox, row.bbox)
    }
    match row.source_ref {
      Some(source_ref) => source_refs.push(source_ref)
      None => ()
    }
    match row.reading_order_index {
      Some(index) => reading_order_indices.push(index)
      None => ()
    }
  }
  Some({
    page_no: rows[0].page_no,
    bbox,
    row_count: rows.length(),
    column_alignment_count: alignment_positions.length(),
    source_refs,
    reading_order_indices,
    line_start: rows[0].line_start,
    line_end: rows[rows.length() - 1].line_end,
    confidence: pdf_native_table_candidate_confidence(
      rows.length(),
      alignment_positions.length(),
    ),
    reason: if rows.any(fn(row) { pdf_native_line_looks_table_like(row.text) }) {
      "table_like_rows"
    } else {
      "repeated_column_alignment"
    },
  })
}

///|
fn pdf_native_table_region_alignment_positions(
  rows : Array[PdfNativeTableRowCandidate],
) -> Array[Double] {
  let positions : Array[Double] = []
  let counts : Array[Int] = []
  for row in rows {
    for x in row.aligned_xs {
      let mut matched = false
      let mut index = 0
      while index < positions.length() {
        if pdf_abs_double(positions[index] - x) <= 8.0 {
          positions[index] = (positions[index] + x) / 2.0
          counts[index] = counts[index] + 1
          matched = true
          break
        }
        index += 1
      }
      if !matched {
        positions.push(x)
        counts.push(1)
      }
    }
  }
  let repeated : Array[Double] = []
  let threshold = if rows.length() >= 3 { 2 } else { rows.length() }
  let mut index = 0
  while index < positions.length() {
    if counts[index] >= threshold {
      repeated.push(positions[index])
    }
    index += 1
  }
  pdf_native_distinct_sorted_xs(repeated)
}

///|
fn pdf_native_table_alignment_overlap_count(
  left : Array[Double],
  right : Array[Double],
) -> Int {
  let mut count = 0
  for lhs in left {
    if right.any(fn(rhs) { pdf_abs_double(lhs - rhs) <= 8.0 }) {
      count += 1
    }
  }
  count
}

///|
fn pdf_native_table_candidate_confidence(
  row_count : Int,
  column_alignment_count : Int,
) -> String {
  if row_count >= 3 && column_alignment_count >= 3 {
    "high"
  } else if row_count >= 2 && column_alignment_count >= 2 {
    "medium"
  } else {
    "low"
  }
}

///|
fn pdf_native_table_region_candidate_json(
  candidate : PdfNativeTableRegionCandidate,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("page", @core.JsonValue::Number(candidate.page_no.to_string()))
  payload.set("bbox", pdf_native_bbox_json(candidate.bbox))
  payload.set(
    "row_count",
    @core.JsonValue::Number(candidate.row_count.to_string()),
  )
  payload.set(
    "column_alignment_count",
    @core.JsonValue::Number(candidate.column_alignment_count.to_string()),
  )
  payload.set("confidence", @core.JsonValue::String(candidate.confidence))
  payload.set("reason", @core.JsonValue::String(candidate.reason))
  match candidate.line_start {
    Some(line_start) =>
      payload.set("line_start", @core.JsonValue::Number(line_start.to_string()))
    None => ()
  }
  match candidate.line_end {
    Some(line_end) =>
      payload.set("line_end", @core.JsonValue::Number(line_end.to_string()))
    None => ()
  }
  if candidate.reading_order_indices.length() > 0 {
    payload.set(
      "reading_order_indices",
      pdf_native_int_array_json(candidate.reading_order_indices),
    )
  }
  if candidate.source_refs.length() > 0 {
    payload.set(
      "source_refs",
      @core.JsonValue::Array(
        candidate.source_refs.map(source_ref => {
          pdf_native_source_ref_json(source_ref)
        }),
      ),
    )
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_table_region_candidates_from_summary(
  summary : PdfNativeTableCandidateSummary,
  policy : @parser.PdfTableReconstructionPolicy,
) -> Array[PdfNativeTableRegionCandidate] {
  if policy != @parser.PdfTableReconstructionPolicy::InternalSimpleRowsOnly {
    return []
  }
  let regions : Array[PdfNativeTableRegionCandidate] = []
  for item in summary.candidates {
    match item {
      @core.JsonValue::Object(payload) => {
        let page_no = match payload.get("page") {
          Some(@core.JsonValue::Number(value)) =>
            @string.parse_int(value) catch {
              _ => -1
            }
          _ => -1
        }
        if page_no <= 0 {
          continue
        }
        let bbox = match payload.get("bbox") {
          Some(@core.JsonValue::Object(bbox_payload)) =>
            pdf_native_bbox_from_json_object(bbox_payload)
          _ => None
        }
        let row_count = match payload.get("row_count") {
          Some(@core.JsonValue::Number(value)) =>
            @string.parse_int(value) catch {
              _ => 0
            }
          _ => 0
        }
        let column_alignment_count = match
          payload.get("column_alignment_count") {
          Some(@core.JsonValue::Number(value)) =>
            @string.parse_int(value) catch {
              _ => 0
            }
          _ => 0
        }
        let confidence = match payload.get("confidence") {
          Some(@core.JsonValue::String(value)) => value
          _ => "low"
        }
        let reason = match payload.get("reason") {
          Some(@core.JsonValue::String(value)) => value
          _ => "unknown"
        }
        let line_start = match payload.get("line_start") {
          Some(@core.JsonValue::Number(value)) =>
            Some(@string.parse_int(value) catch { _ => 0 })
          _ => None
        }
        let line_end = match payload.get("line_end") {
          Some(@core.JsonValue::Number(value)) =>
            Some(@string.parse_int(value) catch { _ => 0 })
          _ => None
        }
        let source_refs = match payload.get("source_refs") {
          Some(@core.JsonValue::Array(values)) =>
            values
            .map(item => {
              match item {
                @core.JsonValue::Object(source_ref_payload) =>
                  pdf_native_source_ref_from_json_object(source_ref_payload)
                _ => None
              }
            })
            .filter_map(fn(value) { value })
          _ => []
        }
        let reading_order_indices = match payload.get("reading_order_indices") {
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
            .filter(index => index >= 0)
          _ => []
        }
        match bbox {
          Some(value) =>
            regions.push({
              page_no,
              bbox: value,
              row_count,
              column_alignment_count,
              source_refs,
              reading_order_indices,
              line_start,
              line_end,
              confidence,
              reason,
            })
          None => ()
        }
      }
      _ => ()
    }
  }
  regions
}

///|
fn pdf_native_source_ref_from_json_object(
  payload : Map[String, @core.JsonValue],
) -> @core.SourceRef? {
  let file_id = match payload.get("file_id") {
    Some(@core.JsonValue::String(value)) => Some(value)
    _ => None
  }
  let format = match payload.get("format") {
    Some(@core.JsonValue::String(value)) => Some(value)
    _ => None
  }
  let page = match payload.get("page") {
    Some(@core.JsonValue::Number(value)) =>
      Some(@string.parse_int(value) catch { _ => return None })
    _ => None
  }
  let line_start = match payload.get("line_start") {
    Some(@core.JsonValue::Number(value)) =>
      Some(@string.parse_int(value) catch { _ => return None })
    _ => None
  }
  let line_end = match payload.get("line_end") {
    Some(@core.JsonValue::Number(value)) =>
      Some(@string.parse_int(value) catch { _ => return None })
    _ => None
  }
  let bbox = match payload.get("bbox") {
    Some(@core.JsonValue::Object(bbox_payload)) =>
      match pdf_native_bbox_from_core_json_object(bbox_payload) {
        Some(value) => Some(value)
        None => return None
      }
    _ => None
  }
  let source_ref = {
    ..@core.empty_source_ref(),
    file_id,
    format,
    page,
    bbox,
    line_start,
    line_end,
  }
  match payload.get("extra") {
    Some(@core.JsonValue::Object(extra_payload)) =>
      for entry in extra_payload.to_array() {
        match entry.1 {
          @core.JsonValue::String(value) => source_ref.extra.set(entry.0, value)
          @core.JsonValue::Number(value) => source_ref.extra.set(entry.0, value)
          @core.JsonValue::Bool(value) =>
            source_ref.extra.set(entry.0, value.to_string())
          _ => ()
        }
      }
    _ => ()
  }
  Some(source_ref)
}

///|
fn pdf_native_bbox_from_core_json_object(
  payload : Map[String, @core.JsonValue],
) -> @core.BBox? {
  let x0 = match payload.get("x0") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  let y0 = match payload.get("y0") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  let x1 = match payload.get("x1") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  let y1 = match payload.get("y1") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  Some({ x0, y0, x1, y1 })
}

///|
fn pdf_native_should_remove_text_block(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  text_block_index : Int,
  candidates : Array[PdfNativeHeaderFooterRemovalCandidate],
) -> Bool {
  if candidates.length() == 0 {
    return false
  }
  if text_block.lines.length() != 1 {
    return false
  }
  let paragraph = pdf_native_text_block_paragraph(
    page, text_block, text_block_index,
  )
  match paragraph {
    Some((text, source_ref)) => {
      let normalized_text = pdf_native_header_footer_normalized_text(text)
      for candidate in candidates {
        if candidate.normalized_text != normalized_text {
          continue
        }
        if !candidate.pages.contains(page.geometry.page_no) {
          continue
        }
        if pdf_native_line_band_kind(page.geometry, text_block.bbox) !=
          Some(candidate.kind) {
          continue
        }
        if !pdf_native_pdf_bboxes_overlap(candidate.bbox, text_block.bbox) {
          continue
        }
        if source_ref.page != Some(page.geometry.page_no) {
          continue
        }
        return true
      }
      false
    }
    None => false
  }
}

///|
fn pdf_native_pdf_bboxes_overlap(left : PdfBBox, right : PdfBBox) -> Bool {
  let left_x1 = pdf_bbox_right(left)
  let left_y1 = pdf_bbox_bottom(left)
  let right_x1 = pdf_bbox_right(right)
  let right_y1 = pdf_bbox_bottom(right)
  !(left_x1 < right.x ||
  right_x1 < left.x ||
  left_y1 < right.y ||
  right_y1 < left.y)
}

///|
fn pdf_native_matching_table_region(
  _page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  block_index : Int,
  source_ref : @core.SourceRef,
  regions : Array[PdfNativeTableRegionCandidate],
) -> PdfNativeTableRegionCandidate? {
  for region in regions {
    if region.confidence != "high" && region.confidence != "medium" {
      continue
    }
    if region.row_count < 2 || region.column_alignment_count < 2 {
      continue
    }
    if !pdf_native_pdf_bboxes_overlap(region.bbox, text_block.bbox) {
      continue
    }
    if block_index != text_block_index_from_source_ref(source_ref, block_index) {
      ()
    }
    if region.line_start is Some(start) &&
      source_ref.line_start is Some(line_start) {
      if line_start < start {
        continue
      }
    }
    return Some(region)
  }
  None
}

///|
fn text_block_index_from_source_ref(
  source_ref : @core.SourceRef,
  fallback : Int,
) -> Int {
  match source_ref.extra.get("pdf_text_block_index") {
    Some(value) => @string.parse_int(value) catch { _ => fallback }
    None => fallback
  }
}

///|
fn pdf_native_table_block_from_region(
  page : PdfNativePage,
  region : PdfNativeTableRegionCandidate,
  text_blocks : Array[PdfNativeTextBlock],
) -> PdfNativeTableLoweringResult {
  let region_blocks : Array[
    (Int, PdfNativeTextBlock, PdfNativeTextLine, @core.SourceRef, String),
  ] = []
  for text_block_index in 0..<text_blocks.length() {
    let block_index = text_block_index + 1
    let text_block = text_blocks[text_block_index]
    let paragraph = pdf_native_text_block_paragraph(
      page, text_block, block_index,
    )
    match paragraph {
      Some((text, source_ref)) =>
        if pdf_native_pdf_bboxes_overlap(region.bbox, text_block.bbox) &&
          source_ref.page == Some(region.page_no) &&
          text_block.lines.length() == 1 {
          region_blocks.push(
            (block_index, text_block, text_block.lines[0], source_ref, text),
          )
        }
      None => ()
    }
  }
  if region_blocks.length() < 2 {
    return PdfNativeTableLoweringResult::Skipped("insufficient_rows")
  }
  region_blocks.sort_by(fn(left, right) {
    let left_index = left.3.extra
      .get("reading_order_index")
      .map(value => @string.parse_int(value) catch { _ => 1_000_000 })
      .unwrap_or(1_000_000)
    let right_index = right.3.extra
      .get("reading_order_index")
      .map(value => @string.parse_int(value) catch { _ => 1_000_000 })
      .unwrap_or(1_000_000)
    if left_index < right_index {
      -1
    } else if left_index > right_index {
      1
    } else {
      0
    }
  })
  let rows : Array[Array[String]] = []
  let block_indexes : Array[Int] = []
  let row_source_refs : Array[@core.SourceRef] = []
  for row_entry in region_blocks {
    let row_text = row_entry.4
    let cells = pdf_native_table_row_cells_from_line(row_entry.2, row_text)
    if cells.length() < 2 {
      return PdfNativeTableLoweringResult::Skipped("row_split_failed")
    }
    rows.push(cells)
    block_indexes.push(row_entry.0)
    row_source_refs.push(row_entry.3)
  }
  let expected_width = rows[0].length()
  if expected_width < 2 {
    return PdfNativeTableLoweringResult::Skipped("insufficient_columns")
  }
  for row in rows {
    if row.length() != expected_width {
      return PdfNativeTableLoweringResult::Skipped("inconsistent_column_count")
    }
  }
  let table_source_ref = pdf_native_table_source_ref_from_rows(row_source_refs)
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=table_source_ref,
  )
  table.attrs.set("header_rows", "1")
  table.attrs.set("table_column_count", expected_width.to_string())
  for row_index in 0..<rows.length() {
    let row_ref = row_source_refs[row_index]
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      rows[row_index].join(" | "),
      source_ref=row_ref,
    )
    for cell_text in rows[row_index] {
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          cell_text,
          source_ref=row_ref,
        ),
      )
    }
    table.children.push(row)
  }
  PdfNativeTableLoweringResult::Lowered(
    table,
    block_indexes,
    pdf_native_source_ref_metric_string(table_source_ref),
  )
}

///|
fn pdf_native_table_row_cells_from_text(text : String) -> Array[String] {
  let cells : Array[String] = []
  let normalized = text
    .split("  ")
    .to_array()
    .map(part => part.trim().to_owned())
    .filter(part => part != "")
  if normalized.length() >= 2 {
    cells.append(normalized[:])
    return cells
  }
  let tokens = pdf_native_table_text_tokens(text)
  if tokens.length() < 4 {
    return []
  }
  let header_like = tokens[0].length() <= 24 && tokens[1].length() <= 24
  if !header_like {
    return []
  }
  cells.push(tokens[0])
  cells.push(tokens[1])
  cells.push(tokens[2:].join(" "))
  cells
}

///|
fn pdf_native_table_row_cells_from_line(
  line : PdfNativeTextLine,
  fallback_text : String,
) -> Array[String] {
  let cells : Array[String] = []
  let spans : Array[PdfNativeTextSpan] = []
  for span in line.spans {
    if span.text.trim() != "" {
      spans.push(span)
    }
  }
  if spans.length() >= 2 {
    let ordered_spans : Array[PdfNativeTextSpan] = []
    ordered_spans.append(spans[:])
    ordered_spans.sort_by(fn(left, right) {
      if left.bbox.x < right.bbox.x {
        -1
      } else if left.bbox.x > right.bbox.x {
        1
      } else {
        0
      }
    })
    for span in ordered_spans {
      let trimmed = span.text.trim().to_owned()
      if trimmed != "" {
        cells.push(trimmed)
      }
    }
    if cells.length() >= 2 {
      return cells
    }
  }
  pdf_native_table_row_cells_from_text(fallback_text)
}

///|
fn pdf_native_table_source_ref_from_rows(
  refs : Array[@core.SourceRef],
) -> @core.SourceRef {
  if refs.length() == 0 {
    return @core.empty_source_ref()
  }
  let first = refs[0]
  let mut merged_bbox = match first.bbox {
    Some(value) => value
    None => { x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0 }
  }
  let mut line_start = first.line_start
  let mut line_end = first.line_end
  for index in 1..<refs.length() {
    let source_ref = refs[index]
    match source_ref.bbox {
      Some(value) =>
        merged_bbox = {
          x0: if value.x0 < merged_bbox.x0 {
            value.x0
          } else {
            merged_bbox.x0
          },
          y0: if value.y0 < merged_bbox.y0 {
            value.y0
          } else {
            merged_bbox.y0
          },
          x1: if value.x1 > merged_bbox.x1 {
            value.x1
          } else {
            merged_bbox.x1
          },
          y1: if value.y1 > merged_bbox.y1 {
            value.y1
          } else {
            merged_bbox.y1
          },
        }
      None => ()
    }
    line_start = match (line_start, source_ref.line_start) {
      (Some(left), Some(right)) => Some(if left < right { left } else { right })
      (None, Some(right)) => Some(right)
      (current, None) => current
    }
    line_end = match (line_end, source_ref.line_end) {
      (Some(left), Some(right)) => Some(if left > right { left } else { right })
      (None, Some(right)) => Some(right)
      (current, None) => current
    }
  }
  { ..first, bbox: Some(merged_bbox), line_start, line_end }
}

///|
fn pdf_native_source_ref_metric_string(source_ref : @core.SourceRef) -> String {
  let parts : Array[String] = []
  match source_ref.page {
    Some(page) => parts.push("page=" + page.to_string())
    None => ()
  }
  match source_ref.line_start {
    Some(line_start) => parts.push("line_start=" + line_start.to_string())
    None => ()
  }
  match source_ref.line_end {
    Some(line_end) => parts.push("line_end=" + line_end.to_string())
    None => ()
  }
  match source_ref.bbox {
    Some(bbox) =>
      parts.push(
        "bbox=" +
        bbox.x0.to_string() +
        "," +
        bbox.y0.to_string() +
        "," +
        bbox.x1.to_string() +
        "," +
        bbox.y1.to_string(),
      )
    None => ()
  }
  if parts.length() == 0 {
    "unknown"
  } else {
    parts.join(";")
  }
}

///|
fn pdf_native_text_block_paragraph(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  text_block_index : Int,
) -> (String, @core.SourceRef)? {
  let parts : Array[String] = []
  let meaningful_lines : Array[PdfNativeTextLine] = []
  for line in text_block.lines {
    let text = pdf_native_line_text(line)
    if text == "" {
      continue
    }
    if parts.length() == 0 {
      parts.push(text)
    } else {
      let previous = parts[parts.length() - 1]
      parts[parts.length() - 1] = pdf_native_merge_block_line_text(
        previous, text,
      )
    }
    meaningful_lines.push(line)
  }
  if parts.length() == 0 {
    return None
  }
  let source_ref = pdf_native_text_block_source_ref(
    page, text_block, meaningful_lines, text_block_index,
  )
  Some((parts.join(" "), source_ref))
}

///|
fn pdf_native_merge_block_line_text(left : String, right : String) -> String {
  let lhs = left.trim_end().to_owned()
  let rhs = right.trim_start().to_owned()
  if lhs == "" {
    return rhs
  }
  if rhs == "" {
    return lhs
  }
  if lhs.has_suffix("-") {
    lhs[:lhs.length() - 1].to_owned() + rhs
  } else {
    lhs + " " + rhs
  }
}

///|
fn pdf_native_text_block_source_ref(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  lines : Array[PdfNativeTextLine],
  text_block_index : Int,
) -> @core.SourceRef {
  let first_line = lines[0]
  let last_line = lines[lines.length() - 1]
  let base = pdf_native_line_base_source_ref(first_line)
  let page_no = base.page.unwrap_or(page.geometry.page_no)
  let line_start = base.line_start.unwrap_or(1)
  let last_base = pdf_native_line_base_source_ref(last_line)
  let line_end = last_base.line_end.unwrap_or(
    last_base.line_start.unwrap_or(line_start),
  )
  let next = {
    ..base,
    format: Some(base.format.unwrap_or("pdf")),
    page: Some(page_no),
    bbox: pdf_native_effective_bbox(base.bbox, text_block.bbox),
    line_start: Some(line_start),
    line_end: Some(line_end),
  }
  if next.extra.get("page_no") == None {
    next.extra.set("page_no", page_no.to_string())
  }
  if next.extra.get("pdf_text_block_index") == None {
    next.extra.set("pdf_text_block_index", text_block_index.to_string())
  }
  if next.extra.get("pdf_line_index") == None {
    next.extra.set("pdf_line_index", line_start.to_string())
  }
  next.extra.set("pdf_line_end_index", line_end.to_string())
  match text_block.reading_order_index {
    Some(value) =>
      if next.extra.get("reading_order_index") == None {
        next.extra.set("reading_order_index", value.to_string())
      }
    None => ()
  }
  next
}

///|
fn pdf_native_line_base_source_ref(line : PdfNativeTextLine) -> @core.SourceRef {
  match line.source_ref {
    Some(source_ref) => source_ref
    None => {
      for span in line.spans {
        match span.source_ref {
          Some(source_ref) => return source_ref
          None => ()
        }
      }
      @core.empty_source_ref()
    }
  }
}

///|
fn pdf_native_effective_bbox(
  current : @core.BBox?,
  fallback : PdfBBox,
) -> @core.BBox? {
  match current {
    Some(value) => Some(value)
    None =>
      if pdf_bbox_is_empty(fallback) {
        None
      } else {
        Some(pdf_native_core_bbox(fallback))
      }
  }
}

///|
fn pdf_native_core_bbox(bbox : PdfBBox) -> @core.BBox {
  {
    x0: bbox.x,
    y0: bbox.y,
    x1: pdf_bbox_right(bbox),
    y1: pdf_bbox_bottom(bbox),
  }
}

///|
fn pdf_native_link_candidate_json(
  link : PdfNativeLinkCandidate,
  fallback_page_no : Int,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("href", @core.JsonValue::String(link.href))
  payload.set("target", @core.JsonValue::String(link.href))
  payload.set(
    "page",
    @core.JsonValue::Number(
      pdf_native_link_page_no(link, fallback_page_no).to_string(),
    ),
  )
  payload.set("bbox", pdf_native_bbox_json(link.bbox))
  match link.text {
    Some(text) =>
      if text.trim() != "" {
        payload.set("text", @core.JsonValue::String(text.trim().to_owned()))
      }
    None => ()
  }
  match link.source_ref {
    Some(source_ref) => {
      match source_ref.file_id {
        Some(file_id) =>
          payload.set("file_id", @core.JsonValue::String(file_id))
        None => ()
      }
      match source_ref.format {
        Some(format) => payload.set("format", @core.JsonValue::String(format))
        None => ()
      }
      match source_ref.page {
        Some(page_no) =>
          payload.set(
            "source_page",
            @core.JsonValue::Number(page_no.to_string()),
          )
        None => ()
      }
      match source_ref.bbox {
        Some(bbox) =>
          payload.set("source_bbox", pdf_native_core_bbox_json(bbox))
        None => ()
      }
      match source_ref.extra.get("reading_order_index") {
        Some(value) =>
          payload.set("reading_order_index", @core.JsonValue::Number(value))
        None => ()
      }
    }
    None => ()
  }
  match link.annotation_index {
    Some(value) =>
      payload.set(
        "annotation_index",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match link.annotation_object_id {
    Some(value) =>
      payload.set(
        "annotation_object_id",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_link_page_no(
  link : PdfNativeLinkCandidate,
  fallback_page_no : Int,
) -> Int {
  match link.source_ref {
    Some(source_ref) => source_ref.page.unwrap_or(fallback_page_no)
    None => fallback_page_no
  }
}

///|
pub fn pdf_native_appendix_blocks(
  metadata : Map[String, @core.JsonValue],
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  let annotation_lines = pdf_native_annotation_appendix_lines(metadata)
  if annotation_lines.length() > 0 {
    blocks.push(pdf_native_appendix_heading("Annotations"))
    blocks.push(pdf_native_appendix_list(annotation_lines))
  }
  let form_lines = pdf_native_form_appendix_lines(metadata)
  if form_lines.length() > 0 {
    blocks.push(pdf_native_appendix_heading("Forms"))
    blocks.push(pdf_native_appendix_list(form_lines))
  }
  let bookmark_lines = pdf_native_bookmark_appendix_lines(metadata)
  if bookmark_lines.length() > 0 {
    blocks.push(pdf_native_appendix_heading("Bookmarks"))
    blocks.push(pdf_native_appendix_list(bookmark_lines))
  }
  blocks
}

///|
fn pdf_native_appendix_heading(title : String) -> @core.CoreBlock {
  let heading = @core.make_block(@core.BlockKind::Heading, title)
  heading.attrs.set("level", "2")
  heading
}

///|
fn pdf_native_appendix_list(lines : Array[String]) -> @core.CoreBlock {
  let items = lines.map(line => {
    @core.make_block(@core.BlockKind::ListItem, line)
  })
  @core.block_with_children(@core.make_block(@core.BlockKind::List, ""), items)
}

///|
fn pdf_native_annotation_appendix_lines(
  metadata : Map[String, @core.JsonValue],
) -> Array[String] {
  let lines : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  match metadata.get("pdf_native_annotations") {
    Some(@core.JsonValue::Array(items)) => {
      let ordered : Array[@core.JsonValue] = []
      ordered.append(items[:])
      ordered.sort_by(fn(left, right) {
        pdf_native_annotation_appendix_compare(left, right)
      })
      for item in ordered {
        match pdf_native_annotation_line(item) {
          Some(line) =>
            if !seen.contains(line) {
              seen.set(line, true)
              lines.push(line)
            }
          None => ()
        }
      }
    }
    _ => ()
  }
  lines
}

///|
fn pdf_native_annotation_line(item : @core.JsonValue) -> String? {
  let payload = match item {
    @core.JsonValue::Object(value) => value
    _ => return None
  }
  let subtype = pdf_native_json_string_field(payload, "subtype").unwrap_or("")
  if subtype == "" || subtype == "Widget" {
    return None
  }
  if !pdf_native_annotation_should_render(payload) {
    return None
  }
  let page = pdf_native_json_string_field(payload, "page").unwrap_or("?")
  let action_kind = pdf_native_json_string_field(payload, "action_kind")
  let target = pdf_native_json_string_field(payload, "target")
  let destination = pdf_native_json_object_field(payload, "destination")
  if subtype == "Link" {
    match action_kind {
      Some("URI") => return None
      _ => ()
    }
    let target_text = match
      pdf_native_annotation_visible_target(target, destination) {
      Some(value) => value
      None => return None
    }
    return Some("Link (page " + page + "): " + target_text)
  }
  let title = pdf_native_json_string_field(payload, "title")
  let subject = pdf_native_json_string_field(payload, "subject")
  let text = pdf_native_json_string_field(payload, "text")
  let file_name = pdf_native_json_string_field(payload, "file_name")
  let fallback_target = pdf_native_annotation_visible_target(
    target, destination,
  )
  let summary = if subtype == "FileAttachment" {
    pdf_native_fact_summary_text(title, file_name, fallback_target)
  } else {
    pdf_native_annotation_summary_text(
      subtype, title, subject, text, fallback_target,
    )
  }
  match summary {
    Some(value) =>
      Some(
        pdf_native_annotation_display_subtype(subtype) +
        " (page " +
        page +
        "): " +
        value,
      )
    None => None
  }
}

///|
fn pdf_native_annotation_summary_text(
  subtype : String,
  title : String?,
  subject : String?,
  text : String?,
  fallback_target : String?,
) -> String? {
  let normalized_title = pdf_native_nonempty_trimmed(title)
  let normalized_subject = pdf_native_nonempty_trimmed(subject)
  let normalized_text = pdf_native_nonempty_trimmed(text)
  let preferred_title = pdf_native_annotation_preferred_title(
    subtype, normalized_title, normalized_subject, normalized_text,
  )
  match (subtype, normalized_subject, normalized_title, normalized_text) {
    ("Square", Some(subject_value), Some(title_value), Some(text_value)) =>
      if title_value == text_value {
        return Some(subject_value)
      }
    ("Circle", Some(subject_value), Some(title_value), Some(text_value)) =>
      if title_value == text_value {
        return Some(subject_value)
      }
    _ => ()
  }
  pdf_native_fact_summary_text(
    preferred_title, normalized_text, fallback_target,
  )
}

///|
fn pdf_native_annotation_preferred_title(
  subtype : String,
  title : String?,
  subject : String?,
  text : String?,
) -> String? {
  let normalized_subtype = subtype.trim().to_owned()
  match subject {
    Some(value) if value.trim() != "" =>
      if pdf_native_annotation_subject_is_preferred(
          normalized_subtype, value, title, text,
        ) {
        Some(value)
      } else {
        title
      }
    _ => title
  }
}

///|
fn pdf_native_annotation_subject_is_preferred(
  subtype : String,
  subject : String,
  title : String?,
  text : String?,
) -> Bool {
  let normalized_subject = subject.trim().to_owned()
  if normalized_subject == "" {
    return false
  }
  match title {
    Some(value) if value.trim() == normalized_subject => return false
    _ => ()
  }
  match text {
    Some(value) if value.trim() == normalized_subject => return false
    _ => ()
  }
  match subtype {
    "Line" => true
    "Square" => true
    "Circle" => true
    "Underline" => true
    "StrikeOut" => true
    "Squiggly" => true
    _ => false
  }
}

///|
fn pdf_native_form_appendix_lines(
  metadata : Map[String, @core.JsonValue],
) -> Array[String] {
  let lines : Array[String] = []
  match metadata.get("pdf_native_form_fields") {
    Some(@core.JsonValue::Array(items)) => {
      let ordered : Array[@core.JsonValue] = []
      ordered.append(items[:])
      ordered.sort_by(fn(left, right) {
        pdf_native_form_appendix_compare(left, right)
      })
      for item in ordered {
        match pdf_native_form_line(item) {
          Some(line) => lines.push(line)
          None => ()
        }
      }
    }
    _ => ()
  }
  lines
}

///|
fn pdf_native_form_line(item : @core.JsonValue) -> String? {
  let payload = match item {
    @core.JsonValue::Object(value) => value
    _ => return None
  }
  let page = pdf_native_json_string_field(payload, "page").unwrap_or("?")
  let kind = pdf_native_json_string_field(payload, "field_type").unwrap_or("")
  let label = pdf_native_form_display_label(payload)
  let field_value = pdf_native_form_visible_value(
    kind,
    pdf_native_json_string_field(payload, "value"),
    pdf_native_json_string_field(payload, "default_value"),
  )
  let options = pdf_native_json_string_array_field(payload, "options")
  let prefix = pdf_native_form_display_kind(kind) + " (page " + page + "): "
  let label_text = match label {
    Some(value) => value
    None => pdf_native_form_fallback_label(kind, payload)
  }
  match (field_value, options.length()) {
    (Some(value), count) =>
      if count > 0 &&
        kind == "Ch" &&
        pdf_native_form_should_prefer_options(payload) {
        Some(
          prefix +
          label_text +
          " — options: " +
          pdf_native_form_options_summary(options),
        )
      } else {
        Some(
          prefix +
          label_text +
          " — " +
          pdf_native_form_display_value(kind, value),
        )
      }
    (None, count) if count > 0 =>
      Some(
        prefix +
        label_text +
        " — options: " +
        pdf_native_form_options_summary(options),
      )
    _ => None
  }
}

///|
fn pdf_native_bookmark_appendix_lines(
  metadata : Map[String, @core.JsonValue],
) -> Array[String] {
  let lines : Array[String] = []
  match metadata.get("pdf_native_outline_items") {
    Some(@core.JsonValue::Array(items)) => {
      let ordered : Array[@core.JsonValue] = []
      ordered.append(items[:])
      ordered.sort_by(fn(left, right) {
        pdf_native_bookmark_appendix_compare(left, right)
      })
      for item in ordered {
        match pdf_native_bookmark_line(item) {
          Some(line) => lines.push(line)
          None => ()
        }
      }
    }
    _ => ()
  }
  lines
}

///|
fn pdf_native_bookmark_line(item : @core.JsonValue) -> String? {
  let payload = match item {
    @core.JsonValue::Object(value) => value
    _ => return None
  }
  let title = pdf_native_json_string_field(payload, "title").unwrap_or("")
  if title.trim() == "" {
    return None
  }
  let title_text = pdf_native_bookmark_title(title, payload)
  let target = match pdf_native_bookmark_target(payload) {
    Some(value) => value
    None => return Some(title_text)
  }
  Some(title_text + " -> " + target)
}

///|
fn pdf_native_json_string_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> String? {
  match payload.get(key) {
    Some(@core.JsonValue::String(value)) => Some(value)
    Some(@core.JsonValue::Number(value)) => Some(value)
    Some(@core.JsonValue::Bool(value)) =>
      Some(if value { "true" } else { "false" })
    _ => None
  }
}

///|
fn pdf_native_json_number_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> Int? {
  match payload.get(key) {
    Some(@core.JsonValue::Number(value)) => pdf_native_parse_int(value)
    Some(@core.JsonValue::String(value)) => pdf_native_parse_int(value)
    _ => None
  }
}

///|
fn pdf_native_json_bool_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> Bool? {
  match payload.get(key) {
    Some(@core.JsonValue::Bool(value)) => Some(value)
    Some(@core.JsonValue::String("true")) => Some(true)
    Some(@core.JsonValue::String("false")) => Some(false)
    _ => None
  }
}

///|
fn pdf_native_json_object_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> Map[String, @core.JsonValue]? {
  match payload.get(key) {
    Some(@core.JsonValue::Object(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_native_json_string_array_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> Array[String] {
  match payload.get(key) {
    Some(@core.JsonValue::Array(items)) =>
      items
      .map(item => pdf_native_json_metric_string(item))
      .filter(item => item.trim() != "")
    _ => []
  }
}

///|
fn pdf_native_form_display_kind(kind : String) -> String {
  match kind {
    "Btn" => "Button"
    "Ch" => "Choice"
    "Tx" => "Text"
    _ => if kind.trim() != "" { kind } else { "Field" }
  }
}

///|
fn pdf_native_annotation_display_subtype(subtype : String) -> String {
  match subtype {
    "FileAttachment" => "FileAttachment"
    _ => subtype
  }
}

///|
fn pdf_native_annotation_appendix_compare(
  left : @core.JsonValue,
  right : @core.JsonValue,
) -> Int {
  let left_payload = match left {
    @core.JsonValue::Object(value) => value
    _ => return 0
  }
  let right_payload = match right {
    @core.JsonValue::Object(value) => value
    _ => return 0
  }
  pdf_native_compare_payload_fields(left_payload, right_payload, [
    "page", "annotation_index", "object_id", "subtype", "text", "title",
  ])
}

///|
fn pdf_native_form_appendix_compare(
  left : @core.JsonValue,
  right : @core.JsonValue,
) -> Int {
  let left_payload = match left {
    @core.JsonValue::Object(value) => value
    _ => return 0
  }
  let right_payload = match right {
    @core.JsonValue::Object(value) => value
    _ => return 0
  }
  pdf_native_compare_payload_fields(left_payload, right_payload, [
    "page", "object_id", "widget_object_id", "alternate_name", "field_name", "field_type",
  ])
}

///|
fn pdf_native_bookmark_appendix_compare(
  left : @core.JsonValue,
  right : @core.JsonValue,
) -> Int {
  let left_payload = match left {
    @core.JsonValue::Object(value) => value
    _ => return 0
  }
  let right_payload = match right {
    @core.JsonValue::Object(value) => value
    _ => return 0
  }
  pdf_native_compare_payload_fields(left_payload, right_payload, [
    "order_index", "level", "page", "title", "object_id",
  ])
}

///|
fn pdf_native_compare_payload_fields(
  left : Map[String, @core.JsonValue],
  right : Map[String, @core.JsonValue],
  keys : Array[String],
) -> Int {
  for key in keys {
    let left_number = pdf_native_json_number_field(left, key)
    let right_number = pdf_native_json_number_field(right, key)
    match (left_number, right_number) {
      (Some(lv), Some(rv)) =>
        if lv < rv {
          return -1
        } else if lv > rv {
          return 1
        }
      _ => ()
    }
    let left_text = pdf_native_json_string_field(left, key).unwrap_or("")
    let right_text = pdf_native_json_string_field(right, key).unwrap_or("")
    if left_text < right_text {
      return -1
    } else if left_text > right_text {
      return 1
    }
  }
  0
}

///|
fn pdf_native_annotation_visible_target(
  target : String?,
  destination : Map[String, @core.JsonValue]?,
) -> String? {
  match target {
    Some(value) if !pdf_native_looks_like_uri(value) && value.trim() != "" =>
      Some(value)
    _ => pdf_native_destination_visible_target(destination)
  }
}

///|
fn pdf_native_annotation_should_render(
  payload : Map[String, @core.JsonValue],
) -> Bool {
  let hidden = pdf_native_json_bool_field(payload, "flag_hidden").unwrap_or(
    false,
  )
  let print = pdf_native_json_bool_field(payload, "flag_print").unwrap_or(false)
  let no_view = pdf_native_json_bool_field(payload, "flag_no_view").unwrap_or(
    false,
  )
  if no_view && !print {
    return false
  }
  if hidden && !print {
    return false
  }
  true
}

///|
fn pdf_native_destination_visible_target(
  destination : Map[String, @core.JsonValue]?,
) -> String? {
  let payload = match destination {
    Some(value) => value
    None => return None
  }
  match pdf_native_json_string_field(payload, "target_page_index") {
    Some(page) if page.trim() != "" => Some("page " + page)
    _ =>
      match pdf_native_json_string_field(payload, "name") {
        Some(value) if value.trim() != "" =>
          Some(
            "named destination \"" +
            pdf_native_appendix_quoted(value.trim().to_owned()) +
            "\"",
          )
        _ =>
          if pdf_native_destination_has_visible_hint(payload) {
            Some("unresolved destination")
          } else {
            None
          }
      }
  }
}

///|
fn pdf_native_destination_has_visible_hint(
  payload : Map[String, @core.JsonValue],
) -> Bool {
  match pdf_native_json_string_field(payload, "raw_value") {
    Some(value) if value.trim() != "" => true
    _ =>
      match pdf_native_json_string_field(payload, "kind") {
        Some(value) if value.trim() != "" => true
        _ =>
          pdf_native_json_number_field(payload, "target_page_object_id")
          is Some(_) ||
          pdf_native_json_number_field(payload, "object_id") is Some(_)
      }
  }
}

///|
fn pdf_native_form_display_label(
  payload : Map[String, @core.JsonValue],
) -> String? {
  match pdf_native_json_string_field(payload, "alternate_name") {
    Some(value) if value.trim() != "" => return Some(value.trim().to_owned())
    _ => ()
  }
  match pdf_native_json_string_field(payload, "field_name") {
    Some(value) if value.trim() != "" => Some(value.trim().to_owned())
    _ => None
  }
}

///|
fn pdf_native_form_visible_value(
  _kind : String,
  value : String?,
  default_value : String?,
) -> String? {
  match value {
    Some(text) if text.trim() != "" => Some(text.trim().to_owned())
    _ =>
      match default_value {
        Some(text) if text.trim() != "" => Some(text.trim().to_owned())
        _ => None
      }
  }
}

///|
fn pdf_native_form_display_value(kind : String, value : String) -> String {
  match kind {
    "Btn" =>
      if value == "true" {
        "checked"
      } else if value == "false" {
        "unchecked"
      } else {
        value
      }
    _ => value
  }
}

///|
fn pdf_native_form_options_summary(options : Array[String]) -> String {
  options.join(", ")
}

///|
fn pdf_native_form_fallback_label(
  kind : String,
  payload : Map[String, @core.JsonValue],
) -> String {
  match kind {
    "Btn" =>
      match pdf_native_json_string_field(payload, "field_name") {
        Some(value) if value.trim() != "" => value.trim().to_owned()
        _ => "Button"
      }
    "Ch" => "Choice"
    "Tx" => "Text"
    _ => "Field"
  }
}

///|
fn pdf_native_form_should_prefer_options(
  payload : Map[String, @core.JsonValue],
) -> Bool {
  let flags = pdf_native_json_number_field(payload, "flags").unwrap_or(0)
  let read_only = (flags & 1) != 0
  read_only
}

///|
fn pdf_native_bookmark_title(
  title : String,
  payload : Map[String, @core.JsonValue],
) -> String {
  match pdf_native_json_number_field(payload, "level") {
    Some(level) if level > 0 => title
    _ => title
  }
}

///|
fn pdf_native_bookmark_target(
  payload : Map[String, @core.JsonValue],
) -> String? {
  let destination_target = pdf_native_destination_visible_target(
    pdf_native_json_object_field(payload, "destination"),
  )
  match pdf_native_json_string_field(payload, "target") {
    Some(value) if value.trim() != "" =>
      if pdf_native_looks_like_raw_destination_target(value) {
        destination_target
      } else {
        Some(value)
      }
    _ => destination_target
  }
}

///|
fn pdf_native_looks_like_raw_destination_target(value : String) -> Bool {
  let trimmed = value.trim().to_owned()
  trimmed.has_prefix("/") ||
  trimmed.contains("<<") ||
  trimmed.contains("[") ||
  trimmed.contains(" R ") ||
  trimmed.has_suffix(" R") ||
  trimmed.contains("/Fit") ||
  trimmed.contains("/XYZ")
}

///|
fn pdf_native_fact_summary_text(
  title : String?,
  text : String?,
  fallback_target : String?,
) -> String? {
  match (title, text) {
    (Some(left), Some(right)) if left.trim() != "" && right.trim() != "" =>
      Some(left + " — " + right)
    (Some(left), _) if left.trim() != "" => Some(left)
    (_, Some(right)) if right.trim() != "" => Some(right)
    _ => fallback_target
  }
}

///|
fn pdf_native_nonempty_trimmed(value : String?) -> String? {
  match value {
    Some(text) => {
      let trimmed = text.trim()
      if trimmed == "" {
        None
      } else {
        Some(trimmed.to_owned())
      }
    }
    None => None
  }
}

///|
fn pdf_native_looks_like_uri(value : String) -> Bool {
  let lowered = value.to_lower()
  lowered.has_prefix("http://") ||
  lowered.has_prefix("https://") ||
  lowered.has_prefix("file://") ||
  lowered.has_prefix("mailto:")
}

///|
fn pdf_native_parse_int(value : String) -> Int? {
  Some(@string.parse_int(value.trim().to_owned()) catch { _ => return None })
}

///|
fn pdf_native_appendix_quoted(value : String) -> String {
  value.replace(old="\"", new="\\\"")
}

///|
fn pdf_native_json_metric_string(value : @core.JsonValue) -> String {
  match value {
    @core.JsonValue::String(text) => text
    @core.JsonValue::Number(text) => text
    @core.JsonValue::Bool(flag) => if flag { "true" } else { "false" }
    _ => ""
  }
}

///|
fn pdf_native_annotation_json(
  annotation : PdfNativeAnnotation,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("subtype", @core.JsonValue::String(annotation.subtype))
  payload.set(
    "page",
    @core.JsonValue::Number(annotation.page_index.to_string()),
  )
  match annotation.bbox {
    Some(bbox) => payload.set("bbox", pdf_native_bbox_json(bbox))
    None => ()
  }
  match annotation.text {
    Some(value) => payload.set("text", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.title {
    Some(value) => payload.set("title", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.subject {
    Some(value) => payload.set("subject", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.file_name {
    Some(value) => payload.set("file_name", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.name {
    Some(value) => payload.set("name", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.modified_at {
    Some(value) => payload.set("modified_at", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.action_kind {
    Some(value) => payload.set("action_kind", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.target {
    Some(value) => payload.set("target", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.annotation_index {
    Some(value) =>
      payload.set(
        "annotation_index",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match annotation.object_id {
    Some(value) =>
      payload.set("object_id", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match annotation.destination {
    Some(value) =>
      payload.set("destination", pdf_native_destination_json(value))
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_form_field_json(field : PdfNativeFormField) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  match field.page_index {
    Some(value) =>
      payload.set("page", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match field.field_type {
    Some(value) => payload.set("field_type", @core.JsonValue::String(value))
    None => ()
  }
  match field.field_name {
    Some(value) => payload.set("field_name", @core.JsonValue::String(value))
    None => ()
  }
  match field.alternate_name {
    Some(value) => payload.set("alternate_name", @core.JsonValue::String(value))
    None => ()
  }
  match field.value {
    Some(value) => payload.set("value", @core.JsonValue::String(value))
    None => ()
  }
  match field.default_value {
    Some(value) => payload.set("default_value", @core.JsonValue::String(value))
    None => ()
  }
  if field.options.length() > 0 {
    payload.set(
      "options",
      @core.JsonValue::Array(
        field.options.map(value => @core.JsonValue::String(value)),
      ),
    )
  }
  match field.bbox {
    Some(bbox) => payload.set("bbox", pdf_native_bbox_json(bbox))
    None => ()
  }
  match field.object_id {
    Some(value) =>
      payload.set("object_id", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match field.widget_object_id {
    Some(value) =>
      payload.set(
        "widget_object_id",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match field.flags {
    Some(value) =>
      payload.set("flags", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_outline_item_json(item : PdfNativeOutlineItem) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("title", @core.JsonValue::String(item.title))
  payload.set("level", @core.JsonValue::Number(item.level.to_string()))
  payload.set(
    "order_index",
    @core.JsonValue::Number(item.order_index.to_string()),
  )
  match item.page_index {
    Some(value) =>
      payload.set("page", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match item.action_kind {
    Some(value) => payload.set("action_kind", @core.JsonValue::String(value))
    None => ()
  }
  match item.target {
    Some(value) => payload.set("target", @core.JsonValue::String(value))
    None => ()
  }
  match item.destination {
    Some(value) =>
      payload.set("destination", pdf_native_destination_json(value))
    None => ()
  }
  match item.object_id {
    Some(value) =>
      payload.set("object_id", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_destination_json(
  destination : PdfNativeDestination,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  match destination.page_index {
    Some(value) =>
      payload.set("page_index", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match destination.target_page_index {
    Some(value) =>
      payload.set(
        "target_page_index",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match destination.target_page_object_id {
    Some(value) =>
      payload.set(
        "target_page_object_id",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match destination.kind {
    Some(value) => payload.set("kind", @core.JsonValue::String(value))
    None => ()
  }
  match destination.raw_value {
    Some(value) => payload.set("raw_value", @core.JsonValue::String(value))
    None => ()
  }
  match destination.name {
    Some(value) => payload.set("name", @core.JsonValue::String(value))
    None => ()
  }
  match destination.object_id {
    Some(value) =>
      payload.set("object_id", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_bbox_json(bbox : PdfBBox) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("x", @core.JsonValue::Number(bbox.x.to_string()))
  payload.set("y", @core.JsonValue::Number(bbox.y.to_string()))
  payload.set("width", @core.JsonValue::Number(bbox.width.to_string()))
  payload.set("height", @core.JsonValue::Number(bbox.height.to_string()))
  payload.set("x1", @core.JsonValue::Number(pdf_bbox_right(bbox).to_string()))
  payload.set("y1", @core.JsonValue::Number(pdf_bbox_bottom(bbox).to_string()))
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_core_bbox_json(bbox : @core.BBox) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("x0", @core.JsonValue::Number(bbox.x0.to_string()))
  payload.set("y0", @core.JsonValue::Number(bbox.y0.to_string()))
  payload.set("x1", @core.JsonValue::Number(bbox.x1.to_string()))
  payload.set("y1", @core.JsonValue::Number(bbox.y1.to_string()))
  @core.JsonValue::Object(payload)
}
