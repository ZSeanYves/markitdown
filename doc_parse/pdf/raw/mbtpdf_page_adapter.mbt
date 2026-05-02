///|
/// page object ref。
fn page_ref_for_index(pdf : @pdf.Pdf, page_index : Int) -> RawPdfRef? {
  try {
    match @pdfpage.PdfPageDoc::new(pdf).page_object_number(page_index + 1) {
      Some(i) => raw_ref_of_obj_num(Some(i))
      None => None
    }
  } catch {
    _ => None
  }
}

///|
/// 页面 content stream refs。
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
/// 页面 MediaBox。
fn page_media_box(pdf : @pdf.Pdf, page : @pdfpage.Page) -> @model.PdfRect? {
  parse_pdf_rect(pdf, page.mediabox)
}

///|
/// 页面 CropBox。
fn page_crop_box(pdf : @pdf.Pdf, page : @pdfpage.Page) -> @model.PdfRect? {
  match page.cropbox {
    Some(crop_box) => parse_pdf_rect(pdf, crop_box)
    None => None
  }
}

///|
/// 页面旋转角度。
fn page_rotation(page : @pdfpage.Page) -> Int {
  page.rotate.to_int()
}
