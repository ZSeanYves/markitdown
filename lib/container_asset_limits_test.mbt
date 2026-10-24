///|
async test "ZIP standalone asset obeys the public payload ceiling" {
  office_asset_limit_case(
    "samples/fixtures/contracts/zip/zip_assets_namespace.zip", "zip",
  )
}

///|
async test "ZIP referenced HTML asset obeys the public payload ceiling" {
  office_asset_limit_case(
    "samples/fixtures/contracts/zip/zip_html_local_image.zip", "zip",
  )
}

///|
async test "EPUB cover obeys the public payload ceiling" {
  office_asset_limit_case(
    "samples/fixtures/contracts/epub/epub_cover_image.epub", "epub",
  )
}

///|
async test "EPUB chapter asset obeys the public payload ceiling" {
  office_asset_limit_case(
    "samples/fixtures/contracts/epub/epub_local_image_basic.epub", "epub",
  )
}

///|
fn container_asset_zip_fixture(padded~ : Bool = false) -> Bytes {
  let entries : Array[(String, Bytes)] = [
    (
      "a.html", b"<html><body><p>first</p><img src=\"images/a.png\"/></body></html>",
    ),
    (
      "b.html", b"<html><body><p>second</p><img src=\"images/b.png\"/></body></html>",
    ),
  ]
  if padded {
    entries.push(("before.bin", Bytes::make(70 * 1024, b' ')))
  }
  entries.push(("images/a.png", b"asset-A"))
  entries.push(("images/b.png", b"asset-B"))
  if padded {
    entries.push(("after.bin", Bytes::make(70 * 1024, b' ')))
  }
  @dzip.build_store_zip_bytes(entries)
}

///|
fn container_asset_epub_fixture(
  cover~ : Bool = false,
  chapter~ : Bytes = b"<html><body><p>body<img src=\"images/a.png\"/></p></body></html>",
  nav~ : Bytes? = None,
) -> Bytes {
  let opf = if cover {
    b"<package><metadata><title>book</title></metadata><manifest><item id=\"ch\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/><item id=\"img\" href=\"images/a.png\" media-type=\"image/png\" properties=\"cover-image\"/></manifest><spine><itemref idref=\"ch\"/></spine></package>"
  } else if nav is Some(_) {
    b"<package><metadata/><manifest><item id=\"ch\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/><item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/><item id=\"img\" href=\"images/a.png\" media-type=\"image/png\"/></manifest><spine><itemref idref=\"ch\"/></spine></package>"
  } else {
    b"<package><metadata/><manifest><item id=\"ch\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/><item id=\"img\" href=\"images/a.png\" media-type=\"image/png\"/></manifest><spine><itemref idref=\"ch\"/></spine></package>"
  }
  let entries : Array[(String, Bytes)] = [
    ("mimetype", b"application/epub+zip"),
    (
      "META-INF/container.xml", b"<container><rootfiles><rootfile full-path=\"OPS/book.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>",
    ),
    ("OPS/book.opf", opf),
    ("OPS/chapter.xhtml", chapter),
    ("OPS/images/a.png", b"asset-A"),
  ]
  if nav is Some(bytes) {
    entries.push(("OPS/nav.xhtml", bytes))
  }
  @dzip.build_store_zip_bytes(entries)
}

///|
fn container_asset_find_bytes(raw : Bytes, needle : Bytes) -> Int32 {
  for start in 0..<(raw.length() - needle.length() + 1) {
    let mut matched = true
    for index in 0..<needle.length() {
      if raw[start + index] != needle[index] {
        matched = false
        break
      }
    }
    if matched {
      return start
    }
  }
  -1
}

///|
async test "container assets retain validated payloads at the exact single and total boundaries" {
  for
    (format, raw, expected_total) in [
      ("zip", container_asset_zip_fixture(), 14L),
      ("epub", container_asset_epub_fixture(), 7L),
      (
        "epub",
        container_asset_epub_fixture(
          cover=true,
          chapter=b"<html><body>cover only</body></html>",
        ),
        7L,
      ),
    ] {
    let options = @lib.ConvertOptions::default()
      .with_format_hint(Some(format))
      .with_limits(
        @lib.ResourceLimits::default()
        .with_max_asset_bytes(7L)
        .with_max_total_asset_bytes(expected_total),
      )
    let input = @lib.Input::from_bytes(raw, source_name="book." + format)
    let result = @lib.convert(input, options~).unwrap()
    let mut total = 0L
    for asset in result.assets {
      match asset.payload {
        Some(Bytes(bytes)) => total += bytes.length().to_int64()
        _ => fail("container asset must own its validated bytes")
      }
    }
    assert_eq(total, expected_total)
    let fragments : Array[String] = []
    let summary = @lib.convert_to_sink(
      input,
      @lib.OutputSink::new(
        fragment => {
          fragments.push(fragment)
          Ok(())
        },
        () => Ok(()),
      ),
      options~,
    ).unwrap()
    assert_eq(fragments.join(""), result.content)
    assert_eq(summary.assets.length(), result.assets.length())
  }
}

///|
async test "ZIP sibling children reject cumulative assets before the second payload read" {
  let raw = container_asset_zip_fixture(padded=true)
  let second_offset = container_asset_find_bytes(raw, b"asset-B")
  assert_true(second_offset >= 70 * 1024)
  let second_reads = Ref(0)
  let writes = Ref(0)
  let finishes = Ref(0)
  let input = @lib.Input::from_async_reader(
    async fn(offset, length) {
      @async.pause()
      let start = offset.to_int()
      let end = (start + length).min(raw.length())
      if start < second_offset + 7 && end > second_offset {
        second_reads.val += 1
      }
      Ok(raw.exact_view(start~, end~).to_owned())
    },
    source_name="siblings.zip",
    size=raw.length().to_int64(),
  )
  let options = @lib.ConvertOptions::default()
    .with_format_hint(Some("zip"))
    .with_limits(
      @lib.ResourceLimits::default()
      .with_max_asset_bytes(7L)
      .with_max_total_asset_bytes(13L),
    )
  let result = @lib.convert_to_sink(
    input,
    @lib.OutputSink::new(
      _ => {
        writes.val += 1
        Ok(())
      },
      () => {
        finishes.val += 1
        Ok(())
      },
    ),
    options~,
  )
  match result {
    Err(ResourceLimitExceeded(kind~, observed~, limit~)) =>
      assert_eq((kind, observed, limit), ("total_asset_bytes", 14L, 13L))
    _ => fail("individually valid sibling assets must share the parent total")
  }
  assert_eq((second_reads.val, writes.val, finishes.val), (0, 0, 0))
}

///|
async test "nested Office child asset totals retain the parent error domain" {
  let inner = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
  )
  let raw = @dzip.build_store_zip_bytes([("a.docx", inner), ("b.docx", inner)])
  let input = @lib.Input::from_bytes(raw, source_name="nested.zip")
  let baseline = @lib.convert(input).unwrap()
  assert_eq(baseline.assets.length(), 2)
  let inner_archive = @dzip.open_zip(inner)
  let media = @dzip.list_entries(inner_archive).filter(entry => {
    !entry.is_directory && entry.name.has_prefix("word/media/")
  })
  assert_eq(media.length(), 1)
  let single = media[0].uncompressed_size.to_int64()
  let total = 2L * single
  let options = @lib.ConvertOptions::default()
    .with_format_hint(Some("zip"))
    .with_limits(
      @lib.ResourceLimits::default()
      .with_max_asset_bytes(single)
      .with_max_total_asset_bytes(total - 1L),
    )
  match @lib.convert(input, options~) {
    Err(ResourceLimitExceeded(kind~, observed~, limit~)) =>
      assert_eq(
        (kind, observed, limit),
        ("total_asset_bytes", total, total - 1L),
      )
    _ => fail("nested asset accounting must not reset the parent total")
  }
  for asset in baseline.assets {
    match asset.payload {
      Some(Bytes(bytes)) => assert_eq(bytes.length().to_int64(), single)
      _ => fail("nested validated payload must remain on the original asset")
    }
  }
}

///|
async test "nested assets retain their own payload when the outer ZIP has a matching path" {
  let inner = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
  )
  let archive = @dzip.open_zip(inner)
  let media = @dzip.list_entries(archive).filter(entry => {
    !entry.is_directory && entry.name.has_prefix("word/media/")
  })
  assert_eq(media.length(), 1)
  let expected = @dzip.read_entry(archive, media[0].name)
  let baseline = @lib.convert(
    @lib.Input::from_bytes(
      @dzip.build_store_zip_bytes([("nested.docx", inner)]),
      source_name="shadow.zip",
    ),
  ).unwrap()
  assert_eq(baseline.assets.length(), 1)
  let result = @lib.convert(
    @lib.Input::from_bytes(
      @dzip.build_store_zip_bytes([
        ("nested.docx", inner),
        (media[0].name, b"outer-shadow"),
      ]),
      source_name="shadow.zip",
    ),
  ).unwrap()
  let nested = result.assets.filter(asset => asset.id == baseline.assets[0].id)
  assert_eq(nested.length(), 1)
  assert_eq(nested[0].path, baseline.assets[0].path)
  assert_eq(
    nested[0].attrs.get("zip_nested_archive_entry_path"),
    Some("nested.docx"),
  )
  assert_eq(
    nested[0].attrs.get("zip_nested_asset_entry_path"),
    Some(media[0].name),
  )
  match nested[0].payload {
    Some(Bytes(bytes)) => assert_eq(bytes, expected)
    _ => fail("nested payload must not be replaced by an unrelated outer entry")
  }
}

///|
async test "container delayed assets validate CRC before publishing or writing" {
  let observed : Array[(String, Bool, Bool, Int32, Int32)] = []
  for
    (format, raw) in [
      ("zip", container_asset_zip_fixture()),
      ("epub", container_asset_epub_fixture(cover=true)),
    ] {
    let corrupt = raw.to_array()
    let offset = container_asset_find_bytes(raw, b"asset-A")
    assert_true(offset >= 0)
    corrupt[offset] = b'X'
    let input = @lib.Input::from_bytes(
      Bytes::from_array(corrupt),
      source_name="bad." + format,
    )
    let options = @lib.ConvertOptions::default().with_format_hint(Some(format))
    let collect_rejected = @lib.convert(input, options~) is Err(_)
    let writes = Ref(0)
    let finishes = Ref(0)
    let sink_rejected = @lib.convert_to_sink(
        input,
        @lib.OutputSink::new(
          _ => {
            writes.val += 1
            Ok(())
          },
          () => {
            finishes.val += 1
            Ok(())
          },
        ),
        options~,
      )
      is Err(_)
    observed.push(
      (format, collect_rejected, sink_rejected, writes.val, finishes.val),
    )
  }
  assert_eq(observed, [("zip", true, true, 0, 0), ("epub", true, true, 0, 0)])
}

///|
async test "EPUB chapter and optional navigation encoding errors cannot become successful recovery" {
  let observed : Array[(Bool, Bool, Int32, Int32)] = []
  for
    raw in [
      container_asset_epub_fixture(chapter=b"<html><body>\xFF</body></html>"),
      container_asset_epub_fixture(nav=Some(b"<html><body>\xFF</body></html>")),
    ] {
    let input = @lib.Input::from_bytes(raw, source_name="bad.epub")
    let options = @lib.ConvertOptions::default().with_format_hint(Some("epub"))
    let collect_rejected = @lib.convert(input, options~) is Err(_)
    let writes = Ref(0)
    let finishes = Ref(0)
    let sink_rejected = @lib.convert_to_sink(
        input,
        @lib.OutputSink::new(
          _ => {
            writes.val += 1
            Ok(())
          },
          () => {
            finishes.val += 1
            Ok(())
          },
        ),
        options~,
      )
      is Err(_)
    observed.push((collect_rejected, sink_rejected, writes.val, finishes.val))
  }
  assert_eq(observed, [(true, true, 0, 0), (true, true, 0, 0)])
}
