///|
/// Public API for `doc_parse/pdf`.
///
/// Position in architecture:
/// - provides raw-PDF-to-model extraction infrastructure
/// - output is parser-facing model, not end-user markdown/IR
/// - higher converter layers own heading/caption/noise semantics
/// PDF lower-layer parser 对外错误。
pub enum PdfError {
  AdapterFailed(String)
  BuildFailed(String)
  Unsupported(String)
}

///|
pub impl Show for PdfError with fn to_string(self : PdfError) -> String {
  match self {
    AdapterFailed(msg) => "AdapterFailed: " + msg
    BuildFailed(msg) => "BuildFailed: " + msg
    Unsupported(msg) => "Unsupported: " + msg
  }
}

///|
pub impl Show for PdfError with fn output(self : PdfError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
/// PDF lower-layer parser 后端类型。
pub enum PdfBackend {
  MbtPdf
}

///|
/// 对外配置。
pub struct PdfConfig {
  backend : PdfBackend
}

///|
/// 默认配置。
pub fn default_pdf_config() -> PdfConfig {
  { backend: PdfBackend::MbtPdf }
}

///|
/// 对外主入口：
/// MBTPDF -> raw -> chars -> spans -> lines -> blocks -> PdfDocumentModel
pub async fn extract_document_model(
  path : String,
  config : PdfConfig,
) -> Result[@model.PdfDocumentModel, PdfError] {
  let raw = match extract_raw_document(path, config) {
    Ok(v) => v
    Err(err) => return Err(err)
  }

  match build_document_model_from_raw(raw) {
    Ok(doc) => Ok(attach_document_outlines(path, doc))
    Err(err) => Err(err)
  }
}

///|
/// 文档摘要，方便最小调试。
pub async fn extract_document_summary(
  path : String,
  config : PdfConfig,
) -> Result[String, PdfError] {
  match extract_document_model(path, config) {
    Ok(doc) => Ok(render_document_summary(doc))
    Err(err) => Err(err)
  }
}

///|
/// Shared lower-layer extraction helper for explicit inspect/debug packages.
pub async fn extract_document_raw_model(
  path : String,
  config : PdfConfig,
) -> Result[(@raw.RawPdfDocumentExtract, @model.PdfDocumentModel), PdfError] {
  let raw = match extract_raw_document(path, config) {
    Ok(v) => v
    Err(err) => return Err(err)
  }

  match build_document_model_from_raw(raw) {
    Ok(doc) => Ok((raw, attach_document_outlines(path, doc)))
    Err(err) => Err(err)
  }
}

///|
pub fn make_pdf_adapter_failed_error(message : String) -> PdfError {
  PdfError::AdapterFailed(message)
}

///|
pub fn make_pdf_build_failed_error(message : String) -> PdfError {
  PdfError::BuildFailed(message)
}

///|
pub fn make_pdf_unsupported_error(message : String) -> PdfError {
  PdfError::Unsupported(message)
}

///|
fn document_block_count(doc : @model.PdfDocumentModel) -> Int {
  let mut total = 0
  for page in doc.pages {
    total = total + page.text_blocks.length()
  }
  total
}

///|
fn document_image_count(doc : @model.PdfDocumentModel) -> Int {
  let mut total = 0
  for page in doc.pages {
    total = total + page.images.length()
  }
  total
}

///|
fn document_annotation_count(doc : @model.PdfDocumentModel) -> Int {
  let mut total = 0
  for page in doc.pages {
    total = total + page.annotations.length()
  }
  total
}

///|
fn render_document_summary(doc : @model.PdfDocumentModel) -> String {
  "PdfDocumentSummary(" +
  "version=" +
  doc.version +
  ", " +
  "page_count=" +
  doc.page_count.to_string() +
  ", " +
  "blocks=" +
  document_block_count(doc).to_string() +
  ", " +
  "images=" +
  document_image_count(doc).to_string() +
  ", " +
  "annotations=" +
  document_annotation_count(doc).to_string() +
  ", " +
  "encrypted=" +
  doc.is_encrypted.to_string() +
  ", " +
  "title=" +
  option_to_string(doc.metadata.title) +
  ")"
}

///|
priv struct FlatOutlineItem {
  level : Int
  title : String
  page_index : Int?
  dest : String?
}

///|
fn map_adapter_error(err : @raw.MbtPdfAdapterError) -> PdfError {
  match err {
    OpenFailed(msg) => PdfError::AdapterFailed("open failed: " + msg)
    ExtractFailed(msg) => PdfError::AdapterFailed("extract failed: " + msg)
    Unsupported(msg) => PdfError::Unsupported(msg)
  }
}

///|
async fn open_pdf_file_silently(path : String) -> @pdf.Pdf {
  let input = @pdfiofs.input_of_file(path, source=path)
  @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input(None, None, input)
}

///|
async fn attach_document_outlines(
  path : String,
  doc : @model.PdfDocumentModel,
) -> @model.PdfDocumentModel {
  { ..doc, outlines: read_document_outlines(path) }
}

///|
async fn read_document_outlines(path : String) -> Array[@model.PdfOutlineItem] {
  let pdf = open_pdf_file_silently(path) catch { _ => return [] }
  let page_doc = @pdfpage.PdfPageDoc::new(pdf)
  let bookmarks = @pdfmarks.PdfMarks::new(pdf).read_bookmarks() catch {
    _ => return []
  }
  build_outline_tree_from_bookmarks(page_doc, bookmarks)
}

///|
fn build_outline_tree_from_bookmarks(
  page_doc : @pdfpage.PdfPageDoc,
  bookmarks : Array[@pdfmarks.Bookmark],
) -> Array[@model.PdfOutlineItem] {
  let flat : Array[FlatOutlineItem] = []
  for bookmark in bookmarks {
    flat.push({
      level: if bookmark.level < 0 {
        0
      } else {
        bookmark.level
      },
      title: decode_outline_title(bookmark.text),
      page_index: resolve_outline_page_index(page_doc, bookmark.target),
      dest: outline_dest_label(bookmark.target),
    })
  }

  let index = Ref(0)
  build_outline_items_at_level(flat, index, 0)
}

///|
fn decode_outline_title(value : String) -> String {
  let decoded = @pdftext.PdfTextUtil::new().utf8_of_pdfdocstring(value) catch {
    _ => value
  }
  decoded.trim().to_owned()
}

///|
fn resolve_outline_page_index(
  page_doc : @pdfpage.PdfPageDoc,
  dest : @pdfdest.Destination,
) -> Int? {
  let page_number = page_doc.pagenumber_of_target(dest) catch {
    _ => return None
  }
  if page_number <= 0 {
    None
  } else {
    Some(page_number - 1)
  }
}

///|
fn outline_dest_label(dest : @pdfdest.Destination) -> String? {
  let raw = match dest {
    @pdfdest.Destination::NamedDestination(name) => Some(name.to_string_bytes())
    @pdfdest.Destination::StringDestination(value) => Some(value)
    _ => None
  }
  match raw {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn build_outline_items_at_level(
  flat : Array[FlatOutlineItem],
  index : Ref[Int],
  level : Int,
) -> Array[@model.PdfOutlineItem] {
  let out : Array[@model.PdfOutlineItem] = []

  while index.val < flat.length() {
    let cur = flat[index.val]
    if cur.level < level {
      break
    }
    if cur.level > level {
      index.val = index.val + 1
      continue
    }

    index.val = index.val + 1
    let children = build_outline_items_at_level(flat, index, level + 1)
    let has_title = cur.title != ""
    let has_target = cur.page_index is Some(_) || cur.dest is Some(_)
    if !has_title && !has_target && children.is_empty() {
      continue
    }
    out.push({
      title: cur.title,
      page_index: cur.page_index,
      dest: cur.dest,
      children,
    })
  }

  out
}

///|
async fn extract_raw_document(
  path : String,
  config : PdfConfig,
) -> Result[@raw.RawPdfDocumentExtract, PdfError] {
  match config.backend {
    PdfBackend::MbtPdf =>
      match @raw.extract_raw_document_with_mbtpdf(path) {
        Ok(v) => Ok(v)
        Err(err) => Err(map_adapter_error(err))
      }
  }
}

///|
/// 由 raw 构建 document model。
///
/// 当前阶段先到 block 层：
/// raw -> chars -> spans -> lines -> blocks
fn build_document_model_from_raw(
  raw : @raw.RawPdfDocumentExtract,
) -> Result[@model.PdfDocumentModel, PdfError] {
  let metadata : @model.PdfDocumentMetadata = {
    title: raw.metadata_title,
    author: raw.metadata_author,
    subject: raw.metadata_subject,
    keywords: raw.metadata_keywords,
    creator: raw.metadata_creator,
    producer: raw.metadata_producer,
    creation_date: raw.metadata_creation_date,
    mod_date: raw.metadata_mod_date,
  }

  let doc_chars = @text.build_document_chars(raw)
  let doc_spans = @text.build_document_spans(doc_chars)
  let doc_lines = @text.build_document_lines(doc_spans)
  let doc_blocks = @text.build_document_blocks(doc_lines)

  if raw.pages.length() != doc_chars.pages.length() {
    return Err(PdfError::BuildFailed("raw pages length != char pages length"))
  }

  if raw.pages.length() != doc_spans.pages.length() {
    return Err(PdfError::BuildFailed("raw pages length != span pages length"))
  }

  if raw.pages.length() != doc_lines.pages.length() {
    return Err(PdfError::BuildFailed("raw pages length != line pages length"))
  }

  if raw.pages.length() != doc_blocks.pages.length() {
    return Err(PdfError::BuildFailed("raw pages length != block pages length"))
  }

  let pages = Array::new()

  for i = 0; i < raw.pages.length(); i = i + 1 {
    let raw_page = raw.pages[i]
    let block_page = doc_blocks.pages[i]
    pages.push(build_page_model_from_blocks(raw_page, block_page.blocks))
  }

  Ok({
    version: raw.version,
    page_count: raw.page_count,
    metadata,
    is_encrypted: raw.is_encrypted,
    has_xref_stream: raw.has_xref_stream,
    has_object_stream: raw.has_object_stream,
    outlines: [],
    pages,
  })
}

///|
/// 从单页 blocks 构建 PageModel。
fn build_page_model_from_blocks(
  raw_page : @raw.RawPdfPageExtract,
  blocks : Array[@model.PdfTextBlock],
) -> @model.PdfPageModel {
  {
    page_index: raw_page.page_index,
    page_label: None,
    rotation: raw_page.rotation,
    user_unit: None,
    boxes: {
      media_box: raw_page.media_box.unwrap_or(default_rect()),
      crop_box: raw_page.crop_box,
      bleed_box: None,
      trim_box: None,
      art_box: None,
    },
    text_blocks: blocks,
    images: build_page_images_from_raw(raw_page.images),
    vectors: [],
    annotations: build_page_annotations_from_raw(raw_page.annotations),
    forms: build_page_forms_from_raw(raw_page.forms),
    reading_order_candidates: [],
    artifact_candidates: [],
    raw_content_stream_refs: raw_page.raw_content_stream_refs,
  }
}

///|
/// 从 raw annotations 构建 page model annotations。
fn build_page_annotations_from_raw(
  raw_annotations : Array[@raw.RawAnnotationInfo],
) -> Array[@model.PdfAnnotationObject] {
  let out : Array[@model.PdfAnnotationObject] = Array::new()

  for raw_annotation in raw_annotations {
    match raw_annotation.bbox {
      Some(bbox) => {
        let annotation : @model.PdfAnnotationObject = {
          id: raw_annotation.id,
          subtype: raw_annotation.subtype,
          flags: raw_annotation.flags,
          bbox,
          contents: raw_annotation.contents,
          subject: raw_annotation.subject,
          uri: raw_annotation.uri,
          dest: raw_annotation.dest,
          target_page: raw_annotation.target_page,
          color: raw_annotation.color,
          object_ref: raw_pdf_ref_to_string(raw_annotation.object_ref),
          source_refs: build_source_refs_from_raw(raw_annotation.source_refs),
        }
        out.push(annotation)
      }
      None => ()
    }
  }

  out
}

///|
fn build_page_forms_from_raw(
  raw_forms : Array[@raw.RawFormFieldInfo],
) -> Array[@model.PdfFormField] {
  let out : Array[@model.PdfFormField] = Array::new()

  for raw_form in raw_forms {
    let form : @model.PdfFormField = {
      id: raw_form.id,
      field_type: raw_form.field_type,
      flags: raw_form.flags,
      field_name: match raw_form.field_label {
        Some(label) => Some(label)
        None => raw_form.field_name
      },
      field_value: raw_form.field_value,
      bbox: raw_form.bbox,
      page_index: raw_form.page_index,
      options: raw_form.options,
      checked_state: raw_form.checked_state,
      source_refs: build_source_refs_from_raw(raw_form.source_refs),
    }
    out.push(form)
  }

  out
}

///|
/// 从 raw images 构建 page model images。
fn build_page_images_from_raw(
  raw_images : Array[@raw.RawImageInfo],
) -> Array[@model.PdfImageObject] {
  let out : Array[@model.PdfImageObject] = Array::new()

  for raw_image in raw_images {
    let image : @model.PdfImageObject = {
      id: raw_image.id,
      bbox: match raw_image.bbox {
        Some(b) => b
        None => default_rect()
      },
      width_px: raw_image.width_px,
      height_px: raw_image.height_px,
      colorspace: raw_image.colorspace,
      bits_per_component: raw_image.bits_per_component,
      image_filter: raw_image.image_filter,
      object_ref: raw_pdf_ref_to_string(raw_image.object_ref),
      alt_text: raw_image.alt_text,
      inline_image: raw_image.inline_image,
      payload: map_image_payload_from_raw(raw_image.payload),
      source_refs: build_source_refs_from_raw(raw_image.source_refs),
    }
    out.push(image)
  }

  out
}

///|
fn map_image_payload_from_raw(
  payload : @raw.RawImagePayload?,
) -> @model.PdfImagePayload? {
  match payload {
    Some(@raw.RawImagePayload::Jpeg(bytes)) =>
      Some(@model.PdfImagePayload::Jpeg(bytes))
    Some(@raw.RawImagePayload::Jpeg2000(bytes)) =>
      Some(@model.PdfImagePayload::Jpeg2000(bytes))
    Some(@raw.RawImagePayload::Jbig2(bytes, globals)) =>
      Some(@model.PdfImagePayload::Jbig2(bytes, globals))
    Some(@raw.RawImagePayload::RawRgb24(bytes)) =>
      Some(@model.PdfImagePayload::RawRgb24(bytes))
    None => None
  }
}

///|
fn build_source_refs_from_raw(
  refs : Array[@raw.RawSourceRef],
) -> Array[@model.PdfSourceRef] {
  let out : Array[@model.PdfSourceRef] = Array::new()

  for _ref in refs {
    let source_ref : @model.PdfSourceRef = {
      page_index: _ref.page_index,
      source_stream_index: _ref.source_stream_index,
      source_op_index: _ref.source_op_index,
      text_object_id: _ref.text_object_id,
      content_order_index: _ref.content_order_index,
      source_object_ref: raw_pdf_ref_to_string(_ref.source_object_ref),
    }
    out.push(source_ref)
  }

  out
}

///|
fn raw_pdf_ref_to_string(raw_ref : @raw.RawPdfRef?) -> String? {
  match raw_ref {
    Some(r) => Some(r.obj_num.to_string() + " " + r.gen_num.to_string() + " R")
    None => None
  }
}

///|
fn default_rect() -> @model.PdfRect {
  { x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0 }
}

///|
fn option_to_string(v : String?) -> String {
  match v {
    Some(s) => s
    None => "None"
  }
}
