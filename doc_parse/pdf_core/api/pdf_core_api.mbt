///|
/// pdf_core 对外错误。
pub enum PdfCoreError {
  AdapterFailed(String)
  BuildFailed(String)
  Unsupported(String)
}

///|
pub impl Show for PdfCoreError with to_string(self : PdfCoreError) -> String {
  match self {
    AdapterFailed(msg) => "AdapterFailed: " + msg
    BuildFailed(msg) => "BuildFailed: " + msg
    Unsupported(msg) => "Unsupported: " + msg
  }
}

///|
pub impl Show for PdfCoreError with output(
  self : PdfCoreError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
/// pdf_core 后端类型。
pub enum PdfCoreBackend {
  MbtPdf
}

///|
/// 对外配置。
pub struct PdfCoreConfig {
  backend : PdfCoreBackend
}

///|
/// 默认配置。
pub fn default_pdf_core_config() -> PdfCoreConfig {
  { backend: PdfCoreBackend::MbtPdf }
}

///|
/// 对外主入口：
/// MBTPDF -> raw -> chars -> spans -> lines -> blocks -> PdfDocumentModel
pub async fn extract_document_model(
  path : String,
  config : PdfCoreConfig,
) -> Result[@model.PdfDocumentModel, PdfCoreError] {
  let raw = match config.backend {
    PdfCoreBackend::MbtPdf =>
      match @raw.extract_raw_document_with_mbtpdf(path) {
        Ok(v) => v
        Err(err) => return Err(map_adapter_error(err))
      }
  }

  build_document_model_from_raw(raw)
}

///|
/// 文档摘要，方便最小调试。
pub async fn extract_document_summary(
  path : String,
  config : PdfCoreConfig,
) -> Result[String, PdfCoreError] {
  match extract_document_model(path, config) {
    Ok(doc) => {
      let mut block_count = 0
      for page in doc.pages {
        block_count = block_count + page.text_blocks.length()
      }

      Ok(
        "PdfDocumentModel(" +
        "pages=" +
        doc.page_count.to_string() +
        ", " +
        "blocks=" +
        block_count.to_string() +
        ", " +
        "encrypted=" +
        doc.is_encrypted.to_string() +
        ", " +
        "title=" +
        option_to_string(doc.metadata.title) +
        ")",
      )
    }
    Err(err) => Err(err)
  }
}

///|
/// 打印 pdf_core 原始 page.text_blocks，
/// 用于确认 header / 标题 / 正文是否已经在 core 层分开。
pub async fn extract_document_block_debug(
  path : String,
  config : PdfCoreConfig,
) -> Result[String, PdfCoreError] {
  match extract_document_model(path, config) {
    Ok(doc) => {
      let mut out = ""
      out = out +
        "PdfDocumentModel(" +
        "pages=" +
        doc.page_count.to_string() +
        ", " +
        "encrypted=" +
        doc.is_encrypted.to_string() +
        ", " +
        "title=" +
        option_to_string(doc.metadata.title) +
        ")\n"

      for page in doc.pages {
        out = out +
          "[page " +
          page.page_index.to_string() +
          "] text_blocks=" +
          page.text_blocks.length().to_string() +
          " images=" +
          page.images.length().to_string() +
          "\n"

        for i = 0; i < page.text_blocks.length(); i = i + 1 {
          let block = page.text_blocks[i]
          let text = @model.block_text(block).trim().to_string()
          let short = if text.length() > 160 {
            text[:160].to_string() + "..."
          } else {
            text
          }

          out = out +
            "  [block " +
            i.to_string() +
            "] " +
            "kind=" +
            core_block_kind_str(block.kind) +
            ", heading_candidate=" +
            block.is_heading_candidate.to_string() +
            ", header_footer_candidate=" +
            block.is_header_footer_candidate.to_string() +
            ", page_number_candidate=" +
            block.is_page_number_candidate.to_string() +
            ", line_count=" +
            block.lines.length().to_string() +
            ", font_size=" +
            opt_f64(block.dominant_font_size) +
            ", font_name=" +
            opt_str(block.dominant_font_name) +
            ", bbox=" +
            rect_str(block.bbox) +
            ", text=\"" +
            short +
            "\"\n"

          for j = 0; j < block.lines.length(); j = j + 1 {
            let line = block.lines[j]
            let line_txt = @model.line_text(line).trim().to_string()
            let line_short = if line_txt.length() > 120 {
              line_txt[:120].to_string() + "..."
            } else {
              line_txt
            }

            out = out +
              "    [line " +
              j.to_string() +
              "] text=\"" +
              line_short +
              "\"" +
              ", indent_left=" +
              opt_f64(line.indent_left) +
              ", gap_before=" +
              opt_f64(line.line_gap_before) +
              ", gap_after=" +
              opt_f64(line.line_gap_after) +
              ", bbox=" +
              rect_str(line.bbox) +
              "\n"
          }
          for k = 0; k < page.images.length(); k = k + 1 {
            let image = page.images[k]
            out = out +
              "  [image " +
              k.to_string() +
              "] " +
              "id=" +
              image.id +
              ", width=" +
              image.width_px.to_string() +
              ", height=" +
              image.height_px.to_string() +
              ", inline=" +
              image.inline_image.to_string() +
              ", filter=" +
              opt_str_or_none(image.image_filter) +
              ", object_ref=" +
              opt_str_or_none(image.object_ref) +
              ", bbox=" +
              rect_str(image.bbox) +
              "\n"
          }
        }
      }

      Ok(out)
    }
    Err(err) => Err(err)
  }
}

///|
fn opt_str_or_none(v : String?) -> String {
  match v {
    Some(s) => s
    None => "None"
  }
} ///|

///|
fn core_block_kind_str(kind : @model.PdfTextBlockKind) -> String {
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
fn opt_f64(v : Double?) -> String {
  match v {
    Some(x) => x.to_string()
    None => "None"
  }
}

///|
fn opt_str(v : String?) -> String {
  match v {
    Some(x) => x
    None => "None"
  }
}

///|
fn rect_str(r : @model.PdfRect) -> String {
  "(" +
  r.x0.to_string() +
  "," +
  r.y0.to_string() +
  "," +
  r.x1.to_string() +
  "," +
  r.y1.to_string() +
  ")"
}

///|
fn map_adapter_error(err : @raw.MbtPdfAdapterError) -> PdfCoreError {
  match err {
    OpenFailed(msg) => PdfCoreError::AdapterFailed("open failed: " + msg)
    ExtractFailed(msg) => PdfCoreError::AdapterFailed("extract failed: " + msg)
    Unsupported(msg) => PdfCoreError::Unsupported(msg)
  }
}

///|
/// 由 raw 构建 document model。
///
/// 当前阶段先到 block 层：
/// raw -> chars -> spans -> lines -> blocks
fn build_document_model_from_raw(
  raw : @raw.RawPdfDocumentExtract,
) -> Result[@model.PdfDocumentModel, PdfCoreError] {
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
    return Err(
      PdfCoreError::BuildFailed("raw pages length != char pages length"),
    )
  }

  if raw.pages.length() != doc_spans.pages.length() {
    return Err(
      PdfCoreError::BuildFailed("raw pages length != span pages length"),
    )
  }

  if raw.pages.length() != doc_lines.pages.length() {
    return Err(
      PdfCoreError::BuildFailed("raw pages length != line pages length"),
    )
  }

  if raw.pages.length() != doc_blocks.pages.length() {
    return Err(
      PdfCoreError::BuildFailed("raw pages length != block pages length"),
    )
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
    rotation: 0,
    user_unit: None,
    boxes: {
      media_box: default_rect(),
      crop_box: None,
      bleed_box: None,
      trim_box: None,
      art_box: None,
    },
    text_blocks: blocks,
    images: build_page_images_from_raw(raw_page.images),
    vectors: [],
    annotations: [],
    forms: [],
    reading_order_candidates: [],
    artifact_candidates: [],
    raw_content_stream_refs: raw_page.raw_content_stream_refs,
  }
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
