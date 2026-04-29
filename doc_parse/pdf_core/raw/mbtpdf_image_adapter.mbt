///|
fn mark_form_visited(visited_forms : Map[Int, Bool], obj_num : Int?) -> Bool {
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

///|
fn lookup_image_int(
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject,
  long_key : String,
  short_key : String,
) -> Int? {
  match pdf.lookup_direct_orelse(long_key, short_key, obj) {
    Some(@pdf.PdfObject::Integer(v)) => Some(v)
    _ => None
  }
}

///|
fn lookup_bits_per_component(pdf : @pdf.Pdf, obj : @pdf.PdfObject) -> Int? {
  match pdf.lookup_direct_orelse("/BitsPerComponent", "/BPC", obj) {
    Some(@pdf.PdfObject::Integer(v)) => Some(v)
    _ => None
  }
}

///|
fn lookup_colorspace_text(pdf : @pdf.Pdf, obj : @pdf.PdfObject) -> String? {
  match pdf.lookup_direct_orelse("/ColorSpace", "/CS", obj) {
    Some(v) => Some(v.to_string())
    None => None
  }
}

///|
fn lookup_filter_text_from_dict(
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject,
) -> String? {
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

///|
fn make_image_source_refs(
  page_index : Int,
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

///|
fn raw_payload_from_pdfimage(image : @pdfimage.Image) -> RawImagePayload {
  match image {
    @pdfimage.Image::JPEG(bytes, _) => RawImagePayload::Jpeg(bytes)
    @pdfimage.Image::JPEG2000(bytes, _) => RawImagePayload::Jpeg2000(bytes)
    @pdfimage.Image::JBIG2(bytes, _, globals) =>
      RawImagePayload::Jbig2(bytes, globals)
    @pdfimage.Image::Raw(_, _, _, bytes) => RawImagePayload::RawRgb24(bytes)
  }
}

///|
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

///|
fn apply_matrix_to_point_image(
  m : @pdftransform.TransformMatrix,
  x : Double,
  y : Double,
) -> @model.PdfPoint {
  { x: m.a * x + m.c * y + m.e, y: m.b * x + m.d * y + m.f }
}

///|
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

///|
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
fn image_bbox_from_ctm(ctm : @pdftransform.TransformMatrix) -> @model.PdfRect {
  let p0 = apply_matrix_to_point_image(ctm, 0.0, 0.0)
  let p1 = apply_matrix_to_point_image(ctm, 1.0, 0.0)
  let p2 = apply_matrix_to_point_image(ctm, 0.0, 1.0)
  let p3 = apply_matrix_to_point_image(ctm, 1.0, 1.0)

  {
    x0: min4(p0.x, p1.x, p2.x, p3.x),
    y0: min4(p0.y, p1.y, p2.y, p3.y),
    x1: max4(p0.x, p1.x, p2.x, p3.x),
    y1: max4(p0.y, p1.y, p2.y, p3.y),
  }
}

///|
fn stream_dict_and_bytes(
  pdf : @pdf.Pdf,
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

///|
fn image_filter_kind_from_dict(
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
) -> String? {
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

///|
fn lookup_jbig2_globals(pdf : @pdf.Pdf, dict : @pdf.PdfObject) -> Int? {
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

///|
fn filter_name_list_from_dict(
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
) -> Array[String] {
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

///|
fn try_exportable_image_payload(
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject,
) -> RawImagePayload? {
  match stream_dict_and_bytes(pdf, obj) {
    Some((dict, bytes)) => {
      let filters = filter_name_list_from_dict(pdf, dict)
      let kind = image_filter_kind_from_dict(pdf, dict)

      // 只有“单层最终图片 filter”时，才能直接把 bytes 当文件内容导出
      if filters.length() == 1 {
        match kind {
          Some("jpeg") => return Some(RawImagePayload::Jpeg(bytes))
          Some("jp2") => return Some(RawImagePayload::Jpeg2000(bytes))
          Some("jbig2") =>
            return Some(
              RawImagePayload::Jbig2(bytes, lookup_jbig2_globals(pdf, dict)),
            )
          _ => ()
        }
      }

      None
    }
    None => None
  }
}

///|
fn xobject_image_payload(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  xobj : @pdf.PdfObject,
) -> RawImagePayload? {
  let staged = pdf.direct(xobj)

  // 先尝试当前对象是否已经是“可直接导出”的最终图像流
  match try_exportable_image_payload(pdf, staged) {
    Some(payload) => return Some(payload)
    None => ()
  }

  // 如果外面还有 ASCII85 / ASCIIHex 等包装，就逐层解开
  for _i = 0; _i < 4; _i = _i + 1 {
    @pdfcodec.PdfCodec::new().decode_pdfstream_onestage(pdf, staged) catch {
      _ => break
    }

    match try_exportable_image_payload(pdf, staged) {
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

///|
fn inline_image_payload(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  dict : @pdf.PdfObject,
  data : @pdfio.MutableBytes,
) -> RawImagePayload? {
  match image_filter_kind_from_dict(pdf, dict) {
    Some("jpeg") => return Some(RawImagePayload::Jpeg(data))
    Some("jp2") => return Some(RawImagePayload::Jpeg2000(data))
    Some("jbig2") =>
      return Some(RawImagePayload::Jbig2(data, lookup_jbig2_globals(pdf, dict)))
    _ => ()
  }

  match
    (
      lookup_image_int(pdf, dict, "/Width", "/W"),
      lookup_image_int(pdf, dict, "/Height", "/H"),
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

///|
fn image_from_dict(
  pdf : @pdf.Pdf,
  page_index : Int,
  ctm : @pdftransform.TransformMatrix,
  id : String,
  dict : @pdf.PdfObject,
  object_ref : RawPdfRef?,
  inline_image : Bool,
  payload : RawImagePayload?,
  located : @pdfops.LocatedOp,
) -> RawImageInfo? {
  match
    (
      lookup_image_int(pdf, dict, "/Width", "/W"),
      lookup_image_int(pdf, dict, "/Height", "/H"),
    ) {
    (Some(width_px), Some(height_px)) =>
      Some({
        id,
        page_index,
        object_ref,
        bbox: Some(image_bbox_from_ctm(ctm)),
        width_px,
        height_px,
        colorspace: lookup_colorspace_text(pdf, dict),
        bits_per_component: lookup_bits_per_component(pdf, dict),
        image_filter: lookup_filter_text_from_dict(pdf, dict),
        alt_text: None,
        inline_image,
        payload,
        source_refs: make_image_source_refs(
          page_index,
          located.source_stream_index,
          located.source_op_index,
          raw_ref_of_obj_num(located.source_object_ref),
        ),
      })
    _ => None
  }
}

///|
fn collect_xobject_images(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  name : String,
  located : @pdfops.LocatedOp,
  page_index : Int,
  current_ctm : @pdftransform.TransformMatrix,
  visited_forms : Map[Int, Bool],
) -> Array[RawImageInfo] raise {
  match pdf.lookup_direct("/XObject", resources) {
    Some(@pdf.PdfObject::Dictionary(entries)) =>
      if entries.search_by(pair => pair.0 == name) is Some(idx) {
        let obj_ref = entries[idx].1
        let raw_ref = raw_ref_from_pdf_object(obj_ref)
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
            let payload = xobject_image_payload(pdf, resources, xobj)
            let image_dict = match stream_dict_and_bytes(pdf, xobj) {
              Some((dict, _)) => dict
              None => xobj
            }
            match
              image_from_dict(
                pdf, page_index, current_ctm, id, image_dict, raw_ref, false, payload,
                located,
              ) {
              Some(image) => [image]
              None => []
            }
          }
          Some(@pdf.PdfObject::Name(n)) if n.equal_string_bytes("/Form") =>
            if mark_form_visited(
                visited_forms,
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
              collect_images_from_ops(
                pdf, xresources, xops, page_index, current_ctm,
              )
            } else {
              []
            }
          _ => []
        }
      } else {
        []
      }
    _ => []
  }
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
      @pdfops.Op::OpDo(name) =>
        out.append(
          collect_xobject_images(
            pdf,
            resources,
            name,
            located,
            page_index,
            image_ctm.val,
            visited_forms,
          ),
        )
      @pdfops.Op::InlineImage((dict, _, data)) => {
        let payload = inline_image_payload(pdf, resources, dict, data)
        match
          image_from_dict(
            pdf,
            page_index,
            image_ctm.val,
            "inline-image-p" +
            page_index.to_string() +
            "-op" +
            located.source_op_index.to_string(),
            dict,
            None,
            true,
            payload,
            located,
          ) {
          Some(image) => out.push(image)
          None => ()
        }
      }
      _ => ()
    }
  }

  out
}
