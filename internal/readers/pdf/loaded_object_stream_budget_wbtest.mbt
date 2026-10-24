///|
fn loaded_objstm_limits(
  parse_work~ : Int64? = None,
  cache_bytes~ : Int64? = None,
  inflate_bytes~ : Int64? = None,
) -> @budget.BudgetLimits {
  @budget.BudgetLimits::new(
    MeasurementOnly,
    inflate_bytes~,
    parse_work~,
    output_utf8_bytes=None,
    source_metadata_bytes=None,
    rag_metadata_bytes=None,
    read_traffic_bytes=None,
    cache_bytes~,
    working_bytes=None,
    temporary_bytes=None,
    ir_bytes=None,
  ).unwrap()
}

///|
// Parse a real encoded object into the production Loaded variant. There is no
// Ranged cursor/key and no metadata prepayment that could hide these charges.
fn loaded_objstm_fixture(
  limits : @budget.BudgetLimits,
  first~ : Int32 = 9,
  corrupt_adler~ : Bool = false,
) -> (@input.InputSession, @budget.Budget, PdfNativeObject) raise {
  let encoded = @zlib.zlib_compress(b"5 0 <<>>")
  let encoded = if corrupt_adler {
    let changed = encoded.to_array()
    changed[changed.length() - 1] = (changed[changed.length() - 1].to_int() ^ 1).to_byte()
    Bytes::from_array(changed)
  } else {
    encoded
  }
  let (bytes, offset) = ranged_test_bytes(
    encoded,
    "/Type /ObjStm /N 1 /First " +
    first.to_string() +
    " /Length " +
    encoded.length().to_string(),
    b"\n",
  )
  let account = @budget.Budget::new(limits)
  let owner = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  let object = pdf_parse_indirect_object_at(
    bytes,
    offset,
    decode_context=pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  assert_true(object.stream is Some(Loaded(_)))
  (owner, account, object)
}

///|
async fn loaded_objstm_result(
  object : PdfNativeObject,
) -> Result[Array[PdfNativeObject], PdfNativeError] {
  pdf_parse_object_stream_entries(object) catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
async test "Loaded ObjStm small ParseWork cap rejects before ordinary syntax and stays on the original ledger" {
  let (owner, account, object) = loaded_objstm_fixture(
    loaded_objstm_limits(parse_work=Some(7L)),
  )
  defer @input.end_input_session(owner)
  assert_true(
    loaded_objstm_result(object)
    is Err(
      BudgetExceeded(
        LimitExceeded(Cumulative(ParseWork), used=0L, requested=8L, limit=7L)
      )
    ),
  )
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  // Inflate has always been charged; only the new logical admission differs.
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
  assert_eq(account.snapshot().resident.cache_bytes, 48L)
  let before = account.snapshot()
  assert_true(loaded_objstm_result(object) is Err(BudgetExceeded(_)))
  assert_true(account.snapshot() == before)
}

///|
async test "Loaded ObjStm small logical Cache cap is typed and cannot recover as malformed First" {
  let (owner, account, object) = loaded_objstm_fixture(
    loaded_objstm_limits(cache_bytes=Some(47L)),
  )
  defer @input.end_input_session(owner)
  assert_true(
    loaded_objstm_result(object)
    is Err(
      BudgetExceeded(
        LimitExceeded(Resident(CacheBytes), used=0L, requested=48L, limit=47L)
      )
    ),
  )
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
  assert_eq(account.snapshot().cumulative.parse_work, 0L)
  assert_eq(account.snapshot().resident.cache_bytes, 0L)
  let before = account.snapshot()
  assert_true(loaded_objstm_result(object) is Err(BudgetExceeded(_)))
  assert_true(account.snapshot() == before)
}

///|
async test "Loaded ObjStm valid repeat retains the conservative logical amount without adding a Result cache" {
  let (owner, account, object) = loaded_objstm_fixture(
    loaded_objstm_limits(),
    first=4,
  )
  defer @input.end_input_session(owner)
  for _ in 0..<2 {
    let entries = loaded_objstm_result(object).unwrap()
    assert_eq(entries.length(), 1)
    assert_eq(entries[0].object_id, 5)
  }
  assert_true(pdf_object_stream_result_key(object) is None)
  assert_eq(account.snapshot().cumulative.inflate_bytes, 16L)
  assert_eq(account.snapshot().cumulative.parse_work, 16L)
  assert_eq(account.snapshot().resident.cache_bytes, 96L)
  assert_true(@input.input_source_failure(owner.source) is None)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().resident.cache_bytes, 0L)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "Loaded ObjStm ordinary syntax error also holds logical admission until the owner ends" {
  let (owner, account, object) = loaded_objstm_fixture(loaded_objstm_limits())
  defer @input.end_input_session(owner)
  for _ in 0..<2 {
    match loaded_objstm_result(object) {
      Err(ParseFailed(message)) =>
        assert_eq(message, "object stream 1 is missing valid /First")
      _ => fail("original local ordinary parse error must remain intact")
    }
  }
  assert_eq(account.snapshot().cumulative.inflate_bytes, 16L)
  assert_eq(account.snapshot().cumulative.parse_work, 16L)
  assert_eq(account.snapshot().resident.cache_bytes, 96L)
  assert_true(@input.input_source_failure(owner.source) is None)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().resident.cache_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async fn loaded_objstm_probe_work(bytes : Bytes) -> Int64 {
  let account = @budget.Budget::new(loaded_objstm_limits())
  let owner = @input.begin_input_session(
    session_test_source(bytes),
    budget=account,
  )
  defer @input.end_input_session(owner)
  ignore(open_pdf_native_session(owner.source).unwrap())
  account.snapshot().cumulative.parse_work
}

///|
async test "Loaded ObjStm repair work uses the already charged probe account and prevents the second repair" {
  let bytes = objstm_result_test_document()
  // Calibrate all existing structural work, not only the 8B ObjStm payload.
  // The second fresh owner has an exact cap at that already completed probe.
  let probe_work = loaded_objstm_probe_work(bytes)
  assert_true(probe_work >= 8L)
  let account = @budget.Budget::new(
    loaded_objstm_limits(parse_work=Some(probe_work)),
  )
  let owner = @input.begin_input_session(
    session_test_source(bytes),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let session = open_pdf_native_session(owner.source).unwrap()
  assert_eq(account.snapshot().cumulative.parse_work, probe_work)
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
  match extract_pdf_native_document_from_session(session) {
    Err(
      BudgetExceeded(
        LimitExceeded(Cumulative(ParseWork), used~, requested~, limit~)
      )
    ) => {
      assert_eq(used, probe_work)
      assert_eq(requested, 8L)
      assert_eq(limit, probe_work)
    }
    _ => fail("Loaded repair must stop on its original ParseWork account")
  }
  // First Loaded emits 8; a second Loaded/scan would incorrectly make 24.
  assert_eq(account.snapshot().cumulative.inflate_bytes, 16L)
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  let before = account.snapshot()
  let parent = session.indexed.unwrap().objects.get(6).unwrap()
  assert_true(loaded_objstm_result(parent) is Err(BudgetExceeded(_)))
  assert_true(account.snapshot() == before)
}

///|
async test "Loaded ObjStm Flate cap was already effective before the new local ledger scope" {
  let (owner, account, object) = loaded_objstm_fixture(
    loaded_objstm_limits(inflate_bytes=Some(7L)),
  )
  defer @input.end_input_session(owner)
  assert_true(
    loaded_objstm_result(object)
    is Err(
      BudgetExceeded(
        LimitExceeded(Cumulative(InflateBytes), used=0L, requested=8L, limit=7L)
      )
    ),
  )
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  assert_eq(account.snapshot().cumulative.parse_work, 0L)
  assert_eq(account.snapshot().resident.cache_bytes, 0L)
}

///|
async test "Loaded ObjStm corrupt Adler still wins before newly added local ParseWork admission" {
  let (owner, account, object) = loaded_objstm_fixture(
    loaded_objstm_limits(parse_work=Some(0L)),
    corrupt_adler=true,
  )
  defer @input.end_input_session(owner)
  assert_true(
    loaded_objstm_result(object)
    is Err(StreamIntegrityFailed(ChecksumMismatch, _)),
  )
  assert_true(account.failure() is None)
  assert_true(@input.input_source_failure(owner.source) is Some(InputError(_)))
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
  assert_eq(account.snapshot().cumulative.parse_work, 0L)
  assert_eq(account.snapshot().resident.cache_bytes, 0L)
  let before = account.snapshot()
  assert_true(loaded_objstm_result(object) is Err(ReadFailed(_)))
  assert_true(account.snapshot() == before)
}
