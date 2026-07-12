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
  let mut lowered_link_count = 0
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
        PdfNativeLoweringItem::Paragraph(paragraph) => {
          let block = @core.make_block(
            @core.BlockKind::Paragraph,
            paragraph.text,
            source_ref=paragraph.source_ref,
          )
          blocks.push(
            match paragraph.rich_inlines {
              Some(rich_inlines) =>
                @core.block_with_rich_inlines(block, Some(rich_inlines))
              None => block
            },
          )
          paragraph_count += 1
          lowered_link_count += paragraph.consumed_link_indexes.length()
        }
        PdfNativeLoweringItem::Table(table) => blocks.push(table)
      }
    }
    let lowered_images = pdf_native_lower_page_images(page, assets, asset_paths)
    blocks.append(lowered_images.0[:])
    lowered_image_count += lowered_images.1
    for link_index in 0..<page.link_candidates.length() {
      if page_plan.consumed_link_indexes.contains(link_index) {
        continue
      }
      let link = page.link_candidates[link_index]
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
    "pdf_link_productized_count",
    @core.JsonValue::Number(lowered_link_count.to_string()),
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
