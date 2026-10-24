///|
// XML variants are ASCII here; separate reader contracts cover real UTF8
// scalars and arbitrary byte chunk boundaries.
fn epub_container_public_ascii(text : String) -> Bytes {
  Bytes::makei(text.length(), i => text.code_unit_at(i).to_int().to_byte())
}

///|
fn epub_container_public_fixture(container : String) -> Bytes {
  @dzip.build_store_zip_bytes([
    ("mimetype", b"application/epub+zip"),
    ("META-INF/container.xml", epub_container_public_ascii(container)),
    (
      "OPS/content.opf", b"<package xmlns='http://www.idpf.org/2007/opf' version='3.0'><metadata><title>Container cursor</title></metadata><manifest><item id='c' href='chapter.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='c'/></spine></package>",
    ),
    (
      "OPS/chapter.xhtml", b"<html><body><p>container-public-body</p></body></html>",
    ),
  ])
}

///|
async test "public EPUB container cursor collect and Sink preserve body through quoted attributes namespaces and numeric entities" {
  for
    container in [
      "<container><rootfiles><rootfile note='x>y' full-path='OPS/content.opf'/></rootfiles></container>",
      "<c:container xmlns:c='urn:oasis:names:tc:opendocument:xmlns:container'><c:rootfiles><c:rootfile xmlns:c='urn:foreign' full-path='OPS/poison.opf'/><c:rootfile full-path='OPS/content&#x2e;opf'/></c:rootfiles></c:container>",
    ] {
    let bytes = epub_container_public_fixture(container)
    for mode in [@lib.OutputMode::Markdown, Debug, Rag] {
      let options = @lib.ConvertOptions::default()
        .with_format_hint(Some("epub"))
        .with_output_mode(mode)
      let input = @lib.Input::from_bytes(
        bytes,
        source_name="container-public.epub",
      )
      let collected = @lib.convert(input, options~).unwrap()
      assert_true(collected.content.contains("container-public-body"))
      let fragments : Array[String] = []
      let finishes = Ref(0)
      let summary = @lib.convert_to_sink(
        input,
        @lib.OutputSink::new(
          fn(fragment) {
            fragments.push(fragment)
            Ok(())
          },
          fn() {
            finishes.val += 1
            Ok(())
          },
        ),
        options~,
      ).unwrap()
      let content = fragments.join("")
      assert_eq(finishes.val, 1)
      assert_eq(summary.detected_format, collected.detected_format)
      assert_eq(summary.chunk_count, collected.chunks.length())
      if mode == Markdown {
        assert_eq(content, collected.content)
      } else {
        ignore(@source_json.parse(content))
        assert_true(content.contains("container-public-body"))
      }
    }
  }
}

///|
async test "public EPUB container cursor one-byte async Reader preserves collecting output" {
  let bytes = epub_container_public_fixture(
    "<container><rootfiles><rootfile full-path='OPS/content&#46;opf'/></rootfiles></container>",
  )
  let options = @lib.ConvertOptions::default().with_format_hint(Some("epub"))
  let expected = @lib.convert(
    @lib.Input::from_bytes(bytes, source_name="reader.epub"),
    options~,
  ).unwrap()
  let callbacks = Ref(0)
  let actual = @lib.convert(
    @lib.Input::from_async_reader(
      async fn(offset, length) {
        @async.pause()
        callbacks.val += 1
        let start = offset.to_int()
        Ok(bytes[start:(start + length.min(1)).min(bytes.length())].to_owned())
      },
      size=bytes.length().to_int64(),
      source_name="reader.epub",
    ),
    options~,
  ).unwrap()
  assert_true(callbacks.val > 1)
  assert_eq(actual.content, expected.content)
  assert_eq(actual.assets, expected.assets)
  assert_eq(actual.source_map, expected.source_map)
}

///|
async test "public EPUB malformed mandatory container rejects collect and Sink before output" {
  let options = @lib.ConvertOptions::default().with_format_hint(Some("epub"))
  for
    container in [
      "<container><rootfiles><rootfile full-path='OPS/content.opf'/></rootfiles></container><broken>",
      "<container xmlns='urn:foreign'><rootfiles><rootfile full-path='OPS/content.opf'/></rootfiles></container>",
    ] {
    let input = @lib.Input::from_bytes(
      epub_container_public_fixture(container),
      source_name="invalid-container.epub",
    )
    assert_true(@lib.convert(input, options~) is Err(ParseFailed(_)))
    let writes = Ref(0)
    let finishes = Ref(0)
    let result = @lib.convert_to_sink(
      input,
      @lib.OutputSink::new(
        fn(_fragment) {
          writes.val += 1
          Ok(())
        },
        fn() {
          finishes.val += 1
          Ok(())
        },
      ),
      options~,
    )
    assert_true(result is Err(ParseFailed(_)))
    assert_eq((writes.val, finishes.val), (0, 0))
  }
}
