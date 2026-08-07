///|
fn pdf_product_wbtest_object(
  object_id : Int,
  dict_text : String,
) -> PdfNativeObject {
  { object_id, dict_text, stream: None }
}

///|
fn pdf_product_wbtest_navigation_objects() -> Map[Int, PdfNativeObject] {
  Map([
    (
      1,
      pdf_product_wbtest_object(
        1, "<< /Type /Catalog /Outlines 10 0 R /Names 20 0 R /Dests 24 0 R /AcroForm 30 0 R >>",
      ),
    ),
    (3, pdf_product_wbtest_object(3, "<< /Type /Page >>")),
    (10, pdf_product_wbtest_object(10, "<< /First 11 0 R >>")),
    (
      11,
      pdf_product_wbtest_object(
        11, "<< /Title (Chapter One) /Dest [3 0 R /XYZ 0 0 0] /First 12 0 R /Next 13 0 R /P 3 0 R /Rect [1 2 20 30] >>",
      ),
    ),
    (
      12,
      pdf_product_wbtest_object(
        12, "<< /Title (Child) /A << /S /URI /URI (https://example.test/child) >> >>",
      ),
    ),
    (
      13,
      pdf_product_wbtest_object(
        13, "<< /Title (Remote) /A << /S /GoToR /F << /UF (manual.pdf) >> /D (appendix) >> >>",
      ),
    ),
    (20, pdf_product_wbtest_object(20, "<< /Dests 21 0 R >>")),
    (21, pdf_product_wbtest_object(21, "<< /Kids [22 0 R 23 0 R] >>")),
    (
      22,
      pdf_product_wbtest_object(
        22, "<< /Names [(first) [3 0 R /Fit] (alias) /NamedTarget] >>",
      ),
    ),
    (
      23,
      pdf_product_wbtest_object(
        23, "<< /Names [<7365636f6e64> << /D [3 0 R /FitH 12] >>] /Kids [22 0 R] >>",
      ),
    ),
    (
      24,
      pdf_product_wbtest_object(
        24, "<< /Flat [3 0 R /Fit] /Named /Other /Wrapped << /D [3 0 R /FitV 4] >> >>",
      ),
    ),
    (30, pdf_product_wbtest_object(30, "<< /Fields [31 0 R 34 0 R 35 0 R] >>")),
    (
      31,
      pdf_product_wbtest_object(
        31, "<< /FT /Tx /T (profile) /TU (Profile field) /V (line one\\nline two) /DV (default) /Ff 2 /Kids [32 0 R] >>",
      ),
    ),
    (
      32,
      pdf_product_wbtest_object(
        32, "<< /Subtype /Widget /Parent 31 0 R /P 3 0 R /Rect [10 20 110 40] >>",
      ),
    ),
    (
      34,
      pdf_product_wbtest_object(
        34, "<< /FT /Btn /T (enabled) /AS /Yes /P 3 0 R /Rect [10 50 20 60] >>",
      ),
    ),
    (
      35,
      pdf_product_wbtest_object(
        35, "<< /FT /Ch /T (choices) /V [(one) (two)] /DV [(fallback one) (fallback two)] /Opt [(one) (two) (two)] >>",
      ),
    ),
  ])
}

///|
test "pdf navigation extracts outline trees and both destination dictionaries" {
  let source = @input.input_from_text("synthetic", source_name="navigation.pdf")
  let objects = pdf_product_wbtest_navigation_objects()
  let pages : Map[Int, Int] = Map([(3, 1)])
  let outlines = pdf_extract_outline_items(
    source,
    ["<< /Root 1 0 R >>"],
    objects,
    pages,
  )
  assert_eq(outlines.length(), 3)
  assert_eq(outlines[0].title, "Chapter One")
  assert_true(outlines[0].page_index == Some(1))
  assert_eq(outlines[1].level, 1)
  assert_true(outlines[1].action_kind == Some("URI"))
  assert_true(outlines[2].action_kind == Some("GoToR"))
  assert_true(outlines[2].target.unwrap().contains("manual.pdf"))
  let destinations = pdf_extract_named_destinations(
    source,
    ["<< /Root 1 0 R >>"],
    objects,
    pages,
  )
  assert_true(destinations.length() >= 6)
  assert_true(destinations.any(dest => dest.name == Some("first")))
  assert_true(destinations.any(dest => dest.name == Some("alias")))
  assert_true(destinations.any(dest => dest.name == Some("Flat")))
  assert_eq(
    pdf_walk_outline_siblings(source, objects, 11, 0, 0, pages, 0).length(),
    0,
  )
  assert_eq(
    pdf_extract_named_destinations_from_name_tree(
      source,
      "<< /Kids [22 0 R] >>",
      objects,
      pages,
      Map([]),
      0,
    ).length(),
    0,
  )
}

///|
test "pdf annotation actions surface flags file specs destinations and JSON" {
  let source = @input.input_from_text(
    "synthetic",
    source_name="annotations.pdf",
  )
  let objects = pdf_product_wbtest_navigation_objects()
  let pages : Map[Int, Int] = Map([(3, 1)])
  let dictionaries = [
    "<< /Subtype /Link /P 3 0 R /Rect [1 2 30 40] /Contents ( first \\n second ) /T (author) /Subj (subject) /NM (a1) /M (today) /F 4 /A << /S /URI /URI (https://example.test) >> >>",
    "<< /Subtype /Link /Rect [1 2 3 4] /Dest [3 0 R /Fit] >>", "<< /Subtype /FileAttachment /Rect [1 2 3 4] /FS << /UF (report.txt) >> >>",
    "<< /Subtype /Widget /Rect [1 2 3 4] /TU (widget help) /F 2 >>",
  ]
  let annotations : Array[PdfNativeAnnotation] = []
  for index, dictionary in dictionaries {
    let object_id = 100 + index
    let object = pdf_product_wbtest_object(object_id, dictionary)
    match
      pdf_annotation_from_object(
        source, object, objects, 2, index, object_id, pages,
      ) {
      Some(annotation) => annotations.push(annotation)
      None => abort("expected surfaced annotation")
    }
  }
  assert_eq(annotations.length(), 4)
  assert_eq(annotations[0].page_index, 1)
  assert_true(annotations[0].action_kind == Some("URI"))
  assert_true(annotations[1].target == Some("page 1"))
  assert_true(annotations[2].file_name == Some("report.txt"))
  assert_true(annotations[3].text == Some("widget help"))
  assert_true(pdf_annotation_should_surface("Widget", Some(2)))
  assert_false(pdf_annotation_should_surface("Text", Some(2)))
  assert_false(pdf_annotation_should_surface("Text", Some(32)))
  assert_true(pdf_annotation_should_surface("Text", Some(36)))
  assert_true(pdf_annotation_flag_is_set(4, 2))
  let json = pdf_native_backend_annotation_json(annotations[0], objects)
  match json {
    Object(payload) => {
      assert_true(payload.contains("annotation_index"))
      assert_false(payload.contains("destination"))
    }
    _ => abort("expected annotation object")
  }
  let destination = make_pdf_native_destination(
    page_index=Some(1),
    target_page_index=Some(2),
    target_page_object_id=Some(3),
    kind=Some("Fit"),
    raw_value=Some("3 0 R /Fit"),
    name=Some("chapter"),
    object_id=Some(9),
  )
  match pdf_native_backend_destination_json(destination) {
    Object(payload) => assert_true(payload.contains("target_page_index"))
    _ => abort("expected destination object")
  }
  match
    pdf_native_backend_bbox_json_value({
      x: 1.0,
      y: 2.0,
      width: 3.0,
      height: 4.0,
    }) {
    Object(payload) => assert_true(payload.contains("width"))
    _ => abort("expected bbox object")
  }
}

///|
test "pdf action summaries cover local remote launch custom and missing actions" {
  let objects = pdf_product_wbtest_navigation_objects()
  let pages : Map[Int, Int] = Map([(3, 7)])
  let uri = pdf_annotation_action_summary(
    "<< /A << /S /URI /URI (https://example.test) >> >>",
    objects,
    1,
    None,
    pages,
  )
  assert_true(uri.0 == Some("URI"))
  let local_action = pdf_annotation_action_summary(
    "<< /A << /S /GoTo /D [3 0 R /Fit] >> >>",
    objects,
    1,
    None,
    pages,
  )
  assert_true(local_action.1 == Some("page 7"))
  let remote = pdf_annotation_action_summary(
    "<< /A << /S /GoToR /F (other.pdf) /D (named) >> >>",
    objects,
    1,
    None,
    pages,
  )
  assert_true(remote.1.unwrap().contains("other.pdf"))
  let launch = pdf_annotation_action_summary(
    "<< /A << /S /Launch /F (tool.exe) >> >>",
    objects,
    1,
    None,
    pages,
  )
  assert_true(launch.0 == Some("Launch"))
  let custom = pdf_annotation_action_summary(
    "<< /A << /S /JavaScript /JS (alert) >> >>",
    objects,
    1,
    None,
    pages,
  )
  assert_true(custom.0 == Some("JavaScript"))
  assert_true(
    pdf_annotation_action_summary("<< >>", objects, 1, None, pages).0 == None,
  )
}

///|
test "pdf AcroForm extraction inherits parent fields and normalizes values" {
  let source = @input.input_from_text("synthetic", source_name="forms.pdf")
  let objects = pdf_product_wbtest_navigation_objects()
  let fields = pdf_extract_form_fields(
    source,
    ["<< /Root 1 0 R >>"],
    objects,
    Map([(3, 1)]),
    Map([(32, 1)]),
  )
  assert_eq(fields.length(), 3)
  assert_true(fields.any(field => field.field_name == Some("profile")))
  assert_true(fields.any(field => field.value == Some("true")))
  assert_true(fields.any(field => field.value == Some("one, two")))
  assert_true(
    pdf_extract_form_value("<< /V (Off) >>", Some("Btn")) == Some("false"),
  )
  assert_true(
    pdf_extract_form_value("<< /AS /Yes >>", Some("Btn")) == Some("true"),
  )
  assert_true(pdf_extract_form_value("<< >>", Some("Btn")) == Some("false"))
  assert_true(
    pdf_extract_form_value("<< /V [(one)] >>", Some("Ch")) == Some("one"),
  )
  assert_true(pdf_extract_form_value("<< >>", Some("Ch")) == None)
  assert_true(pdf_extract_form_default_value("<< /DV (one) >>") == Some("one"))
  assert_true(
    pdf_extract_form_options("<< /Opt [(one) (one) () (two)] >>") ==
    ["one", "two"],
  )
  assert_eq(
    pdf_form_normalized_value_text(" one\r\ntwo\nthree "),
    "one / two / three",
  )
  assert_true(
    pdf_form_field_inherit_text(Some(" "), Some("parent")) == Some("parent"),
  )
  assert_true(
    pdf_form_field_has_visible_facts(None, None, None, None, None, ["choice"]),
  )
  assert_false(
    pdf_form_field_has_visible_facts(None, None, None, None, None, []),
  )
}
