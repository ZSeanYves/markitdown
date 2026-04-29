///|
type PdfObject = @pdf.PdfObject

///|
/// The type of the four rotations of pages.
pub(all) enum Rotation {
  Rotate0
  Rotate90
  Rotate180
  Rotate270
} derive(Debug)

///|
/// A type representing a page.
pub(all) struct Page {
  content : Array[PdfObject]
  mediabox : PdfObject
  resources : PdfObject
  rotate : Rotation
  rest : PdfObject
}

///|
pub struct PdfPageDoc {
  pdf : @pdf.Pdf
}

///|
pub fn PdfPageDoc::new(pdf : @pdf.Pdf) -> PdfPageDoc {
  { pdf, }
}

///|
/// Create a page with empty content and no extra dictionary entries.
pub fn Page::custom(rectangle : PdfObject) -> Page {
  {
    content: [],
    mediabox: rectangle,
    resources: PdfObject::Dictionary([]),
    rotate: Rotate0,
    rest: PdfObject::Dictionary([]),
  }
}

///|
/// Create a blank page using the given paper size.
pub fn Page::blank(paper : @pdfpaper.Paper) -> Page {
  Page::custom(paper.rectangle())
}

///|
/// Convert rotation to integers.
pub fn Rotation::to_int(self : Rotation) -> Int {
  match self {
    Rotate0 => 0
    Rotate90 => 90
    Rotate180 => 180
    Rotate270 => 270
  }
}

///|
/// Convert an integer to rotation.
pub fn Rotation::from_int(i : Int) -> Rotation raise {
  let r = i % 360
  match r {
    0 => Rotate0
    90 | -270 => Rotate90
    180 | -180 => Rotate180
    270 | -90 => Rotate270
    _ => raise @pdf.PdfError::Msg("Bad /Rotate")
  }
}
