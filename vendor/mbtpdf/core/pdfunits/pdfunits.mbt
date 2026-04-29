///|
/// Units for paper sizes and conversions.
pub(all) enum LengthUnit {
  PdfPoint
  Inch
  Centimetre
  Millimetre
} derive(Debug)

///|
/// Convert a measurement to points.
pub fn LengthUnit::to_points(self : LengthUnit, value : Double) -> Double {
  match self {
    PdfPoint => value
    Inch => value * 72.0
    Centimetre => value * 28.3465
    Millimetre => value * 2.83465
  }
}

///|
/// Convert a measurement to inches.
pub fn LengthUnit::to_inches(self : LengthUnit, value : Double) -> Double {
  match self {
    Inch => value
    PdfPoint => value / 72.0
    Centimetre => value / 2.54
    Millimetre => value / 25.4
  }
}

///|
/// Convert a measurement to centimetres.
pub fn LengthUnit::to_centimetres(self : LengthUnit, value : Double) -> Double {
  match self {
    Centimetre => value
    Inch => value * 2.54
    Millimetre => value / 10.0
    PdfPoint => value / 28.3456
  }
}

///|
/// Convert a measurement to millimetres.
pub fn LengthUnit::to_millimetres(self : LengthUnit, value : Double) -> Double {
  self.to_centimetres(value) * 10.0
}
