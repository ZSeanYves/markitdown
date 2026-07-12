///|
fn pdf_text_coverage_source() -> @input.InputSource {
  @input.input_from_bytes_with_format(
    @utf8.encode("%PDF-1.4\n%%EOF\n"),
    "synthetic-text-coverage.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
}

///|
fn pdf_text_coverage_font_info() -> PdfNativeFontInfo {
  {
    base_font: Some("Helvetica"),
    normalized_base_font: Some("helvetica"),
    descendant_subtype: None,
    encoding_name: Some("WinAnsiEncoding"),
    code_hex_widths: [1],
    unicode_map: Map([]),
    tounicode_invalid_keys: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
    tounicode_builtin_name: None,
    predefined_cmap: None,
    cid_collection_cmap: None,
    embedded_font_program: None,
    cid_to_gid_map: None,
    simple_widths: Map([]),
    simple_default_width: Some(600),
    cid_width_pairs: [],
    cid_default_width: None,
    cid_vertical_width_pairs: [],
    cid_default_vertical_width: None,
  }
}

///|
fn pdf_text_coverage_stream_object(
  object_id : Int,
  dict_text : String,
  payload : String,
) -> PdfNativeObject {
  {
    object_id,
    dict_text,
    stream: Some({
      primary_bytes: @utf8.encode(payload),
      endstream_bytes: @utf8.encode(payload),
      declared_length: Some(payload.length()),
    }),
  }
}

///|
test "pdf text content operators cover positioning spacing arrays and actual text" {
  let fonts : Map[Int, PdfNativeFontInfo] = Map([
    (1, pdf_text_coverage_font_info()),
  ])
  let aliases : Map[String, Int] = Map([("F1", 1)])
  let content = [
    "q 1 0 0 1 5 7 cm", "BT /F1 10 Tf 10 100 Tm", "2 Tc 3 Tw 80 Tz 4 Ts", "(alpha) Tj",
    "12 TL T* (beta) Tj", "2 -14 TD (gamma) Tj", "(delta) '", "5 1 (epsilon) \"",
    "[(A) -250 (B) 100 (C)] TJ", "/Span << /ActualText (replacement) >> BDC (ignored) Tj EMC",
    "ET Q Q",
  ].join("\n")
  let fragments = match
    pdf_extract_text_fragments_from_stream(
      pdf_text_coverage_source(),
      make_pdf_page_geometry(1, 200.0, 200.0),
      aliases,
      fonts,
      Map([]),
      content,
    ) {
    Ok(value) => value
    Err(err) => fail("synthetic content stream failed: " + err.to_string())
  }
  assert_true(fragments.length() >= 7)
  assert_true(fragments.any(fn(fragment) { fragment.text == "alpha" }))
  assert_true(fragments.any(fn(fragment) { fragment.text == "ABC" }))
  assert_true(fragments.any(fn(fragment) { fragment.text == "replacement" }))
  assert_true(fragments.all(fn(fragment) { fragment.bbox.width > 0.0 }))
}

///|
test "pdf text stream covers depth malformed tokens and form xobjects" {
  let source = pdf_text_coverage_source()
  let geometry = make_pdf_page_geometry(2, 300.0, 300.0)
  let fonts : Map[Int, PdfNativeFontInfo] = Map([
    (1, pdf_text_coverage_font_info()),
  ])
  let aliases : Map[String, Int] = Map([("F1", 1)])
  let empty = pdf_extract_text_fragments_from_stream(
    source,
    geometry,
    aliases,
    fonts,
    Map([]),
    "BT (hidden) Tj ET",
    remaining_depth=0,
  )
  assert_true(empty is Ok([]))
  match
    pdf_extract_text_fragments_from_stream(
      source,
      geometry,
      aliases,
      fonts,
      Map([]),
      "BT [(unterminated] TJ ET",
    ) {
    Err(PdfNativeError::ParseFailed(_)) => ()
    _ => fail("unterminated array must fail closed")
  }

  let form = pdf_text_coverage_stream_object(
    9, "<< /Subtype /Form /Matrix [1 0 0 1 20 30] /Resources << /Font << /F1 1 0 R >> >> >>",
    "BT /F1 9 Tf 1 0 0 1 10 20 Tm (from form) Tj ET",
  )
  let objects : Map[Int, PdfNativeObject] = Map([(9, form)])
  let fragments = match
    pdf_extract_text_fragments_from_stream(
      source,
      geometry,
      aliases,
      fonts,
      Map([]),
      "/Fm0 Do /Missing Do",
      object_index=objects,
      resources_text=Some("<< /XObject << /Fm0 9 0 R >> >>"),
    ) {
    Ok(value) => value
    Err(err) => fail("form xobject extraction failed: " + err.to_string())
  }
  assert_true(fragments.length() == 1)
  assert_eq(fragments[0].text, "from form")
  assert_true(fragments[0].x >= 30.0)
}

///|
test "pdf text utility edge cases remain deterministic" {
  let zero : PdfNativeGraphicsMatrix = { a: 0.0, d: 0.0, e: 1.0, f: 2.0 }
  let scaled : PdfNativeGraphicsMatrix = { a: -2.0, d: 3.0, e: 4.0, f: 5.0 }
  assert_true(pdf_effective_font_size(zero, None) == 12.0)
  assert_true(pdf_effective_font_size(scaled, None) == 3.0)
  assert_true(pdf_effective_font_size(scaled, Some(4.0)) == 12.0)
  let moved = pdf_text_matrix_translated(zero, 2.0, 3.0)
  assert_true(moved.e == 3.0 && moved.f == 5.0)
  let bbox = pdf_estimate_text_bbox("", 2.0, 1.0, 0.0)
  assert_true(bbox.y == 1.0 && bbox.height == 12.0)
  assert_true(pdf_estimate_text_width(" A,!中", 10.0) > 0.0)
  assert_eq(pdf_prepare_line_text_fragment("  a  b  ", None, None), "a b")
  assert_eq(
    pdf_prepare_line_text_fragment(
      "\tA\u{FB01} ",
      Some(20.0),
      Some(10.0),
      preserve_outer_space=true,
    ),
    " Afi  ",
  )
  assert_true(pdf_text_has_outer_space(" x"))
  assert_true(!pdf_text_has_outer_space(""))
  assert_true(pdf_text_outer_space_is_latinish(" x "))
  assert_true(!pdf_text_outer_space_is_latinish(" 中 "))
  assert_true(pdf_text_prefers_no_gap(",next"))
  assert_true(!pdf_text_prefers_no_gap("next"))
  assert_true(
    pdf_actual_text_from_operands([
      PdfNativeContentToken::Dict("<< /ActualText (visible) >>"),
    ]) ==
    Some("visible"),
  )
  assert_true(
    pdf_actual_text_from_operands([PdfNativeContentToken::Number(1.0)]) == None,
  )
}

///|
test "pdf embedded font extraction covers missing corrupt and supported streams" {
  let empty : Map[Int, PdfNativeObject] = Map([])
  assert_true(pdf_extract_embedded_font_program("<< >>", empty) is None)
  assert_true(
    pdf_extract_embedded_font_program("<< /FontDescriptor 8 0 R >>", empty)
    is None,
  )
  let descriptor_missing_file : PdfNativeObject = {
    object_id: 8,
    dict_text: "<< /FontFile2 10 0 R >>",
    stream: None,
  }
  let only_descriptor : Map[Int, PdfNativeObject] = Map([
    (8, descriptor_missing_file),
  ])
  assert_true(
    pdf_extract_embedded_font_program(
      "<< /FontDescriptor 8 0 R >>", only_descriptor,
    )
    is None,
  )

  let sfnt = pdf_text_coverage_stream_object(10, "<< >>", "tiny")
  let objects : Map[Int, PdfNativeObject] = Map([
    (8, descriptor_missing_file),
    (10, sfnt),
  ])
  assert_true(
    pdf_extract_embedded_font_program("<< /FontDescriptor 8 0 R >>", objects)
    is Some(_),
  )

  for subtype in ["OpenType", "Type1C", "CIDFontType0C", "Unknown"] {
    let descriptor : PdfNativeObject = {
      object_id: 8,
      dict_text: "<< /FontFile3 11 0 R >>",
      stream: None,
    }
    let file3 = pdf_text_coverage_stream_object(
      11,
      "<< /Subtype /" + subtype + " >>",
      "minimal",
    )
    let index : Map[Int, PdfNativeObject] = Map([(8, descriptor), (11, file3)])
    let result = pdf_extract_embedded_font_program(
      "<< /FontDescriptor 8 0 R >>", index,
    )
    if subtype == "Unknown" {
      assert_true(result is None)
    } else {
      assert_true(result is Some(_))
    }
  }
}

///|
test "pdf embedded font maps decoding and widths cover controlled fallbacks" {
  let identity : Map[Int, PdfNativeObject] = Map([])
  assert_true(
    pdf_extract_cid_to_gid_map("<< /CIDToGIDMap /Identity >>", identity) == None,
  )
  assert_true(
    pdf_extract_cid_to_gid_map("<< /CIDToGIDMap 7 0 R >>", identity) == None,
  )
  let mapping_object = pdf_text_coverage_stream_object(
    7,
    "<< >>",
    String::from_array([
      '\u{0000}', '\u{0001}', '\u{0000}', '\u{0002}', '\u{0009}',
    ]),
  )
  let mapping = match
    pdf_extract_cid_to_gid_map(
      "<< /CIDToGIDMap 7 0 R >>",
      Map([(7, mapping_object)]),
    ) {
    Some(value) => value
    None => fail("expected CIDToGIDMap bytes")
  }
  assert_true(mapping == [1, 2])

  let program : PdfEmbeddedFontProgram = {
    gid_unicode_gids: [1, 2],
    gid_unicode_values: ["A", "B"],
    gid_glyph_name_gids: [3],
    gid_glyph_name_values: ["space"],
    gid_advance_pairs: [1, 500],
    default_advance_width: Some(700),
  }
  let base = pdf_text_coverage_font_info()
  let info : PdfNativeFontInfo = {
    ..base,
    descendant_subtype: Some("CIDFontType2"),
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2, 1, 0],
    embedded_font_program: Some(program),
    cid_to_gid_map: Some([0, 1, 2, 3]),
  }
  let decoded = match pdf_embedded_font_decode_bytes([0, 1, 0, 2], info) {
    Some(value) => value
    None => fail("expected embedded font decoding")
  }
  assert_eq(decoded.text, "AB")
  assert_true(pdf_embedded_font_decode_bytes([0, 9], info) is None)
  assert_true(pdf_embedded_font_gid_for_charcode(info, 99) == None)
  assert_true(
    pdf_embedded_font_gid_for_charcode({ ..info, cid_to_gid_map: None }, 4) ==
    Some(4),
  )
  assert_true(pdf_embedded_font_program_unicode(program, 3) == Some(" "))
  assert_true(pdf_embedded_font_program_unicode(program, 99) == None)
  match decoded.units {
    [first, second] => {
      assert_true(
        pdf_embedded_font_program_width_1000(info, first) == Some(500),
      )
      assert_true(
        pdf_embedded_font_program_width_1000(info, second) == Some(700),
      )
    }
    _ => fail("expected two embedded units")
  }
  let no_gid : PdfDecodedFontUnit = {
    byte_width: 1,
    charcode: 0,
    cid: None,
    gid: None,
    text: "",
  }
  assert_true(pdf_embedded_font_program_width_1000(info, no_gid) == Some(700))
  assert_true(pdf_embedded_font_program_width_1000(base, no_gid) == None)
  assert_true(pdf_embedded_font_charcode_from_bytes([1, 2, 3], 1, 8) == 0x0203)
}

///|
test "pdf byte parser primitives cover comments line endings and boundaries" {
  let bytes = @utf8.encode("  % comment\r\nABC\rDEF\n")
  assert_true(pdf_find_bytes(bytes, @utf8.encode(""), 4) == Some(4))
  assert_true(pdf_find_bytes(bytes, @utf8.encode("ABC"), 0) is Some(_))
  assert_true(pdf_find_bytes(bytes, @utf8.encode("XYZ"), 0) == None)
  assert_true(!pdf_bytes_have_prefix(bytes, -1, "ABC"))
  assert_true(!pdf_bytes_have_prefix(bytes, bytes.length(), "ABC"))
  let start = pdf_skip_ascii_whitespace_and_comments_bytes(bytes, 0)
  assert_true(pdf_bytes_have_prefix(bytes, start, "ABC"))
  let first = pdf_read_ascii_line(bytes, start)
  assert_eq(first.0, "ABC")
  assert_eq(pdf_read_ascii_line(bytes, first.1).0, "DEF")
  assert_true(
    !pdf_bytes_match_except_suffix(@utf8.encode("ab"), @utf8.encode("ab")),
  )
}

///|
fn pdf_text_coverage_fragment(
  x : Double,
  y : Double,
  size : Double,
  vertical : Bool,
) -> PdfNativeTextFragment {
  {
    text: "x",
    preserves_outer_space: false,
    x,
    y,
    font_name: None,
    font_size: Some(size),
    bbox: make_pdf_bbox(x, y, size, size),
    vertical_writing: vertical,
  }
}

///|
test "pdf font utility comparisons normalization and byte boundaries cover fallbacks" {
  let crlf = @utf8.encode("one\r\ntwo\n")
  let first = pdf_read_ascii_line(crlf, 0)
  assert_true(first == ("one", 5))
  assert_true(
    pdf_bytes_match_except_suffix(@utf8.encode("ab\n"), @utf8.encode("ab")),
  )
  assert_true(
    pdf_stream_suffix_is_single_eol(@utf8.encode("ab\n"), @utf8.encode("ab")),
  )
  assert_true(
    !pdf_stream_suffix_is_single_eol(@utf8.encode("abx"), @utf8.encode("ab")),
  )
  assert_true(pdf_find_substring("abc", "a", -1) == None)
  assert_true(pdf_find_last_substring("abc", "") == None)
  assert_true(pdf_find_last_substring("abc", "abcd") == None)
  assert_true(pdf_parse_dict_text_at("x", 0) == None)
  assert_true(pdf_parse_dict_text_at("xx", 0) == None)
  assert_true(pdf_parse_dict_text_at("<< /A 1", 0) == None)
  assert_eq(pdf_normalize_pdf_text("\u{0000}\r\nA\u{FB01}\t B"), "Afi  B")
  let left = pdf_text_coverage_fragment(10.0, 10.0, 12.0, false)
  let right = pdf_text_coverage_fragment(20.0, 20.0, 8.0, false)
  let equal = pdf_text_coverage_fragment(10.0, 10.0, 12.0, false)
  let vertical_left = pdf_text_coverage_fragment(30.0, 20.0, 12.0, true)
  let vertical_right = pdf_text_coverage_fragment(20.0, 10.0, 12.0, true)
  assert_true(pdf_line_merge_tolerance([left], right) == 3.6)
  assert_true(pdf_fragment_visual_compare(right, left) == 1)
  assert_true(pdf_fragment_visual_compare(equal, left) == 0)
  assert_true(pdf_fragment_visual_compare(vertical_left, vertical_right) == -1)
  assert_true(pdf_fragment_vertical_compare(vertical_right, vertical_left) == 1)
  assert_true(pdf_fragment_vertical_compare(vertical_left, vertical_left) == 0)
  assert_true(pdf_fragment_reading_order_compare(left, right) == 1)
  assert_true(
    pdf_fragment_reading_order_compare(vertical_left, vertical_right) == -1,
  )
  let line_a = make_pdf_native_text_line(
    [],
    make_pdf_bbox(0.0, 1.0, 2.0, 2.0),
    reading_order_index=Some(2),
  )
  let line_b = make_pdf_native_text_line(
    [],
    make_pdf_bbox(3.0, 10.0, 2.0, 2.0),
    reading_order_index=Some(1),
  )
  let line_c = make_pdf_native_text_line(
    [],
    make_pdf_bbox(4.0, 1.0, 2.0, 2.0),
    reading_order_index=Some(2),
  )
  assert_true(pdf_native_line_reading_order_compare(line_a, line_b) == 1)
  assert_true(pdf_native_line_reading_order_compare(line_a, line_c) == -1)
  assert_true(
    pdf_native_line_reading_order_compare(
      { ..line_a, reading_order_index: None },
      line_b,
    ) ==
    -1,
  )
  assert_true(pdf_native_line_bbox_compare(line_b, line_a) == 1)
  assert_true(pdf_native_line_bbox_compare(line_c, line_a) == 1)
  assert_true(pdf_native_line_bbox_compare(line_a, line_a) == 0)
  assert_true(pdf_font_has_multibyte_widths([1, 2]))
}

///|
test "pdf font policy and fallback decoding cover encoding evidence branches" {
  let base = pdf_text_coverage_font_info()
  let absent : PdfNativeFontInfo = {
    ..base,
    encoding_name: None,
    normalized_base_font: None,
    code_hex_widths: [],
  }
  assert_true(!pdf_font_encoding_name_has_suffix(absent, "-V"))
  assert_true(pdf_font_decode_widths(absent) == [1])
  assert_true(!pdf_font_prefers_raw_gb_family_decode(absent))
  assert_true(!pdf_font_prefers_raw_euc_jp_decode(absent))
  assert_true(!pdf_font_prefers_raw_shift_jis_decode(absent))
  assert_true(pdf_normalized_pdf_font_name(Some("  ")) == None)
  assert_true(
    pdf_normalized_pdf_font_name(Some("Bad#GGName")) == Some("bad#ggname"),
  )
  let identity : PdfNativeFontInfo = {
    ..absent,
    encoding_name: Some("Identity-H"),
    has_tounicode: true,
  }
  assert_true(pdf_font_should_fail_closed_after_tounicode(identity))
  assert_true(!pdf_font_may_use_raw_cjk_decode(identity))
  assert_true(pdf_font_decode_widths(identity) == [2])
  assert_true(
    pdf_decode_font_code_fallback("0001", { ..identity, has_tounicode: false }) ==
    Some(" "),
  )
  let embedded_program : PdfEmbeddedFontProgram = {
    gid_unicode_gids: [],
    gid_unicode_values: [],
    gid_glyph_name_gids: [],
    gid_glyph_name_values: [],
    gid_advance_pairs: [],
    default_advance_width: None,
  }
  let embedded : PdfNativeFontInfo = {
    ..absent,
    descendant_subtype: Some("CIDFontType2"),
    embedded_font_program: Some(embedded_program),
  }
  assert_true(pdf_font_decode_widths(embedded) == [2])
  assert_true(
    pdf_embedded_font_decode_bytes([1], { ..embedded, code_hex_widths: [] })
    is None,
  )
  let simple_embedded : PdfNativeFontInfo = {
    ..absent,
    embedded_font_program: Some(embedded_program),
  }
  assert_true(pdf_font_decode_widths(simple_embedded) == [1])
  let gb : PdfNativeFontInfo = {
    ..absent,
    encoding_name: Some("GB-EUC-H"),
    normalized_base_font: Some("simsun"),
  }
  let euc : PdfNativeFontInfo = {
    ..absent,
    encoding_name: Some("EUC-H"),
    normalized_base_font: Some("mincho"),
  }
  let sjis : PdfNativeFontInfo = {
    ..absent,
    encoding_name: Some("90ms-RKSJ-H"),
    normalized_base_font: Some("gothic"),
  }
  assert_true(pdf_font_prefers_raw_gb_family_decode(gb))
  assert_true(pdf_font_prefers_raw_euc_jp_decode(euc))
  assert_true(pdf_font_prefers_raw_shift_jis_decode(sjis))
  assert_true(pdf_font_raw_cjk_encoding_kind(euc) is Some(_))
  assert_true(pdf_font_raw_cjk_encoding_kind(sjis) is Some(_))
  assert_true(pdf_decode_raw_cjk_bytes_for_font([65], gb) == None)
  assert_true(pdf_decode_raw_cjk_bytes_for_font([0xFF], gb) == None)
  assert_true(pdf_decode_raw_cjk_hex_fallback("Z", gb) == None)
  assert_true(pdf_decode_raw_cjk_hex_fallback("4142", base) == None)
  assert_true(pdf_decode_font_code_fallback("80", base) == Some("€"))
  assert_true(pdf_decode_font_code_fallback("0080", base) == Some("€"))
  assert_true(pdf_decode_font_code_fallback("GG", base) == None)
  assert_true(pdf_decode_font_code_fallback("A1A1", gb) == None)
  assert_true(pdf_text_has_disallowed_control("\u{0000}"))
  assert_true(pdf_text_has_disallowed_control("\u{0001}"))
  assert_true(!pdf_text_has_disallowed_control("\t\nA"))
  assert_true(!pdf_is_usable_tounicode_text(""))
  assert_true(!pdf_is_usable_tounicode_text("\u{FDD0}"))
  assert_true(pdf_hex_byte_values("") == None)
  assert_true(pdf_hex_byte_values("A") == None)
  assert_true(pdf_hex_byte_values("GG") == None)
}

///|
test "pdf content token escapes operands and primitive parsers cover failures" {
  let literal = pdf_parse_literal_token(
    "(a\\rb\\tc\\bd\\fe\\)f\\\\g\\\nh\\\ri\\101(j))", 0,
  )
  assert_true(literal.0.terminated)
  assert_true(literal.0.decoded.contains("\r"))
  assert_true(literal.0.decoded.contains("\t"))
  assert_true(literal.0.decoded.contains("\u{0008}"))
  assert_true(literal.0.decoded.contains("\u{000C}"))
  assert_true(literal.0.decoded.contains(")"))
  assert_true(literal.0.decoded.contains("\\"))
  assert_true(literal.0.decoded.contains("A(j)"))
  assert_true(!pdf_parse_literal_token("(tail\\", 0).0.terminated)
  match pdf_parse_array_token("[[(broken]", 0) {
    Err(PdfNativeError::ParseFailed(_)) => ()
    _ => fail("nested unterminated array must fail")
  }
  assert_true(pdf_parse_dict_token("<< /A << /B 1 >>", 0).0.has_prefix("<<"))
  let info = pdf_text_coverage_font_info()
  let lit = PdfNativeContentToken::LiteralString({
    decoded: "A B",
    terminated: true,
  })
  let hex = PdfNativeContentToken::HexString("4142")
  let bad_hex = PdfNativeContentToken::HexString("GG")
  let mixed = PdfNativeContentToken::Array([
    lit,
    PdfNativeContentToken::Number(-100.0),
    hex,
    bad_hex,
  ])
  assert_true(pdf_decode_text_operand(mixed, Some(info)) is Some(_))
  assert_true(
    pdf_decode_text_operand(
      PdfNativeContentToken::Array([PdfNativeContentToken::Number(1.0)]),
      None,
    ) ==
    None,
  )
  assert_true(
    pdf_decode_text_operand(PdfNativeContentToken::Number(1.0), None) == None,
  )
  assert_true(
    pdf_text_operand_advance_width(lit, None, 10.0, 1.0, 2.0, 0.5) > 0.0,
  )
  assert_true(
    pdf_text_operand_advance_width(hex, Some(info), 10.0, 0.0, 0.0, 1.0) > 0.0,
  )
  assert_true(
    pdf_text_operand_advance_width(bad_hex, Some(info), 10.0, 0.0, 0.0, 1.0) ==
    0.0,
  )
  assert_true(
    pdf_text_operand_advance_width(mixed, None, 10.0, 0.0, 0.0, 1.0) > 0.0,
  )
  assert_true(
    pdf_text_operand_advance_width(
      PdfNativeContentToken::Name("x"),
      None,
      10.0,
      0.0,
      0.0,
      1.0,
    ) ==
    0.0,
  )
  assert_true(pdf_text_string_advance_width("", 10.0, 1.0, 1.0, 1.0) == 0.0)
  assert_true(pdf_normalize_pdf_fragment_text("\u{0000}") == "")
  assert_true(!pdf_text_outer_space_is_latinish("   "))
  assert_true(!pdf_text_prefers_no_gap(""))
  assert_true(pdf_token_name(PdfNativeContentToken::Number(1.0)) == None)
  assert_true(pdf_hex_to_string("") == None)
  assert_true(pdf_hex_to_string("  ") == None)
  assert_true(pdf_hex_to_string("FDD0") == None)
  assert_true(pdf_hex_to_string("GGGG") == None)
  assert_true(pdf_hex_to_string("FFFE") == None)
  assert_true(pdf_first_codepoint_from_hex("41") == Some(0x41))
  assert_true(pdf_first_codepoint_from_hex("A") == None)
  assert_true(pdf_parse_octal("9") == None)
  assert_true(pdf_parse_int("") == None)
  assert_true(pdf_parse_int("x") == None)
  assert_true(pdf_parse_double("") == None)
  assert_true(pdf_parse_double("x") == None)
  assert_true(pdf_parse_hex_int("") == None)
  assert_true(pdf_parse_hex_int("G") == None)
  assert_true(pdf_decode_big_endian_int(@utf8.encode("abc"), 0, 0) == 0)
  let actual = String::from_array(['\u{00FE}', '\u{00FF}', '\u{0000}', 'A'])
  assert_true(pdf_decode_actual_text_literal(actual) == Some("A"))
  assert_true(pdf_decode_actual_text_literal("ABCD") == None)
  assert_true(
    pdf_actual_text_from_operands([
      PdfNativeContentToken::Dict("<< /ActualText () >>"),
    ]) ==
    None,
  )
}

///|
test "pdf sfnt cmap formats and malformed tables cover bounded parsing" {
  let map0 : Map[Int, String] = Map([])
  pdf_sfnt_parse_cmap_format0(
    pdf_wbtest_bytes_from_hex(
      "000001060000" + "00".repeat(65) + "01" + "00".repeat(190),
    ),
    0,
    map0,
  )
  assert_true(map0.get(1) == Some("A"))
  pdf_sfnt_parse_cmap_format0(@utf8.encode("short"), 0, map0)
  let map6 : Map[Int, String] = Map([])
  pdf_sfnt_parse_cmap_format6(
    pdf_wbtest_bytes_from_hex("0006001000000041000200010002"),
    0,
    map6,
  )
  assert_true(map6.get(1) == Some("A"))
  assert_true(map6.get(2) == Some("B"))
  pdf_sfnt_parse_cmap_format6(@utf8.encode("short"), 0, map6)
  pdf_sfnt_parse_cmap_format6(
    pdf_wbtest_bytes_from_hex("000600100000004100020001"),
    0,
    Map([]),
  )
  let map12 : Map[Int, String] = Map([])
  pdf_sfnt_parse_cmap_format12(
    pdf_wbtest_bytes_from_hex(
      "000C00000000001C00000000000000010001F6000001F60100000005",
    ),
    0,
    map12,
  )
  assert_true(map12.get(5) == Some("😀"))
  assert_true(map12.get(6) == Some("😁"))
  pdf_sfnt_parse_cmap_format12(@utf8.encode("short"), 0, map12)
  pdf_sfnt_parse_cmap_format12(
    pdf_wbtest_bytes_from_hex("000C0000001C000000000001"),
    0,
    Map([]),
  )
  let format4_short : Map[Int, String] = Map([])
  pdf_sfnt_parse_cmap_format4(@utf8.encode("short"), 0, format4_short)
  assert_true(format4_short.length() == 0)
  assert_true(
    pdf_sfnt_collect_gid_unicode_pairs(@utf8.encode(""), 0) == ([], []),
  )
  assert_true(
    pdf_sfnt_collect_gid_unicode_pairs(pdf_wbtest_bytes_from_hex("00070000"), 0) ==
    ([], []),
  )
  assert_true(
    pdf_parse_sfnt_tables(
      pdf_wbtest_bytes_from_hex("00010000000100000000000041424344"),
    ).length() ==
    0,
  )
  let bad_tables : Map[String, PdfSfntTableRecord] = Map([
    ("head", { offset: 100 }),
    ("maxp", { offset: 100 }),
    ("hhea", { offset: 100 }),
    ("cmap", { offset: 100 }),
  ])
  let tiny = @utf8.encode("tiny")
  assert_true(pdf_sfnt_table_head_units_per_em(tiny, bad_tables) == None)
  assert_true(pdf_sfnt_table_num_glyphs(tiny, bad_tables) == None)
  assert_true(pdf_sfnt_table_num_h_metrics(tiny, bad_tables) == None)
  assert_true(pdf_sfnt_table_unicode_map(tiny, bad_tables) == ([], []))
  assert_true(pdf_sfnt_table_hmtx_advances(tiny, Map([]), 1000, 1, 1) == [])
  assert_true(
    pdf_cff_read_index(@utf8.encode("x"), 0) == ([], @utf8.encode("x").length()),
  )
  assert_true(
    pdf_cff_read_index(pdf_wbtest_bytes_from_hex("000101"), 0).0 == [],
  )
  assert_true(
    pdf_cff_read_index(pdf_wbtest_bytes_from_hex("0001010001"), 0).0 == [],
  )
  assert_true(
    pdf_cff_parse_dict_entries(pdf_wbtest_bytes_from_hex("FF")).length() == 0,
  )
  assert_true(pdf_cff_private_dict_value(@utf8.encode("tiny"), 20) == None)
  let no_map = pdf_text_coverage_font_info()
  assert_true(pdf_embedded_font_gid_for_charcode(no_map, 65) == Some(65))
  assert_true(pdf_embedded_font_gid_for_charcode(no_map, 0x10000) == None)
  assert_true(
    pdf_parse_embedded_cff_font_program(@utf8.encode("tiny"), false) is Some(_),
  )
}
