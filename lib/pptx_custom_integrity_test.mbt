///|
fn pptx_custom_integrity_payload(
  early_syntax : Bool,
  invalid_utf8 : Bool,
) -> Bytes {
  let mut prefix = b"<Properties>"
  for _ in 0..<257 {
    prefix += b"<property name='n'><vt:i4>1</vt:i4></property>"
  }
  prefix +
  (if early_syntax { b"</wrong>" } else { b"</Properties>" }) +
  Bytes::from_array(Array::make(70000, b' ')) +
  (if invalid_utf8 { b"\xff" } else { b"" })
}

///|
async fn pptx_custom_integrity_document(
  payload : Bytes,
  corrupt_crc : Bool,
) -> Bytes {
  let raw = @dzip.build_store_zip_bytes([
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
    ("docProps/custom.xml", payload),
  ])
  if !corrupt_crc {
    return raw
  }
  let slice = @dzip.read_entry_data_slice(
    @dzip.open_zip(raw),
    "docProps/custom.xml",
  )
  let damaged = raw.to_array()
  damaged[slice.data_start + 65537] = b'\t'
  Bytes::from_array(damaged)
}

///|
async test "public PPTX custom selection limit cannot hide tail UTF8 CRC even after recoverable syntax direct or nested" {
  for nested in [false, true] {
    for early_syntax in [false, true] {
      for invalid_utf8 in [false, true] {
        let child = pptx_custom_integrity_document(
          pptx_custom_integrity_payload(early_syntax, invalid_utf8),
          !invalid_utf8,
        )
        let raw = if nested {
          @dzip.build_store_zip_bytes([("child.pptx", child)])
        } else {
          child
        }
        let format = if nested { "zip" } else { "pptx" }
        assert_eq(
          relationship_integrity_rejected(raw, format),
          (true, true, 0, 0),
        )
      }
    }
  }
}

///|
async test "public PPTX syntax only recovery preserves body and one completed candidate limit warning" {
  for early_syntax in [false, true] {
    let raw = pptx_custom_integrity_document(
      pptx_custom_integrity_payload(early_syntax, false),
      false,
    )
    let result = @lib.convert(
      @lib.Input::from_bytes(raw, source_name="custom.pptx"),
      options=@lib.ConvertOptions::default().with_format_hint(Some("pptx")),
    ).unwrap()
    assert_true(result.content.contains("Body"))
    assert_eq(
      result.content
      .split("pptx custom document property budget exceeded")
      .count(),
      2,
    )
  }
}

///|
async test "public PPTX custom cancellation in skipped tail does not write finish or resume input" {
  let raw = pptx_custom_integrity_document(
    pptx_custom_integrity_payload(false, false),
    false,
  )
  let slice = @dzip.read_entry_data_slice(
    @dzip.open_zip(raw),
    "docProps/custom.xml",
  )
  let entered = Ref(false)
  let resumed = Ref(false)
  let blocked_reads = Ref(0)
  let writes = Ref(0)
  let finishes = Ref(0)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        @lib.convert_to_sink(
          @lib.Input::from_async_reader(
            async fn(offset, length) {
              let start = offset.to_int()
              if start == slice.data_start + 65536 {
                entered.val = true
                blocked_reads.val += 1
                @async.sleep(60000)
                resumed.val = true
              }
              Ok(raw[start:start + length].to_owned())
            },
            size=raw.length().to_int64(),
            source_name="cancelled.pptx",
          ),
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
          options=@lib.ConvertOptions::default().with_format_hint(Some("pptx")),
        )
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  @async.pause()
  assert_eq(blocked_reads.val, 1)
  assert_false(resumed.val)
  assert_eq(writes.val, 0)
  assert_eq(finishes.val, 0)
}
