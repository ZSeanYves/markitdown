///|
fn unit_pdf_point() -> LengthUnit {
  LengthUnit::PdfPoint
}

///|
fn unit_inch() -> LengthUnit {
  LengthUnit::Inch
}

///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "points and inches conversions" {
  let pdf_point = unit_pdf_point()
  let inch = unit_inch()
  assert_close(pdf_point.to_points(1.0), 1.0)
  assert_close(inch.to_points(1.0), 72.0)
  assert_close(pdf_point.to_inches(72.0), 1.0)
}
