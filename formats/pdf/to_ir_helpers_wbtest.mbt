///|
fn pdf_helper_object(
  entries : Array[(String, @core.JsonValue)],
) -> @core.JsonValue {
  @core.JsonValue::Object(Map(entries))
}

///|
fn pdf_helper_destination(
  target_page? : String? = None,
  name? : String? = None,
  raw? : String? = None,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  match target_page {
    Some(value) =>
      payload.set("target_page_index", @core.JsonValue::Number(value))
    None => ()
  }
  match name {
    Some(value) => payload.set("name", @core.JsonValue::String(value))
    None => ()
  }
  match raw {
    Some(value) => payload.set("raw_value", @core.JsonValue::String(value))
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_helper_source_ref(file_id : String, page : Int) -> @core.SourceRef {
  {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(file_id),
      Some("pdf"),
      Some(1),
      Some(1),
    ),
    page: Some(page),
    bbox: Some({ x0: 0.0, y0: 0.0, x1: 10.0, y1: 10.0 }),
  }
}

///|
test "PDF appendix lowering covers annotation visibility targets summaries and deduplication" {
  let annotations = [
    @core.JsonValue::String("invalid"),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("1")),
      ("subtype", @core.JsonValue::String("Widget")),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("1")),
      ("subtype", @core.JsonValue::String("Link")),
      ("action_kind", @core.JsonValue::String("URI")),
      ("target", @core.JsonValue::String("https://example.test")),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("2")),
      ("annotation_index", @core.JsonValue::Number("2")),
      ("subtype", @core.JsonValue::String("Link")),
      ("action_kind", @core.JsonValue::String("GoTo")),
      ("destination", pdf_helper_destination(target_page=Some("4"))),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("3")),
      ("subtype", @core.JsonValue::String("Text")),
      ("text", @core.JsonValue::String("hidden")),
      ("flag_hidden", @core.JsonValue::Bool(true)),
      ("flag_print", @core.JsonValue::Bool(false)),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("1")),
      ("annotation_index", @core.JsonValue::Number("1")),
      ("subtype", @core.JsonValue::String("Square")),
      ("title", @core.JsonValue::String("same")),
      ("text", @core.JsonValue::String("same")),
      ("subject", @core.JsonValue::String("Important")),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("5")),
      ("subtype", @core.JsonValue::String("FileAttachment")),
      ("title", @core.JsonValue::String("Spec")),
      ("file_name", @core.JsonValue::String("spec.txt")),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("1")),
      ("annotation_index", @core.JsonValue::Number("1")),
      ("subtype", @core.JsonValue::String("Square")),
      ("title", @core.JsonValue::String("same")),
      ("text", @core.JsonValue::String("same")),
      ("subject", @core.JsonValue::String("Important")),
    ]),
  ]
  let metadata : Map[String, @core.JsonValue] = Map([
    ("pdf_native_annotations", @core.JsonValue::Array(annotations)),
  ])
  let lines = pdf_native_annotation_appendix_lines(metadata)
  assert_eq(lines.length(), 3)
  assert_true(lines.any(line => line == "Square (page 1): Important"))
  assert_true(lines.any(line => line == "Link (page 2): page 4"))
  assert_true(lines.any(line => line.contains("spec.txt")))
  let blocks = pdf_native_appendix_blocks(metadata)
  assert_eq(blocks.length(), 2)
  assert_eq(blocks[0].text, "Annotations")
  assert_eq(blocks[1].children.length(), 3)
}

///|
test "PDF appendix lowering covers form kinds values defaults options and labels" {
  let forms = [
    @core.JsonValue::Null,
    pdf_helper_object([
      ("page", @core.JsonValue::Number("1")),
      ("field_type", @core.JsonValue::String("Btn")),
      ("field_name", @core.JsonValue::String("approved")),
      ("value", @core.JsonValue::String("true")),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("2")),
      ("field_type", @core.JsonValue::String("Btn")),
      ("value", @core.JsonValue::String("false")),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("3")),
      ("field_type", @core.JsonValue::String("Ch")),
      ("alternate_name", @core.JsonValue::String("Status")),
      ("value", @core.JsonValue::String("ready")),
      ("flags", @core.JsonValue::Number("1")),
      (
        "options",
        @core.JsonValue::Array([
          @core.JsonValue::String("draft"),
          @core.JsonValue::String("ready"),
          @core.JsonValue::Bool(true),
          @core.JsonValue::Null,
        ]),
      ),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("4")),
      ("field_type", @core.JsonValue::String("Tx")),
      ("field_name", @core.JsonValue::String("comment")),
      ("default_value", @core.JsonValue::String("fallback")),
    ]),
    pdf_helper_object([
      ("page", @core.JsonValue::Number("5")),
      ("field_type", @core.JsonValue::String("Ch")),
      (
        "options",
        @core.JsonValue::Array([
          @core.JsonValue::String("one"),
          @core.JsonValue::String("two"),
        ]),
      ),
    ]),
  ]
  let metadata : Map[String, @core.JsonValue] = Map([
    ("pdf_native_form_fields", @core.JsonValue::Array(forms)),
  ])
  let lines = pdf_native_form_appendix_lines(metadata)
  assert_eq(lines.length(), 5)
  assert_true(lines.any(line => line.contains("approved — checked")))
  assert_true(lines.any(line => line.contains("Button — unchecked")))
  assert_true(
    lines.any(line => line.contains("Status — options: draft, ready, true")),
  )
  assert_true(lines.any(line => line.contains("comment — fallback")))
  assert_true(lines.any(line => line.contains("Choice — options: one, two")))
  assert_eq(pdf_native_appendix_blocks(metadata).length(), 2)
}

///|
test "PDF appendix lowering covers bookmarks destinations JSON helpers and ordering" {
  let bookmarks = [
    @core.JsonValue::Bool(false),
    pdf_helper_object([("title", @core.JsonValue::String("   "))]),
    pdf_helper_object([
      ("order_index", @core.JsonValue::Number("2")),
      ("title", @core.JsonValue::String("Second")),
      ("target", @core.JsonValue::String("chapter-two")),
    ]),
    pdf_helper_object([
      ("order_index", @core.JsonValue::Number("1")),
      ("level", @core.JsonValue::Number("1")),
      ("title", @core.JsonValue::String("First")),
      ("target", @core.JsonValue::String("/XYZ raw")),
      ("destination", pdf_helper_destination(name=Some("intro\"section"))),
    ]),
    pdf_helper_object([
      ("order_index", @core.JsonValue::Number("3")),
      ("title", @core.JsonValue::String("Untargeted")),
    ]),
  ]
  let metadata : Map[String, @core.JsonValue] = Map([
    ("pdf_native_outline_items", @core.JsonValue::Array(bookmarks)),
  ])
  let lines = pdf_native_bookmark_appendix_lines(metadata)
  assert_eq(lines.length(), 3)
  assert_true(lines[0].contains("named destination \"intro\\\"section\""))
  assert_eq(lines[1], "Second -> chapter-two")
  assert_eq(lines[2], "Untargeted")
  let payload : Map[String, @core.JsonValue] = Map([
    ("string", @core.JsonValue::String("value")),
    ("number", @core.JsonValue::Number("12")),
    ("yes", @core.JsonValue::Bool(true)),
    ("no", @core.JsonValue::String("false")),
    ("object", pdf_helper_destination(raw=Some("/Fit"))),
  ])
  assert_true(pdf_native_json_string_field(payload, "number") == Some("12"))
  assert_true(pdf_native_json_string_field(payload, "yes") == Some("true"))
  assert_true(pdf_native_json_number_field(payload, "string") is None)
  assert_true(pdf_native_json_bool_field(payload, "yes") == Some(true))
  assert_true(pdf_native_json_bool_field(payload, "no") == Some(false))
  assert_true(pdf_native_json_object_field(payload, "object") is Some(_))
  assert_true(pdf_native_nonempty_trimmed(Some(" x ")) == Some("x"))
  assert_true(pdf_native_nonempty_trimmed(Some(" ")) is None)
  assert_true(pdf_native_looks_like_uri("MAILTO:a@example.test"))
  assert_true(!pdf_native_looks_like_uri("chapter"))
  assert_true(pdf_native_parse_int(" 42 ") == Some(42))
  assert_true(pdf_native_parse_int("bad") is None)
  assert_eq(pdf_native_form_display_kind(""), "Field")
  assert_eq(pdf_native_form_display_kind("Custom"), "Custom")
  assert_eq(pdf_native_form_display_value("Btn", "true"), "checked")
  assert_eq(pdf_native_form_display_value("Btn", "false"), "unchecked")
  assert_true(pdf_native_looks_like_raw_destination_target("12 0 R"))
  assert_true(
    pdf_native_destination_has_visible_hint(
      Map([("object_id", @core.JsonValue::Number("7"))]),
    ),
  )
}

///|
test "PDF image asset helpers cover extension path deduplication alt and numbering" {
  let source_ref = pdf_helper_source_ref("images.pdf", 1)
  let base = @core.make_asset_ref(
    @core.AssetKind::Image,
    "asset-one",
    source_ref~,
  )
  let fallback_alt_asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    "asset-fallback",
    source_ref~,
  )
  let jpeg = { ..base, mime_type: Some("image/jpeg") }
  assert_eq(pdf_native_asset_ext(jpeg), "jpg")
  assert_eq(
    pdf_native_asset_ext({ ..base, mime_type: Some("image/png") }),
    "png",
  )
  assert_eq(
    pdf_native_asset_ext({ ..base, mime_type: Some("image/gif") }),
    "gif",
  )
  assert_eq(
    pdf_native_asset_ext({ ..base, mime_type: Some("image/bmp") }),
    "bmp",
  )
  assert_eq(
    pdf_native_asset_ext({ ..base, mime_type: Some("image/webp") }),
    "webp",
  )
  assert_eq(
    pdf_native_asset_ext({ ..base, mime_type: Some("image/jp2") }),
    "jp2",
  )
  assert_eq(pdf_native_asset_ext(base), "bin")
  jpeg.attrs.set("file_ext", " custom ")
  jpeg.attrs.set("alt", " Diagram ")
  assert_eq(pdf_native_asset_ext(jpeg), "custom")
  assert_eq(pdf_native_image_alt_text(2, 3, jpeg), "Diagram")
  assert_eq(
    pdf_native_image_alt_text(2, 3, fallback_alt_asset),
    "page-2-image-3",
  )
  assert_eq(pdf_native_two_digits(1), "01")
  assert_eq(pdf_native_two_digits(12), "12")
  let assets : Array[@core.AssetRef] = []
  let paths : Map[String, String] = Map([])
  let first = pdf_native_materialize_image_asset(jpeg, assets, paths)
  assert_true(first.path == Some("assets/image01.custom"))
  assert_eq(assets.length(), 1)
  let duplicate = pdf_native_materialize_image_asset(jpeg, assets, paths)
  assert_true(duplicate.path == first.path)
  assert_eq(assets.length(), 1)
  let explicit = {
    ..base,
    asset_id: "asset-two",
    path: Some("custom/image.bin"),
  }
  assert_true(
    pdf_native_materialize_image_asset(explicit, assets, paths).path ==
    Some("custom/image.bin"),
  )
}

///|
test "PDF table helpers cover text fallback span alignment multiline and tolerance" {
  assert_true(
    pdf_native_table_row_cells_from_text("Name  Value  Notes") ==
    ["Name", "Value", "Notes"],
  )
  assert_true(
    pdf_native_table_row_cells_from_text("A B C D") == ["A", "B", "C D"],
  )
  assert_eq(pdf_native_table_row_cells_from_text("one two").length(), 0)
  assert_true(pdf_native_table_text_tokens(" a  b\tc\nd ") == ["a", "b\tc\nd"])
  assert_true(pdf_native_table_token_has_letter("123A"))
  assert_true(!pdf_native_table_token_has_letter("123"))
  assert_true(
    pdf_native_distinct_sorted_xs([30.0, 10.0, 10.4, 20.0]) ==
    [10.0, 20.0, 30.0],
  )
  assert_true(pdf_native_table_alignment_tolerance([]) == 18.0)
  assert_true(pdf_native_table_alignment_tolerance([10.0, 20.0]) == 12.0)
  assert_true(pdf_native_table_alignment_tolerance([10.0, 110.0]) == 24.0)
  assert_true(
    pdf_native_table_alignment_index(11.0, [10.0, 20.0], 2, 5.0) == Some(0),
  )
  assert_true(
    pdf_native_table_alignment_index(50.0, [10.0, 20.0], 2, 5.0) is None,
  )
  let bbox1 = @dpdfnative.make_pdf_bbox(10.0, 10.0, 20.0, 10.0)
  let bbox2 = @dpdfnative.make_pdf_bbox(100.0, 10.0, 20.0, 10.0)
  let line = @dpdfnative.make_pdf_native_text_line(
    [
      @dpdfnative.make_pdf_native_text_span("one", bbox1),
      @dpdfnative.make_pdf_native_text_span("two", bbox2),
    ],
    @dpdfnative.make_pdf_bbox(10.0, 10.0, 110.0, 10.0),
  )
  assert_true(
    pdf_native_table_line_cells_from_alignment(line, [10.0, 100.0], 2).unwrap() ==
    ["one", "two"],
  )
  assert_true(
    pdf_native_table_row_cells_from_line(line, "fallback") == ["one", "two"],
  )
  assert_true(pdf_native_table_line_cells_from_alignment(line, [], 2) is None)
  let source_ref = pdf_helper_source_ref("table.pdf", 1)
  assert_true(
    pdf_native_table_cell_rich_inlines("first\nsecond", source_ref) is Some(_),
  )
  assert_true(pdf_native_table_cell_rich_inlines("single", source_ref) is None)
}

///|
test "PDF link and text helpers cover URI overlap anchors substring and line merging" {
  assert_true(pdf_native_href_is_external_uri("https://example.test"))
  assert_true(pdf_native_href_is_external_uri("mailto:a@example.test"))
  assert_true(!pdf_native_href_is_external_uri("#local"))
  assert_true(!pdf_native_href_is_external_uri("https://bad url"))
  assert_eq(pdf_native_inline_anchor_text("  one   two  "), "one two")
  assert_true(pdf_native_find_substring("alpha beta", "beta", 0) == Some(6))
  assert_true(pdf_native_find_substring("alpha", "", 2) == Some(2))
  assert_true(pdf_native_find_substring("alpha", "x", -1) is None)
  assert_true(
    pdf_native_unique_substring_range("alpha beta", "beta") == Some((6, 10)),
  )
  assert_true(pdf_native_unique_substring_range("x x", "x") is None)
  assert_true(pdf_native_unique_substring_range("text", "") is None)
  assert_eq(pdf_native_merge_block_line_text("hyphen-", "ated"), "hyphenated")
  assert_eq(pdf_native_merge_block_line_text("left", "right"), "left right")
  assert_eq(pdf_native_merge_block_line_text("", "right"), "right")
  assert_eq(pdf_native_merge_block_line_text("left", ""), "left")
  assert_true(pdf_native_line_looks_like_list_boundary_text("- item"))
  assert_true(pdf_native_line_looks_like_list_boundary_text("12. item"))
  assert_true(!pdf_native_line_looks_like_list_boundary_text("paragraph"))
  assert_true(pdf_native_line_looks_table_like("Name | Value"))
  assert_true(!pdf_native_line_looks_table_like("plain paragraph"))
  assert_true(pdf_native_parse_json_double(" 1.25 ") == Some(1.25))
  assert_true(pdf_native_parse_json_double("") is None)
  assert_true(pdf_native_parse_json_double("bad") is None)
  let bbox = pdf_native_bbox_from_json_object(
    Map([
      ("x", @core.JsonValue::Number("1")),
      ("y", @core.JsonValue::Number("2")),
      ("width", @core.JsonValue::Number("3")),
      ("height", @core.JsonValue::Number("4")),
    ]),
  ).unwrap()
  assert_true(bbox.x == 1.0 && bbox.height == 4.0)
  assert_true(pdf_native_bbox_from_json_object(Map([])) is None)
}

///|
fn pdf_helper_table_row(
  page_no : Int,
  text : String,
  y : Double,
  aligned_xs : Array[Double],
  order? : Int? = None,
) -> PdfNativeTableRowCandidate {
  {
    page_no,
    text,
    bbox: @dpdfnative.make_pdf_bbox(10.0, y, 120.0, 12.0),
    source_ref: Some(pdf_helper_source_ref("table.pdf", page_no)),
    reading_order_index: order,
    line_start: Some(page_no),
    line_end: Some(page_no),
    aligned_xs,
  }
}

///|
test "PDF table candidate helpers cover eligibility alignment joins and regions" {
  assert_true(pdf_native_table_row_text_is_eligible("Name | Value"))
  assert_true(pdf_native_table_row_text_is_eligible("Name  Value  Notes"))
  assert_true(!pdf_native_table_row_text_is_eligible(""))
  assert_true(!pdf_native_table_row_text_is_eligible("- list item"))
  assert_true(!pdf_native_table_row_text_is_eligible("one two"))
  assert_true(
    !pdf_native_table_row_text_is_eligible(Array::make(161, "x").join("")),
  )
  let span1 = @dpdfnative.make_pdf_native_text_span(
    "Name",
    @dpdfnative.make_pdf_bbox(10.0, 100.0, 20.0, 10.0),
  )
  let span2 = @dpdfnative.make_pdf_native_text_span(
    "Value",
    @dpdfnative.make_pdf_bbox(80.0, 100.0, 20.0, 10.0),
  )
  let line = @dpdfnative.make_pdf_native_text_line(
    [span1, span2],
    @dpdfnative.make_pdf_bbox(10.0, 100.0, 100.0, 10.0),
  )
  assert_true(
    pdf_native_table_row_alignment_positions(line, "Name Value") == [10.0, 80.0],
  )
  let fallback_line = @dpdfnative.make_pdf_native_text_line(
    [span1],
    @dpdfnative.make_pdf_bbox(10.0, 100.0, 100.0, 10.0),
  )
  assert_true(
    pdf_native_table_row_alignment_positions(
      fallback_line, "Name  Value  Notes",
    ) ==
    [10.0, 34.0, 58.0],
  )
  assert_true(
    pdf_native_table_row_alignment_positions(fallback_line, "plain text") == [],
  )
  let row1 = pdf_helper_table_row(
    1,
    "Name | Value",
    100.0,
    [10.0, 80.0],
    order=Some(1),
  )
  let row2 = pdf_helper_table_row(1, "A | 1", 84.0, [11.0, 81.0], order=Some(2))
  let row3 = pdf_helper_table_row(1, "B | 2", 68.0, [9.0, 79.0], order=Some(3))
  assert_true(pdf_native_table_row_should_join_region([row1], row2))
  assert_true(
    !pdf_native_table_row_should_join_region([row1], {
      ..row2,
      reading_order_index: Some(5),
    }),
  )
  assert_true(
    !pdf_native_table_row_should_join_region([row1], {
      ..row2,
      bbox: @dpdfnative.make_pdf_bbox(10.0, 10.0, 120.0, 12.0),
    }),
  )
  assert_true(
    !pdf_native_table_row_should_join_region([row1], {
      ..row2,
      aligned_xs: [200.0, 300.0],
    }),
  )
  assert_true(
    pdf_native_table_region_alignment_positions([row1, row2, row3]).length() ==
    2,
  )
  assert_eq(
    pdf_native_table_alignment_overlap_count([10.0, 80.0], [12.0, 200.0]),
    1,
  )
  assert_eq(pdf_native_table_candidate_confidence(3, 3), "high")
  assert_eq(pdf_native_table_candidate_confidence(2, 2), "medium")
  assert_eq(pdf_native_table_candidate_confidence(1, 1), "low")
  assert_true(pdf_native_table_region_candidate([row1]) is None)
  let region = pdf_native_table_region_candidate([row1, row2, row3]).unwrap()
  assert_eq(region.row_count, 3)
  assert_eq(region.reason, "table_like_rows")
  assert_eq(region.confidence, "medium")
  assert_true(region.source_refs.length() == 3)
  match pdf_native_table_region_candidate_json(region) {
    @core.JsonValue::Object(payload) => {
      assert_true(
        payload.get("row_count") == Some(@core.JsonValue::Number("3")),
      )
      assert_true(payload.get("source_refs") is Some(_))
      assert_true(payload.get("reading_order_indices") is Some(_))
    }
    _ => fail("table region must serialize as object")
  }
}
