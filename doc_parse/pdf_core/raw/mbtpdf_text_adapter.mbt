///|
/// 适配层错误。

///|
pub(all) suberror MbtPdfAdapterError {
  OpenFailed(String)
  ExtractFailed(String)
  Unsupported(String)
}

///|
pub impl Show for MbtPdfAdapterError with to_string(self : MbtPdfAdapterError) -> String {
  match self {
    OpenFailed(msg) => "OpenFailed: " + msg
    ExtractFailed(msg) => "ExtractFailed: " + msg
    Unsupported(msg) => "Unsupported: " + msg
  }
}

///|
pub impl Show for MbtPdfAdapterError with output(
  self : MbtPdfAdapterError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
priv struct TextState {
  mut in_text : Bool
  mut current_font_name : String?
  mut current_font_size : Double?
  mut current_extractor : @pdftext.TextExtractor?
  mut text_object_id : Int
  mut content_order_index : Int
  mut _pending_break_before : Bool
  mut _pending_break_reason : String?
}

///|
fn default_text_state() -> TextState {
  {
    in_text: false,
    current_font_name: None,
    current_font_size: None,
    current_extractor: None,
    text_object_id: 0,
    content_order_index: 0,
    _pending_break_before: false,
    _pending_break_reason: None,
  }
}

///|
/// 对外主入口：
/// - 读文件
/// - 枚举 pages
/// - 逐页抽 RawTextOp
pub async fn extract_raw_document_with_mbtpdf(
  path : String,
) -> Result[RawPdfDocumentExtract, MbtPdfAdapterError] {
  let pdf = @mbtpdf.read_file(path) catch {
    err => {
      let _ = err
      return Err(MbtPdfAdapterError::OpenFailed(path))
    }
  }

  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree() catch {
    err => {
      let _ = err
      return Err(MbtPdfAdapterError::ExtractFailed("pages_of_pagetree failed"))
    }
  }

  let raw_pages = Array::new()

  for i = 0; i < pages.length(); i = i + 1 {
    let page = pages[i]
    let raw_page = extract_raw_page_from_page(pdf, page, i) catch {
      err => {
        let _ = err
        return Err(
          MbtPdfAdapterError::ExtractFailed(
            "extract_raw_page_from_page failed at page " + i.to_string(),
          ),
        )
      }
    }
    raw_pages.push(raw_page)
  }

  Ok({
    version: pdf.major.to_string() + "." + pdf.minor.to_string(),
    page_count: raw_pages.length(),
    is_encrypted: pdf.saved_encryption is Some(_),
    has_xref_stream: false,
    has_object_stream: false,
    metadata_title: None,
    metadata_author: None,
    metadata_subject: None,
    metadata_keywords: [],
    metadata_creator: None,
    metadata_producer: None,
    metadata_creation_date: None,
    metadata_mod_date: None,
    pages: raw_pages,
  })
}

///|
/// 逐页抽取。
fn extract_raw_page_from_page(
  pdf : @pdf.Pdf,
  page : @pdfpage.Page,
  page_index : Int,
) -> RawPdfPageExtract raise {
  let text = @pdftext.PdfText::new(pdf)
  let ops = @pdfops.Op::parse_operators(pdf, page.resources, page.content)
  let text_ops = collect_text_ops_from_ops(
    pdf,
    text,
    page.resources,
    page.content,
    ops,
    page_index,
    0,
  )

  {
    page_index,
    raw_page_ref: None,
    text_ops,
    images: [],
    annotations: [],
    raw_content_stream_refs: [],
  }
}

///|
/// 核心：把 operator 流转成 RawTextOp。
///
/// 这里故意不走 PdfText::extract_text()，因为那条链最终会写进 StringBuilder，
/// 结构信号会在终点丢失。当前它内部正是消费 parse_operators(...) 的结果。
fn collect_text_ops_from_ops(
  pdf : @pdf.Pdf,
  text : @pdftext.PdfText,
  resources : @pdf.PdfObject,
  _streams : Array[@pdf.PdfObject],
  ops : Array[@pdfops.Op],
  page_index : Int,
  source_stream_index : Int,
) -> Array[RawTextOp] raise {
  let out = Array::new()
  let extractor_cache : Map[String, @pdftext.TextExtractor] = Map::new()
  let visited : Map[Int, Bool] = Map::new()
  let state = Ref::new(default_text_state())

  fn next_content_order() -> Int {
    let v = state.val.content_order_index
    state.val.content_order_index = v + 1
    v
  }

  fn set_pending_break(reason : String) -> Unit {
    state.val._pending_break_before = true
    state.val._pending_break_reason = Some(reason)
  }

  fn clear_pending_break() -> Unit {
    state.val._pending_break_before = false
    state.val._pending_break_reason = None
  }

  fn maybe_update_font(font_name : String, size : Double) -> Unit {
    let extractor = lookup_text_extractor(
      pdf, text, resources, font_name, extractor_cache,
    )
    state.val.current_font_name = Some(font_name)
    state.val.current_font_size = Some(size)
    state.val.current_extractor = extractor
  }

  fn append_show_text(
    kind : RawTextOpKind,
    raw_text : String,
    source_op_index : Int,
  ) -> Unit {
    if !state.val.in_text {
      return
    }

    let source = make_source_ref(
      page_index,
      source_stream_index,
      source_op_index,
      Some(state.val.text_object_id),
      Some(next_content_order()),
    )

    let glyphs = decode_glyphs(
      state.val.current_extractor,
      raw_text,
      source,
      state.val.current_font_name,
      state.val.current_font_size,
    )

    let font = make_raw_font_info(
      state.val.current_font_name,
      state.val.current_font_size,
    )

    out.push({
      kind,
      page_index,
      source_stream_index,
      source_op_index,
      text_object_id: Some(state.val.text_object_id),
      content_order_index: source.content_order_index,
      raw_text: Some(raw_text),
      glyphs,
      origin: None,
      bbox: None,
      font: Some(font),
      break_before: state.val._pending_break_before,
      break_reason: state.val._pending_break_reason,
    })

    clear_pending_break()
  }

  fn append_show_text_array(
    obj : @pdf.PdfObject,
    source_op_index : Int,
  ) -> Unit {
    if !state.val.in_text {
      return
    }

    let parts = extract_text_fragments_from_tj_array(obj)
    if parts.is_empty() {
      return
    }

    let joined = parts.join("")
    let source = make_source_ref(
      page_index,
      source_stream_index,
      source_op_index,
      Some(state.val.text_object_id),
      Some(next_content_order()),
    )

    let glyphs = decode_glyphs(
      state.val.current_extractor,
      joined,
      source,
      state.val.current_font_name,
      state.val.current_font_size,
    )

    let font = make_raw_font_info(
      state.val.current_font_name,
      state.val.current_font_size,
    )

    out.push({
      kind: RawTextOpKind::ShowTextArray,
      page_index,
      source_stream_index,
      source_op_index,
      text_object_id: Some(state.val.text_object_id),
      content_order_index: source.content_order_index,
      raw_text: Some(joined),
      glyphs,
      origin: None,
      bbox: None,
      font: Some(font),
      break_before: state.val._pending_break_before,
      break_reason: state.val._pending_break_reason,
    })

    clear_pending_break()
  }

  fn mark_visited(obj_num : Int?) -> Bool {
    match obj_num {
      Some(i) =>
        match visited.get(i) {
          Some(true) => false
          _ => {
            visited.set(i, true)
            true
          }
        }
      None => true
    }
  }

  fn recurse_form_xobject(name : String, _source_op_index : Int) -> Unit raise {
    match pdf.lookup_direct("/XObject", resources) {
      Some(@pdf.PdfObject::Dictionary(entries)) =>
        if entries.search_by(pair => pair.0 == name) is Some(idx) {
          let obj_ref = entries[idx].1
          let obj_num : Int? = if obj_ref is @pdf.PdfObject::Indirect(i) {
            Some(i)
          } else {
            None
          }
          if mark_visited(obj_num) {
            let xobj = pdf.direct(obj_ref)
            if pdf.lookup_direct("/Subtype", xobj)
              is Some(@pdf.PdfObject::Name(n)) &&
              n.equal_string_bytes("/Form") {
              let xresources = pdf
                .lookup_direct("/Resources", xobj)
                .unwrap_or(resources)
              let xstreams : Array[@pdf.PdfObject] = [xobj]
              let xops = @pdfops.Op::parse_operators(pdf, xresources, xstreams)
              let nested = collect_text_ops_from_ops(
                pdf, text, xresources, xstreams, xops, page_index, source_stream_index,
              )
              for op in nested {
                out.push({
                  kind: RawTextOpKind::FormXObjectText,
                  page_index: op.page_index,
                  source_stream_index: op.source_stream_index,
                  source_op_index: op.source_op_index,
                  text_object_id: op.text_object_id,
                  content_order_index: op.content_order_index,
                  raw_text: op.raw_text,
                  glyphs: op.glyphs,
                  origin: op.origin,
                  bbox: op.bbox,
                  font: op.font,
                  break_before: op.break_before,
                  break_reason: op.break_reason,
                })
              }
            }
          }
        }
      _ => ()
    }
  }

  for i = 0; i < ops.length(); i = i + 1 {
    let op = ops[i]
    match op {
      @pdfops.Op::OpBT => {
        state.val.in_text = true
        state.val.current_extractor = None
        state.val.text_object_id = state.val.text_object_id + 1
      }
      @pdfops.Op::OpET => {
        state.val.in_text = false
        state.val.current_extractor = None
      }
      @pdfops.Op::OpTf(name, size) =>
        if state.val.in_text {
          maybe_update_font(name, size)
        }
      @pdfops.Op::OpTj(text_value) =>
        append_show_text(RawTextOpKind::ShowText, text_value, i)
      @pdfops.Op::OpTJ(obj) => append_show_text_array(obj, i)
      @pdfops.Op::OpSingleQuote(text_value) =>
        if state.val.in_text {
          set_pending_break("single_quote")
          append_show_text(RawTextOpKind::Quote, text_value, i)
        }
      @pdfops.Op::OpDoubleQuote(_, _, text_value) =>
        if state.val.in_text {
          set_pending_break("double_quote")
          append_show_text(RawTextOpKind::DoubleQuote, text_value, i)
        }
      @pdfops.Op::OpTStar => if state.val.in_text { set_pending_break("tstar") }
      @pdfops.Op::OpTd(_, _) => ()
      @pdfops.Op::OpTD(_, _) => ()
      @pdfops.Op::OpTm(_) => ()
      @pdfops.Op::OpDo(name) => recurse_form_xobject(name, i)
      _ => ()
    }
  }

  out
}

///|
/// 从 TJ 数组里抽 string 片段。
///
/// 当前先复用 MBTPDF 现有 extract_text 行为：
/// 只消费 string 元素，忽略数值间距项。:contentReference[oaicite:3]{index=3}
fn extract_text_fragments_from_tj_array(obj : @pdf.PdfObject) -> Array[String] {
  let out = Array::new()
  match obj {
    @pdf.PdfObject::Array(values) =>
      for value in values {
        match value {
          @pdf.PdfObject::String(text) => out.push(text)
          _ => ()
        }
      }
    @pdf.PdfObject::String(text) => out.push(text)
    _ => ()
  }
  out
}

///|
/// 通过当前 TextExtractor 解码 glyph / codepoints。
fn decode_glyphs(
  extractor : @pdftext.TextExtractor?,
  raw_text : String,
  source : RawSourceRef,
  font_name : String?,
  font_size : Double?,
) -> Array[RawDecodedGlyph] {
  match extractor {
    Some(ext) =>
      try {
        let pairs = ext.glyphnames_and_codepoints_of_text(raw_text)
        let out = Array::new()
        for pair in pairs {
          let glyph_name = pair.0
          let cps = pair.1
          let decoded_text = @pdftext.PdfTextUtil::new().utf8_of_codepoints(cps) catch {
            _ => glyph_name
          }
          out.push({
            unicode: decoded_text,
            raw_bytes: None,
            decoded_text,
            origin: None,
            bbox: None,
            advance_width: None,
            glyph_width: None,
            font_name,
            font_size,
            fill_color: None,
            rotation: None,
            is_ligature: false,
            is_compat_glyph: false,
            decode_confidence: Some(1.0),
            source,
          })
        }
        out
      } catch {
        _ => [make_fallback_glyph(raw_text, source, font_name, font_size)]
      }
    None => [make_fallback_glyph(raw_text, source, font_name, font_size)]
  }
}

///|
fn make_fallback_glyph(
  text : String,
  source : RawSourceRef,
  font_name : String?,
  font_size : Double?,
) -> RawDecodedGlyph {
  {
    unicode: text,
    raw_bytes: None,
    decoded_text: text,
    origin: None,
    bbox: None,
    advance_width: None,
    glyph_width: None,
    font_name,
    font_size,
    fill_color: None,
    rotation: None,
    is_ligature: false,
    is_compat_glyph: false,
    decode_confidence: Some(0.5),
    source,
  }
}

///|
fn lookup_text_extractor(
  pdf : @pdf.Pdf,
  text : @pdftext.PdfText,
  resources : @pdf.PdfObject,
  font_name : String,
  cache : Map[String, @pdftext.TextExtractor],
) -> @pdftext.TextExtractor? {
  if cache.get(font_name) is Some(extractor) {
    return Some(extractor)
  }

  match pdf.lookup_direct("/Font", resources) {
    Some(fonts) =>
      match pdf.lookup_direct(font_name, fonts) {
        Some(obj) =>
          try {
            let extractor = text.text_extractor_of_font(obj)
            cache.set(font_name, extractor)
            Some(extractor)
          } catch {
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn make_source_ref(
  page_index : Int,
  source_stream_index : Int,
  source_op_index : Int,
  text_object_id : Int?,
  content_order_index : Int?,
) -> RawSourceRef {
  {
    page_index,
    source_stream_index,
    source_op_index,
    text_object_id,
    content_order_index,
    source_object_ref: None,
  }
}

///|
fn make_raw_font_info(font_name : String?, font_size : Double?) -> RawFontInfo {
  {
    font_name,
    font_family: None,
    font_size,
    is_bold: false,
    is_italic: false,
    is_monospace: false,
    fill_color: None,
    stroke_color: None,
    char_spacing: None,
    word_spacing: None,
    text_rise: None,
    scale_x: None,
  }
}
