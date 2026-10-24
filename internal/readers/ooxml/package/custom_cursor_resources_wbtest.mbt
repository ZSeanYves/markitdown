///|
fn custom_scope(
  working~ : Int64? = None,
  work~ : Int64? = None,
) -> (@budget.BudgetContext, Array[@budget.BudgetLease]) {
  let account = @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=work,
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes=working,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
  let retained : Array[@budget.BudgetLease] = []
  let context = @budget.BudgetContext::new(account, fn(kind, amount) {
    match account.reserve(kind, amount) {
      Ok(lease) => {
        retained.push(lease)
        Ok(())
      }
      Err(error) => Err(error)
    }
  })
  (context, retained)
}

///|
async fn custom_budget_fixture(
  payload : Bytes,
  context : @budget.BudgetContext,
) -> OoxmlPackage {
  open_ooxml_archive(
    @zip.open_zip(
      @zip.build_store_zip_bytes([
        ("[Content_Types].xml", b"<Types/>"),
        ("docProps/custom.xml", payload),
      ]),
      budget_context=context,
    ),
  )
}

///|
async test "custom structural partition matrix retains wrapper attributes namespaces and CDATA characters" {
  let custom_uri = "http://schemas.openxmlformats.org/officeDocument/2006/custom-properties"
  let vt_uri = "http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"
  let xml = "<Properties xmlns='" +
    custom_uri +
    "' xmlns:vt='" +
    vt_uri +
    "' xmlns:q='urn:outer'>" +
    "<property name='😀' fmtid='{D5CDD505-2E9C-101B-9397-08002B2CF9AE}' pid='2'><vt:vector baseType='lpwstr' size='2'>" +
    "<vt:lpwstr>😀&amp;lt;\r\nA&#13;Z</vt:lpwstr>" +
    "<vt:lpwstr><![CDATA[B &amp; <x>]]></vt:lpwstr>" +
    "</vt:vector></property></Properties>"
  let expected = "<vt:vector xmlns=\"" +
    custom_uri +
    "\" xmlns:vt=\"" +
    vt_uri +
    "\" xmlns:q=\"urn:outer\" baseType=\"lpwstr\" size=\"2\">" +
    "<vt:lpwstr>😀&amp;lt;\nA&#13;Z</vt:lpwstr>" +
    "<vt:lpwstr>B &amp;amp; &lt;x&gt;</vt:lpwstr></vt:vector>"
  for chunk_size in [1, 2, 3, 7, 65536] {
    let pkg = open_ooxml_package(
      @zip.build_store_zip_bytes([
        ("[Content_Types].xml", b"<Types/>"),
        ("docProps/custom.xml", b"\xef\xbb\xbf" + @utf8.encode(xml)),
      ]),
    )
    let values = read_custom_values(pkg, chunk_size~)
    assert_eq(
      values.map(value => (value.name, value.value, value.value_type)),
      [("😀", expected, Some("vector"))],
    )
    let limits = @xml.XmlCursorLimits::new(
      MeasurementOnly,
      max_depth=None,
      max_token_bytes=None,
      max_attributes=None,
      max_tokens=None,
      text_fragment_bytes=8,
    ).unwrap()
    let cursor = @xml.new_xml_cursor(limits).unwrap()
    defer cursor.close()
    cursor.feed(@utf8.encode(values[0].value), eof=true).unwrap()
    let texts : Array[String] = []
    let names : Array[(String, String?)] = []
    while true {
      match cursor.next().unwrap() {
        End => break
        Token(StartElement(name, _, _, _)) =>
          names.push((name.raw, name.namespace_uri))
        Token(TextFragment(text)) => texts.push(text.text)
        _ => ()
      }
    }
    assert_eq(names, [
      ("vt:vector", Some(vt_uri)),
      ("vt:lpwstr", Some(vt_uri)),
      ("vt:lpwstr", Some(vt_uri)),
    ])
    assert_eq(texts.join(""), "😀&lt;\nA\rZB &amp; <x>")
  }
}

///|
async test "custom namespace stack preserves QName value bindings shadowing and sibling restoration" {
  let pkg = custom_contract_fixture(
    "<Properties xmlns:vt='urn:vt' xmlns:q='urn:outer'>" +
    "<property name='one' xmlns:q='urn:property'><vt:opaque kind='q:T'>" +
    "<q:x xmlns:q='urn:inner'/><q:y/>" +
    "</vt:opaque></property>" +
    "<property name='two'><vt:opaque kind='q:U'/></property>" +
    "</Properties>",
  )
  let values = read_custom_properties(pkg)
  assert_eq(
    values[0].value,
    "<vt:opaque xmlns:vt=\"urn:vt\" xmlns:q=\"urn:property\" kind=\"q:T\"><q:x xmlns:q=\"urn:inner\"/><q:y/></vt:opaque>",
  )
  assert_eq(
    values[1].value,
    "<vt:opaque xmlns:vt=\"urn:vt\" xmlns:q=\"urn:outer\" kind=\"q:U\"/>",
  )
}

///|
async test "custom legacy selection stays raw property and first vt while selfclosing cannot steal next row" {
  assert_eq(
    custom_contract_values(
      "<p:property name='ignored'><vt:i4>1</vt:i4></p:property>" +
      "<property name='alternate' xmlns:v='http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes'><v:i4>2</v:i4></property>" +
      "<property name='foreign' xmlns:vt='urn:foreign'><vt:i4>003</vt:i4></property>" +
      "<property name='skip'/><property name='next'><vt:i4>4</vt:i4></property>" +
      "<property name='escapes'><vt:bstr>_x005F_x0008_ &amp;lt;</vt:bstr></property>",
    ),
    [
      ("alternate", "", None),
      ("foreign", "003", Some("i4")),
      ("next", "4", Some("i4")),
      ("escapes", "_x005F_x0008_ &lt;", Some("bstr")),
    ],
  )
}

///|
async test "custom projected cache admits exact UTF8 UTF16 payloads once and returns shallow array copies" {
  let payload = @utf8.encode(
    "<r><property name='n'><vt:lpwstr>😀</vt:lpwstr></property></r>",
  )
  let (context, retained) = content_types_scope(
    cache=Some(18L),
    metadata=Some(11L),
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
  let first = read_custom_properties(pkg)
  assert_eq(first[0].value, "😀")
  let before = context.account.snapshot()
  assert_eq(before.cumulative.source_metadata_bytes, 11L)
  assert_eq(before.resident.cache_bytes, 18L)
  assert_eq(before.resident.working_bytes, 8L + payload.length().to_int64())
  let reads_before = reads.val
  first.clear()
  assert_eq(read_custom_properties(pkg).length(), 1)
  assert_eq(reads.val, reads_before)
  assert_true(context.account.snapshot() == before)
  assert_true(context.account.charge(ParseWork, 9223372036854775807L) is Err(_))
  let result = try read_custom_properties(pkg) |> Ok catch {
    error => Err(error)
  }
  assert_true(result is Err(BudgetExceeded(_)))
}

///|
async test "custom typed metadata and cache limits fail before publishing projected cache" {
  let payload = @utf8.encode(
    "<r><property name='n'><vt:lpwstr>😀</vt:lpwstr></property></r>",
  )
  for cache_limit in [false, true] {
    let (context, retained) = if cache_limit {
      content_types_scope(cache=Some(17L))
    } else {
      content_types_scope(metadata=Some(10L))
    }
    defer content_types_scope_end(context, retained)
    let pkg = custom_budget_fixture(payload, context)
    let result = try read_custom_properties(pkg) |> Ok catch {
      error => Err(error)
    }
    assert_true(result is Err(BudgetExceeded(LimitExceeded(_, ..))))
    assert_true(pkg.custom_properties_cache.val is None)
    assert_true(@zip.archive_hard_failure(pkg.archive) is Some(_))
    assert_eq(
      context.account.snapshot().resident.working_bytes,
      8L + payload.length().to_int64(),
    )
  }
}

///|
async test "custom namespace and value workspace participates in typed budget cleanup" {
  let payload = @utf8.encode(
    "<r xmlns:vt='urn:vt'><property name='n'><vt:vector size='1' baseType='lpwstr'><vt:lpwstr>abcdefgh</vt:lpwstr></vt:vector></property></r>",
  )
  for work_limit in [false, true] {
    let (context, retained) = custom_scope()
    let pkg = custom_budget_fixture(payload, context)
    ignore(read_custom_properties(pkg))
    let snapshot = context.account.snapshot()
    content_types_scope_end(context, retained)
    let (limited, held) = if work_limit {
      custom_scope(work=Some(snapshot.cumulative.parse_work - 1L))
    } else {
      custom_scope(working=Some(snapshot.resident_peak.working_bytes - 1L))
    }
    defer content_types_scope_end(limited, held)
    let pkg = custom_budget_fixture(payload, limited)
    let result = try read_custom_properties(pkg) |> Ok catch {
      error => Err(error)
    }
    assert_true(result is Err(BudgetExceeded(LimitExceeded(_, ..))))
    assert_true(pkg.custom_properties_cache.val is None)
    assert_eq(
      limited.account.snapshot().resident.working_bytes,
      8L + payload.length().to_int64(),
    )
  }
}

///|
async test "cancelling custom read releases active namespaces name type and value without publishing cache" {
  let payload = b"<r xmlns:vt='urn:vt' xmlns:q='urn:q'><property name='name'><vt:vector>" +
    Bytes::from_array(Array::make(70000, b'x')) +
    b"</vt:vector></property></r>"
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
      @async.handle_cancellation(() => read_custom_properties(pkg))
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
  assert_true(pkg.custom_properties_cache.val is None)
  assert_eq(context.account.snapshot().resident.working_bytes, 8L + 65536L)
}
