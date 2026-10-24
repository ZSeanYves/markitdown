///|
async test "paragraph projection preserves legacy first attributes and empty run keys" {
  let xml = "<w:document><w:body><w:p><w:pPr><w:pStyle/><w:pStyle w:val='ignored'/>" +
    "<w:jc w:val='center'/><w:ilvl w:val='2'/><w:numId w:val='7'/></w:pPr>" +
    "<w:r/><w:r><w:rPr><w:rStyle w:val='Strong'/><w:bCs w:val='0'/></w:rPr>" +
    "<w:t>A&amp;B</w:t></w:r><w:r><w:rPr><w:rStyle/><w:rStyle w:val='ignored'/></w:rPr>" +
    "<w:t>C</w:t></w:r></w:p></w:body></w:document>"
  let doc = parse_docx_source_document_xml("word/document.xml", xml)
  let block = doc.parts[0].blocks[0]
  assert_eq(block.paragraph_style_id, None)
  assert_eq(block.paragraph_alignment, Some("center"))
  assert_eq(block.numbering_ref.unwrap().num_id, "7")
  assert_eq(block.numbering_ref.unwrap().ilvl, Some("2"))
  assert_eq(block.text, "A&BC")
  assert_eq(block.runs.length(), 2)
  assert_eq(block.runs[0].source_key.node_key, "word/document.xml:p:0:r:1")
  assert_eq(block.runs[0].style_id, Some("Strong"))
  assert_true(block.runs[0].bold)
  assert_eq(block.runs[1].style_id, None)
  assert_true(!block.runs[1].bold)
}

///|
async test "paragraph projection preserves raw inline helper handoff and UTF16 source indices" {
  let xml = "<w:document><w:body><w:p><w:r><w:t>😀\r\n&amp;lt;</w:t></w:r>" +
    "<w:hyperlink w:anchor='target'><w:r><w:t>link&amp;amp;</w:t></w:r></w:hyperlink>" +
    "<w:fldSimple w:instr='DATE'><w:r><w:t>field</w:t></w:r></w:fldSimple>" +
    "<w:sdt><w:sdtContent><w:r><w:t>sdt</w:t></w:r></w:sdtContent></w:sdt>" +
    "<w:smartTag><w:r><w:t>smart</w:t></w:r></w:smartTag>" +
    "<m:oMath><m:r><m:t>x</m:t></m:r></m:oMath>" +
    "<w:bookmarkStart w:id='1' w:name='mark'/></w:p></w:body></w:document>"
  let doc = parse_docx_source_document_xml("word/document.xml", xml)
  let block = doc.parts[0].blocks[0]
  assert_eq(block.runs.length(), 7)
  assert_eq(docx_source_inline_text(block.runs[0].inlines), "😀\r\n&lt;")
  assert_eq(docx_source_inline_text(block.runs[1].inlines), "link&amp;")
  assert_eq(docx_source_inline_text(block.runs[2].inlines), "field")
  assert_eq(docx_source_inline_text(block.runs[3].inlines), "sdt")
  assert_eq(docx_source_inline_text(block.runs[4].inlines), "smart")
  assert_eq(
    block.runs[1].source_key.node_key,
    "word/document.xml:p:0:hyperlink:1",
  )
  assert_eq(
    block.runs[6].source_key.node_key,
    "word/document.xml:p:0:bookmark:6",
  )
}

///|
async test "paragraph projection shares table cell and ordinary paragraph contracts" {
  let paragraph = "<w:p><w:pPr><w:pStyle w:val='Body'/></w:pPr>" +
    "<w:r><w:rPr><w:b w:val='0'/></w:rPr><w:t>same</w:t></w:r></w:p>"
  let doc = parse_docx_source_document_xml(
    "word/document.xml",
    "<w:document><w:body>" +
    paragraph +
    "<w:tbl><w:tr><w:tc>" +
    paragraph +
    "</w:tc></w:tr></w:tbl></w:body></w:document>",
  )
  let ordinary = doc.parts[0].blocks[0]
  let cell = doc.parts[0].blocks[1].table.unwrap().rows[0].cells[0].blocks[0]
  assert_eq(ordinary.text, cell.text)
  assert_eq(ordinary.paragraph_style_id, cell.paragraph_style_id)
  assert_true(ordinary.runs[0].bold && cell.runs[0].bold)
  assert_eq(
    cell.runs[0].source_key.node_key,
    "word/document.xml:tbl:1:row:0:cell:0:p:0:r:0",
  )
}
