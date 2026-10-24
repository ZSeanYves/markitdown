///|
async test "paragraph property discovery ignores comment fake tags" {
  let doc = parse_docx_source_document_xml(
    "word/document.xml",
    "<w:document><w:body><w:p>" +
    "<w:pPr><!-- <w:pStyle w:val='fake'/> --><w:pStyle w:val='real'/></w:pPr>" +
    "<w:r><w:rPr><!-- <w:b/> --></w:rPr><w:t>body</w:t></w:r></w:p></w:body></w:document>",
  )
  let block = doc.parts[0].blocks[0]
  assert_eq(block.paragraph_style_id, Some("real"))
  assert_true(!block.runs[0].bold)
}

///|
async test "paragraph property discovery is quote aware and decodes attribute once" {
  let doc = parse_docx_source_document_xml(
    "word/document.xml",
    "<w:document><w:body><w:p>" +
    "<w:pPr><w:pStyle note='>' w:val='A&amp;quot;&#x1F600;'/></w:pPr>" +
    "<w:r><w:rPr><w:rStyle note='>' w:val='R&amp;quot;'/></w:rPr><w:t>raw</w:t></w:r>" +
    "</w:p></w:body></w:document>",
  )
  let block = doc.parts[0].blocks[0]
  assert_eq(block.paragraph_style_id, Some("A&quot;😀"))
  assert_eq(block.runs[0].style_id, Some("R&quot;"))
  assert_eq(block.text, "raw")
}

///|
async test "malformed paragraph grammar preserves only completed semantic prefix" {
  let doc = parse_docx_source_document_xml(
    "word/document.xml",
    "<w:document><w:body><w:p>" +
    "<w:r><w:t>prior</w:t></w:r><w:unknown></w:wrong><w:r><w:t>after</w:t></w:r>" +
    "</w:p></w:body></w:document>",
  )
  assert_eq(doc.parts[0].blocks[0].text, "prior")
  assert_eq(doc.parts[0].blocks[0].runs.length(), 1)
}

///|
async test "paragraph property character references decode once independently of quote handling" {
  let doc = parse_docx_source_document_xml(
    "word/document.xml",
    "<w:document><w:body><w:p>" +
    "<w:pPr><w:pStyle w:val='&amp;quot;&#x1F600;'/></w:pPr>" +
    "<w:r><w:t>body</w:t></w:r></w:p></w:body></w:document>",
  )
  assert_eq(doc.parts[0].blocks[0].paragraph_style_id, Some("&quot;😀"))
}
