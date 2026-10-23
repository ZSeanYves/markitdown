///|
fn cursor_account(
  parse_work : Int64?,
  working_bytes : Int64?,
) -> @budget.Budget {
  @budget.Budget::new(
    @budget.BudgetLimits::new(
      @budget.MeasurementOnly,
      inflate_bytes=None,
      parse_work~,
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes~,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
}

///|
fn cursor_context(account : @budget.Budget) -> @budget.BudgetContext {
  @budget.BudgetContext::new(account, fn(_kind, _bytes) { Ok(()) })
}

///|
test "XML cursor charges one shared account deterministically and releases workspace at EOF" {
  let source = @utf8.encode(
    "<a:r xmlns:a='urn:a' x='&amp;lt;'>😀&amp;<![CDATA[abcdef]]></a:r>",
  )
  let mut work : Int64? = None
  for chunk_size in [1, 2, 3, 7, 65536] {
    let account = cursor_account(None, None)
    let cursor = @xml.new_xml_cursor(
      cursor_limits(),
      budget_context=cursor_context(account),
    ).unwrap()
    let mut offset = 0
    while true {
      match cursor.next().unwrap() {
        NeedInput => {
          let end = (offset + chunk_size).min(source.length())
          cursor
          .feed(source[offset:end].to_owned(), eof=end == source.length())
          .unwrap()
          offset = end
        }
        End => break
        Token(_) => ()
      }
    }
    let snapshot = account.snapshot()
    assert_true(snapshot.cumulative.parse_work > source.length().to_int64())
    if work is Some(expected) {
      assert_eq(snapshot.cumulative.parse_work, expected)
    } else {
      work = Some(snapshot.cumulative.parse_work)
    }
    assert_true(snapshot.resident_peak.working_bytes > 0L)
    assert_eq(snapshot.resident.working_bytes, 0L)
    assert_eq(snapshot.active_leases, 0L)
    assert_true(cursor.next() is Ok(End))
    cursor.close()
    account.close().unwrap()
  }
}

///|
test "XML cursor budget failure and early close release all workspace without resetting the shared account" {
  let account = cursor_account(Some(4L), None)
  let cursor = @xml.new_xml_cursor(
    cursor_limits(),
    budget_context=cursor_context(account),
  ).unwrap()
  cursor.feed(b"<r/>", eof=true).unwrap()
  assert_true(
    cursor.next()
    is Err(
      Budget(@budget.LimitExceeded(@budget.Cumulative(@budget.ParseWork), ..))
    ),
  )
  assert_true(cursor.next() is Err(Budget(_)))
  assert_eq(account.snapshot().cumulative.parse_work, 4L)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
  cursor.close()
  account.close().unwrap()

  let account = cursor_account(None, None)
  let cursor = @xml.new_xml_cursor(
    cursor_limits(),
    budget_context=cursor_context(account),
  ).unwrap()
  cursor.feed(b"<a:r xmlns:a='urn:a'>not yet consumed</a:r>", eof=true).unwrap()
  assert_true(cursor.next() is Ok(Token(StartElement(_, _, false, _))))
  assert_true(account.snapshot().resident.working_bytes > 0L)
  let work = account.snapshot().cumulative.parse_work
  cursor.close()
  cursor.close()
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
  assert_eq(account.snapshot().cumulative.parse_work, work)
  account.close().unwrap()

  let account = cursor_account(None, Some(3L))
  let cursor = @xml.new_xml_cursor(
    cursor_limits(),
    budget_context=cursor_context(account),
  ).unwrap()
  assert_true(
    cursor.feed(b"<r/>", eof=true)
    is Err(
      Budget(@budget.LimitExceeded(@budget.Resident(@budget.WorkingBytes), ..))
    ),
  )
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
  account.close().unwrap()

  let account = cursor_account(Some(0L), None)
  let cursor = @xml.new_xml_cursor(
    cursor_limits(),
    budget_context=cursor_context(account),
  ).unwrap()
  assert_true(account.charge(@budget.ParseWork, 1L) is Err(_))
  // A foreign failure must be observed before NeedInput, which otherwise
  // authorizes the asynchronous driver to issue another read.
  assert_true(
    cursor.next()
    is Err(
      Budget(@budget.LimitExceeded(@budget.Cumulative(@budget.ParseWork), ..))
    ),
  )
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
  account.close().unwrap()
}

///|
test "XML cursor splits long text while its atomic markup cap stays small" {
  let builder = StringBuilder()
  builder.write_string("<r>")
  for _ in 0..<4096 {
    builder.write_char('x')
  }
  builder.write_string("</r>")
  let cursor = @xml.new_xml_cursor(cursor_limits(token=4L, fragment=16)).unwrap()
  defer cursor.close()
  cursor.feed(@utf8.encode(builder.to_string()), eof=true).unwrap()
  let mut fragments = 0
  let mut bytes = 0
  let mut first = 0
  let mut last = 0
  while true {
    match cursor.next().unwrap() {
      End => break
      NeedInput => fail("final input must not request another chunk")
      Token(TextFragment(value)) => {
        assert_true(value.text.length() <= 16)
        fragments += 1
        bytes += value.text.length()
        if value.first {
          first += 1
        }
        if value.last {
          last += 1
        }
      }
      Token(_) => ()
    }
  }
  assert_true(fragments > 1)
  assert_eq(bytes, 4096)
  assert_eq(first, 1)
  assert_eq(last, 1)
  assert_eq(cursor.stats().logical_tokens, 3L)
  assert_eq(cursor.stats().max_fragment_bytes, 16L)
}
