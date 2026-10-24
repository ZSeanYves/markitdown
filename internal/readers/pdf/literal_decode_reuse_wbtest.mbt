///|
fn literal_reuse_font() -> PdfNativeFontInfo {
  {
    ..pdf_text_coverage_font_info(),
    has_tounicode: true,
    unicode_map: Map([("41", "A"), ("42", "B"), ("20", " ")]),
    simple_widths: Map([(65, 620), (66, 680), (32, 250)]),
  }
}

///|
fn literal_reuse_compare(
  token : PdfNativeContentToken,
  font : PdfNativeFontInfo,
  actual_text : String?,
  style : (Double, Double, Double, Double),
) -> Unit raise {
  let source = pdf_text_coverage_source()
  let geometry = make_pdf_page_geometry(3, 300.0, 400.0)
  let ctm : PdfNativeGraphicsMatrix = { a: 1.5, d: 0.75, e: 4.0, f: -5.0, }
  let tm : PdfNativeGraphicsMatrix = { a: 0.8, d: 1.2, e: 20.0, f: 180.0, }
  // Existing default helpers remain the exact pre-reuse display/advance path.
  let expected = pdf_fragment_from_text_operand(
    source,
    geometry,
    ctm,
    tm,
    Some("F"),
    Some(12.0),
    Some(font),
    token,
    actual_text,
    text_rise=style.3,
  )
  let width = pdf_text_operand_advance_width(
    token,
    Some(font),
    pdf_effective_font_size(tm, Some(12.0)),
    style.0,
    style.1,
    style.2,
  )
  let fragments : Array[PdfNativeTextFragment] = []
  let matrix = pdf_append_text_operand_fragment(
    fragments,
    source,
    geometry,
    ctm,
    tm,
    Some("F"),
    Some(12.0),
    Map([("F", 1)]),
    Map([(1, font)]),
    token,
    actual_text,
    style.0,
    style.1,
    style.2,
    style.3,
  )
  assert_eq(matrix.a, tm.a)
  assert_eq(matrix.d, tm.d)
  if pdf_font_uses_vertical_writing(font) {
    assert_eq(matrix.e, tm.e)
    assert_eq(matrix.f, tm.f - width)
  } else {
    assert_eq(matrix.e, tm.e + width)
    assert_eq(matrix.f, tm.f)
  }
  match expected {
    None => assert_eq(fragments.length(), 0)
    Some(old) => {
      assert_eq(fragments.length(), 1)
      let next = fragments[0]
      assert_eq(next.text, old.text)
      assert_eq(next.preserves_outer_space, old.preserves_outer_space)
      assert_eq(next.x, old.x)
      assert_eq(next.y, old.y)
      assert_eq(next.font_name, old.font_name)
      assert_eq(next.font_size, old.font_size)
      assert_eq(next.vertical_writing, old.vertical_writing)
      assert_eq(next.bbox.x, old.bbox.x)
      assert_eq(next.bbox.y, old.bbox.y)
      assert_eq(next.bbox.width, old.bbox.width)
      assert_eq(next.bbox.height, old.bbox.height)
    }
  }
}

///|
test "scalar literal reuse preserves exact fragment bbox CTM width spacing and writing direction" {
  let font = literal_reuse_font()
  let fonts = [
    font,
    {
      ..font,
      encoding_name: Some("Identity-V"),
      descendant_subtype: Some("CIDFontType2"),
      cid_width_pairs: [65, 620, 66, 680, 32, 250],
      cid_vertical_width_pairs: [65, -900, 66, -1100, 32, -500],
    },
  ]
  for font in fonts {
    for literal in ["(A B)", "( A )", "(AB)", "()", "( )"] {
      let token : PdfNativeContentToken = LiteralString(
        pdf_parse_literal_token(literal, 0).0,
      )
      for actual in [None, Some(""), Some("replacement")] {
        for
          style in [
            (0.0, 0.0, 1.0, 0.0),
            (0.7, 1.9, 0.75, 2.3),
            (-0.2, 0.5, -1.25, -3.0),
          ] {
          literal_reuse_compare(token, font, actual, style)
        }
      }
    }
  }
}

///|
test "receipt records only the original successful non-BOM code-unit scalar literal path" {
  let font = literal_reuse_font()
  let receipt : Ref[PdfDecodedFontBytes?] = Ref(None)
  assert_eq(
    pdf_decode_content_literal_pdf_text(
      "A B",
      Some(font),
      successful_literal=Some(receipt),
    ),
    "A B",
  )
  let decoded = receipt.val.unwrap()
  assert_eq(decoded.text, "A B")
  assert_eq(decoded.units.length(), 3)
  for (unit, charcode) in decoded.units.zip([65, 32, 66]) {
    assert_eq(unit.charcode, charcode)
    assert_eq(unit.byte_width, 1)
  }
  for literal in ["(\\376\\377\\000A)", "(\\377\\376A\\000)"] {
    receipt.val = None
    let parsed = pdf_parse_literal_token(literal, 0).0
    ignore(
      pdf_decode_content_literal_pdf_text(
        parsed.decoded,
        Some(font),
        successful_literal=Some(receipt),
      ),
    )
    assert_true(receipt.val is None)
    literal_reuse_compare(
      LiteralString(parsed),
      font,
      None,
      (0.3, 0.6, 0.8, 1.0),
    )
  }
  let incomplete = {
    ..font,
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    unicode_map: Map([]),
    has_tounicode: false,
    descendant_subtype: Some("CIDFontType2"),
  }
  receipt.val = None
  assert_eq(
    pdf_decode_content_literal_pdf_text(
      "A",
      Some(incomplete),
      successful_literal=Some(receipt),
    ),
    "A",
  )
  assert_true(receipt.val is None)
  let literal = pdf_parse_literal_token("(A)", 0).0
  let non_literals : Array[PdfNativeContentToken] = [
    HexString("41"),
    Array([LiteralString(literal), Number(-120.0), HexString("42")]),
  ]
  for token in non_literals {
    receipt.val = None
    ignore(
      pdf_decode_text_operand(
        token,
        Some(font),
        successful_literal=Some(receipt),
      ),
    )
    assert_true(receipt.val is None)
    literal_reuse_compare(token, font, None, (0.7, 1.4, 0.9, 3.0))
  }
}

///|
test "literal fail-closed absent-font and ordinary fallback branches keep exact prior behavior" {
  let base = pdf_text_coverage_font_info()
  let closed = {
    ..base,
    has_tounicode: true,
    tounicode_invalid_keys: Map([("41", true)]),
  }
  let failed = { ..base, has_tounicode: true, tounicode_decode_failed: true, }
  let identity = {
    ..base,
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    descendant_subtype: Some("CIDFontType2"),
  }
  for font in [base, closed, failed, identity] {
    for literal in ["(A)", "(\\000A)", "(\\376\\377\\000B)", "( A )", "(\\377)"] {
      let token : PdfNativeContentToken = LiteralString(
        pdf_parse_literal_token(literal, 0).0,
      )
      for actual in [None, Some("semantic override")] {
        literal_reuse_compare(token, font, actual, (0.8, 2.0, 1.1, -1.0))
      }
    }
  }
  let fragments : Array[PdfNativeTextFragment] = []
  let matrix = pdf_append_text_operand_fragment(
    fragments,
    pdf_text_coverage_source(),
    make_pdf_page_geometry(1, 200.0, 200.0),
    pdf_identity_matrix(),
    pdf_identity_matrix(),
    None,
    Some(12.0),
    Map([]),
    Map([]),
    LiteralString(pdf_parse_literal_token("(A)", 0).0),
    None,
    0.0,
    0.0,
    1.0,
    0.0,
  )
  assert_eq(fragments[0].text, "A")
  assert_eq(
    matrix.e,
    pdf_text_operand_advance_width(
      LiteralString(pdf_parse_literal_token("(A)", 0).0),
      None,
      12.0,
      0.0,
      0.0,
      1.0,
    ),
  )
}
