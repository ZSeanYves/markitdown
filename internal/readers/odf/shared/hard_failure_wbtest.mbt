///|
fn odf_integrity_fixture(kind : String, metadata : Bytes?) -> Bytes {
  let body = match kind {
    "text" => "<office:text><text:p>Body</text:p></office:text>"
    "spreadsheet" =>
      "<office:spreadsheet><table:table table:name=\"Body\"/></office:spreadsheet>"
    _ =>
      "<office:presentation><draw:page draw:name=\"Body\"/></office:presentation>"
  }
  let entries = [
    ("mimetype", @utf8.encode("application/vnd.oasis.opendocument." + kind)),
    ("META-INF/manifest.xml", b"<manifest:manifest/>"),
    (
      "content.xml",
      @utf8.encode(
        "<office:document-content><office:body>" +
        body +
        "</office:body></office:document-content>",
      ),
    ),
    ("styles.xml", b"<office:document-styles/>"),
  ]
  if metadata is Some(bytes) {
    entries.push(("meta.xml", bytes))
  }
  @dzip.build_store_zip_bytes(entries)
}

///|
async fn odf_integrity_damage_metadata(bytes : Bytes) -> Bytes {
  let archive = @dzip.open_zip(bytes)
  let slice = @dzip.read_entry_data_slice(archive, "meta.xml")
  let damaged = bytes.to_array()
  damaged[slice.data_start] = b'!'
  Bytes::from_array(damaged)
}

///|
async fn odf_integrity_open(archive : @dzip.ZipArchive, kind : String) -> Unit {
  match kind {
    "text" => ignore(open_odt_archive(archive))
    "spreadsheet" => ignore(open_ods_archive(archive))
    _ => ignore(open_odp_archive(archive))
  }
}

///|
async test "standalone ODF readers reject caught metadata CRC and UTF8 failures without further I/O" {
  for kind in ["text", "spreadsheet", "presentation"] {
    for corrupt_crc in [true, false] {
      let bytes = if corrupt_crc {
        odf_integrity_damage_metadata(
          odf_integrity_fixture(
            kind,
            Some(b"<meta><title>Title</title></meta>"),
          ),
        )
      } else {
        odf_integrity_fixture(kind, Some(b"<meta>\xff</meta>"))
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
      let failed = try {
        odf_integrity_open(archive, kind)
        false
      } catch {
        _ => true
      }
      assert_true(failed)
      let first = @dzip.archive_hard_failure(archive).unwrap()
      assert_eq(reads.val, reads_at_failure.val)
      let failed_again = try {
        odf_integrity_open(archive, kind)
        false
      } catch {
        _ => true
      }
      assert_true(failed_again)
      assert_eq(@dzip.archive_hard_failure(archive), Some(first))
      assert_eq(reads.val, reads_at_failure.val)
    }
  }
}

///|
async test "standalone ODF readers preserve missing and syntactically malformed optional metadata recovery" {
  for kind in ["text", "spreadsheet", "presentation"] {
    for metadata in [None, Some(b"<meta><broken>")] {
      let archive = @dzip.open_zip(odf_integrity_fixture(kind, metadata))
      odf_integrity_open(archive, kind)
      assert_true(@dzip.archive_hard_failure(archive) is None)
    }
  }
}
