///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  if diff >= 0.001 {
    fail("Expected \{b} but got \{a} (diff: \{diff})")
  }
}

///|
test "points conversions" {
  // Test cases: (value, unit, expected_points)
  let cases : Array[(Double, @pdfunits.LengthUnit, Double)] = [
    (1.0, @pdfunits.LengthUnit::PdfPoint, 1.0),
    (1.0, @pdfunits.LengthUnit::Inch, 72.0),
    (2.54, @pdfunits.LengthUnit::Centimetre, 72.0), // 1 inch in cm
    (25.4, @pdfunits.LengthUnit::Millimetre, 72.0), // 1 inch in mm
  ]
  for case_ in cases {
    let (value, unit, expected) = case_
    assert_close(unit.to_points(value), expected)
  }
}

///|
test "inches conversions" {
  // Test cases: (value, unit, expected_inches)
  let cases : Array[(Double, @pdfunits.LengthUnit, Double)] = [
    (1.0, @pdfunits.LengthUnit::Inch, 1.0),
    (72.0, @pdfunits.LengthUnit::PdfPoint, 1.0),
    (2.54, @pdfunits.LengthUnit::Centimetre, 1.0),
    (25.4, @pdfunits.LengthUnit::Millimetre, 1.0),
  ]
  for case_ in cases {
    let (value, unit, expected) = case_
    assert_close(unit.to_inches(value), expected)
  }
}

///|
test "centimetres conversions" {
  // Test cases: (value, unit, expected_cm)
  let cases : Array[(Double, @pdfunits.LengthUnit, Double)] = [
    (1.0, @pdfunits.LengthUnit::Centimetre, 1.0),
    (1.0, @pdfunits.LengthUnit::Inch, 2.54),
    (10.0, @pdfunits.LengthUnit::Millimetre, 1.0),
    (28.3456, @pdfunits.LengthUnit::PdfPoint, 1.0),
  ]
  for case_ in cases {
    let (value, unit, expected) = case_
    assert_close(unit.to_centimetres(value), expected)
  }
}

///|
test "millimetres conversions" {
  // Test cases: (value, unit, expected_mm)
  let cases : Array[(Double, @pdfunits.LengthUnit, Double)] = [
    (1.0, @pdfunits.LengthUnit::Millimetre, 1.0),
    (1.0, @pdfunits.LengthUnit::Centimetre, 10.0),
    (1.0, @pdfunits.LengthUnit::Inch, 25.4),
  ]
  for case_ in cases {
    let (value, unit, expected) = case_
    assert_close(unit.to_millimetres(value), expected)
  }
}

///|
test "roundtrip conversions" {
  // Converting to another unit and back should return the original value
  let original = 123.456
  // points -> inches -> points
  assert_close(
    @pdfunits.LengthUnit::Inch.to_points(
      @pdfunits.LengthUnit::PdfPoint.to_inches(original),
    ),
    original,
  )
  // inches -> cm -> inches
  assert_close(
    @pdfunits.LengthUnit::Centimetre.to_inches(
      @pdfunits.LengthUnit::Inch.to_centimetres(original),
    ),
    original,
  )
  // cm -> mm -> cm
  assert_close(
    @pdfunits.LengthUnit::Millimetre.to_centimetres(
      @pdfunits.LengthUnit::Centimetre.to_millimetres(original),
    ),
    original,
  )
}
