///|
test "ODF repeated row and column counts enforce bounded positive values" {
  assert_eq(odf_parse_repeated_count(None, "table:number-rows-repeated"), 1)
  assert_eq(
    odf_parse_repeated_count(Some("1048576"), "table:number-rows-repeated"),
    1_048_576,
  )
  assert_eq(
    odf_parse_repeated_count(Some(" 3 "), "table:number-rows-repeated"),
    3,
  )
  assert_eq(
    odf_parse_repeated_count(Some("16384"), "table:number-columns-repeated"),
    16_384,
  )
  for
    pair in [
      (Some("0"), "table:number-rows-repeated"),
      (Some("-1"), "table:number-rows-repeated"),
      (Some("1048577"), "table:number-rows-repeated"),
      (Some("16385"), "table:number-columns-repeated"),
      (Some("invalid"), "table:number-columns-repeated"),
    ] {
    let failed = try {
      ignore(odf_parse_repeated_count(pair.0, pair.1))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
test "ODS extracts sheet-local drawing images and package bytes" {
  let content =
    #|<office:document-content><office:body><office:spreadsheet>
    #|  <table:table table:name="Images">
    #|    <draw:frame draw:name="Chart image"><draw:image xlink:href="Pictures/chart.png"/></draw:frame>
    #|  </table:table>
    #|</office:spreadsheet></office:body></office:document-content>
  let image = Bytes::from_array([(0x89).to_byte(), (0x50).to_byte()])
  let bytes = @therm.build_store_zip_bytes([
    ("mimetype", @utf8.encode(ODF_MIMETYPE_ODS)),
    (
      "META-INF/manifest.xml",
      @utf8.encode(
        "<manifest:manifest><manifest:file-entry manifest:full-path=\"Pictures/chart.png\" manifest:media-type=\"image/png\"/></manifest:manifest>",
      ),
    ),
    ("content.xml", @utf8.encode(content)),
    ("Pictures/chart.png", image),
  ])
  let document = open_ods_document(bytes)
  assert_eq(document.sheets.length(), 1)
  assert_eq(document.sheets[0].images.length(), 1)
  assert_eq(document.assets.length(), 1)
  assert_true(document.assets[0].href == "Pictures/chart.png")
  assert_true(document.assets[0].bytes.unwrap().to_array() == image.to_array())
}

///|
test "ODP groups preserve nested frame reading order and depth" {
  let content =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<office:document-content>
    #|  <office:body><office:presentation>
    #|    <draw:page draw:name="Grouped">
    #|      <draw:g>
    #|        <draw:frame><draw:text-box><text:h>First</text:h></draw:text-box></draw:frame>
    #|        <draw:g><draw:frame><draw:text-box><text:p>Second</text:p></draw:text-box></draw:frame></draw:g>
    #|        <draw:frame><draw:object xlink:href="./Object 1"/></draw:frame>
    #|      </draw:g>
    #|    </draw:page>
    #|  </office:presentation></office:body>
    #|</office:document-content>
  let bytes = @therm.build_store_zip_bytes([
    ("mimetype", @utf8.encode(ODF_MIMETYPE_ODP)),
    ("META-INF/manifest.xml", @utf8.encode("<manifest:manifest/>")),
    ("content.xml", @utf8.encode(content)),
    (
      "Object 1/content.xml",
      @utf8.encode(
        "<office:document-content><office:body><chart:chart><chart:title><text:p>Revenue 2026</text:p></chart:title></chart:chart></office:body></office:document-content>",
      ),
    ),
  ])
  let document = open_odp_document(bytes)
  assert_eq(document.slides.length(), 1)
  let blocks = document.slides[0].blocks
  assert_true(blocks.any(block => block.text == "First"))
  assert_true(blocks.any(block => block.text == "Second"))
  let first = blocks.filter(block => block.text == "First")[0]
  let second = blocks.filter(block => block.text == "Second")[0]
  assert_true(first.attrs.get("group_depth") == Some("1"))
  assert_true(second.attrs.get("group_depth") == Some("2"))
  let chart = blocks.filter(block => block.text.contains("Revenue 2026"))[0]
  assert_true(chart.attrs.get("semantic_kind") == Some("chart_text"))
}

///|
test "ODT repeated spaces rows and cells expand within materialization limits" {
  let content =
    #|<office:document-content><office:body><office:text>
    #|  <text:p>A<text:s text:c="3"/>B</text:p>
    #|  <table:table><table:table-row table:number-rows-repeated="2">
    #|    <table:table-cell table:number-columns-repeated="2"><text:p>X</text:p></table:table-cell>
    #|  </table:table-row></table:table>
    #|</office:text></office:body></office:document-content>
  let bytes = @therm.build_store_zip_bytes([
    ("mimetype", @utf8.encode(ODF_MIMETYPE_ODT)),
    ("META-INF/manifest.xml", @utf8.encode("<manifest:manifest/>")),
    ("content.xml", @utf8.encode(content)),
  ])
  let document = open_odt_document(bytes)
  assert_true(document.blocks.any(block => block.text == "A   B"))
  let table = document.blocks.filter(block => block.kind == OdtBlockKind::Table)[0]
  assert_eq(table.rows.length(), 2)
  assert_eq(table.rows[0].cells.length(), 2)
  assert_true(table.rows[0].cells.all(cell => cell.text == "X"))
}

///|
test "ODT paragraph styles inherit heading and code semantics" {
  let content =
    #|<office:document-content><office:automatic-styles>
    #|  <style:style style:name="ChildHeading" style:family="paragraph" style:parent-style-name="HeadingBase"/>
    #|  <style:style style:name="ChildCode" style:family="paragraph" style:parent-style-name="CodeBase"/>
    #|</office:automatic-styles><office:body><office:text>
    #|  <text:p text:style-name="ChildHeading">Inherited heading</text:p>
    #|  <text:p text:style-name="ChildCode">let value = 1</text:p>
    #|</office:text></office:body></office:document-content>
  let styles =
    #|<office:document-styles><office:styles>
    #|  <style:style style:name="HeadingBase" style:display-name="Heading 2" style:family="paragraph"/>
    #|  <style:style style:name="CodeBase" style:display-name="Source Code" style:family="paragraph"/>
    #|</office:styles></office:document-styles>
  let bytes = @therm.build_store_zip_bytes([
    ("mimetype", @utf8.encode(ODF_MIMETYPE_ODT)),
    ("META-INF/manifest.xml", @utf8.encode("<manifest:manifest/>")),
    ("content.xml", @utf8.encode(content)),
    ("styles.xml", @utf8.encode(styles)),
  ])
  let document = open_odt_document(bytes)
  let heading = document.blocks.filter(block => {
      block.text == "Inherited heading"
    })[0]
  assert_true(heading.kind == OdtBlockKind::Heading)
  assert_true(heading.level == Some(2))
  let code = document.blocks.filter(block => block.text == "let value = 1")[0]
  assert_true(code.kind == OdtBlockKind::Code)
}
