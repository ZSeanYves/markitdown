///|
fn docx_integrity_fixture(styles : Bytes?) -> Bytes {
  let entries = [
    (
      "[Content_Types].xml", b"<Types><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>",
    ),
    (
      "_rels/.rels", b"<Relationships><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>",
    ),
    (
      "word/document.xml", b"<w:document><w:body><w:p><w:r><w:t>Body</w:t></w:r></w:p></w:body></w:document>",
    ),
    (
      "word/_rels/document.xml.rels", b"<Relationships><Relationship Id=\"styles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/></Relationships>",
    ),
    ("word/numbering.xml", b"<w:numbering/>"),
  ]
  if styles is Some(bytes) {
    entries.push(("word/styles.xml", bytes))
  }
  @dzip.build_store_zip_bytes(entries)
}

///|
async fn docx_integrity_damage_styles(bytes : Bytes) -> Bytes {
  let slice = @dzip.read_entry_data_slice(
    @dzip.open_zip(bytes),
    "word/styles.xml",
  )
  let damaged = bytes.to_array()
  damaged[slice.data_start] = b'!'
  Bytes::from_array(damaged)
}

///|
async test "standalone DOCX source and document readers reject caught service-part CRC and UTF8 failures" {
  for normalized in [false, true] {
    for corrupt_crc in [true, false] {
      let bytes = if corrupt_crc {
        docx_integrity_damage_styles(
          docx_integrity_fixture(Some(b"<w:styles/>")),
        )
      } else {
        docx_integrity_fixture(Some(b"<w:styles>\xff</w:styles>"))
      }
      let reads = Ref(0)
      let reads_at_failure = Ref(-1)
      let archive = @dzip.open_zip_reader(bytes.length(), fn(offset, length) {
        reads.val += 1
        Ok(bytes[offset:offset + length].to_owned())
      })
      @dzip.set_hard_failure_reporter(archive, _message => {
        reads_at_failure.val = reads.val
      })
      let pkg = @ox.open_ooxml_archive(archive)
      let failed = try {
        if normalized {
          ignore(parse_docx_document_from_package(pkg))
        } else {
          ignore(parse_docx_source_from_package(pkg))
        }
        false
      } catch {
        _ => true
      }
      assert_true(failed)
      assert_true(@dzip.archive_hard_failure(archive) is Some(_))
      assert_eq(reads.val, reads_at_failure.val)
      let warnings : Array[DocxSourceWarning] = []
      assert_true(
        read_docx_service_part_text(
          pkg,
          "word/numbering.xml",
          MissingNumberingPart,
          "missing: ",
          warnings,
        )
        is None,
      )
      assert_eq(reads.val, reads_at_failure.val)
    }
  }
}

///|
async test "standalone DOCX retains missing and malformed optional style recovery" {
  for styles in [None, Some(b"<w:styles><w:style")] {
    let archive = @dzip.open_zip(docx_integrity_fixture(styles))
    let document = parse_docx_document_from_package(
      @ox.open_ooxml_archive(archive),
    )
    assert_true(document.body.length() > 0)
    assert_true(@dzip.archive_hard_failure(archive) is None)
  }
}
