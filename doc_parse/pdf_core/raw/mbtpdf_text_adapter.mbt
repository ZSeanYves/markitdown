///|
/// 适配层错误。
const DEBUG_MBTPDF_OP = false

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

  // 当前页面空间位置
  mut text_x : Double
  mut text_y : Double
  mut line_x : Double
  mut line_y : Double
  mut leading : Double

  // graphics state: CTM
  mut ctm : @pdftransform.TransformMatrix
  ctm_stack : Array[@pdftransform.TransformMatrix]

  // text matrix（只维护当前文本矩阵即可）
  mut tm_a : Double
  mut tm_b : Double
  mut _tm_c : Double
  mut _tm_d : Double
  mut tm_e : Double
  mut tm_f : Double
}

///|
fn identity_matrix() -> @pdftransform.TransformMatrix {
  @pdftransform.TransformMatrix::{
    a: 1.0,
    b: 0.0,
    c: 0.0,
    d: 1.0,
    e: 0.0,
    f: 0.0,
  }
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
    text_x: 0.0,
    text_y: 0.0,
    line_x: 0.0,
    line_y: 0.0,
    leading: 0.0,
    ctm: identity_matrix(),
    ctm_stack: Array::new(),
    tm_a: 1.0,
    tm_b: 0.0,
    _tm_c: 0.0,
    _tm_d: 1.0,
    tm_e: 0.0,
    tm_f: 0.0,
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
  let ops = @pdfops.Op::parse_operators_with_source(
    pdf,
    page.resources,
    page.content,
  )
  let text_ops = collect_text_ops_from_ops(
    pdf,
    text,
    page.resources,
    ops,
    page_index,
  )

  let images = collect_images_from_ops(
    pdf,
    page.resources,
    ops,
    page_index,
    identity_matrix(),
  )
  let annotations = collect_annotations_from_page(pdf, page, page_index)

  {
    page_index,
    raw_page_ref: page_ref_for_index(pdf, page_index),
    media_box: parse_pdf_rect(pdf, page.mediabox),
    crop_box: page_crop_box(pdf, page),
    rotation: page.rotate.to_int(),
    text_ops,
    images,
    annotations,
    raw_content_stream_refs: content_stream_refs(page.content),
  }
}

///|
fn page_ref_for_index(pdf : @pdf.Pdf, page_index : Int) -> RawPdfRef? {
  try {
    match @pdfpage.PdfPageDoc::new(pdf).page_object_number(page_index + 1) {
      Some(i) => Some({ obj_num: i, gen_num: 0 })
      None => None
    }
  } catch {
    _ => None
  }
}

///|
fn content_stream_refs(content : Array[@pdf.PdfObject]) -> Array[String] {
  let refs : Array[String] = []
  for obj in content {
    match obj {
      @pdf.PdfObject::Indirect(i) => refs.push(i.to_string() + " 0 R")
      _ => ()
    }
  }
  refs
}

///|
fn parse_pdf_rect(pdf : @pdf.Pdf, obj : @pdf.PdfObject) -> @model.PdfRect? {
  try {
    match pdf.parse_rectangle(obj) {
      (x0, y0, x1, y1) => Some({ x0, y0, x1, y1 })
    }
  } catch {
    _ => None
  }
}

///|
fn page_crop_box(pdf : @pdf.Pdf, page : @pdfpage.Page) -> @model.PdfRect? {
  match page.cropbox {
    Some(crop_box) => parse_pdf_rect(pdf, crop_box)
    None => None
  }
}

///|
fn raw_ref_from_pdf_object(obj : @pdf.PdfObject) -> RawPdfRef? {
  match obj {
    @pdf.PdfObject::Indirect(i) => Some({ obj_num: i, gen_num: 0 })
    _ => None
  }
}

///|
fn string_from_pdf_object(obj : @pdf.PdfObject?) -> String? {
  match obj {
    Some(@pdf.PdfObject::String(s)) => Some(s)
    _ => None
  }
}

///|
fn name_string_from_pdf_object(obj : @pdf.PdfObject?) -> String? {
  match obj {
    Some(@pdf.PdfObject::Name(name)) => Some(name.to_string_bytes())
    _ => None
  }
}

///|
fn color_from_pdf_object(
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject?,
) -> @model.PdfColor? {
  try {
    match obj {
      Some(@pdf.PdfObject::Array([r, g, b])) =>
        Some({
          r: pdf.getnum(r).to_int(),
          g: pdf.getnum(g).to_int(),
          b: pdf.getnum(b).to_int(),
        })
      _ => None
    }
  } catch {
    _ => None
  }
}

///|
fn uri_from_annotation_action(
  pdf : @pdf.Pdf,
  action : @pdf.PdfObject?,
) -> String? {
  match action {
    Some(action_obj) =>
      match pdf.lookup_direct("/S", action_obj) {
        Some(@pdf.PdfObject::Name(name)) if name.equal_string_bytes("/URI") =>
          string_from_pdf_object(pdf.lookup_direct("/URI", action_obj))
        _ => None
      }
    None => None
  }
}

///|
fn dest_string_from_annotation(
  pdf : @pdf.Pdf,
  annot_obj : @pdf.PdfObject,
) -> String? {
  match pdf.lookup_direct("/Dest", annot_obj) {
    Some(dest) => Some(dest.to_string())
    None =>
      match pdf.lookup_direct("/A", annot_obj) {
        Some(action) =>
          match pdf.lookup_direct("/D", action) {
            Some(dest) => Some(dest.to_string())
            None => None
          }
        None => None
      }
  }
}

///|
fn annotation_from_pdf_object(
  pdf : @pdf.Pdf,
  annot_ref : @pdf.PdfObject,
  page_index : Int,
  annotation_index : Int,
) -> RawAnnotationInfo? {
  let annot_obj = pdf.direct(annot_ref)
  match annot_obj {
    @pdf.PdfObject::Dictionary(_) => {
      let bbox = match pdf.lookup_direct("/Rect", annot_obj) {
        Some(rect_obj) => parse_pdf_rect(pdf, rect_obj)
        None => None
      }
      match bbox {
        Some(bbox) => {
          let action = pdf.lookup_direct("/A", annot_obj)
          Some({
            id: "annot-" +
            page_index.to_string() +
            "-" +
            annotation_index.to_string(),
            page_index,
            object_ref: raw_ref_from_pdf_object(annot_ref),
            subtype: name_string_from_pdf_object(
              pdf.lookup_direct("/Subtype", annot_obj),
            ).unwrap_or(""),
            bbox: Some(bbox),
            contents: string_from_pdf_object(
              pdf.lookup_direct("/Contents", annot_obj),
            ),
            subject: string_from_pdf_object(
              pdf.lookup_direct("/Subj", annot_obj),
            ),
            uri: uri_from_annotation_action(pdf, action),
            dest: dest_string_from_annotation(pdf, annot_obj),
            target_page: None,
            color: color_from_pdf_object(
              pdf,
              pdf.lookup_direct("/C", annot_obj),
            ),
            source_refs: [],
          })
        }
        None => None
      }
    }
    _ => None
  }
}

///|
fn collect_annotations_from_page(
  pdf : @pdf.Pdf,
  page : @pdfpage.Page,
  page_index : Int,
) -> Array[RawAnnotationInfo] {
  let out : Array[RawAnnotationInfo] = Array::new()
  match pdf.lookup_direct("/Annots", page.rest) {
    Some(@pdf.PdfObject::Array(annots)) =>
      for i = 0; i < annots.length(); i = i + 1 {
        match annotation_from_pdf_object(pdf, annots[i], page_index, i) {
          Some(annotation) => out.push(annotation)
          None => ()
        }
      }
    _ => ()
  }
  out
}

///|
/// 核心：把 operator 流转成 RawTextOp。
///
/// 这里故意不走 PdfText::extract_text()，因为那条链最终会写进 StringBuilder，
/// 结构信号会在终点丢失。当前它内部正是消费 parse_operators(...) 的结果。

///|
/// 核心：把 operator 流转成 RawTextOp。
///
/// 这里故意不走 PdfText::extract_text()，因为那条链最终会写进 StringBuilder，
/// 结构信号会在终点丢失。当前它内部正是消费 parse_operators(...) 的结果。
fn collect_text_ops_from_ops(
  pdf : @pdf.Pdf,
  text : @pdftext.PdfText,
  resources : @pdf.PdfObject,
  ops : Array[@pdfops.LocatedOp],
  page_index : Int,
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

  fn reset_text_geometry() -> Unit {
    state.val.text_x = 0.0
    state.val.text_y = 0.0
    state.val.line_x = 0.0
    state.val.line_y = 0.0
    state.val.leading = 0.0

    state.val.tm_a = 1.0
    state.val.tm_b = 0.0
    state.val._tm_c = 0.0
    state.val._tm_d = 1.0
    state.val.tm_e = 0.0
    state.val.tm_f = 0.0
  }

  fn mul_matrix(
    left : @pdftransform.TransformMatrix,
    right : @pdftransform.TransformMatrix,
  ) -> @pdftransform.TransformMatrix {
    @pdftransform.TransformMatrix::{
      a: left.a * right.a + left.b * right.c,
      b: left.a * right.b + left.b * right.d,
      c: left.c * right.a + left.d * right.c,
      d: left.c * right.b + left.d * right.d,
      e: left.e * right.a + left.f * right.c + right.e,
      f: left.e * right.b + left.f * right.d + right.f,
    }
  }

  fn apply_matrix_to_point(
    m : @pdftransform.TransformMatrix,
    x : Double,
    y : Double,
  ) -> @model.PdfPoint {
    { x: m.a * x + m.c * y + m.e, y: m.b * x + m.d * y + m.f }
  }

  fn sync_page_position_from_tm() -> Unit {
    let p = apply_matrix_to_point(state.val.ctm, state.val.tm_e, state.val.tm_f)
    state.val.line_x = p.x
    state.val.line_y = p.y
    state.val.text_x = p.x
    state.val.text_y = p.y
  }

  fn set_text_matrix(m : @pdftransform.TransformMatrix) -> Unit {
    state.val.tm_a = m.a
    state.val.tm_b = m.b
    state.val._tm_c = m.c
    state.val._tm_d = m.d
    state.val.tm_e = m.e
    state.val.tm_f = m.f
    sync_page_position_from_tm()
  }

  fn move_text_matrix_by(dx : Double, dy : Double) -> Unit {
    state.val.tm_e = state.val.tm_e + dx
    state.val.tm_f = state.val.tm_f + dy
    sync_page_position_from_tm()
  }

  fn current_origin() -> @model.PdfPoint {
    { x: state.val.text_x, y: state.val.text_y }
  }
  fn current_effective_font_size() -> Double? {
    match state.val.current_font_size {
      Some(fs) => {
        let ax = state.val.tm_a.abs()
        let by = state.val.tm_b.abs()
        let scale = if ax > by { ax } else { by }

        Some(if scale > 0.0 { fs * scale } else { fs })
      }
      None => None
    }
  }

  fn debug_op(msg : String) -> Unit {
    if DEBUG_MBTPDF_OP {
      println("[pdf-adapter] " + msg)
    }
  }

  fn debug_text_state(tag : String) -> Unit {
    if !DEBUG_MBTPDF_OP {
      return
    }

    let font_str = match state.val.current_font_size {
      Some(v) => v.to_string()
      None => "None"
    }

    println(
      "[pdf-adapter] " +
      tag +
      " tx=" +
      state.val.text_x.to_string() +
      " ty=" +
      state.val.text_y.to_string() +
      " lx=" +
      state.val.line_x.to_string() +
      " ly=" +
      state.val.line_y.to_string() +
      " leading=" +
      state.val.leading.to_string() +
      " font=" +
      font_str,
    )
  }

  fn append_show_text(
    kind : RawTextOpKind,
    raw_text : String,
    located : @pdfops.LocatedOp,
  ) -> Unit {
    if !state.val.in_text {
      return
    }

    let source_stream_index = located.source_stream_index
    let source_op_index = located.source_op_index
    let source = make_source_ref(
      page_index,
      source_stream_index,
      source_op_index,
      Some(state.val.text_object_id),
      Some(next_content_order()),
      raw_ref_of_obj_num(located.source_object_ref),
    )

    let run_origin = Some(current_origin())
    let effective_font_size = current_effective_font_size()

    let glyphs = decode_glyphs(
      state.val.current_extractor,
      raw_text,
      source,
      state.val.current_font_name,
      effective_font_size,
      run_origin,
    )

    let font = make_raw_font_info(
      state.val.current_font_name,
      effective_font_size,
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
      origin: run_origin,
      bbox: None,
      font: Some(font),
      break_before: state.val._pending_break_before,
      break_reason: state.val._pending_break_reason,
    })

    clear_pending_break()
  }

  fn append_show_text_array(
    obj : @pdf.PdfObject,
    located : @pdfops.LocatedOp,
  ) -> Unit {
    if !state.val.in_text {
      return
    }

    let parts = extract_text_fragments_from_tj_array(obj)
    if parts.is_empty() {
      return
    }

    let joined = parts.join("")
    let source_stream_index = located.source_stream_index
    let source_op_index = located.source_op_index
    let source = make_source_ref(
      page_index,
      source_stream_index,
      source_op_index,
      Some(state.val.text_object_id),
      Some(next_content_order()),
      raw_ref_of_obj_num(located.source_object_ref),
    )

    let run_origin = Some(current_origin())
    let effective_font_size = current_effective_font_size()

    let glyphs = decode_glyphs(
      state.val.current_extractor,
      joined,
      source,
      state.val.current_font_name,
      effective_font_size,
      run_origin,
    )

    let font = make_raw_font_info(
      state.val.current_font_name,
      effective_font_size,
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
      origin: run_origin,
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

  fn recurse_form_xobject(name : String) -> Unit raise {
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
              let xops = @pdfops.Op::parse_operators_with_source(
                pdf, xresources, xstreams,
              )
              let nested = collect_text_ops_from_ops(
                pdf, text, xresources, xops, page_index,
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
    let located = ops[i]
    let op = located.op
    match op {
      @pdfops.Op::Opq => {
        state.val.ctm_stack.push(state.val.ctm)
        debug_op("q")
      }
      @pdfops.Op::OpQ => {
        debug_op("Q")
        if !state.val.ctm_stack.is_empty() {
          state.val.ctm = state.val.ctm_stack[state.val.ctm_stack.length() - 1]
          let _ = state.val.ctm_stack.pop()
        }
      }
      @pdfops.Op::Opcm(m) => {
        debug_op(
          "cm a=" +
          m.a.to_string() +
          " b=" +
          m.b.to_string() +
          " c=" +
          m.c.to_string() +
          " d=" +
          m.d.to_string() +
          " e=" +
          m.e.to_string() +
          " f=" +
          m.f.to_string(),
        )
        state.val.ctm = mul_matrix(state.val.ctm, m)
      }
      @pdfops.Op::OpBT => {
        state.val.in_text = true
        state.val.current_extractor = None
        state.val.text_object_id = state.val.text_object_id + 1
        reset_text_geometry()
        debug_op("BT")
        debug_text_state("after BT")
      }
      @pdfops.Op::OpET => {
        debug_op("ET")
        debug_text_state("before ET")
        state.val.in_text = false
        state.val.current_extractor = None
      }
      @pdfops.Op::OpTf(name, size) =>
        if state.val.in_text {
          maybe_update_font(name, size)
          debug_op("Tf name=" + name + " size=" + size.to_string())
          debug_text_state("after Tf")
        }
      @pdfops.Op::OpTj(text_value) => {
        debug_op("Tj text=" + text_value)
        debug_text_state("before Tj")
        append_show_text(RawTextOpKind::ShowText, text_value, located)
        debug_text_state("after Tj")
      }
      @pdfops.Op::OpTJ(obj) => {
        let parts = extract_text_fragments_from_tj_array(obj)
        let joined = parts.join("")
        debug_op("TJ text=" + joined)
        debug_text_state("before TJ")
        append_show_text_array(obj, located)
        debug_text_state("after TJ")
      }
      @pdfops.Op::OpSingleQuote(text_value) =>
        if state.val.in_text {
          debug_op("' text=" + text_value)
          debug_text_state("before single_quote")
          set_pending_break("single_quote")
          append_show_text(RawTextOpKind::Quote, text_value, located)
          debug_text_state("after single_quote")
        }
      @pdfops.Op::OpDoubleQuote(_, _, text_value) =>
        if state.val.in_text {
          debug_op("\" text=" + text_value)
          debug_text_state("before double_quote")
          set_pending_break("double_quote")
          append_show_text(RawTextOpKind::DoubleQuote, text_value, located)
          debug_text_state("after double_quote")
        }
      @pdfops.Op::OpTStar =>
        if state.val.in_text {
          debug_op("T*")
          debug_text_state("before T*")
          set_pending_break("tstar")
          move_text_matrix_by(0.0, -state.val.leading)
          debug_text_state("after T*")
        }
      @pdfops.Op::OpTd(tx, ty) =>
        if state.val.in_text {
          debug_op("Td tx=" + tx.to_string() + " ty=" + ty.to_string())
          debug_text_state("before Td")
          move_text_matrix_by(tx, ty)
          debug_text_state("after Td")
        }
      @pdfops.Op::OpTD(tx, ty) =>
        if state.val.in_text {
          debug_op("TD tx=" + tx.to_string() + " ty=" + ty.to_string())
          debug_text_state("before TD")
          state.val.leading = -ty
          move_text_matrix_by(tx, ty)
          debug_text_state("after TD")
        }
      @pdfops.Op::OpTm(m) =>
        if state.val.in_text {
          debug_op(
            "Tm a=" +
            m.a.to_string() +
            " b=" +
            m.b.to_string() +
            " c=" +
            m.c.to_string() +
            " d=" +
            m.d.to_string() +
            " e=" +
            m.e.to_string() +
            " f=" +
            m.f.to_string(),
          )
          debug_text_state("before Tm")
          set_text_matrix(m)
          debug_text_state("after Tm")
        }
      @pdfops.Op::OpDo(name) => {
        debug_op("Do name=" + name)
        recurse_form_xobject(name)
      }
      _ => ()
    }
  }

  out
}

///|
/// 从 operator 流里收集页面图片：
/// - OpDo(name) -> XObject /Image
/// - InlineImage(...) -> inline image
/// - 维护 q/Q/cm 的 graphics state，给图片估算 placement bbox
fn collect_images_from_ops(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  ops : Array[@pdfops.LocatedOp],
  page_index : Int,
  initial_ctm : @pdftransform.TransformMatrix,
) -> Array[RawImageInfo] raise {
  let out : Array[RawImageInfo] = Array::new()
  let visited_forms : Map[Int, Bool] = Map::new()

  let image_ctm = Ref::new(initial_ctm)
  let image_ctm_stack : Array[@pdftransform.TransformMatrix] = Array::new()

  fn mark_form_visited(obj_num : Int?) -> Bool {
    match obj_num {
      Some(i) =>
        match visited_forms.get(i) {
          Some(true) => false
          _ => {
            visited_forms.set(i, true)
            true
          }
        }
      None => true
    }
  }

  fn lookup_image_int(
    obj : @pdf.PdfObject,
    long_key : String,
    short_key : String,
  ) -> Int? {
    match pdf.lookup_direct_orelse(long_key, short_key, obj) {
      Some(@pdf.PdfObject::Integer(v)) => Some(v)
      _ => None
    }
  }

  fn lookup_bits_per_component(obj : @pdf.PdfObject) -> Int? {
    match pdf.lookup_direct_orelse("/BitsPerComponent", "/BPC", obj) {
      Some(@pdf.PdfObject::Integer(v)) => Some(v)
      _ => None
    }
  }

  fn lookup_colorspace_text(obj : @pdf.PdfObject) -> String? {
    match pdf.lookup_direct_orelse("/ColorSpace", "/CS", obj) {
      Some(v) => Some(v.to_string())
      None => None
    }
  }

  fn lookup_filter_text_from_dict(obj : @pdf.PdfObject) -> String? {
    match pdf.lookup_direct_orelse("/Filter", "/F", obj) {
      Some(@pdf.PdfObject::Name(name)) => Some(name.to_string_bytes())
      Some(@pdf.PdfObject::Array(items)) => {
        let names = Array::new()
        for item in items {
          match item {
            @pdf.PdfObject::Name(name) => names.push(name.to_string_bytes())
            _ => ()
          }
        }
        if names.is_empty() {
          None
        } else {
          Some(names.join(","))
        }
      }
      _ => None
    }
  }

  fn make_image_source_refs(
    source_stream_index : Int,
    source_op_index : Int,
    source_object_ref : RawPdfRef?,
  ) -> Array[RawSourceRef] {
    [
      {
        page_index,
        source_stream_index,
        source_op_index,
        text_object_id: None,
        content_order_index: None,
        source_object_ref,
      },
    ]
  }

  fn raw_payload_from_pdfimage(image : @pdfimage.Image) -> RawImagePayload {
    match image {
      @pdfimage.Image::JPEG(bytes, _) => RawImagePayload::Jpeg(bytes)
      @pdfimage.Image::JPEG2000(bytes, _) => RawImagePayload::Jpeg2000(bytes)
      @pdfimage.Image::JBIG2(bytes, _, globals) =>
        RawImagePayload::Jbig2(bytes, globals)
      @pdfimage.Image::Raw(_, _, _, bytes) => RawImagePayload::RawRgb24(bytes)
    }
  }

  fn mul_matrix_image(
    left : @pdftransform.TransformMatrix,
    right : @pdftransform.TransformMatrix,
  ) -> @pdftransform.TransformMatrix {
    @pdftransform.TransformMatrix::{
      a: left.a * right.a + left.b * right.c,
      b: left.a * right.b + left.b * right.d,
      c: left.c * right.a + left.d * right.c,
      d: left.c * right.b + left.d * right.d,
      e: left.e * right.a + left.f * right.c + right.e,
      f: left.e * right.b + left.f * right.d + right.f,
    }
  }

  fn apply_matrix_to_point_image(
    m : @pdftransform.TransformMatrix,
    x : Double,
    y : Double,
  ) -> @model.PdfPoint {
    { x: m.a * x + m.c * y + m.e, y: m.b * x + m.d * y + m.f }
  }

  fn min4(a : Double, b : Double, c : Double, d : Double) -> Double {
    let mut m = a
    if b < m {
      m = b
    }
    if c < m {
      m = c
    }
    if d < m {
      m = d
    }
    m
  }

  fn max4(a : Double, b : Double, c : Double, d : Double) -> Double {
    let mut m = a
    if b > m {
      m = b
    }
    if c > m {
      m = c
    }
    if d > m {
      m = d
    }
    m
  }

  ///|
  /// 用当前 CTM 估算图片在页面上的放置 bbox。
  /// 将单位图像空间 [0,0]-[1,1] 变换到页面坐标，再取外接矩形。
  fn image_bbox_from_current_ctm() -> @model.PdfRect {
    let p0 = apply_matrix_to_point_image(image_ctm.val, 0.0, 0.0)
    let p1 = apply_matrix_to_point_image(image_ctm.val, 1.0, 0.0)
    let p2 = apply_matrix_to_point_image(image_ctm.val, 0.0, 1.0)
    let p3 = apply_matrix_to_point_image(image_ctm.val, 1.0, 1.0)

    {
      x0: min4(p0.x, p1.x, p2.x, p3.x),
      y0: min4(p0.y, p1.y, p2.y, p3.y),
      x1: max4(p0.x, p1.x, p2.x, p3.x),
      y1: max4(p0.y, p1.y, p2.y, p3.y),
    }
  }

  fn stream_dict_and_bytes(
    obj : @pdf.PdfObject,
  ) -> (@pdf.PdfObject, @pdfio.MutableBytes)? {
    let s = pdf.direct(obj)
    s.getstream() catch {
      _ => return None
    }

    match s {
      @pdf.PdfObject::Stream(r) =>
        match r.val {
          (dict, @pdf.Stream::Got(bytes)) => Some((dict, bytes))
          _ => None
        }
      _ => None
    }
  }

  fn image_filter_kind_from_dict(dict : @pdf.PdfObject) -> String? {
    match pdf.lookup_direct_orelse("/Filter", "/F", dict) {
      Some(@pdf.PdfObject::Name(name)) => {
        let s = name.to_string_bytes()
        if s == "/DCTDecode" || s == "/DCT" {
          Some("jpeg")
        } else if s == "/JPXDecode" {
          Some("jp2")
        } else if s == "/JBIG2Decode" {
          Some("jbig2")
        } else {
          None
        }
      }
      Some(@pdf.PdfObject::Array(items)) => {
        let names = Array::new()
        for item in items {
          match item {
            @pdf.PdfObject::Name(name) => names.push(name.to_string_bytes())
            _ => ()
          }
        }
        if names.is_empty() {
          return None
        }

        let last = names[names.length() - 1]
        if last == "/DCTDecode" || last == "/DCT" {
          Some("jpeg")
        } else if last == "/JPXDecode" {
          Some("jp2")
        } else if last == "/JBIG2Decode" {
          Some("jbig2")
        } else {
          None
        }
      }
      _ => None
    }
  }

  fn lookup_jbig2_globals(dict : @pdf.PdfObject) -> Int? {
    match pdf.lookup_direct("/DecodeParms", dict) {
      Some(@pdf.PdfObject::Dictionary(parms)) =>
        match
          @pdf.PdfObject::Dictionary(parms).lookup_immediate("/JBIG2Globals") {
          Some(@pdf.PdfObject::Indirect(i)) => Some(i)
          _ => None
        }
      _ => None
    }
  }
  fn filter_name_list_from_dict(dict : @pdf.PdfObject) -> Array[String] {
    let out : Array[String] = []
    match pdf.lookup_direct_orelse("/Filter", "/F", dict) {
      Some(@pdf.PdfObject::Name(name)) => out.push(name.to_string_bytes())
      Some(@pdf.PdfObject::Array(items)) =>
        for item in items {
          match item {
            @pdf.PdfObject::Name(name) => out.push(name.to_string_bytes())
            _ => ()
          }
        }
      _ => ()
    }
    out
  }

  fn xobject_image_payload(xobj : @pdf.PdfObject) -> RawImagePayload? {
    let staged = pdf.direct(xobj)

    fn try_exportable_payload(obj : @pdf.PdfObject) -> RawImagePayload? {
      match stream_dict_and_bytes(obj) {
        Some((dict, bytes)) => {
          let filters = filter_name_list_from_dict(dict)
          let kind = image_filter_kind_from_dict(dict)

          // 只有“单层最终图片 filter”时，才能直接把 bytes 当文件内容导出
          if filters.length() == 1 {
            match kind {
              Some("jpeg") => return Some(RawImagePayload::Jpeg(bytes))
              Some("jp2") => return Some(RawImagePayload::Jpeg2000(bytes))
              Some("jbig2") =>
                return Some(
                  RawImagePayload::Jbig2(bytes, lookup_jbig2_globals(dict)),
                )
              _ => ()
            }
          }

          None
        }
        None => None
      }
    }

    // 先尝试当前对象是否已经是“可直接导出”的最终图像流
    match try_exportable_payload(staged) {
      Some(payload) => return Some(payload)
      None => ()
    }

    // 如果外面还有 ASCII85 / ASCIIHex 等包装，就逐层解开
    for _i = 0; _i < 4; _i = _i + 1 {
      @pdfcodec.PdfCodec::new().decode_pdfstream_onestage(pdf, staged) catch {
        _ => break
      }

      match try_exportable_payload(staged) {
        Some(payload) => return Some(payload)
        None => ()
      }
    }

    // 最后再 fallback 到完全解码成像素
    Some(
      raw_payload_from_pdfimage(
        @pdfimage.Image::get_image_24bpp(pdf, resources, staged),
      ),
    ) catch {
      _ => None
    }
  }
  fn inline_image_payload(
    dict : @pdf.PdfObject,
    data : @pdfio.MutableBytes,
  ) -> RawImagePayload? {
    match image_filter_kind_from_dict(dict) {
      Some("jpeg") => return Some(RawImagePayload::Jpeg(data))
      Some("jp2") => return Some(RawImagePayload::Jpeg2000(data))
      Some("jbig2") =>
        return Some(RawImagePayload::Jbig2(data, lookup_jbig2_globals(dict)))
      _ => ()
    }

    match
      (
        lookup_image_int(dict, "/Width", "/W"),
        lookup_image_int(dict, "/Height", "/H"),
      ) {
      (Some(width_px), Some(height_px)) =>
        Some(
          raw_payload_from_pdfimage(
            @pdfimage.Image::from_stream_data(
              pdf, resources, width_px, height_px, dict, data,
            ),
          ),
        ) catch {
          err => {
            if DEBUG_MBTPDF_OP {
              println(
                "[pdf-image-debug] inline decode failed: " + err.to_string(),
              )
              println("[pdf-image-debug] inline dict=" + dict.to_string())
            }
            None
          }
        }
      _ => None
    }
  }

  fn append_image_from_dict(
    id : String,
    dict : @pdf.PdfObject,
    object_ref : RawPdfRef?,
    inline_image : Bool,
    payload : RawImagePayload?,
    located : @pdfops.LocatedOp,
  ) -> Unit {
    match
      (
        lookup_image_int(dict, "/Width", "/W"),
        lookup_image_int(dict, "/Height", "/H"),
      ) {
      (Some(width_px), Some(height_px)) => {
        let image : RawImageInfo = {
          id,
          page_index,
          object_ref,
          bbox: Some(image_bbox_from_current_ctm()),
          width_px,
          height_px,
          colorspace: lookup_colorspace_text(dict),
          bits_per_component: lookup_bits_per_component(dict),
          image_filter: lookup_filter_text_from_dict(dict),
          alt_text: None,
          inline_image,
          payload,
          source_refs: make_image_source_refs(
            located.source_stream_index,
            located.source_op_index,
            raw_ref_of_obj_num(located.source_object_ref),
          ),
        }
        out.push(image)
      }
      _ => ()
    }
  }

  fn recurse_xobject(name : String, located : @pdfops.LocatedOp) -> Unit raise {
    match pdf.lookup_direct("/XObject", resources) {
      Some(@pdf.PdfObject::Dictionary(entries)) =>
        if entries.search_by(pair => pair.0 == name) is Some(idx) {
          let obj_ref = entries[idx].1
          let raw_ref : RawPdfRef? = if obj_ref is @pdf.PdfObject::Indirect(i) {
            Some({ obj_num: i, gen_num: 0 })
          } else {
            None
          }

          let xobj = pdf.direct(obj_ref)

          match pdf.lookup_direct("/Subtype", xobj) {
            Some(@pdf.PdfObject::Name(n)) if n.equal_string_bytes("/Image") => {
              let id = match raw_ref {
                Some(r) => "xobj-image-" + r.obj_num.to_string()
                None =>
                  "xobj-image-p" +
                  page_index.to_string() +
                  "-op" +
                  located.source_op_index.to_string()
              }
              let payload = xobject_image_payload(xobj)
              let image_dict = match stream_dict_and_bytes(xobj) {
                Some((dict, _)) => dict
                None => xobj
              }
              append_image_from_dict(
                id, image_dict, raw_ref, false, payload, located,
              )
            }
            Some(@pdf.PdfObject::Name(n)) if n.equal_string_bytes("/Form") =>
              if mark_form_visited(
                  match raw_ref {
                    Some(r) => Some(r.obj_num)
                    None => None
                  },
                ) {
                let xresources = pdf
                  .lookup_direct("/Resources", xobj)
                  .unwrap_or(resources)
                let xstreams : Array[@pdf.PdfObject] = [xobj]
                let xops = @pdfops.Op::parse_operators_with_source(
                  pdf, xresources, xstreams,
                )
                let nested = collect_images_from_ops(
                  pdf,
                  xresources,
                  xops,
                  page_index,
                  image_ctm.val,
                )
                for image in nested {
                  out.push(image)
                }
              }
            _ => ()
          }
        }
      _ => ()
    }
  }

  for i = 0; i < ops.length(); i = i + 1 {
    let located = ops[i]
    match located.op {
      @pdfops.Op::Opq => image_ctm_stack.push(image_ctm.val)
      @pdfops.Op::OpQ =>
        if !image_ctm_stack.is_empty() {
          image_ctm.val = image_ctm_stack[image_ctm_stack.length() - 1]
          let _ = image_ctm_stack.pop()
        }
      @pdfops.Op::Opcm(m) => image_ctm.val = mul_matrix_image(image_ctm.val, m)
      @pdfops.Op::OpDo(name) => recurse_xobject(name, located)
      @pdfops.Op::InlineImage((dict, _, data)) => {
        let payload = inline_image_payload(dict, data)
        append_image_from_dict(
          "inline-image-p" +
          page_index.to_string() +
          "-op" +
          located.source_op_index.to_string(),
          dict,
          None,
          true,
          payload,
          located,
        )
      }
      _ => ()
    }
  }

  out
}

///|
/// 从 TJ 数组里抽 string 片段。
///
/// 当前先复用 MBTPDF 现有 extract_text 行为：
/// 只消费 string 元素，忽略数值间距项。
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
  run_origin : @model.PdfPoint?,
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
            origin: run_origin,
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
        _ =>
          [
            make_fallback_glyph(
              raw_text, source, font_name, font_size, run_origin,
            ),
          ]
      }
    None =>
      [make_fallback_glyph(raw_text, source, font_name, font_size, run_origin)]
  }
}

///|
fn make_fallback_glyph(
  text : String,
  source : RawSourceRef,
  font_name : String?,
  font_size : Double?,
  run_origin : @model.PdfPoint?,
) -> RawDecodedGlyph {
  {
    unicode: text,
    raw_bytes: None,
    decoded_text: text,
    origin: run_origin,
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
  source_object_ref : RawPdfRef?,
) -> RawSourceRef {
  {
    page_index,
    source_stream_index,
    source_op_index,
    text_object_id,
    content_order_index,
    source_object_ref,
  }
}

///|
fn raw_ref_of_obj_num(obj_num : Int?) -> RawPdfRef? {
  match obj_num {
    Some(i) => Some({ obj_num: i, gen_num: 0 })
    None => None
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
