///|
fn session_test_source(bytes : Bytes) -> @input.InputSource {
  @input.input_from_bytes_with_format(bytes, "session.pdf", Some(Pdf))
}

///|
fn session_test_metadata_pdf(
  compressed~ : Bool = false,
  indirect_kids~ : Bool = false,
  cyclic~ : Bool = false,
) -> Bytes {
  let content = "BT /F1 12 Tf 1 0 0 1 50 100 Tm (session text) Tj ET"
  let metadata = [
    (
      3, "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    ),
    (
      4,
      "<< /Type /Pages /Kids " +
      (if cyclic {
        "[4 0 R]"
      } else if indirect_kids {
        "8 0 R"
      } else {
        "[3 0 R]"
      }) +
      " /Count 99 >>",
    ),
    (5, "<< /Type /Catalog /Pages 4 0 R >>"),
  ]
  let objects = [
    (1, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
    (
      2,
      "<< /Length " +
      content.length().to_string() +
      " >>\nstream\n" +
      content +
      "\nendstream",
    ),
  ]
  if indirect_kids {
    objects.push((8, "[3 0 R]"))
  }
  let extra : Array[PdfWbtestXrefEntry] = []
  if compressed {
    let header : Array[String] = []
    let bodies : Array[String] = []
    let mut offset = 0
    for (id, body) in metadata {
      header.push(id.to_string() + " " + offset.to_string())
      bodies.push(body)
      offset += body.length() + 1
      extra.push({
        object_id: id,
        entry_type: 2,
        field1: 6,
        field2: extra.length(),
      })
    }
    let prefix = header.join(" ") + " "
    let payload = pdf_ascii_bytes(prefix + bodies.join(" "))
    objects.push(
      (
        6,
        bounded_pdf_test_stream(
          @zlib.zlib_compress(payload),
          extra="/Type /ObjStm /N 3 /First " + prefix.length().to_string(),
        ),
      ),
    )
  } else {
    objects.append(metadata[:])
  }
  pdf_wbtest_xref_stream_pdf_bytes(objects, 5, 9, extra_entries=extra)
}

///|
async test "structural session fetches only catalog page-tree metadata before content interpretation" {
  for corrupt in [false, true] {
    let account = @budget.Budget::new(bounded_pdf_test_limits(None))
    let owner = @input.begin_input_session(
      session_test_source(bounded_pdf_test_document("content", corrupt)),
      budget=account,
    )
    let session = open_pdf_native_session(owner.source).unwrap()
    let facts = pdf_structural_facts(session)
    assert_eq(facts.page_count, Some(1))
    assert_eq(facts.metadata_object_count, 3)
    assert_eq(facts.metadata_object_stream_count, 0)
    assert_eq(account.snapshot().cumulative.inflate_bytes, 0L)
    assert_true(@input.input_source_failure(owner.source) is None)
    let objects = session.indexed.unwrap().objects
    assert_true(!objects.contains(1) && !objects.contains(2))
    let result = extract_pdf_native_document_from_session(session)
    if corrupt {
      assert_true(result is Err(StreamIntegrityFailed(_, _)))
      assert_true(
        @input.input_source_failure(owner.source) is Some(InputError(_)),
      )
    } else {
      assert_true(result is Ok(_))
      assert_true(account.snapshot().cumulative.inflate_bytes > 0L)
    }
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "metadata ObjStm decode and sorted xref locations are reused exactly once" {
  let bytes = session_test_metadata_pdf(compressed=true)
  let original = extract_pdf_native_document(session_test_source(bytes)).unwrap()
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    session_test_source(bytes),
    budget=account,
  )
  let session = open_pdf_native_session(owner.source).unwrap()
  assert_eq(pdf_structural_facts(session).page_count, Some(1))
  assert_eq(pdf_structural_facts(session).metadata_object_stream_count, 1)
  let after_probe = account.snapshot().cumulative.inflate_bytes
  assert_true(after_probe > 0L)
  let parsed = extract_pdf_native_document_from_session(session).unwrap()
  assert_eq(account.snapshot().cumulative.inflate_bytes, after_probe)
  assert_eq(
    pdf_native_line_text(parsed.pages[0].text_blocks[0].lines[0]),
    pdf_native_line_text(original.pages[0].text_blocks[0].lines[0]),
  )
  assert_eq(
    parsed.diagnostics.metrics.get("pdf_xref_mode"),
    original.diagnostics.metrics.get("pdf_xref_mode"),
  )
  assert_eq(
    parsed.diagnostics.metrics.get("pdf_input_access_mode"),
    original.diagnostics.metrics.get("pdf_input_access_mode"),
  )
  assert_true(
    extract_pdf_native_document_from_session(session)
    is Err(ParseFailed("PDF session has already been consumed")),
  )
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "page count traverses indirect Kids and ignores Count while cycles defer repair" {
  for cyclic in [false, true] {
    let bytes = session_test_metadata_pdf(indirect_kids=true, cyclic~)
    let owner = @input.begin_input_session(session_test_source(bytes))
    let session = open_pdf_native_session(owner.source).unwrap()
    let facts = pdf_structural_facts(session)
    if cyclic {
      assert_eq(facts.page_count, None)
      assert_true(facts.deferred_repair)
    } else {
      assert_eq(facts.page_count, Some(1))
      assert_true(!facts.deferred_repair)
    }
    let parsed = extract_pdf_native_document_from_session(session).unwrap()
    assert_eq(parsed.pages.length(), 1)
    assert_eq(
      pdf_native_line_text(parsed.pages[0].text_blocks[0].lines[0]),
      "session text",
    )
    @input.end_input_session(owner)
  }
}

///|
async test "unknown size Reader is untouched by structural probe and materialized once at parse" {
  let bytes = session_test_metadata_pdf()
  let calls = Ref(0)
  let reader = @input.make_input_reader(fn(offset, length) {
    calls.val += 1
    let start = offset.to_int()
    if start >= bytes.length() {
      return Ok(b"")
    }
    Ok(bytes[start:(start + length.min(19)).min(bytes.length())].to_owned())
  })
  let owner = @input.begin_input_session(
    @input.input_from_reader_with_format(reader, "unknown.pdf", Some(Pdf)),
  )
  let session = open_pdf_native_session(owner.source).unwrap()
  assert_eq(calls.val, 0)
  assert_eq(pdf_structural_facts(session).page_count, None)
  let parsed = extract_pdf_native_document_from_session(session).unwrap()
  assert_eq(parsed.pages.length(), 1)
  assert_true(calls.val > 0)
  assert_eq(
    parsed.diagnostics.metrics.get("pdf_input_access_mode"),
    Some("materialized_xref"),
  )
  @input.end_input_session(owner)
}

///|
async test "missing index defers legacy scan and owner closure rejects cached structural artifact" {
  let bytes = pdf_wbtest_tiny_pdf_bytes()
  let owner = @input.begin_input_session(session_test_source(bytes))
  let session = open_pdf_native_session(owner.source).unwrap()
  assert_eq(pdf_structural_facts(session).page_count, None)
  let parsed = extract_pdf_native_document_from_session(session).unwrap()
  assert_eq(parsed.pages.length(), 1)
  @input.end_input_session(owner)
  let closed = @input.begin_input_session(
    session_test_source(session_test_metadata_pdf()),
  )
  let artifact = open_pdf_native_session(closed.source).unwrap()
  @input.end_input_session(closed)
  assert_true(
    extract_pdf_native_document_from_session(artifact) is Err(ReadFailed(_)),
  )
  assert_true(
    open_pdf_native_session(session_test_source(bytes)) is Err(ReadFailed(_)),
  )
}

///|
async test "structural cursor read failure stops without a materialized retry" {
  let bytes = session_test_metadata_pdf()
  let calls = Ref(0)
  let owner = @input.begin_input_session(
    @input.input_from_reader_with_format(
      @input.make_input_reader(
        fn(offset, length) {
          calls.val += 1
          if calls.val >= 2 {
            return Err("forced structural failure")
          }
          let start = offset.to_int()
          Ok(bytes[start:(start + length).min(bytes.length())].to_owned())
        },
        size=bytes.length().to_int64(),
      ),
      "failing.pdf",
      Some(Pdf),
    ),
  )
  assert_true(
    open_pdf_native_session(owner.source)
    is Err(ReadFailed("forced structural failure")),
  )
  assert_eq(calls.val, 2)
  assert_true(@input.read_input_bytes(owner.source) is Err(_))
  assert_eq(calls.val, 2)
  @input.end_input_session(owner)
}

///|
async test "structural session metadata budget failure stays typed and prevents later Reader calls" {
  for kind in ["cache", "work"] {
    let limits = @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=if kind == "work" { Some(0L) } else { None },
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=if kind == "cache" { Some(0L) } else { None },
      working_bytes=None,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap()
    let account = @budget.Budget::new(limits)
    let bytes = session_test_metadata_pdf()
    let calls = Ref(0)
    let owner = @input.begin_input_session(
      @input.input_from_reader(
        @input.make_input_reader(
          fn(offset, length) {
            calls.val += 1
            let start = offset.to_int()
            Ok(bytes[start:(start + length).min(bytes.length())].to_owned())
          },
          size=bytes.length().to_int64(),
        ),
      ),
      budget=account,
    )
    assert_true(open_pdf_native_session(owner.source) is Err(BudgetExceeded(_)))
    assert_true(
      @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
    )
    let before = calls.val
    assert_true(@input.read_input_bytes(owner.source) is Err(_))
    assert_eq(calls.val, before)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "structural header cancellation stays in async channel" {
  let entered = Ref(false)
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_reader(
      @input.make_async_input_reader(
        async fn(_, _) {
          entered.val = true
          while true {
            @async.pause()
          }
          Ok(b"")
        },
        size=100L,
      ),
    ),
    budget=account,
  )
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => open_pdf_native_session(owner.source))
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "structural probe defers font CMap and image resources with invalid compressed payload" {
  for kind in ["cmap", "font", "mask"] {
    let account = @budget.Budget::new(bounded_pdf_test_limits(None))
    let owner = @input.begin_input_session(
      session_test_source(bounded_pdf_test_document(kind, true)),
      budget=account,
    )
    let session = open_pdf_native_session(owner.source).unwrap()
    assert_eq(pdf_structural_facts(session).page_count, Some(1))
    assert_eq(pdf_structural_facts(session).metadata_object_count, 3)
    assert_eq(account.snapshot().cumulative.inflate_bytes, 0L)
    assert_true(
      extract_pdf_native_document_from_session(session)
      is Err(StreamIntegrityFailed(_, _)),
    )
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "structural xref hard failure bypasses later-section continue and shares parent latch" {
  for later in [false, true] {
    let parent = @input.begin_input_session(@input.input_from_bytes(b"parent"))
    let source = @input.input_source_inherit_session(
      session_test_source(bounded_pdf_test_broken_xref(later)),
      parent.source,
    )
    assert_true(
      open_pdf_native_session(source) is Err(StreamIntegrityFailed(_, _)),
    )
    assert_true(
      @input.input_source_failure(parent.source) is Some(InputError(_)),
    )
    assert_true(@input.read_input_bytes(parent.source) is Err(_))
    @input.end_input_session(parent)
  }
}

///|
async test "required metadata ObjStm obeys shared actual inflate budget before session publication" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(Some(0L)))
  let owner = @input.begin_input_session(
    session_test_source(session_test_metadata_pdf(compressed=true)),
    budget=account,
  )
  assert_true(open_pdf_native_session(owner.source) is Err(BudgetExceeded(_)))
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  assert_true(@input.read_input_bytes(owner.source) is Err(_))
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "indexed structural probe does not fetch the full unrelated multi-megabyte stream" {
  let content = "BT /F1 12 Tf (small page) Tj ET"
  let unrelated = "Z".repeat(2 * 1024 * 1024)
  let bytes = pdf_wbtest_xref_stream_pdf_bytes(
    [
      (1, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
      (
        2,
        "<< /Length " +
        content.length().to_string() +
        " >>\nstream\n" +
        content +
        "\nendstream",
      ),
      (
        3, "<< /Type /Page /Parent 4 0 R /Contents 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >> >>",
      ),
      (4, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
      (5, "<< /Type /Catalog /Pages 4 0 R >>"),
      (
        6,
        "<< /Length " +
        unrelated.length().to_string() +
        " >>\nstream\n" +
        unrelated +
        "\nendstream",
      ),
    ],
    5,
    9,
  )
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    session_test_source(bytes),
    budget=account,
  )
  let session = open_pdf_native_session(owner.source).unwrap()
  assert_eq(pdf_structural_facts(session).page_count, Some(1))
  assert_true(!session.indexed.unwrap().objects.contains(6))
  // Header/tail/xref windows can overlap physical content, but the unrelated
  // object is neither fetched whole nor interpreted for structural facts.
  assert_true(account.snapshot().cumulative.read_traffic_bytes < 100000L)
  assert_eq(account.snapshot().cumulative.inflate_bytes, 0L)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}
