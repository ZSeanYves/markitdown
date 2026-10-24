///|
fn framing_test_object(
  compressed : Bytes,
  length_dict : String,
  separator : Bytes,
  context~ : PdfStreamDecodeContext? = None,
) -> PdfNativeObject raise PdfHardDecodeFailure {
  let output = Buffer()
  output.write_bytes(
    pdf_ascii_bytes(
      "1 0 obj\n<< /Filter /FlateDecode " + length_dict + " >>\nstream\n",
    ),
  )
  output.write_bytes(compressed)
  output.write_bytes(separator)
  output.write_bytes(b"endstream\nendobj\n")
  pdf_parse_indirect_object_at(output.to_bytes(), 0, decode_context=context).unwrap()
}

///|
async fn framing_test_decode(
  object : PdfNativeObject,
) -> Result[Bytes, PdfNativeError] {
  pdf_decode_stream_bytes(object, "framing regression") catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
async test "PDF indirect Length preserves Adler CR before syntax LF" {
  let compressed = @zlib.zlib_compress(b"\x0c")
  assert_eq(compressed[compressed.length() - 1], b'\r')
  let object = framing_test_object(compressed, "/Length 2 0 R", b"\n")
  let scalar : PdfNativeObject = {
    object_id: 2,
    dict_text: compressed.length().to_string(),
    stream: None,
  }
  let objects = [object, scalar]
  let index : Map[Int32, PdfNativeObject] = Map([(1, object), (2, scalar)])
  let store = pdf_build_parsed_object_store(
    objects,
    index,
    [],
    "fixture",
    "fixture",
  )
  let resolved = store.object_index.get(1).unwrap()
  match framing_test_decode(resolved) {
    Ok(value) => assert_eq(value, b"\x0c")
    Err(error) => fail(error.to_string())
  }
  assert_eq(
    pdf_wbtest_loaded_stream(resolved.stream.unwrap()).declared_length,
    Some(compressed.length()),
  )
}

///|
async test "PDF marker framing keeps legal CR LF data bytes for LF and CRLF separators" {
  for decoded in [b"\x0c", b"\x09"] {
    let compressed = @zlib.zlib_compress(decoded)
    for separator in [b"\n", b"\r\n"] {
      for
        length_dict in [
          "/Length " + compressed.length().to_string(),
          "/Length1 1",
        ] {
        let object = framing_test_object(compressed, length_dict, separator)
        match framing_test_decode(object) {
          Ok(value) => assert_eq(value, decoded)
          Err(error) => fail(error.to_string())
        }
      }
    }
  }
}

///|
async test "PDF Length keys are exact and declared EOL ambiguity repairs real framing" {
  let compressed = @zlib.zlib_compress(b"framed font")
  let output = Buffer()
  output.write_bytes(compressed)
  output.write_byte(b'\n')
  let overlong = output.to_bytes()
  let object = framing_test_object(
    overlong,
    "/Length1 99 /Length " + overlong.length().to_string(),
    b"\n",
  )
  assert_eq(
    pdf_wbtest_loaded_stream(object.stream.unwrap()).declared_length,
    Some(overlong.length()),
  )
  match framing_test_decode(object) {
    Ok(value) => assert_eq(value, b"framed font")
    Err(error) => fail(error.to_string())
  }
  let exact_key = framing_test_object(
    compressed, "/Length1 1 /Length99 2", b"\n",
  )
  assert_eq(
    pdf_wbtest_loaded_stream(exact_key.stream.unwrap()).declared_length,
    None,
  )
}

///|
async test "PDF framing never drops junk or recovers a corrupt Adler ending CR LF" {
  let compressed = @zlib.zlib_compress(b"guarded")
  for suffix in [b"X\n", b"\x00\n", b" \n"] {
    let output = Buffer()
    output.write_bytes(compressed)
    output.write_bytes(suffix)
    let payload = output.to_bytes()
    let object = framing_test_object(
      payload,
      "/Length " + payload.length().to_string(),
      b"\n",
    )
    assert_true(framing_test_decode(object) is Err(StreamIntegrityFailed(_, _)))
  }
  for last in [b'\r', b'\n'] {
    let bad = Bytes::makei(compressed.length(), i => {
      if i + 1 == compressed.length() {
        last
      } else {
        compressed[i]
      }
    })
    let account = @budget.Budget::new(bounded_pdf_test_limits(None))
    let owner = @input.begin_input_session(
      @input.input_from_bytes(bad),
      budget=account,
    )
    let object = framing_test_object(
      bad,
      "/Length " + bad.length().to_string(),
      b"\n",
      context=pdf_make_stream_decode_context(owner.source),
    )
    assert_true(
      framing_test_decode(object)
      is Err(StreamIntegrityFailed(ChecksumMismatch, _)),
    )
    // The correctly selected corrupt payload is attempted exactly once.
    assert_eq(account.snapshot().cumulative.inflate_bytes, 7L)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "PDF EOL framing retry cannot follow a typed first budget failure" {
  let compressed = @zlib.zlib_compress(b"A")
  let output = Buffer()
  output.write_bytes(compressed)
  output.write_byte(b'\n')
  let payload = output.to_bytes()
  let account = @budget.Budget::new(bounded_pdf_test_limits(Some(0L)))
  let reads = Ref(0)
  let owner = @input.begin_input_session(
    @input.input_from_reader(
      @input.make_input_reader(fn(_, _) {
        reads.val += 1
        Ok(b"not read")
      }),
    ),
    budget=account,
  )
  let object = framing_test_object(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
    context=pdf_make_stream_decode_context(owner.source),
  )
  assert_true(
    framing_test_decode(object)
    is Err(
      BudgetExceeded(
        LimitExceeded(Cumulative(InflateBytes), used=0L, requested=1L, limit=0L)
      )
    ),
  )
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
  assert_eq(reads.val, 0)
}

///|
async test "PDF candidate failure prevents subsequent parent Reader calls" {
  let compressed = @zlib.zlib_compress(b"A")
  let output = Buffer()
  output.write_bytes(compressed)
  output.write_byte(b'\n')
  let payload = output.to_bytes()
  let account = @budget.Budget::new(bounded_pdf_test_limits(Some(1L)))
  let reads = Ref(0)
  let owner = @input.begin_input_session(
    @input.input_from_reader(
      @input.make_input_reader(fn(_, _) {
        reads.val += 1
        Ok(b"not read")
      }),
    ),
    budget=account,
  )
  let object = framing_test_object(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
    context=pdf_make_stream_decode_context(owner.source),
  )
  // First framing emitted A then failed exact-consumption; the next strict
  // framing attempts another actual A and must stop at the shared account.
  assert_true(
    framing_test_decode(object)
    is Err(
      BudgetExceeded(
        LimitExceeded(Cumulative(InflateBytes), used=1L, requested=1L, limit=1L)
      )
    ),
  )
  assert_true(@input.read_input_bytes(owner.source) is Err(_))
  assert_eq(reads.val, 0)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}
