///|
fn relationship_integrity_payload(invalid_utf8 : Bool) -> Bytes {
  b"<Wrong>" +
  Bytes::from_array(Array::make(70000, b' ')) +
  (if invalid_utf8 { b"\xff" } else { b"" }) +
  b"</Wrong>"
}

///|
async fn relationship_integrity_document(
  format : String,
  rels : Bytes,
  corrupt_crc : Bool,
) -> Bytes {
  let rels_path = if format == "docx" {
    "word/_rels/footnotes.xml.rels"
  } else {
    "ppt/slides/_rels/slide1.xml.rels"
  }
  let entries = if format == "docx" {
    [
      (
        "[Content_Types].xml", b"<Types><Default Extension='xml' ContentType='application/xml'/><Override PartName='/word/document.xml' ContentType='application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'/></Types>",
      ),
      (
        "_rels/.rels", b"<Relationships><Relationship Id='main' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument' Target='word/document.xml'/></Relationships>",
      ),
      (
        "word/document.xml", b"<w:document><w:body><w:p><w:r><w:t>Body</w:t></w:r></w:p></w:body></w:document>",
      ),
      (
        "word/_rels/document.xml.rels", b"<Relationships><Relationship Id='notes' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes' Target='footnotes.xml'/></Relationships>",
      ),
      (
        "word/footnotes.xml", b"<w:footnotes><w:footnote w:id='1'><w:p><w:r><w:t>Note</w:t></w:r></w:p></w:footnote></w:footnotes>",
      ),
      (rels_path, rels),
    ]
  } else {
    [
      (
        "[Content_Types].xml", b"<Types><Default Extension='xml' ContentType='application/xml'/><Override PartName='/ppt/presentation.xml' ContentType='application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml'/><Override PartName='/ppt/slides/slide1.xml' ContentType='application/vnd.openxmlformats-officedocument.presentationml.slide+xml'/></Types>",
      ),
      (
        "_rels/.rels", b"<Relationships><Relationship Id='main' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument' Target='ppt/presentation.xml'/></Relationships>",
      ),
      (
        "ppt/presentation.xml", b"<p:presentation><p:sldIdLst><p:sldId id='256' r:id='s1'/></p:sldIdLst></p:presentation>",
      ),
      (
        "ppt/_rels/presentation.xml.rels", b"<Relationships><Relationship Id='s1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide' Target='slides/slide1.xml'/></Relationships>",
      ),
      (
        "ppt/slides/slide1.xml", b"<p:sld><p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>Body</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>",
      ),
      (rels_path, rels),
    ]
  }
  let raw = @dzip.build_store_zip_bytes(entries)
  if !corrupt_crc {
    return raw
  }
  let slice = @dzip.read_entry_data_slice(@dzip.open_zip(raw), rels_path)
  let damaged = raw.to_array()
  damaged[slice.data_start + 65537] = b'\t'
  Bytes::from_array(damaged)
}

///|
async fn relationship_integrity_rejected(
  raw : Bytes,
  format : String,
) -> (Bool, Bool, Int32, Int32) {
  let input = @lib.Input::from_bytes(raw, source_name="relations." + format)
  let options = @lib.ConvertOptions::default().with_format_hint(Some(format))
  let collected = match @lib.convert(input, options~) {
    Err(@lib.ConvertError::DetectionFailed(_)) | Err(@lib.ParseFailed(_)) =>
      true
    _ => false
  }
  let writes = Ref(0)
  let finishes = Ref(0)
  let streamed = match
    @lib.convert_to_sink(
      input,
      @lib.OutputSink::new(
        _fragment => {
          writes.val += 1
          Ok(())
        },
        () => {
          finishes.val += 1
          Ok(())
        },
      ),
      options~,
    ) {
    Err(@lib.ConvertError::DetectionFailed(_)) | Err(@lib.ParseFailed(_)) =>
      true
    _ => false
  }
  (collected, streamed, writes.val, finishes.val)
}

///|
async test "public DOCX footnote and PPTX slide relationship syntax recovery retains valid body" {
  for format in ["docx", "pptx"] {
    let raw = relationship_integrity_document(format, b"<Wrong/>", false)
    let input = @lib.Input::from_bytes(raw, source_name="recover." + format)
    let options = @lib.ConvertOptions::default().with_format_hint(Some(format))
    let result = @lib.convert(input, options~).unwrap()
    assert_true(result.content.contains("Body"))
  }
}

///|
async test "public DOCX footnote and PPTX slide recovery cannot hide tail UTF8 or CRC failures" {
  let observed : Array[(String, Bool, Bool, Int32, Int32)] = []
  for format in ["docx", "pptx"] {
    for invalid_utf8 in [true, false] {
      let raw = relationship_integrity_document(
        format,
        relationship_integrity_payload(invalid_utf8),
        !invalid_utf8,
      )
      let (collected, streamed, writes, finishes) = relationship_integrity_rejected(
        raw, format,
      )
      observed.push((format, collected, streamed, writes, finishes))
    }
  }
  assert_eq(observed, [
    ("docx", true, true, 0, 0),
    ("docx", true, true, 0, 0),
    ("pptx", true, true, 0, 0),
    ("pptx", true, true, 0, 0),
  ])
}

///|
async test "nested ZIP cannot turn a child optional relationship hard failure into skipped success" {
  let observed : Array[(String, Bool, Bool, Int32, Int32)] = []
  for format in ["docx", "pptx"] {
    for invalid_utf8 in [true, false] {
      let child = relationship_integrity_document(
        format,
        relationship_integrity_payload(invalid_utf8),
        !invalid_utf8,
      )
      let raw = @dzip.build_store_zip_bytes([("child." + format, child)])
      let (collected, streamed, writes, finishes) = relationship_integrity_rejected(
        raw, "zip",
      )
      observed.push((format, collected, streamed, writes, finishes))
    }
  }
  assert_eq(observed, [
    ("docx", true, true, 0, 0),
    ("docx", true, true, 0, 0),
    ("pptx", true, true, 0, 0),
    ("pptx", true, true, 0, 0),
  ])
}
