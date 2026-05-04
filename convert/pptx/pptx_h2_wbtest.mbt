///|
test "pptx hidden slide entry parsing reads show flag conservatively" {
  let xml = "<p:presentation><p:sldIdLst>" +
    "<p:sldId id=\"256\" r:id=\"rId8\"/>" +
    "<p:sldId id=\"257\" r:id=\"rId9\" show=\"0\"/>" +
    "<p:sldId id=\"258\" r:id=\"rId10\" show=\"false\"/>" +
    "</p:sldIdLst></p:presentation>"
  let entries = parse_presentation_slide_entries(xml)
  assert_eq(entries.length(), 3)
  assert_eq(entries[0], ("rId8", false))
  assert_eq(entries[1], ("rId9", true))
  assert_eq(entries[2], ("rId10", true))
}

///|
test "pptx notes placeholder filtering skips boilerplate kinds" {
  assert_eq(
    is_notes_shape_placeholder_noise(
      pat(
        "<p:sp><p:nvSpPr><p:nvPr><p:ph type=\"sldImg\"/></p:nvPr></p:nvSpPr></p:sp>",
      ),
    ),
    true,
  )
  assert_eq(
    is_notes_shape_placeholder_noise(
      pat(
        "<p:sp><p:nvSpPr><p:nvPr><p:ph type=\"body\"/></p:nvPr></p:nvSpPr></p:sp>",
      ),
    ),
    false,
  )
  assert_eq(is_notes_placeholder_noise("  "), true)
  assert_eq(is_notes_placeholder_noise("2026"), true)
  assert_eq(is_notes_placeholder_noise("Footer"), true)
  assert_eq(is_notes_placeholder_noise("Takeaway"), false)
}

///|
test "pptx explicit table parser keeps rows and breaks" {
  let frame_xml = "<p:graphicFrame>" +
    "<p:nvGraphicFramePr><p:cNvPr id=\"7\" name=\"Table 6\"/></p:nvGraphicFramePr>" +
    "<a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\">" +
    "<a:tbl><a:tblPr firstRow=\"1\"/>" +
    "<a:tr>" +
    "<a:tc><a:txBody><a:p><a:r><a:t>Head</a:t></a:r></a:p></a:txBody></a:tc>" +
    "<a:tc><a:txBody><a:p><a:r><a:t>Value</a:t></a:r></a:p></a:txBody></a:tc>" +
    "</a:tr>" +
    "<a:tr>" +
    "<a:tc><a:txBody><a:p><a:r><a:t>Q1</a:t></a:r></a:p></a:txBody></a:tc>" +
    "<a:tc><a:txBody><a:p><a:r><a:t>Line 1</a:t></a:r><a:br/><a:r><a:t>Line 2</a:t></a:r></a:p></a:txBody></a:tc>" +
    "</a:tr>" +
    "</a:tbl></a:graphicData></a:graphic>" +
    "</p:graphicFrame>"
  let frames = collect_explicit_table_frames(
    @utf8.encode(frame_xml),
    Map::new(),
  )
  assert_eq(frames.length(), 1)
  let frame = frames[0]
  assert_eq(frame.header_rows, 1)
  match frame.object_ref {
    Some(obj_ref) => assert_eq(obj_ref, "graphicFrame-7")
    None => fail("expected graphic frame object_ref")
  }
  assert_eq(frame.rows, [["Head", "Value"], ["Q1", "Line 1<br>Line 2"]])
}

///|
test "pptx grouped shape children are still discovered by current scans" {
  let slide_xml = "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
    "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" " +
    "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"9\" name=\"Group 1\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"10\" y=\"20\"/><a:ext cx=\"30\" cy=\"40\"/></a:xfrm></p:grpSpPr>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"Grouped Text\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Inside Group</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "<p:pic>" +
    "<p:nvPicPr><p:cNvPr id=\"3\" name=\"Grouped Pic\" descr=\"grouped alt\"/>" +
    "<p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId5\"/></p:blipFill>" +
    "</p:pic>" +
    "<p:graphicFrame>" +
    "<p:nvGraphicFramePr><p:cNvPr id=\"7\" name=\"Grouped Table\"/></p:nvGraphicFramePr>" +
    "<a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\">" +
    "<a:tbl><a:tblPr firstRow=\"1\"/>" +
    "<a:tr><a:tc><a:txBody><a:p><a:r><a:t>H</a:t></a:r></a:p></a:txBody></a:tc></a:tr>" +
    "</a:tbl></a:graphicData></a:graphic>" +
    "</p:graphicFrame>" +
    "</p:grpSp>" +
    "</p:spTree></p:cSld></p:sld>"

  let objects = collect_slide_objects(@utf8.encode(slide_xml))
  let shapes = objects.text_shapes
  assert_eq(shapes.length(), 1)
  assert_eq(normalize_shape_text_for_title(shapes[0].xml), "Inside Group")
  match shapes[0].object_ref {
    Some(obj_ref) => assert_eq(obj_ref, "group-9/shape-2")
    None => fail("expected grouped text object_ref")
  }

  let raw_pictures = objects.picture_shapes
  assert_eq(raw_pictures.length(), 1)
  match raw_pictures[0].object_ref {
    Some(obj_ref) => assert_eq(obj_ref, "group-9/picture-3")
    None => fail("expected grouped picture object_ref")
  }

  let pictures = collect_slide_picture_shape_metas(@utf8.encode(slide_xml))
  assert_eq(pictures.length(), 1)
  assert_eq(pictures[0].rid, "rId5")
  match pictures[0].descr {
    Some(descr) => assert_eq(descr, "grouped alt")
    None => fail("expected grouped picture descr")
  }
  match pictures[0].object_ref {
    Some(obj_ref) => assert_eq(obj_ref, "group-9/picture-3")
    None => fail("expected grouped picture object_ref in picture meta")
  }

  let raw_frames = objects.graphic_frames
  assert_eq(raw_frames.length(), 1)
  match raw_frames[0].object_ref {
    Some(obj_ref) => assert_eq(obj_ref, "group-9/graphicFrame-7")
    None => fail("expected grouped table object_ref")
  }

  let frames = collect_explicit_table_frames(
    @utf8.encode(slide_xml),
    Map::new(),
  )
  assert_eq(frames.length(), 1)
  assert_eq(frames[0].rows, [["H"]])
  match frames[0].object_ref {
    Some(obj_ref) => assert_eq(obj_ref, "group-9/graphicFrame-7")
    None => fail("expected grouped frame object_ref")
  }
}

///|
test "pptx nested group traversal preserves nested object refs and order" {
  let slide_xml = "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
    "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" " +
    "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"Before\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"100\" y=\"100\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Before Group</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"20\" name=\"Outer Group\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"21\" name=\"Inner Group\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"22\" name=\"Nested Text\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"200\" y=\"200\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Nested Text</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:grpSp>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"23\" name=\"Outer Text\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"300\" y=\"300\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Outer Text</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:grpSp>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"24\" name=\"After\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"400\" y=\"400\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>After Group</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"

  let shapes = collect_slide_shapes(@utf8.encode(slide_xml))
  assert_eq(shapes.length(), 4)
  assert_eq(normalize_shape_text_for_title(shapes[0].xml), "Before Group")
  assert_eq(normalize_shape_text_for_title(shapes[1].xml), "Nested Text")
  assert_eq(normalize_shape_text_for_title(shapes[2].xml), "Outer Text")
  assert_eq(normalize_shape_text_for_title(shapes[3].xml), "After Group")

  match shapes[1].object_ref {
    Some(obj_ref) => assert_eq(obj_ref, "group-20/group-21/shape-22")
    None => fail("expected nested grouped text object_ref")
  }
  match shapes[2].object_ref {
    Some(obj_ref) => assert_eq(obj_ref, "group-20/shape-23")
    None => fail("expected outer grouped text object_ref")
  }
}

///|
test "pptx top non-caption title-like text still promotes to heading" {
  let slide_xml = "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
    "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"Top Label\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"700000\" y=\"180000\"/><a:ext cx=\"7800000\" cy=\"500000\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Release Notes</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"3\" name=\"Body\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"850000\" y=\"1550000\"/><a:ext cx=\"2250000\" cy=\"360000\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Security</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"

  let shapes = collect_slide_shapes(@utf8.encode(slide_xml))
  assert_eq(shapes.length(), 2)
  assert_eq(normalize_shape_text_for_title(shapes[0].xml), "Release Notes")
  assert_eq(normalize_shape_text_for_title(shapes[1].xml), "Security")

  let probe_shapes : Array[SlideShape] = [
    {
      xml: shapes[0].xml,
      x: 700000,
      y: 180000,
      w: 7800000,
      h: 500000,
      is_title: false,
      is_body: true,
      object_ref: None,
    },
    {
      xml: shapes[1].xml,
      x: 850000,
      y: 1550000,
      w: 2250000,
      h: 360000,
      is_title: false,
      is_body: true,
      object_ref: None,
    },
  ]
  let enriched = enrich_layout_shapes(probe_shapes)
  match find_promotable_title_candidate(enriched) {
    Some(idx) => assert_eq(idx, 0)
    None => fail("expected promotable title candidate")
  }

  let (title_shapes, body_shapes) = split_title_shapes(enriched)
  assert_eq(title_shapes.length(), 1)
  assert_eq(body_shapes.length(), 1)
  assert_eq(
    normalize_shape_text_for_title(title_shapes[0].shape.xml),
    "Release Notes",
  )
  assert_eq(
    normalize_shape_text_for_title(body_shapes[0].shape.xml),
    "Security",
  )

  let paras : Array[SlideParagraph] = [
    {
      source_para_id: 1,
      text: "Release Notes",
      inlines: [@cor.Inline::Text("Release Notes")],
      bullet_kind: None,
      level: 0,
      from_title_shape: true,
      from_body_shape: false,
      associated_with_image_caption: false,
    },
    {
      source_para_id: 2,
      text: "Security",
      inlines: [@cor.Inline::Text("Security")],
      bullet_kind: None,
      level: 0,
      from_title_shape: false,
      from_body_shape: true,
      associated_with_image_caption: false,
    },
  ]
  let blocks = classify_slide_paragraphs(paras)
  assert_eq(blocks.length(), 2)
  match blocks[0] {
    PptxBlock::Heading(text, _) => assert_eq(text, "Release Notes")
    _ => fail("expected top title-like text to classify as heading")
  }
}
