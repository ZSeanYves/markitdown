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
    images: [],
    vectors: [],
    annotations: [],
    forms: [],
    reading_order_candidates: [],
    artifact_candidates: [],
    raw_content_stream_refs: raw_page.raw_content_stream_refs,
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
