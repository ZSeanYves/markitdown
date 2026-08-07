///|
test "PDF deterministic PNG encoder wraps gray and RGB pixels" {
  for
    encoded in [
      pdf_encode_png_8bit(
        Bytes::from_array([(0).to_byte(), (255).to_byte()]),
        2,
        1,
        1,
      ),
      pdf_encode_png_8bit(
        Bytes::from_array([
          (255).to_byte(),
          (0).to_byte(),
          (0).to_byte(),
          (0).to_byte(),
          (255).to_byte(),
          (0).to_byte(),
        ]),
        2,
        1,
        3,
      ),
    ] {
    let png = encoded.unwrap()
    assert_true(png.length() > 40)
    assert_true(png[0].to_int() == 0x89)
    assert_true(png[1].to_int() == 0x50)
    assert_true(png[2].to_int() == 0x4E)
    assert_true(png[3].to_int() == 0x47)
  }
}

///|
test "PDF PNG encoder rejects mismatched and over-budget pixels" {
  assert_true(pdf_encode_png_8bit(Bytes::new(0), 1, 1, 3) is None)
  assert_true(
    pdf_encode_png_8bit(Bytes::new(0), PDF_PNG_MAX_PIXELS, 2, 1) is None,
  )
}

///|
test "PDF 1-bit grayscale expansion respects row padding and inversion" {
  let packed = Bytes::from_array([(0xA0).to_byte(), (0x40).to_byte()])
  let pixels = pdf_expand_1bit_grayscale(packed, 3, 2, false).unwrap()
  assert_true(
    pixels.to_array() ==
    [
      (255).to_byte(),
      (0).to_byte(),
      (255).to_byte(),
      (0).to_byte(),
      (255).to_byte(),
      (0).to_byte(),
    ],
  )
  let inverted = pdf_expand_1bit_grayscale(packed, 3, 2, true).unwrap()
  assert_true(inverted[0].to_int() == 0)
  assert_true(inverted[1].to_int() == 255)
}

///|
test "PDF image normalization helpers reject malformed dimensions and clamp CMYK" {
  assert_eq(pdf_min_int(2, 3), 2)
  assert_eq(pdf_min_int(5, 3), 3)
  assert_true(pdf_convert_cmyk_to_rgb(Bytes::new(0), 1, 1) is None)
  let rgb = pdf_convert_cmyk_to_rgb(
    Bytes::from_array([
      (250).to_byte(),
      (10).to_byte(),
      (0).to_byte(),
      (10).to_byte(),
    ]),
    1,
    1,
  ).unwrap()
  assert_true(rgb[0].to_int() == 0)
  assert_true(rgb[1].to_int() == 235)
  assert_true(rgb[2].to_int() == 245)
}
