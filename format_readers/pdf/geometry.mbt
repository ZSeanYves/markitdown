///|
pub struct PdfBBox {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub struct PdfPageGeometry {
  page_no : Int
  width : Double
  height : Double
  rotation_degrees : Int
  crop_box : PdfBBox?
}

///|
pub fn make_pdf_bbox(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> PdfBBox {
  { x, y, width, height }
}

///|
pub fn make_pdf_page_geometry(
  page_no : Int,
  width : Double,
  height : Double,
  rotation_degrees? : Int = 0,
  crop_box? : PdfBBox? = None,
) -> PdfPageGeometry {
  { page_no, width, height, rotation_degrees, crop_box }
}

///|
pub fn pdf_bbox_right(bbox : PdfBBox) -> Double {
  bbox.x + bbox.width
}

///|
pub fn pdf_bbox_bottom(bbox : PdfBBox) -> Double {
  bbox.y + bbox.height
}

///|
pub fn pdf_bbox_is_empty(bbox : PdfBBox) -> Bool {
  bbox.width <= 0.0 || bbox.height <= 0.0
}

///|
pub fn pdf_union_bbox(left : PdfBBox, right : PdfBBox) -> PdfBBox {
  if pdf_bbox_is_empty(left) {
    return right
  }
  if pdf_bbox_is_empty(right) {
    return left
  }
  let x0 = pdf_double_min(left.x, right.x)
  let y0 = pdf_double_min(left.y, right.y)
  let x1 = pdf_double_max(pdf_bbox_right(left), pdf_bbox_right(right))
  let y1 = pdf_double_max(pdf_bbox_bottom(left), pdf_bbox_bottom(right))
  { x: x0, y: y0, width: x1 - x0, height: y1 - y0 }
}

///|
fn pdf_double_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn pdf_double_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
