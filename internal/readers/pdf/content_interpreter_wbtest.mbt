///|
// Legacy whitebox entry points share the production kernel; no second loop.
async fn pdf_extract_text_fragments_from_stream(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  font_aliases : Map[String, Int32],
  fonts : Map[Int32, PdfNativeFontInfo],
  inline_font_ids : Map[String, Int32],
  content_text : String,
  object_index~ : Map[Int32, PdfNativeObject] = Map([]),
  resources_text~ : String? = None,
  base_matrix~ : PdfNativeGraphicsMatrix = pdf_identity_matrix(),
  remaining_depth~ : Int32 = 6,
) -> Result[Array[PdfNativeTextFragment], PdfNativeError] {
  pdf_interpret_content_stream(
    source,
    geometry,
    font_aliases,
    fonts,
    inline_font_ids,
    content_text,
    object_index~,
    resources_text~,
    base_matrix~,
    remaining_depth~,
  )
}

///|
async fn pdf_extract_text_fragments_from_xobject_name(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  object_index : Map[Int32, PdfNativeObject],
  resources_text : String?,
  fonts : Map[Int32, PdfNativeFontInfo],
  inline_font_ids : Map[String, Int32],
  xobject_name : String,
  current_matrix : PdfNativeGraphicsMatrix,
  remaining_depth : Int32,
) -> Result[Array[PdfNativeTextFragment], PdfNativeError] {
  pdf_interpret_content_xobject(
    source,
    geometry,
    object_index,
    resources_text,
    fonts,
    inline_font_ids,
    xobject_name,
    current_matrix,
    remaining_depth,
    None,
    false,
  )
}

///|
fn content_test_limits(working : Int64?) -> @budget.BudgetLimits {
  @budget.BudgetLimits::new(
    MeasurementOnly,
    inflate_bytes=None,
    parse_work=None,
    output_utf8_bytes=None,
    source_metadata_bytes=None,
    rag_metadata_bytes=None,
    read_traffic_bytes=None,
    cache_bytes=None,
    working_bytes=working,
    temporary_bytes=None,
    ir_bytes=None,
  ).unwrap()
}

///|
fn content_test_image(id : Int32) -> PdfNativeObject {
  pdf_text_coverage_stream_object(
    id, "<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /ASCIIHexDecode >>",
    "80>",
  )
}

///|
async fn content_test_enqueue(
  queue : PdfPendingImageQueue,
  name : String,
  object : PdfNativeObject,
) -> Result[Unit, PdfNativeError] {
  Ok(pdf_enqueue_pending_image(queue, name, object, pdf_identity_matrix())) catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
async fn content_test_observe(
  source : @input.InputSource,
  content : String,
  objects : Map[Int32, PdfNativeObject],
  resources : String?,
) -> Result[
  (Array[PdfNativeTextFragment], Array[PdfNativeImageCandidate]),
  PdfNativeError,
] {
  pdf_extract_content_fragments_and_images(
    source,
    make_pdf_page_geometry(1, 200.0, 200.0),
    Map([("F1", 1)]),
    Map([(1, pdf_text_coverage_font_info())]),
    Map([]),
    content,
    objects,
    resources,
  ) catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
async test "pending ImageDo Native capacity and descriptor leases include growth overlap" {
  let account = @budget.Budget::new(content_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_bytes(b"queue"),
    budget=account,
  )
  let queue = pdf_pending_image_queue(owner.source)
  defer pdf_release_pending_images(queue)
  defer @input.end_input_session(owner)
  let object = content_test_image(20)
  for index in 0..<9 {
    content_test_enqueue(queue, "Im0", object).unwrap()
    assert_eq(queue.entries.capacity(), if index < 8 { 8 } else { 16 })
  }
  assert_eq(account.snapshot().resident.working_bytes, 686L)
  assert_eq(account.snapshot().resident_peak.working_bytes, 744L)
  pdf_release_pending_images(queue)
  // Alias payload may escape into image refs and stays with the original owner.
  assert_eq(account.snapshot().resident.working_bytes, 54L)
  assert_eq(account.snapshot().active_leases, 9L)
  pdf_release_pending_images(queue)
  assert_eq(account.snapshot().resident.working_bytes, 54L)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "queue buffer admission precedes allocation and failed item is never published" {
  let account = @budget.Budget::new(content_test_limits(Some(119L)))
  let owner = @input.begin_input_session(
    @input.input_from_bytes(b"queue"),
    budget=account,
  )
  let queue = pdf_pending_image_queue(owner.source)
  let result = content_test_enqueue(queue, "Im0", content_test_image(20))
  assert_true(result is Err(BudgetExceeded(_)))
  assert_eq(queue.entries.length(), 0)
  assert_eq(queue.entries.capacity(), 0)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  assert_true(
    content_test_enqueue(queue, "Im0", content_test_image(20))
    is Err(BudgetExceeded(_)),
  )
  pdf_release_pending_images(queue)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "new and old queue buffers must coexist within the Working cap" {
  let account = @budget.Budget::new(content_test_limits(Some(743L)))
  let owner = @input.begin_input_session(
    @input.input_from_bytes(b"queue"),
    budget=account,
  )
  let queue = pdf_pending_image_queue(owner.source)
  let object = content_test_image(20)
  for _ in 0..<8 {
    content_test_enqueue(queue, "Im0", object).unwrap()
  }
  assert_true(
    content_test_enqueue(queue, "Im0", object) is Err(BudgetExceeded(_)),
  )
  assert_eq(queue.entries.capacity(), 8)
  assert_eq(queue.entries.length(), 8)
  assert_eq(account.snapshot().resident.working_bytes, 560L)
  pdf_release_pending_images(queue)
  assert_eq(account.snapshot().resident.working_bytes, 48L)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "post-lex name retention failure cleans private queue leases" {
  let account = @budget.Budget::new(content_test_limits(Some(125L)))
  let owner = @input.begin_input_session(
    @input.input_from_bytes(b"queue"),
    budget=account,
  )
  let queue = pdf_pending_image_queue(owner.source)
  assert_true(
    content_test_enqueue(queue, "Im0", content_test_image(20))
    is Err(BudgetExceeded(_)),
  )
  assert_eq(queue.entries.length(), 0)
  pdf_release_pending_images(queue)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
test "queue capacity math checks Int32 representability without SDK growth abort" {
  assert_eq(pdf_pending_image_capacity(None, 0, 1L), 8)
  assert_eq(pdf_pending_image_capacity(None, 8, 9L), 16)
  assert_eq(
    pdf_pending_image_capacity(None, 1073741824, 1073741825L),
    1073741825,
  )
  let overflow = Ok(pdf_pending_image_capacity(None, 2147483647, 2147483648L)) catch {
    PdfHardDecodeFailure(error) => Err(error)
  }
  assert_true(overflow is Err(ParseFailed(_)))
}

///|
async test "single interpreter preserves sticky image resource reachability and captured CTM" {
  let owner = @input.begin_input_session(@input.input_from_bytes(b"content"))
  defer @input.end_input_session(owner)
  let resources = Some(
    "<< /XObject << /Im 20 0 R /NoLocal 10 0 R /Local 11 0 R >> /Font << /F1 1 0 R >> >>",
  )
  let own_resources = "<< /XObject << /Im 20 0 R >> /Font << /F1 1 0 R >> >>"
  let objects = Map([
    (20, content_test_image(20)),
    (
      10,
      pdf_text_coverage_stream_object(
        10, "<< /Subtype /Form >>", "/Im Do /Local Do BT /F1 10 Tf (inherited text) Tj ET",
      ),
    ),
    (
      11,
      pdf_text_coverage_stream_object(
        11,
        "<< /Subtype /Form /Matrix [4 0 0 5 1 2] /Resources " +
        own_resources +
        " >>",
        "/Im Do BT /F1 10 Tf (local text) Tj ET",
      ),
    ),
  ])
  let queue = pdf_pending_image_queue(owner.source)
  defer pdf_release_pending_images(queue)
  let fragments = pdf_interpret_content_stream(
    owner.source,
    make_pdf_page_geometry(1, 200.0, 200.0),
    Map([("F1", 1)]),
    Map([(1, pdf_text_coverage_font_info())]),
    Map([]),
    "q 2 0 0 3 7 11 cm /Im Do /NoLocal Do Q /Local Do /Im Do",
    object_index=objects,
    resources_text=resources,
    pending_images=Some(queue),
    observe_images=true,
  ).unwrap()
  assert_eq(fragments.map(fragment => fragment.text), [
    "local text", "inherited text", "local text",
  ])
  assert_eq(queue.entries.length(), 3)
  let first = queue.entries[0].unwrap()
  let middle = queue.entries[1].unwrap()
  let last = queue.entries[2].unwrap()
  assert_eq([first.a, first.d, first.e, first.f], [2.0, 3.0, 7.0, 11.0])
  assert_eq([middle.a, middle.d, middle.e, middle.f], [4.0, 5.0, 1.0, 2.0])
  assert_eq([last.a, last.d, last.e, last.f], [1.0, 1.0, 0.0, 0.0])
  let images = pdf_fulfill_pending_images(
    queue,
    owner.source,
    make_pdf_page_geometry(1, 200.0, 200.0),
    objects,
  )
  assert_eq(images.length(), 3)
  for image in images {
    assert_eq(
      image.source_ref.unwrap().extra.get("pdf_xobject_name"),
      Some("Im"),
    )
    assert_true(image.asset_ref is Some(_))
  }
}

///|
async fn content_test_double_fault(
  working : Int64?,
  long_name : Bool,
  bad_image~ : Bool = false,
) -> (
  Result[
    (Array[PdfNativeTextFragment], Array[PdfNativeImageCandidate]),
    PdfNativeError,
  ],
  Int32,
  Bool,
) {
  let compressed = @zlib.zlib_compress(b"")
  let corrupt = Bytes::makei(compressed.length(), i => {
    if i + 1 == compressed.length() {
      compressed[i] ^ b'\x01'
    } else {
      compressed[i]
    }
  })
  let (bytes, offset) = ranged_test_bytes(
    corrupt,
    "/Subtype /Form /Resources << >> /Length " + corrupt.length().to_string(),
    b"\n",
  )
  let calls = Ref(0)
  let reader = @input.make_input_reader(
    fn(offset, length) {
      calls.val += 1
      let start = offset.to_int()
      Ok(bytes[start:start + length].to_owned())
    },
    size=bytes.length().to_int64(),
  )
  let account = @budget.Budget::new(content_test_limits(working))
  let owner = @input.begin_input_session(
    @input.input_from_reader(reader),
    budget=account,
  )
  let form = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  let name = if long_name { "I".repeat(250000) } else { "Im" }
  let objects = Map([
    (1, form),
    (
      20,
      if bad_image {
        content_test_loaded_bytes(
          20, "/Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode",
          corrupt,
        )
      } else {
        content_test_image(20)
      },
    ),
  ])
  let resources = Some("<< /XObject << /" + name + " 20 0 R /Bad 1 0 R >> >>")
  let result = content_test_observe(
    owner.source,
    "/" + name + " Do /Bad Do",
    objects,
    resources,
  )
  let typed_budget = @input.input_source_failure(owner.source)
    is Some(BudgetFailure(_))
  // A prior admission failure cannot be followed by source reads on retry.
  if typed_budget {
    assert_true(
      content_test_observe(owner.source, "/Bad Do", objects, resources)
      is Err(BudgetExceeded(_)),
    )
  }
  let count = calls.val
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
  (result, count, typed_budget)
}

///|
async test "new queue Working admission stops before a later Form checksum failure" {
  let (result, reads, typed_budget) = content_test_double_fault(
    Some(480000L),
    true,
  )
  assert_true(result is Err(BudgetExceeded(_)))
  assert_eq(reads, 0)
  assert_true(typed_budget)
}

///|
async test "sufficient queue budget retains text Form checksum error before earlier image decode" {
  let (result, reads, typed_budget) = content_test_double_fault(None, false)
  assert_true(result is Err(StreamIntegrityFailed(ChecksumMismatch, _)))
  assert_eq(reads, 1)
  assert_false(typed_budget)
}

///|
async test "queue typed first failure rejects both enqueue and fulfill" {
  let account = @budget.Budget::new(content_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_bytes(b"queue"),
    budget=account,
  )
  let queue = pdf_pending_image_queue(owner.source)
  content_test_enqueue(queue, "Im0", content_test_image(20)).unwrap()
  let error : @budget.BudgetError = LimitExceeded(
    Resident(WorkingBytes),
    used=0L,
    requested=1L,
    limit=0L,
  )
  @input.record_input_budget_failure(owner.source, error)
  assert_true(
    content_test_enqueue(queue, "Im0", content_test_image(20))
    is Err(BudgetExceeded(found)) &&
    found == error,
  )
  let fulfilled = try {
    ignore(
      pdf_fulfill_pending_images(
        queue,
        owner.source,
        make_pdf_page_geometry(1, 10.0, 10.0),
        Map([]),
      ),
    )
    Ok(())
  } catch {
    PdfHardDecodeFailure(error) => Err(error)
    other => raise other
  }
  assert_true(fulfilled is Err(BudgetExceeded(found)) && found == error)
  pdf_release_pending_images(queue)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
  assert_true(
    content_test_enqueue(queue, "Im0", content_test_image(20))
    is Err(BudgetExceeded(_)),
  )
}

///|
async test "cancelled image fulfillment releases private pending leases without poisoning source" {
  let (bytes, offset) = ranged_test_bytes(
    @zlib.zlib_compress(b"\x80"),
    "/Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Length 2 0 R",
    b"\n",
  )
  let entered = Ref(false)
  let reader = @input.make_async_input_reader(
    async fn(_, _) {
      entered.val = true
      while true {
        @async.pause()
      }
      Ok(b"")
    },
    size=bytes.length().to_int64(),
  )
  let account = @budget.Budget::new(content_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_reader(reader),
    budget=account,
  )
  let object = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  let objects = Map([(object.object_id, object)])
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        content_test_observe(
          owner.source,
          "/Im Do",
          objects,
          Some("<< /XObject << /Im 1 0 R >> >>"),
        )
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_true(@input.input_source_failure(owner.source) is None)
  assert_eq(account.snapshot().resident.working_bytes, 4L)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
fn content_test_loaded_bytes(
  id : Int32,
  dict_fields : String,
  bytes : Bytes,
  context~ : PdfStreamDecodeContext? = None,
) -> PdfNativeObject {
  {
    object_id: id,
    dict_text: "<< " +
    dict_fields +
    " /Length " +
    bytes.length().to_string() +
    " >>",
    stream: Some(
      Loaded({
        primary_bytes: bytes,
        endstream_bytes: bytes,
        endstream_eol_suffix: 0,
        endstream_eol_length: 0,
        declared_length: Some(bytes.length()),
        decode_context: context,
      }),
    ),
  }
}

///|
fn content_test_bad_adler() -> Bytes {
  let compressed = @zlib.zlib_compress(b"")
  Bytes::makei(compressed.length(), i => {
    if i + 1 == compressed.length() {
      compressed[i] ^ b'\x01'
    } else {
      compressed[i]
    }
  })
}

///|
async test "fresh closed owner rejects queue work without a prior injected failure" {
  let empty_account = @budget.Budget::new(content_test_limits(None))
  let empty_owner = @input.begin_input_session(
    @input.input_from_bytes(b"queue"),
    budget=empty_account,
  )
  let empty_queue = pdf_pending_image_queue(empty_owner.source)
  @input.end_input_session(empty_owner)
  assert_true(empty_account.failure() is None)
  assert_true(
    content_test_enqueue(empty_queue, "Im0", content_test_image(20))
    is Err(ReadFailed(_)),
  )
  assert_eq(empty_queue.entries.capacity(), 0)
  assert_eq(empty_account.snapshot().active_leases, 0L)

  let calls = Ref(0)
  let reader = @input.make_input_reader(
    fn(_, _) {
      calls.val += 1
      Ok(b"queue")
    },
    size=5L,
  )
  let account = @budget.Budget::new(content_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_reader(reader),
    budget=account,
  )
  let queue = pdf_pending_image_queue(owner.source)
  content_test_enqueue(queue, "Im0", content_test_image(20)).unwrap()
  // Closing a real owner while private work is live reports its two outstanding
  // leases. This is a fresh closure, not an injected pre-existing budget error.
  @input.end_input_session(owner)
  assert_true(account.failure() is Some(OutstandingLeases(2L)))
  let result = try {
    ignore(
      pdf_fulfill_pending_images(
        queue,
        owner.source,
        make_pdf_page_geometry(1, 10.0, 10.0),
        Map([]),
      ),
    )
    Ok(())
  } catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
  assert_true(result is Err(BudgetExceeded(OutstandingLeases(2L))))
  assert_eq(calls.val, 0)
  pdf_release_pending_images(queue)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "each Contents image phase completes before the next Contents text decode" {
  for bad_first_image in [true, false] {
    let owner = @input.begin_input_session(@input.input_from_bytes(b"page"))
    let image = if bad_first_image {
      content_test_loaded_bytes(
        20,
        "/Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode",
        content_test_bad_adler(),
      )
    } else {
      content_test_image(20)
    }
    let objects = Map([
      (
        3,
        pdf_product_wbtest_object(
          3, "<< /Type /Page /MediaBox [0 0 200 200] /Resources << /XObject << /Im 20 0 R >> >> /Contents [4 0 R 5 0 R] >>",
        ),
      ),
      (4, pdf_text_coverage_stream_object(4, "<< >>", "/Im Do")),
      (5, content_test_loaded_bytes(5, "/Filter /FlateDecode", b"x")),
      (20, image),
    ])
    let result = pdf_build_native_pages(
      owner.source,
      [3],
      objects,
      Map([]),
      Map([]),
      Map([(3, 1)]),
    ) catch {
      PdfHardDecodeFailure(error) => Err(error)
      error => raise error
    }
    if bad_first_image {
      // If text from all references were processed first, this would instead
      // report the second reference's Truncated wrapper error.
      assert_true(result is Err(StreamIntegrityFailed(ChecksumMismatch, _)))
    } else {
      // Negative control proves the later content is present and reachable.
      assert_true(result is Err(StreamIntegrityFailed(Truncated, _)))
    }
    @input.end_input_session(owner)
    assert_eq(
      @input.input_source_budget_context(owner.source).unwrap().account.snapshot().active_leases,
      0L,
    )
  }
}

///|
async test "depth one still decodes Form integrity and budget before child depth zero" {
  for corrupt in [true, false] {
    let account = @budget.Budget::new(
      bounded_pdf_test_limits(if corrupt { None } else { Some(0L) }),
    )
    let owner = @input.begin_input_session(
      @input.input_from_bytes(b"form"),
      budget=account,
    )
    let form = content_test_loaded_bytes(
      1,
      "/Subtype /Form /Resources << >> /Filter /FlateDecode",
      if corrupt {
        content_test_bad_adler()
      } else {
        @zlib.zlib_compress(b"BT (not reached) Tj ET")
      },
      context=pdf_make_stream_decode_context(owner.source),
    )
    let resources = Some("<< /XObject << /Fm 1 0 R >> >>")
    let objects = Map([(1, form)])
    let result = pdf_interpret_content_stream(
      owner.source,
      make_pdf_page_geometry(1, 10.0, 10.0),
      Map([]),
      Map([]),
      Map([]),
      "/Fm Do",
      object_index=objects,
      resources_text=resources,
      remaining_depth=1,
    ) catch {
      PdfHardDecodeFailure(error) => Err(error)
      error => raise error
    }
    if corrupt {
      assert_true(result is Err(StreamIntegrityFailed(ChecksumMismatch, _)))
    } else {
      assert_true(result is Err(BudgetExceeded(_)))
      assert_true(
        @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
      )
    }
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
  let hidden = pdf_interpret_content_stream(
    pdf_text_coverage_source(),
    make_pdf_page_geometry(1, 10.0, 10.0),
    Map([]),
    Map([]),
    Map([]),
    "(unterminated",
    remaining_depth=0,
  ).unwrap()
  assert_eq(hidden.length(), 0)
}

///|
async test "two bad CRCs preserve later Form text failure ahead of earlier image payload" {
  let (result, reads, typed_budget) = content_test_double_fault(
    None,
    false,
    bad_image=true,
  )
  assert_true(result is Err(StreamIntegrityFailed(ChecksumMismatch, _)))
  // The bad image is Loaded and would fail without a Reader callback. Seeing
  // exactly one Form range read proves image decode did not run before text.
  assert_eq(reads, 1)
  assert_false(typed_budget)
}
