///|
fn pdf_product_wbtest_stream_object(
  object_id : Int,
  dict_text : String,
  body : String,
) -> PdfNativeObject {
  {
    object_id,
    dict_text,
    stream: Some({
      primary_bytes: @utf8.encode(body),
      endstream_bytes: @utf8.encode(body),
      declared_length: Some(body.length()),
    }),
  }
}

///|
test "pdf rich content stream covers graphics text positioning and marked content" {
  let source = @input.input_from_text("synthetic", source_name="content.pdf")
  let content = [
    "% a comment", "q 1 0 0 1 4 5 cm", "BT /F1 12 Tf 14 TL 1 Tc 2 Tw 90 Tz 3 Ts 1 0 0 1 20 180 Tm",
    "/Span << /ActualText (replacement) >> BDC (ignored) Tj EMC", "10 -20 Td (second) Tj",
    "0 -18 TD [(third) -120 <666f75727468>] TJ", "T* (fifth) Tj", "(sixth) '", "3 1 (seventh) \"",
    "ET Q /Missing Do",
  ].join("\n")
  let fragments = pdf_extract_text_fragments_from_stream(
    source,
    make_pdf_page_geometry(1, 200.0, 200.0),
    Map([]),
    Map([]),
    Map([]),
    content,
  ).unwrap()
  assert_true(fragments.length() >= 6)
  assert_true(fragments.any(fragment => fragment.text == "replacement"))
  assert_true(fragments.any(fragment => fragment.text.contains("third")))
  assert_eq(
    pdf_extract_text_fragments_from_stream(
      source,
      make_pdf_page_geometry(1, 10.0, 10.0),
      Map([]),
      Map([]),
      Map([]),
      "BT (hidden) Tj ET",
      remaining_depth=0,
    )
    .unwrap()
    .length(),
    0,
  )
  assert_true(pdf_scan_content_tokens("(unterminated") is Err(_))
  assert_true(pdf_scan_content_tokens("[(unterminated]") is Err(_))
}

///|
test "pdf form XObject recursively extracts text and obeys depth and subtype" {
  let source = @input.input_from_text("synthetic", source_name="form.pdf")
  let objects : Map[Int, PdfNativeObject] = Map([
    (
      40,
      pdf_product_wbtest_stream_object(
        40, "<< /Subtype /Form /Matrix [1 0 0 1 8 9] /Resources << >> >>", "BT 1 0 0 1 10 20 Tm (inside form) Tj ET",
      ),
    ),
    (
      41,
      pdf_product_wbtest_stream_object(41, "<< /Subtype /Image >>", "not text"),
    ),
  ])
  let resources = Some("<< /XObject << /Fm0 40 0 R /Im0 41 0 R >> >>")
  let fragments = pdf_extract_text_fragments_from_stream(
    source,
    make_pdf_page_geometry(1, 200.0, 200.0),
    Map([]),
    Map([]),
    Map([]),
    "q /Fm0 Do /Im0 Do Q",
    object_index=objects,
    resources_text=resources,
  ).unwrap()
  assert_eq(fragments.length(), 1)
  assert_eq(fragments[0].text, "inside form")
  assert_eq(
    pdf_extract_text_fragments_from_xobject_name(
      source,
      make_pdf_page_geometry(1, 10.0, 10.0),
      objects,
      resources,
      Map([]),
      Map([]),
      "Fm0",
      pdf_identity_matrix(),
      0,
    )
    .unwrap()
    .length(),
    0,
  )
  assert_eq(
    pdf_extract_text_fragments_from_xobject_name(
      source,
      make_pdf_page_geometry(1, 10.0, 10.0),
      objects,
      resources,
      Map([]),
      Map([]),
      "missing",
      pdf_identity_matrix(),
      2,
    )
    .unwrap()
    .length(),
    0,
  )
}

///|
test "pdf page tree geometry resources metadata and annotation indexes are deterministic" {
  let catalog = pdf_product_wbtest_object(
    1, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  let pages = pdf_product_wbtest_object(
    2, "<< /Type /Pages /Kids [3 0 R 4 0 R] /MediaBox [0 0 300 400] /Resources 7 0 R >>",
  )
  let page_one = pdf_product_wbtest_object(
    3, "<< /Type /Page /Parent 2 0 R /Annots [8 0 R 9 0 R] >>",
  )
  let page_two = pdf_product_wbtest_object(
    4, "<< /Type /Page /Parent 2 0 R /MediaBox [10 20 210 320] /Resources << /Font << /F2 6 0 R >> >> >>",
  )
  let font = pdf_product_wbtest_object(6, "<< /Type /Font /Subtype /Type1 >>")
  let resources = pdf_product_wbtest_object(7, "<< /Font << /F1 6 0 R >> >>")
  let annotation = pdf_product_wbtest_object(
    8, "<< /Subtype /Link /Rect [1 2 3 4] /A << /S /URI /URI (https://example.test) >> >>",
  )
  let annotation_array = pdf_product_wbtest_object(9, "[8 0 R]")
  let info = pdf_product_wbtest_object(
    10, "<< /Title (Synthetic) /Author (Tester) /Subject () /Keywords (pdf) /Producer (MoonBit) /Creator (wbtest) >>",
  )
  let objects = [
    catalog, pages, page_one, page_two, font, resources, annotation, annotation_array,
    info,
  ]
  let index : Map[Int, PdfNativeObject] = Map([])
  for object in objects {
    index.set(object.object_id, object)
  }
  let ordered = pdf_ordered_page_object_ids(
    ["<< /Root 1 0 R >>"],
    index,
    objects,
  )
  assert_true(ordered == [3, 4])
  let numbers = pdf_page_number_index(ordered)
  assert_true(numbers.get(3) == Some(1))
  assert_true(numbers.get(4) == Some(2))
  assert_true(pdf_page_object_ids(objects) == [3, 4])
  assert_true(pdf_collect_page_tree_ids(index, 2, Map([]), 256).length() == 0)
  assert_true(pdf_collect_page_tree_ids(index, 99, Map([]), 0).length() == 0)
  let geometry_one = pdf_page_geometry(page_one, index, 1)
  let geometry_two = pdf_page_geometry(page_two, index, 2)
  assert_true(geometry_one.width == 300.0 && geometry_one.height == 400.0)
  assert_true(geometry_two.width == 200.0 && geometry_two.height == 300.0)
  assert_true(pdf_object_is_font(font))
  assert_false(pdf_object_is_font(page_one))
  let inherited = pdf_extract_resources_text(page_one.dict_text, index)
  assert_true(inherited.unwrap().contains("/F1"))
  assert_true(
    pdf_extract_resources_text(page_two.dict_text, index)
    .unwrap()
    .contains("/F2"),
  )
  assert_true(
    pdf_extract_parent_resources_text(page_one.dict_text, index, 0) == None,
  )
  assert_true(
    pdf_font_resource_dict_text(inherited, index).unwrap().contains("/F1"),
  )
  assert_true(
    pdf_font_aliases_from_resources_text(inherited, index, Map([])).get("F1") ==
    Some(6),
  )
  let metadata = pdf_extract_info_metadata(["<< /Info 10 0 R >>"], index).unwrap()
  assert_true(metadata.contains("title"))
  assert_true(metadata.contains("author"))
  assert_true(pdf_extract_info_metadata(["<< >>"], index) == None)
  let annotation_pages = pdf_annotation_page_index(objects, index, numbers)
  assert_true(annotation_pages.get(8) == Some(1))
  assert_true(
    pdf_collect_xref_follow_offsets("<< /Prev 4 /XRefStm 8 >>") == [4, 8],
  )
  assert_true(
    pdf_collect_xref_follow_offsets("<< /Prev 4 /XRefStm 4 >>") == [4],
  )
}

///|
test "pdf dictionary extraction helpers cover scalar array string and fallback forms" {
  let text = "<< /Ref 3 0 R /Refs [3 0 R 4 0 R] /Name /Example /Int 7 /BadInt 1.5 /Rect [10 20 50 80] /Literal (hello\\nworld) /Hex <6869> /Strings [(one) <74776f> /three 4] /Inner << /A (b) >> >>"
  assert_true(pdf_extract_object_reference_after(text, "/Ref") == Some(3))
  assert_true(pdf_extract_object_references_after(text, "/Refs") == [3, 4])
  assert_true(pdf_extract_name_after(text, "/Name") == Some("Example"))
  assert_true(pdf_extract_int_after(text, "/Int") == Some(7))
  assert_true(pdf_extract_int_after(text, "/BadInt") == None)
  assert_true(pdf_extract_int_array_after(text, "/Refs") == [3, 0, 4, 0])
  assert_true(
    pdf_extract_literal_string_after(text, "/Literal") == Some("hello\nworld"),
  )
  assert_true(pdf_extract_string_after(text, "/Hex") is Some(_))
  assert_true(pdf_extract_raw_string_after(text, "/Name") == Some("Example"))
  assert_true(
    pdf_extract_string_array_after(text, "/Strings") ==
    ["one", "two", "three", "4"],
  )
  assert_true(
    pdf_extract_inline_dict_after(text, "/Inner").unwrap().contains("/A"),
  )
  assert_true(pdf_reference_ids_from_object_text("[3 0 R 4 0 R]") == [3, 4])
  assert_true(pdf_reference_ids_from_object_text("not an array") == [])
  assert_true(
    pdf_decode_utf16_literal_string("\u{00fe}\u{00ff}\u{00}\u{41}") == Some("A"),
  )
  assert_eq(pdf_decode_pdfdoc_byte_string("plain"), "plain")
  assert_eq(pdf_decode_winansi_bytes([0x80]), "€")
  assert_eq(pdf_hex_from_bytes([0x12, 0xAB, 0x00], 0, 2), "12AB")
}

///|
test "pdf byte decoders exercise complete PDFDoc and WinAnsi code pages" {
  let bytes : Array[Int] = []
  for byte in 0..<256 {
    bytes.push(byte)
    ignore(pdf_pdfdoc_byte_char(byte))
    ignore(pdf_winansi_byte_char(byte))
  }
  assert_eq(pdf_decode_pdfdoc_bytes(bytes).length(), 256)
  assert_eq(pdf_decode_winansi_bytes(bytes).length(), 256)
  assert_eq(pdf_pdfdoc_byte_char(0x80), '\u{2022}')
  assert_eq(pdf_pdfdoc_byte_char(0xA0), '\u{20AC}')
  assert_eq(pdf_winansi_byte_char(0x80), '\u{20AC}')
  assert_eq(pdf_winansi_byte_char(0x9F), '\u{0178}')
}

///|
test "pdf page annotations create only visible actionable link candidates" {
  let source = @input.input_from_text("synthetic", source_name="links.pdf")
  let page = pdf_product_wbtest_object(
    3, "<< /Type /Page /Annots [8 0 R 9 0 R 10 0 R 99 0 R] >>",
  )
  let objects : Map[Int, PdfNativeObject] = Map([
    (3, page),
    (
      8,
      pdf_product_wbtest_object(
        8, "<< /Subtype /Link /Rect [1 2 30 40] /Contents (web) /A << /S /URI /URI (https://example.test) >> >>",
      ),
    ),
    (
      9,
      pdf_product_wbtest_object(
        9, "<< /Subtype /Text /Rect [1 2 3 4] /Contents (note) >>",
      ),
    ),
    (
      10,
      pdf_product_wbtest_object(
        10, "<< /Subtype /Link /Rect [1 2 3 4] /F 2 /A << /S /URI /URI (hidden) >> >>",
      ),
    ),
  ])
  let geometry = make_pdf_page_geometry(1, 100.0, 100.0)
  let annotations = pdf_page_annotations(
    source,
    page,
    objects,
    geometry,
    Map([(3, 1)]),
  )
  assert_eq(annotations.length(), 2)
  let links = pdf_page_link_candidates(
    source,
    page,
    objects,
    geometry,
    Map([(3, 1)]),
  )
  assert_eq(links.length(), 1)
  assert_eq(links[0].href, "https://example.test")
  let destination = make_pdf_native_destination(target_page_index=Some(2))
  assert_eq(
    pdf_page_destinations([
      make_pdf_native_annotation(1, "Link", destination=Some(destination)),
      make_pdf_native_annotation(1, "Text"),
    ]).length(),
    1,
  )
}

///|
fn pdf_product_wbtest_fragment(
  text : String,
  x : Double,
  y : Double,
  size? : Double? = Some(12.0),
  vertical? : Bool = false,
) -> PdfNativeTextFragment {
  {
    text,
    preserves_outer_space: false,
    x,
    y,
    font_name: Some("Synthetic"),
    font_size: size,
    bbox: make_pdf_bbox(x, y, 40.0, 12.0),
    vertical_writing: vertical,
  }
}

///|
fn pdf_product_wbtest_line(
  text : String,
  x : Double,
  y : Double,
  size? : Double? = Some(12.0),
) -> PdfNativeTextLine {
  make_pdf_native_text_line(
    [
      make_pdf_native_text_span(
        text,
        make_pdf_bbox(x, y, 80.0, 12.0),
        font_size=size,
      ),
    ],
    make_pdf_bbox(x, y, 80.0, 12.0),
  )
}

///|
test "pdf text line and block grouping covers continuation and boundary policy" {
  let source = @input.input_from_text("synthetic", source_name="grouping.pdf")
  let geometry = make_pdf_page_geometry(1, 300.0, 400.0)
  let fragments = [
    pdf_product_wbtest_fragment("hello", 10.0, 20.0),
    pdf_product_wbtest_fragment("world", 55.0, 20.5),
    pdf_product_wbtest_fragment("next", 10.0, 50.0),
    pdf_product_wbtest_fragment("vertical", 200.0, 10.0, vertical=true),
  ]
  let lines = pdf_group_text_fragments_into_lines(source, geometry, fragments)
  assert_true(lines.length() >= 3)
  assert_true(lines[0].spans.length() >= 1)
  let mergeable = [
    pdf_product_wbtest_line("opening", 10.0, 10.0),
    pdf_product_wbtest_line("continuation", 10.0, 24.0),
  ]
  assert_true(pdf_should_merge_line_into_block([mergeable[0]], mergeable[1]))
  let blocks = pdf_group_lines_into_text_blocks(source, geometry, mergeable)
  assert_eq(blocks.length(), 1)
  assert_eq(blocks[0].lines.length(), 2)
  assert_true(pdf_should_merge_line_into_block([], mergeable[0]))
  let boundaries = [
    pdf_product_wbtest_line("- item", 10.0, 24.0),
    pdf_product_wbtest_line("1) item", 10.0, 24.0),
    pdf_product_wbtest_line("Finished.", 10.0, 10.0),
    pdf_product_wbtest_line("Uppercase", 10.0, 24.0),
    pdf_product_wbtest_line("continuation", 80.0, 24.0),
    pdf_product_wbtest_line("continuation", 10.0, 80.0),
    pdf_product_wbtest_line("continuation", 10.0, 24.0, size=Some(20.0)),
  ]
  assert_false(pdf_should_merge_line_into_block([mergeable[0]], boundaries[0]))
  assert_false(pdf_should_merge_line_into_block([boundaries[2]], mergeable[1]))
  assert_false(pdf_should_merge_line_into_block([mergeable[0]], boundaries[3]))
  assert_false(pdf_should_merge_line_into_block([mergeable[0]], boundaries[4]))
  assert_false(pdf_should_merge_line_into_block([mergeable[0]], boundaries[5]))
  assert_false(pdf_should_merge_line_into_block([mergeable[0]], boundaries[6]))
  for text in ["- x", "* x", "+ x", "1. x", "2) x"] {
    assert_true(
      pdf_line_looks_like_list_boundary(pdf_product_wbtest_line(text, 0.0, 0.0)),
    )
  }
  for ending in [".", "!", "?", ":", ";", "。", "！", "？", "：", "；"] {
    assert_true(
      pdf_line_has_strong_terminal_punctuation(
        pdf_product_wbtest_line("x" + ending, 0.0, 0.0),
      ),
    )
  }
  for prefix in ["a", "中", "\"quoted", "'quoted", "(open", "[open"] {
    assert_true(
      pdf_line_looks_like_continuation(
        pdf_product_wbtest_line(prefix, 0.0, 0.0),
      ),
    )
  }
  assert_eq(
    pdf_native_line_average_font_size(
      pdf_product_wbtest_line("x", 0.0, 0.0, size=None),
    ),
    12.0,
  )
  assert_eq(pdf_native_line_vertical_gap(mergeable[0], mergeable[1]), 2.0)
  assert_eq(pdf_native_line_vertical_gap(mergeable[1], mergeable[0]), 0.0)
}

///|
test "pdf ToUnicode parser covers scalar array invalid and malformed ranges" {
  let cmap = [
    "/Identity-H usecmap", "1 begincodespacerange <00> <FF> endcodespacerange", "2 beginbfchar <01> <0041> <02> <FFFF> endbfchar",
    "2 beginbfrange <10> <12> <0061> <20> <22> [<0064> <FFFF> <0066>] endbfrange",
  ].join("\n")
  let info = pdf_parse_tounicode_cmap_info(cmap)
  assert_true(info.mapping.get("01") == Some("A"))
  assert_true(info.mapping.get("10") == Some("a"))
  assert_true(info.mapping.get("12") == Some("c"))
  assert_true(info.mapping.get("20") == Some("d"))
  assert_true(info.invalid_keys.get("02") == Some(true))
  assert_true(info.invalid_keys.get("21") == Some(true))
  assert_true(info.usecmap_name == Some("Identity-H"))
  let mapping : Map[String, String] = Map([])
  let invalid : Map[String, Bool] = Map([])
  pdf_apply_tounicode_bfrange(mapping, invalid, "zz", "12", "0061", None)
  pdf_apply_tounicode_bfrange(mapping, invalid, "30", "31", "", None)
  pdf_apply_tounicode_bfrange(
    mapping,
    invalid,
    "40",
    "40",
    "",
    Some([Word("bad")]),
  )
  assert_true(mapping.length() == 0)
  assert_true(invalid.get("30") == Some(true))
  assert_true(
    pdf_sort_desc_widths(
      Map([(1, true), (4, true), (2, true), (0, true), (3, false)]),
    ) ==
    [4, 2, 1],
  )
}
