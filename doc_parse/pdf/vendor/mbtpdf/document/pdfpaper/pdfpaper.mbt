///|
/// Paper sizes for PDF page boxes.
pub struct Paper {
  unit : @pdfunits.LengthUnit
  width : Double
  height : Double
  // uncomment later
  // fn new(
  //   unit~ : @pdfunits.LengthUnit,
  //   width~ : Double,
  //   height~ : Double,
  // ) -> Paper
} derive(Debug)

///|
/// Make a paper size from unit, width, and height.
pub fn Paper::new(
  unit~ : @pdfunits.LengthUnit,
  width~ : Double,
  height~ : Double,
) -> Paper {
  { unit, width, height }
}

///|
/// Project the unit from a paper size.
pub fn Paper::unit(self : Paper) -> @pdfunits.LengthUnit {
  self.unit
}

///|
/// Project the width from a paper size.
pub fn Paper::width(self : Paper) -> Double {
  self.width
}

///|
/// Project the height from a paper size.
pub fn Paper::height(self : Paper) -> Double {
  self.height
}

///|
/// Convert a paper size to a PDF rectangle.
pub fn Paper::rectangle(self : Paper) -> @pdf.PdfObject {
  let unit = self.unit()
  let width = unit.to_points(self.width())
  let height = unit.to_points(self.height())
  @pdf.PdfObject::Array([
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(0.0),
    @pdf.PdfObject::Real(width),
    @pdf.PdfObject::Real(height),
  ])
}

///|
/// Flip a paper size between landscape and portrait.
pub fn Paper::landscape(self : Paper) -> Paper {
  { unit: self.unit, width: self.height, height: self.width }
}

///|
fn mm_paper(width : Double, height : Double) -> Paper {
  { unit: @pdfunits.LengthUnit::Millimetre, width, height }
}

///|
fn inch_paper(width : Double, height : Double) -> Paper {
  { unit: @pdfunits.LengthUnit::Inch, width, height }
}

///|
/// ISO A series paper sizes (portrait).
pub let a0 : Paper = mm_paper(841.0, 1189.0)

///|
pub let a1 : Paper = mm_paper(594.0, 841.0)

///|
pub let a2 : Paper = mm_paper(420.0, 594.0)

///|
pub let a3 : Paper = mm_paper(297.0, 420.0)

///|
pub let a4 : Paper = mm_paper(210.0, 297.0)

///|
pub let a5 : Paper = mm_paper(148.0, 210.0)

///|
pub let a6 : Paper = mm_paper(105.0, 148.0)

///|
pub let a7 : Paper = mm_paper(74.0, 105.0)

///|
pub let a8 : Paper = mm_paper(52.0, 74.0)

///|
pub let a9 : Paper = mm_paper(37.0, 52.0)

///|
pub let a10 : Paper = mm_paper(26.0, 37.0)

///|
/// United States paper sizes (portrait).
pub let usletter : Paper = inch_paper(8.5, 11.0)

///|
pub let uslegal : Paper = inch_paper(8.5, 14.0)
