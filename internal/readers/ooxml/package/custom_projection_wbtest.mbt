///|
fn custom_prefix_policy(limit : Int32) -> CustomPropertyProjectionPolicy {
  {
    max_candidates: Some(limit),
    qualified_value_type: true,
    omit_empty_scalar_values: true,
  }
}

///|
async test "bounded custom projection consumes candidate slots before filtering and counts only completed extras" {
  for
    tail in [
      "<property name='tail'><vt:i4>2</vt:i4></property>", "<property name='tail'/>",
      "<property name='tail'><vt:i4>2",
    ] {
    let pkg = custom_contract_fixture(
      "<r><property><property name='inner'><vt:i4>1</vt:i4></property></property>" +
      tail +
      "</r>",
    )
    let selected = read_custom_properties_projected(pkg, max_candidates=1)
    assert_eq(selected.properties.length(), 0)
    assert_eq(selected.limit_exceeded, !tail.has_suffix("2"))
  }
  let pkg = custom_contract_fixture(
    "<r><!-- <property name='fake'><vt:i4>0</vt:i4></property> -->" +
    "<property name='one'><vt:i4>1</vt:i4></property></r>",
  )
  let selected = read_custom_properties_projected(pkg, max_candidates=1)
  assert_eq(selected.properties[0].name, "one")
  assert_false(selected.limit_exceeded)
}

///|
async test "bounded custom projection zero and negative configuration never imply unlimited selection" {
  let pkg = custom_contract_fixture(
    "<r><property name='one'><vt:i4>1</vt:i4></property></r>",
  )
  let selected = read_custom_properties_projected(pkg, max_candidates=0)
  assert_eq(selected.properties.length(), 0)
  assert_true(selected.limit_exceeded)
  let rejected = try
    read_custom_properties_projected(pkg, max_candidates=-1) |> Ok
  catch {
    error => Err(error)
  }
  assert_true(rejected is Err(InvalidXml(_)))
}

///|
async test "bounded custom projection partition matrix uses shared character and structural semantics" {
  let xml = "<r xmlns:vt='urn:vt' xmlns:q='urn:q'>" +
    "<property name='😀'><vt:vector size='1' baseType='lpwstr'><vt:lpwstr note='a>b'>😀&amp;lt;\r\nA&#13;<![CDATA[<raw>&amp;]]></vt:lpwstr></vt:vector></property>" +
    "<property name='later'><vt:i4>2</vt:i4></property></r>"
  let expected = "<vt:vector xmlns:vt=\"urn:vt\" xmlns:q=\"urn:q\" size=\"1\" baseType=\"lpwstr\"><vt:lpwstr note=\"a&gt;b\">😀&amp;lt;\nA&#13;&lt;raw&gt;&amp;amp;</vt:lpwstr></vt:vector>"
  for chunk_size in [1, 2, 3, 7, 65536] {
    let pkg = open_ooxml_package(
      @zip.build_store_zip_bytes([
        ("[Content_Types].xml", b"<Types/>"),
        ("docProps/custom.xml", b"\xef\xbb\xbf" + @utf8.encode(xml)),
      ]),
    )
    let selected = read_custom_projection(
      pkg,
      custom_prefix_policy(1),
      chunk_size~,
    )
    assert_eq(
      selected.properties.map(value => {
        (value.name, value.value, value.value_type)
      }),
      [("😀", expected, Some("vt:vector"))],
    )
    assert_true(selected.limit_exceeded)
    assert_false(pkg.part_cache.bytes_by_part.contains("docProps/custom.xml"))
    assert_false(pkg.part_cache.text_by_part.contains("docProps/custom.xml"))
  }
}

///|
async test "bounded custom cache charges actual qualified type once and does not retain skipped values" {
  let payload = b"<r><property name='n'><vt:lpwstr>\xf0\x9f\x98\x80</vt:lpwstr></property>" +
    b"<property name='skipped'><vt:lpwstr>" +
    Bytes::from_array(Array::make(100000, b'x')) +
    b"</vt:lpwstr></property></r>"
  // n=1, raw vt:lpwstr=9, emoji=4 UTF8 bytes / 1+9+2 UTF16 units.
  let (context, retained) = content_types_scope(
    cache=Some(24L),
    metadata=Some(14L),
  )
  defer content_types_scope_end(context, retained)
  let raw = @zip.build_store_zip_bytes([
    ("[Content_Types].xml", b"<Types/>"),
    ("docProps/custom.xml", payload),
  ])
  let reads = Ref(0)
  let archive = @zip.open_zip_reader(
    raw.length(),
    fn(offset, length) {
      reads.val += 1
      Ok(raw[offset:offset + length].to_owned())
    },
    budget_context=context,
  )
  let pkg = open_ooxml_archive(archive)
  let first = read_custom_properties_projected(
    pkg,
    max_candidates=1,
    qualified_value_type=true,
    omit_empty_scalar_values=true,
  )
  assert_eq(first.properties[0].value_type, Some("vt:lpwstr"))
  assert_eq(first.properties[0].value, "😀")
  assert_true(first.limit_exceeded)
  let before = context.account.snapshot()
  assert_eq(before.cumulative.source_metadata_bytes, 14L)
  assert_eq(before.resident.cache_bytes, 24L)
  let reads_before = reads.val
  first.properties.clear()
  let second = read_custom_properties_projected(
    pkg,
    max_candidates=1,
    qualified_value_type=true,
    omit_empty_scalar_values=true,
  )
  assert_eq(second.properties.length(), 1)
  assert_eq(reads.val, reads_before)
  assert_true(context.account.snapshot() == before)
  assert_true(context.account.charge(ParseWork, 9223372036854775807L) is Err(_))
  let rejected = try
    read_custom_properties_projected(
      pkg,
      max_candidates=1,
      qualified_value_type=true,
      omit_empty_scalar_values=true,
    )
    |> Ok
  catch {
    error => Err(error)
  }
  assert_true(rejected is Err(BudgetExceeded(_)))
}

///|
async test "bounded projection cache policies do not alias unlimited or differently qualified results" {
  let pkg = custom_contract_fixture(
    "<r><property name='empty'><vt:i4/></property>" +
    "<property name='n'><vt:i4>2</vt:i4></property></r>",
  )
  let empty = read_custom_properties_projected(
    pkg,
    max_candidates=1,
    omit_empty_scalar_values=true,
  )
  assert_eq(empty.properties.length(), 0)
  assert_true(empty.limit_exceeded)
  let raw = read_custom_properties_projected(
    pkg,
    max_candidates=2,
    qualified_value_type=true,
  )
  assert_eq(raw.properties[0].value_type, Some("vt:i4"))
  assert_eq(raw.properties[0].value, "")
  assert_false(raw.limit_exceeded)
  let local_types = read_custom_properties_projected(pkg, max_candidates=2)
  assert_eq(local_types.properties[0].value_type, Some("i4"))
  assert_eq(read_custom_properties(pkg).length(), 2)
  assert_eq(read_custom_properties(pkg)[0].value_type, Some("i4"))
  assert_eq(pkg.custom_projections_cache.length(), 3)
}

///|
async test "bounded custom typed payload limits fail before cache publication" {
  for cache_limit in [false, true] {
    let (context, retained) = if cache_limit {
      content_types_scope(cache=Some(23L))
    } else {
      content_types_scope(metadata=Some(13L))
    }
    defer content_types_scope_end(context, retained)
    let pkg = custom_budget_fixture(
      b"<r><property name='n'><vt:lpwstr>\xf0\x9f\x98\x80</vt:lpwstr></property></r>",
      context,
    )
    let rejected = try
      read_custom_properties_projected(
        pkg,
        max_candidates=1,
        qualified_value_type=true,
        omit_empty_scalar_values=true,
      )
      |> Ok
    catch {
      error => Err(error)
    }
    assert_true(rejected is Err(BudgetExceeded(LimitExceeded(_, ..))))
    assert_true(pkg.custom_projections_cache.is_empty())
    assert_true(@zip.archive_hard_failure(pkg.archive) is Some(_))
  }
}

///|
async test "bounded custom skipped values still spend shared parse work and fail typed budget" {
  let payload = b"<r><property name='n'><vt:i4>1</vt:i4></property>" +
    b"<property name='later'><vt:lpwstr>" +
    Bytes::from_array(Array::make(70000, b'x')) +
    b"</vt:lpwstr></property></r>"
  let (context, retained) = custom_scope()
  let pkg = custom_budget_fixture(payload, context)
  ignore(read_custom_properties_projected(pkg, max_candidates=1))
  let work = context.account.snapshot().cumulative.parse_work
  content_types_scope_end(context, retained)
  let (limited, held) = custom_scope(work=Some(work - 1L))
  defer content_types_scope_end(limited, held)
  let pkg = custom_budget_fixture(payload, limited)
  let rejected = try
    read_custom_properties_projected(pkg, max_candidates=1) |> Ok
  catch {
    error => Err(error)
  }
  assert_true(rejected is Err(BudgetExceeded(LimitExceeded(_, ..))))
  assert_true(pkg.custom_projections_cache.is_empty())
}

///|
async test "bounded custom cancellation during skipped tail closes private state without publishing" {
  let payload = b"<r xmlns:vt='urn:vt'><property name='n'><vt:i4>1</vt:i4></property>" +
    b"<property name='skipped'><vt:lpwstr>" +
    Bytes::from_array(Array::make(70000, b'x')) +
    b"</vt:lpwstr></property></r>"
  let raw = @zip.build_store_zip_bytes([
    ("[Content_Types].xml", b"<Types/>"),
    ("docProps/custom.xml", payload),
  ])
  let slice = @zip.read_entry_data_slice(
    @zip.open_zip(raw),
    "docProps/custom.xml",
  )
  let (context, retained) = content_types_scope()
  defer content_types_scope_end(context, retained)
  let enabled = Ref(false)
  let entered = Ref(false)
  let resumed = Ref(false)
  let blocked_reads = Ref(0)
  let archive = @zip.open_zip_reader(
    raw.length(),
    async fn(offset, length) {
      if enabled.val && offset == slice.data_start + 65536 {
        blocked_reads.val += 1
        entered.val = true
        @async.sleep(60000)
        resumed.val = true
      }
      Ok(raw[offset:offset + length].to_owned())
    },
    budget_context=context,
  )
  let pkg = open_ooxml_archive(archive)
  enabled.val = true
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        read_custom_properties_projected(pkg, max_candidates=1)
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
  assert_true(pkg.custom_projections_cache.is_empty())
  assert_eq(context.account.snapshot().resident.working_bytes, 8L + 65536L)
}
