///|
/// 基础几何类型。
pub(all) struct PdfPoint {
  x : Double
  y : Double
}

///|
/// 轴对齐矩形，PDF 页面坐标系下使用。
pub(all) struct PdfRect {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
/// 四边形，后续如果要支持旋转文本、高亮区域、annotation quadpoints 会有用。
pub(all) struct PdfQuad {
  p1 : PdfPoint
  p2 : PdfPoint
  p3 : PdfPoint
  p4 : PdfPoint
}

///|
/// RGB 颜色；后续如要支持 CMYK/Gray，可再扩 enum。
pub(all) struct PdfColor {
  r : Int
  g : Int
  b : Int
}

///|
/// 页面盒模型。
pub(all) struct PdfPageBoxes {
  media_box : PdfRect
  crop_box : PdfRect?
  bleed_box : PdfRect?
  trim_box : PdfRect?
  art_box : PdfRect?
}

///|
/// 几何辅助：宽度。
pub fn rect_width(rect : PdfRect) -> Double {
  rect.x1 - rect.x0
}

///|
/// 几何辅助：高度。
pub fn rect_height(rect : PdfRect) -> Double {
  rect.y1 - rect.y0
}

///|
/// 几何辅助：中心点。
pub fn rect_center(rect : PdfRect) -> PdfPoint {
  { x: (rect.x0 + rect.x1) / 2.0, y: (rect.y0 + rect.y1) / 2.0 }
}

///|
/// 几何辅助：判空/非法矩形。
pub fn is_rect_valid(rect : PdfRect) -> Bool {
  rect.x1 >= rect.x0 && rect.y1 >= rect.y0
}

///|
/// 合并两个矩形的包围盒。
pub fn union_rect(a : PdfRect, b : PdfRect) -> PdfRect {
  {
    x0: if a.x0 < b.x0 {
      a.x0
    } else {
      b.x0
    },
    y0: if a.y0 < b.y0 {
      a.y0
    } else {
      b.y0
    },
    x1: if a.x1 > b.x1 {
      a.x1
    } else {
      b.x1
    },
    y1: if a.y1 > b.y1 {
      a.y1
    } else {
      b.y1
    },
  }
}
