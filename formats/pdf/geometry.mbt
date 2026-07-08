///|
pub type PdfBBox = @dpdfnative.PdfBBox

///|
pub type PdfPageGeometry = @dpdfnative.PdfPageGeometry

///|
pub fn make_pdf_bbox(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> PdfBBox {
  @dpdfnative.make_pdf_bbox(x, y, width, height)
}

///|
pub fn make_pdf_page_geometry(
  page_no : Int,
  width : Double,
  height : Double,
  rotation_degrees? : Int = 0,
  crop_box? : PdfBBox? = None,
) -> PdfPageGeometry {
  @dpdfnative.make_pdf_page_geometry(
    page_no,
    width,
    height,
    rotation_degrees~,
    crop_box~,
  )
}

///|
pub fn pdf_bbox_right(bbox : PdfBBox) -> Double {
  @dpdfnative.pdf_bbox_right(bbox)
}

///|
pub fn pdf_bbox_bottom(bbox : PdfBBox) -> Double {
  @dpdfnative.pdf_bbox_bottom(bbox)
}

///|
pub fn pdf_bbox_is_empty(bbox : PdfBBox) -> Bool {
  @dpdfnative.pdf_bbox_is_empty(bbox)
}

///|
pub fn pdf_union_bbox(left : PdfBBox, right : PdfBBox) -> PdfBBox {
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
