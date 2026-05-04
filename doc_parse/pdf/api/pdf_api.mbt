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
pub impl Show for PdfError with to_string(self : PdfError) -> String {
  match self {
    AdapterFailed(msg) => "AdapterFailed: " + msg
    BuildFailed(msg) => "BuildFailed: " + msg
    Unsupported(msg) => "Unsupported: " + msg
  }
}

///|
pub impl Show for PdfError with output(self : PdfError, logger : &Logger) -> Unit {
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
priv struct PdfDebugBundle {
  raw : @raw.RawPdfDocumentExtract
  doc : @model.PdfDocumentModel
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

  build_document_model_from_raw(raw)
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
/// 打印 PDF lower-layer parser 页面 / block / line / image / annotation 调试信息，
/// 用于确认 page geometry、对象来源和文本结构是否符合预期。
pub async fn extract_document_block_debug(
  path : String,
  config : PdfConfig,
) -> Result[String, PdfError] {
  match extract_document_debug_bundle(path, config) {
    Ok(bundle) => Ok(render_document_block_debug(bundle.raw, bundle.doc))
    Err(err) => Err(err)
  }
}

///|
/// 更细粒度的 inspect dump：
/// - 页级统计
/// - block / line / span / char 结构
/// - image / annotation 来源
///
/// 这是诊断输出，不是稳定的 IR / Markdown 合同。
pub async fn extract_document_inspect_dump(
  path : String,
  config : PdfConfig,
) -> Result[String, PdfError] {
  match extract_document_debug_bundle(path, config) {
    Ok(bundle) => Ok(render_document_inspect_dump(bundle.raw, bundle.doc))
    Err(err) => Err(err)
  }
}

///|
fn opt_str_or_none(v : String?) -> String {
  match v {
    Some(s) => s
    None => "None"
  }
}

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
fn opt_rect_str(r : @model.PdfRect?) -> String {
  match r {
    Some(rect) => rect_str(rect)
    None => "None"
  }
}

///|
fn string_array_str(items : Array[String]) -> String {
  if items.is_empty() {
    return "[]"
  }

  "[" + items.join(", ") + "]"
}

///|
fn page_line_count(page : @model.PdfPageModel) -> Int {
  let mut total = 0
  for block in page.text_blocks {
    total = total + block.lines.length()
  }
  total
}

///|
fn page_span_count(page : @model.PdfPageModel) -> Int {
  @model.page_span_count(page)
}

///|
fn page_char_count(page : @model.PdfPageModel) -> Int {
  @model.page_char_count(page)
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
fn document_line_count(doc : @model.PdfDocumentModel) -> Int {
  let mut total = 0
  for page in doc.pages {
    total = total + page_line_count(page)
  }
  total
}

///|
fn document_span_count(doc : @model.PdfDocumentModel) -> Int {
  let mut total = 0
  for page in doc.pages {
    total = total + page_span_count(page)
  }
  total
}

///|
fn document_char_count(doc : @model.PdfDocumentModel) -> Int {
  let mut total = 0
  for page in doc.pages {
    total = total + page_char_count(page)
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
fn shorten_text(text : String, limit : Int) -> String {
  if text.length() > limit {
    text[:limit].to_owned() + "..."
  } else {
    text
  }
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
fn render_document_block_debug(
  raw : @raw.RawPdfDocumentExtract,
  doc : @model.PdfDocumentModel,
) -> String {
  let mut out = ""
  out = out +
    "PdfDocumentDebug(" +
    "version=" +
    doc.version +
    ", " +
    "page_count=" +
    doc.page_count.to_string() +
    ", " +
    "encrypted=" +
    doc.is_encrypted.to_string() +
    ", " +
    "has_xref_stream=" +
    doc.has_xref_stream.to_string() +
    ", " +
    "has_object_stream=" +
    doc.has_object_stream.to_string() +
    ", " +
    "title=" +
    option_to_string(doc.metadata.title) +
    ", " +
    "total_blocks=" +
    document_block_count(doc).to_string() +
    ", " +
    "total_lines=" +
    document_line_count(doc).to_string() +
    ", " +
    "total_spans=" +
    document_span_count(doc).to_string() +
    ", " +
    "total_images=" +
    document_image_count(doc).to_string() +
    ", " +
    "total_annotations=" +
    document_annotation_count(doc).to_string() +
    ")\n"

  for i = 0; i < doc.pages.length(); i = i + 1 {
    let raw_page = raw.pages[i]
    let page = doc.pages[i]

    out = out + "[page " + page.page_index.to_string() + "]\n"
    out = out +
      "  raw_page_ref=" +
      opt_str_or_none(raw_pdf_ref_to_string(raw_page.raw_page_ref)) +
      "\n"
    out = out + "  media_box=" + opt_rect_str(raw_page.media_box) + "\n"
    out = out + "  crop_box=" + opt_rect_str(raw_page.crop_box) + "\n"
    out = out + "  rotation=" + raw_page.rotation.to_string() + "\n"
    out = out +
      "  raw_content_stream_refs=" +
      string_array_str(raw_page.raw_content_stream_refs) +
      "\n"
    out = out +
      "  stats: text_blocks=" +
      page.text_blocks.length().to_string() +
      ", lines=" +
      page_line_count(page).to_string() +
      ", spans=" +
      page_span_count(page).to_string() +
      ", images=" +
      page.images.length().to_string() +
      ", annotations=" +
      page.annotations.length().to_string() +
      ", page_objects=" +
      @model.page_object_count(page).to_string() +
      "\n"

    if page.images.is_empty() {
      out = out + "  images=[]\n"
    } else {
      for j = 0; j < page.images.length(); j = j + 1 {
        let image = page.images[j]
        out = out +
          "  [image " +
          j.to_string() +
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

    if page.annotations.is_empty() {
      out = out + "  annotations=[]\n"
    } else {
      for j = 0; j < page.annotations.length(); j = j + 1 {
        let annotation = page.annotations[j]
        let target_page_str = match annotation.target_page {
          Some(v) => v.to_string()
          None => "None"
        }
        out = out +
          "  [annotation " +
          j.to_string() +
          "] " +
          "subtype=" +
          annotation.subtype +
          ", uri=" +
          opt_str_or_none(annotation.uri) +
          ", dest=" +
          opt_str_or_none(annotation.dest) +
          ", target_page=" +
          target_page_str +
          ", object_ref=" +
          opt_str_or_none(annotation.object_ref) +
          ", bbox=" +
          rect_str(annotation.bbox) +
          "\n"
      }
    }

    for j = 0; j < page.text_blocks.length(); j = j + 1 {
      let block = page.text_blocks[j]
      let text = shorten_text(@model.block_text(block).trim().to_owned(), 160)

      out = out +
        "  [block " +
        j.to_string() +
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
        ", span_count=" +
        @model.block_span_count(block).to_string() +
        ", char_count=" +
        @model.block_char_count(block).to_string() +
        ", font_size=" +
        opt_f64(block.dominant_font_size) +
        ", font_name=" +
        opt_str(block.dominant_font_name) +
        ", bbox=" +
        rect_str(block.bbox) +
        ", text=\"" +
        text +
        "\"\n"

      for k = 0; k < block.lines.length(); k = k + 1 {
        let line = block.lines[k]
        let line_short = shorten_text(
          @model.line_text(line).trim().to_owned(),
          120,
        )

        out = out +
          "    [line " +
          k.to_string() +
          "] text=\"" +
          line_short +
          "\"" +
          ", indent_left=" +
          opt_f64(line.indent_left) +
          ", gap_before=" +
          opt_f64(line.line_gap_before) +
          ", gap_after=" +
          opt_f64(line.line_gap_after) +
          ", source_refs=" +
          line.source_refs.length().to_string() +
          ", bbox=" +
          rect_str(line.bbox) +
          "\n"
      }
    }
  }

  out
}

///|
fn render_document_inspect_dump(
  raw : @raw.RawPdfDocumentExtract,
  doc : @model.PdfDocumentModel,
) -> String {
  let out : Array[String] = []
  out.push(
    "PdfDocumentInspect(" +
    "version=" +
    doc.version +
    ", page_count=" +
    doc.page_count.to_string() +
    ", encrypted=" +
    doc.is_encrypted.to_string() +
    ", has_xref_stream=" +
    doc.has_xref_stream.to_string() +
    ", has_object_stream=" +
    doc.has_object_stream.to_string() +
    ", outlines=" +
    doc.outlines.length().to_string() +
    ", blocks=" +
    document_block_count(doc).to_string() +
    ", lines=" +
    document_line_count(doc).to_string() +
    ", spans=" +
    document_span_count(doc).to_string() +
    ", chars=" +
    document_char_count(doc).to_string() +
    ", images=" +
    document_image_count(doc).to_string() +
    ", annotations=" +
    document_annotation_count(doc).to_string() +
    ")",
  )

  for i = 0; i < doc.pages.length(); i = i + 1 {
    let raw_page = raw.pages[i]
    let page = doc.pages[i]
    out.push(
      "[page " +
      page.page_index.to_string() +
      "] media_box=" +
      rect_str(page.boxes.media_box) +
      " crop_box=" +
      opt_rect_str(page.boxes.crop_box) +
      " rotation=" +
      page.rotation.to_string() +
      " raw_page_ref=" +
      opt_str_or_none(raw_pdf_ref_to_string(raw_page.raw_page_ref)) +
      " raw_content_stream_refs=" +
      string_array_str(page.raw_content_stream_refs),
    )
    out.push(
      "  stats: blocks=" +
      page.text_blocks.length().to_string() +
      ", lines=" +
      @model.page_line_count(page).to_string() +
      ", spans=" +
      @model.page_span_count(page).to_string() +
      ", chars=" +
      @model.page_char_count(page).to_string() +
      ", images=" +
      page.images.length().to_string() +
      ", annotations=" +
      page.annotations.length().to_string() +
      ", object_count=" +
      @model.page_object_count(page).to_string(),
    )
    out.push(
      "  signals: top_edge_threshold=" +
      @model.top_edge_threshold(page).to_string() +
      ", bottom_edge_threshold=" +
      @model.bottom_edge_threshold(page).to_string() +
      ", header_footer_candidates=" +
      @model.page_header_footer_candidate_count(page).to_string() +
      ", page_number_candidates=" +
      @model.page_page_number_candidate_count(page).to_string() +
      ", artifact_candidates=" +
      @model.page_artifact_candidate_count(page).to_string(),
    )

    for block_index = 0
        block_index < page.text_blocks.length()
        block_index = block_index + 1 {
      let block = page.text_blocks[block_index]
      out.push(
        "  [block " +
        block_index.to_string() +
        "] id=" +
        block.id +
        " kind=" +
        core_block_kind_str(block.kind) +
        " bbox=" +
        rect_str(block.bbox) +
        " top_edge=" +
        @model.is_top_edge_block(page, block).to_string() +
        " bottom_edge=" +
        @model.is_bottom_edge_block(page, block).to_string() +
        " edge_region=" +
        @model.is_edge_region_block(page, block).to_string() +
        " heading=" +
        block.is_heading_candidate.to_string() +
        " header_footer=" +
        block.is_header_footer_candidate.to_string() +
        " page_number=" +
        block.is_page_number_candidate.to_string() +
        " artifact=" +
        block.is_artifact_candidate.to_string() +
        " caption=" +
        block.is_caption_candidate.to_string() +
        " table_cell=" +
        block.is_table_cell_candidate.to_string() +
        " lines=" +
        block.lines.length().to_string() +
        " spans=" +
        @model.block_span_count(block).to_string() +
        " chars=" +
        @model.block_char_count(block).to_string() +
        " source_refs=" +
        @model.block_source_ref_count(block).to_string() +
        " text=\"" +
        shorten_text(@model.block_text(block).trim().to_owned(), 120) +
        "\"",
      )
      if !block.source_refs.is_empty() {
        out.push(
          "    block_source[0]=" +
          @model.source_ref_to_string(block.source_refs[0]),
        )
      }

      for line_index = 0
          line_index < block.lines.length()
          line_index = line_index + 1 {
        let line = block.lines[line_index]
        out.push(
          "    [line " +
          line_index.to_string() +
          "] id=" +
          line.id +
          " bbox=" +
          rect_str(line.bbox) +
          " baseline_y=" +
          opt_f64(line.baseline_y) +
          " line_height=" +
          opt_f64(line.line_height) +
          " indent_left=" +
          opt_f64(line.indent_left) +
          " indent_right=" +
          opt_f64(line.indent_right) +
          " gap_before=" +
          opt_f64(line.line_gap_before) +
          " gap_after=" +
          opt_f64(line.line_gap_after) +
          " wrapped=" +
          line.is_wrapped_candidate.to_string() +
          " same_paragraph_prev=" +
          line.is_same_paragraph_with_prev_candidate.to_string() +
          " spans=" +
          line.spans.length().to_string() +
          " chars=" +
          @model.line_char_count(line).to_string() +
          " source_refs=" +
          @model.line_source_ref_count(line).to_string() +
          " text=\"" +
          shorten_text(@model.line_text(line).trim().to_owned(), 100) +
          "\"",
        )
        if !line.source_refs.is_empty() {
          out.push(
            "      line_source[0]=" +
            @model.source_ref_to_string(line.source_refs[0]),
          )
        }

        for span_index = 0
            span_index < line.spans.length()
            span_index = span_index + 1 {
          let span = line.spans[span_index]
          out.push(
            "      [span " +
            span_index.to_string() +
            "] id=" +
            span.id +
            " bbox=" +
            rect_str(span.bbox) +
            " font_name=" +
            opt_str(span.font_name) +
            " font_size=" +
            opt_f64(span.font_size) +
            " bold=" +
            span.is_bold.to_string() +
            " italic=" +
            span.is_italic.to_string() +
            " monospace=" +
            span.is_monospace.to_string() +
            " chars=" +
            span.chars.length().to_string() +
            " source_refs=" +
            @model.span_source_ref_count(span).to_string() +
            " text=\"" +
            shorten_text(span.text, 80) +
            "\"",
          )
          if !span.source_refs.is_empty() {
            out.push(
              "        span_source[0]=" +
              @model.source_ref_to_string(span.source_refs[0]),
            )
          }
        }
      }
    }

    if page.images.is_empty() {
      out.push("  images=[]")
    } else {
      for image_index = 0
          image_index < page.images.length()
          image_index = image_index + 1 {
        let image = page.images[image_index]
        out.push(
          "  [image " +
          image_index.to_string() +
          "] id=" +
          image.id +
          " bbox=" +
          rect_str(image.bbox) +
          " width=" +
          image.width_px.to_string() +
          " height=" +
          image.height_px.to_string() +
          " inline=" +
          image.inline_image.to_string() +
          " object_ref=" +
          opt_str_or_none(image.object_ref) +
          " source_refs=" +
          image.source_refs.length().to_string(),
        )
        if !image.source_refs.is_empty() {
          out.push(
            "    image_source[0]=" +
            @model.source_ref_to_string(image.source_refs[0]),
          )
        }
      }
    }

    if page.annotations.is_empty() {
      out.push("  annotations=[]")
    } else {
      for annotation_index = 0
          annotation_index < page.annotations.length()
          annotation_index = annotation_index + 1 {
        let annotation = page.annotations[annotation_index]
        let target_page_str = match annotation.target_page {
          Some(v) => v.to_string()
          None => "None"
        }
        out.push(
          "  [annotation " +
          annotation_index.to_string() +
          "] id=" +
          annotation.id +
          " subtype=" +
          annotation.subtype +
          " bbox=" +
          rect_str(annotation.bbox) +
          " uri=" +
          opt_str_or_none(annotation.uri) +
          " dest=" +
          opt_str_or_none(annotation.dest) +
          " target_page=" +
          target_page_str +
          " object_ref=" +
          opt_str_or_none(annotation.object_ref) +
          " source_refs=" +
          annotation.source_refs.length().to_string(),
        )
        if !annotation.source_refs.is_empty() {
          out.push(
            "    annotation_source[0]=" +
            @model.source_ref_to_string(annotation.source_refs[0]),
          )
        }
      }
    }
  }

  out.join("\n") + "\n"
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
async fn extract_document_debug_bundle(
  path : String,
  config : PdfConfig,
) -> Result[PdfDebugBundle, PdfError] {
  let raw = match extract_raw_document(path, config) {
    Ok(v) => v
    Err(err) => return Err(err)
  }

  match build_document_model_from_raw(raw) {
    Ok(doc) => Ok({ raw, doc })
    Err(err) => Err(err)
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
    forms: [],
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
