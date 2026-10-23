///|
fn pptx_integrity_fixture(presentation : Bytes?) -> Bytes {
  let entries = [
    (
      "[Content_Types].xml", b"<Types><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>",
    ),
  ]
  if presentation is Some(bytes) {
    entries.push(("ppt/presentation.xml", bytes))
  }
  @dzip.build_store_zip_bytes(entries)
}

///|
async fn pptx_integrity_damage_presentation(bytes : Bytes) -> Bytes {
  let slice = @dzip.read_entry_data_slice(
    @dzip.open_zip(bytes),
    "ppt/presentation.xml",
  )
  let damaged = bytes.to_array()
  damaged[slice.data_start] = b'!'
  Bytes::from_array(damaged)
}

///|
async test "standalone PPTX source and document readers reject caught presentation CRC and UTF8 failures" {
  for normalized in [false, true] {
    for corrupt_crc in [true, false] {
      let bytes = if corrupt_crc {
        pptx_integrity_damage_presentation(
          pptx_integrity_fixture(Some(b"<p:presentation/>")),
        )
      } else {
        pptx_integrity_fixture(Some(b"<p:presentation>\xff</p:presentation>"))
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
          ignore(parse_pptx_document_from_package(pkg))
        } else {
          ignore(parse_pptx_source(pkg))
        }
        false
      } catch {
        _ => true
      }
      assert_true(failed)
      assert_true(@dzip.archive_hard_failure(archive) is Some(_))
      assert_eq(reads.val, reads_at_failure.val)
      let ctx = new_pptx_source_parse_context(pkg)
      assert_true(read_source_part_text(ctx, "ppt/presentation.xml") is None)
      assert_eq(reads.val, reads_at_failure.val)
    }
  }
}

///|
async test "standalone PPTX retains missing and malformed optional presentation recovery" {
  for presentation in [None, Some(b"<p:presentation><p:sldId")] {
    let archive = @dzip.open_zip(pptx_integrity_fixture(presentation))
    let document = parse_pptx_document_from_package(
      @ox.open_ooxml_archive(archive),
    )
    assert_eq(document.slides.length(), 0)
    assert_true(@dzip.archive_hard_failure(archive) is None)
  }
}
