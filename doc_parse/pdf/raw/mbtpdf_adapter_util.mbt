///|
/// 通用 helper：几何、source ref、基础 PDF object 取值。
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
