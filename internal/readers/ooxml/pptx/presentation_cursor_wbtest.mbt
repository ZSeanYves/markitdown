///|
async fn presentation_cursor_fixture(
  body : Bytes,
  budget_context? : @budget.BudgetContext,
) -> PptxSourceParseContext {
  let archive = @dzip.open_zip(
    @dzip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      ("ppt/presentation.xml", body),
      (
        "ppt/_rels/presentation.xml.rels", b"<Relationships><Relationship Id='rId1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide' Target='slides/slide1.xml'/><Relationship Id='rId2' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide' Target='slides/slide2.xml'/></Relationships>",
      ),
      ("ppt/slides/slide1.xml", b"<p:sld/>"),
      ("ppt/slides/slide2.xml", b"<p:sld/>"),
    ]),
    budget_context?,
  )
  new_pptx_source_parse_context(@ox.open_ooxml_archive(archive))
}

///|
async fn presentation_cursor_observe(
  body : String,
) -> Array[(String, String?, Bool, String)] {
  let ctx = presentation_cursor_fixture(@utf8.encode(body))
  let graph = build_pptx_part_graph(ctx)
  parse_source_presentation(ctx, graph).slide_refs.map(value => {
    (value.part_name, value.slide_id, value.hidden, value.source_key.node_key)
  })
}

///|
async test "presentation cursor ignores comment slide references" {
  let values = presentation_cursor_observe(
    "<p:presentation><p:sldIdLst><!-- <p:sldId id='258' r:id='rId2'/> -->" +
    "<p:sldId id='257' r:id='rId1'/></p:sldIdLst></p:presentation>",
  )
  assert_eq(values.length(), 1)
  assert_eq(values[0].0, "ppt/slides/slide1.xml")
  assert_eq(values[0].1, Some("257"))
}

///|
async test "presentation cursor keeps quoted greater-than inside opening tag" {
  let values = presentation_cursor_observe(
    "<p:presentation><p:sldId note='a>b' id='257' r:id='rId1'/></p:presentation>",
  )
  assert_eq(values.length(), 1)
  assert_eq(values[0].1, Some("257"))
}

///|
async test "presentation cursor uses exact qualified element and attribute names" {
  let values = presentation_cursor_observe(
    "<p:presentation><p:sldIdLst r:id='rId2'/>" +
    "<p:sldId data-r:id='rId2' id='257' r:id='rId1'/></p:presentation>",
  )
  assert_eq(values.length(), 1)
  assert_eq(values[0].0, "ppt/slides/slide1.xml")
  assert_eq(values[0].1, Some("257"))
}

///|
async test "presentation cursor separates slide id from preceding relationship id" {
  let values = presentation_cursor_observe(
    "<p:presentation><p:sldId r:id='rId1' id='257'/></p:presentation>",
  )
  assert_eq(values.length(), 1)
  assert_eq(values[0].1, Some("257"))
}

///|
async test "presentation cursor accepts XML attribute whitespace" {
  let values = presentation_cursor_observe(
    "<p:presentation><p:sldId id = '257' r:id = 'rId1' show = 'false'/></p:presentation>",
  )
  assert_eq(values.length(), 1)
  assert_eq(values[0].1, Some("257"))
  assert_true(values[0].2)
}

///|
async test "presentation cursor resolves recognized prefixes and rejects rebound unrelated namespace" {
  let values = presentation_cursor_observe(
    "<p:presentation xmlns:p='http://schemas.openxmlformats.org/presentationml/2006/main' " +
    "xmlns:x='http://schemas.openxmlformats.org/presentationml/2006/main' " +
    "xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'>" +
    "<x:sldId id='257' r:id='rId1'/>" +
    "<p:sldId xmlns:p='urn:unrelated' id='258' r:id='rId2'/></p:presentation>",
  )
  assert_eq(values.length(), 1)
  assert_eq(values[0].0, "ppt/slides/slide1.xml")
  assert_eq(values[0].1, Some("257"))
}

///|
async test "presentation cursor preserves ordinary refs hidden values ordering and missing-reference ordinal" {
  let values = presentation_cursor_observe(
    "<p:presentation><p:sldId id='257' r:id='rId1'/>" +
    "<p:sldId id='258' r:id='missing'/><p:sldId id='259' r:id='rId2' show='0'/>" +
    "</p:presentation>",
  )
  assert_eq(values.length(), 2)
  assert_eq(values[0].0, "ppt/slides/slide1.xml")
  assert_false(values[0].2)
  assert_eq(values[1].0, "ppt/slides/slide2.xml")
  assert_eq(values[1].1, Some("259"))
  assert_true(values[1].2)
  assert_true(values[1].3.has_suffix("slide-ref-3"))
}

///|
async test "presentation cursor decodes numeric entities once" {
  let values = presentation_cursor_observe(
    "<p:presentation><p:sldId id='&#50;57' r:id='r&#73;d1' show='fa&#108;se'/></p:presentation>",
  )
  assert_eq(values.length(), 1)
  assert_eq(values[0].1, Some("257"))
  assert_true(values[0].2)
}

///|
async test "presentation cursor ordinary syntax recovery cannot hide tail invalid UTF8" {
  let ctx = presentation_cursor_fixture(
    b"<p:presentation><p:sldId id='257' r:id='rId1'/><broken></wrong></p:presentation>\xff",
  )
  assert_true(
    try {
      ignore(parse_pptx_source(ctx.pkg))
      false
    } catch {
      _ => true
    },
  )
  assert_true(@dzip.archive_hard_failure(ctx.pkg.archive) is Some(_))
}
