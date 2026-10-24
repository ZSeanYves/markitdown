///|
fn mime_range_nested(depth : Int32) -> String {
  "Content-Type: message/rfc822\n\n".repeat(depth) +
  "Content-Type: text/plain\n\nleaf"
}

///|
fn mime_range_parts(count : Int32) -> String {
  "Content-Type: multipart/mixed; boundary=b\r\n\r\n" +
  "--b\r\nContent-Type: text/plain\r\n\r\nleaf\r\n".repeat(count) +
  "--b--"
}

///|
// Fixture-only ASCII adapter; Unicode wire fixtures below spell actual bytes.
fn mime_range_ascii_bytes(text : String) -> Bytes {
  Bytes::makei(text.length(), i => text.code_unit_at(i).to_int().to_byte())
}

///|
async fn mime_range_reject(
  input : @lib.Input,
  kind : String,
  observed : Int64,
  limit : Int64,
  format_hint~ : String = "eml",
) -> Unit {
  let options = @lib.ConvertOptions::default().with_format_hint(
    Some(format_hint),
  )
  match @lib.convert(input, options~) {
    Err(ResourceLimitExceeded(kind=actual, observed=got, limit=cap)) =>
      assert_eq((actual, got, cap), (kind, observed, limit))
    _ => fail("MIME structural limit must reject before raw fallback")
  }
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
  match result {
    Err(ResourceLimitExceeded(kind=actual, observed=got, limit=cap)) =>
      assert_eq((actual, got, cap), (kind, observed, limit))
    _ => fail("MIME Sink must return the same structural resource kind")
  }
  assert_eq((writes.val, finishes.val), (0, 0))
}

///|
async test "public MIME depth eight and 1024 parts stay accepted while one more is hard" {
  let options = @lib.ConvertOptions::default().with_format_hint(Some("eml"))
  for text in [mime_range_nested(8), mime_range_parts(1024)] {
    let input = @lib.Input::from_text(text, source_name="boundary.eml")
    let collected = @lib.convert(input, options~).unwrap()
    assert_true(collected.content.contains("leaf"))
    assert_false(
      collected.diagnostics.any(diagnostic => {
        diagnostic.code == "eml_raw_fenced_fallback"
      }),
    )
    let fragments : Array[String] = []
    let finishes = Ref(0)
    ignore(
      @lib.convert_to_sink(
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
      ).unwrap(),
    )
    assert_eq(fragments.join(""), collected.content)
    assert_eq(finishes.val, 1)
  }
  mime_range_reject(
    @lib.Input::from_text(mime_range_nested(9), source_name="depth.eml"),
    "mime_nesting_depth",
    9L,
    8L,
  )
  mime_range_reject(
    @lib.Input::from_text(mime_range_parts(1025), source_name="parts.eml"),
    "mime_multipart_parts",
    1025L,
    1024L,
  )
}

///|
async test "public MIME short reads retain global byte mode CRLF and Unicode" {
  let bytes = b"Subject: caf\xc3\xa9\r\nContent-Type: multipart/mixed; boundary=b\r\n\r\n--b\r\nContent-Type: text/plain\r\n\r\ncaf\xc3\xa9 \xf0\x9f\x98\x80\r\n--b--\r\n\xff"
  let options = @lib.ConvertOptions::default().with_format_hint(Some("eml"))
  let baseline = @lib.convert(
    @lib.Input::from_bytes(bytes, source_name="mixed.eml"),
    options~,
  ).unwrap()
  assert_true(baseline.content.contains("cafÃ©"))
  for chunk in [1, 3, 7] {
    let input = @lib.Input::from_async_reader(
      async fn(offset, length) {
        @async.pause()
        let start = offset.to_int()
        let end = (start + length.min(chunk)).min(bytes.length())
        Ok(bytes[start:end].to_owned())
      },
      size=bytes.length().to_int64(),
      source_name="mixed.eml",
    )
    let output = @lib.convert(input, options~).unwrap()
    assert_eq(output.content, baseline.content)
    assert_eq(output.metadata_json, baseline.metadata_json)
  }
}

///|
async test "nested MIME structural failure keeps its domain through container resource reporter" {
  let bytes = @dzip.build_store_zip_bytes([
    ("assets/cover.png", b"\x89PNG\r\n\x1a\n"),
    ("mail.eml", mime_range_ascii_bytes(mime_range_nested(9))),
  ])
  mime_range_reject(
    @lib.Input::from_bytes(bytes, source_name="outer.zip"),
    "mime_nesting_depth",
    9L,
    8L,
    format_hint="zip",
  )
}

///|
async test "MIME tail Reader errors precede structural failure and never reach Sink" {
  let bytes = mime_range_ascii_bytes(mime_range_nested(9))
  for early_eof in [false, true] {
    let input = @lib.Input::from_async_reader(
      async fn(offset, length) {
        @async.pause()
        if offset >= bytes.length().to_int64() {
          if early_eof {
            return Ok(b"")
          } else {
            return Err("MIME forced tail IO")
          }
        }
        let start = offset.to_int()
        Ok(bytes[start:(start + length.min(3)).min(bytes.length())].to_owned())
      },
      size=bytes.length().to_int64() + 1L,
      source_name="io-before-limit.eml",
    )
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
      options=@lib.ConvertOptions::default().with_format_hint(Some("eml")),
    )
    match result {
      Err(ResourceLimitExceeded(..)) =>
        fail("unread input must not manufacture a MIME limit first")
      Err(error) =>
        assert_true(
          error
          .message()
          .contains(
            if early_eof {
              "declared size"
            } else {
              "MIME forced tail IO"
            },
          ),
        )
      Ok(_) => fail("hard Reader failure must reject")
    }
    assert_eq((writes.val, finishes.val), (0, 0))
  }
}

///|
fn mime_range_qp(bytes : Bytes) -> String {
  let hex = "0123456789ABCDEF"
  let out = StringBuilder()
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    out.write_char('=')
    out.write_char(
      hex.code_unit_at(byte.to_int() >> 4).to_int().unsafe_to_char(),
    )
    out.write_char(
      hex.code_unit_at(byte.to_int() & 15).to_int().unsafe_to_char(),
    )
  }
  out.to_string()
}

///|
async test "MIME nested ZIP integrity bypasses attachment raw recovery and keeps earlier admission" {
  let bytes = @dzip.build_store_zip_bytes([("doc.txt", b"content")])
  let slice = @dzip.read_entry_data_slice(@dzip.open_zip(bytes), "doc.txt")
  let damaged = bytes.to_array()
  damaged[slice.data_start] = b'!'
  let prefix = "Content-Type: application/octet-stream; name=payload.zip\nContent-Disposition: attachment; filename=payload.zip\nContent-Transfer-Encoding: quoted-printable\n\n"
  let options = @lib.ConvertOptions::default().with_format_hint(Some("eml"))
  let valid = @lib.convert(
    @lib.Input::from_text(prefix + mime_range_qp(bytes), source_name="zip.eml"),
    options~,
  ).unwrap()
  assert_true(valid.content.contains("content"))
  for small_limit in [false, true] {
    let input = @lib.Input::from_text(
      prefix + mime_range_qp(Bytes::from_array(damaged)),
      source_name="crc.eml",
    )
    let options = if small_limit {
      options.with_limits(
        @lib.ResourceLimits::default().with_max_asset_bytes(1L),
      )
    } else {
      options
    }
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
    if small_limit {
      assert_true(
        result is Err(ResourceLimitExceeded(kind="single_asset_bytes", ..)),
      )
    } else {
      match result {
        Err(error) =>
          assert_true(
            error.message().contains("crc32 mismatch for entry: doc.txt"),
            msg=error.message(),
          )
        Ok(_) => fail("child CRC cannot become attachment fallback success")
      }
    }
    assert_eq((writes.val, finishes.val), (0, 0))
  }
}

///|
async test "cancelling MIME Reader await never finishes or resumes more reads" {
  let entered = Ref(false)
  let resumed = Ref(false)
  let reads = Ref(0)
  let finishes = Ref(0)
  let writes = Ref(0)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        @lib.convert_to_sink(
          @lib.Input::from_async_reader(
            async fn(_offset, _length) {
              reads.val += 1
              entered.val = true
              @async.sleep(60000)
              resumed.val = true
              Ok(b"Content-Type: text/plain\n\nbody")
            },
            source_name="cancel.eml",
          ),
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
          options=@lib.ConvertOptions::default().with_format_hint(Some("eml")),
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
  assert_eq(
    (reads.val, resumed.val, writes.val, finishes.val),
    (1, false, 0, 0),
  )
}
