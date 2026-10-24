///|
fn paragraph_test_scope(
  context~ : @budget.BudgetContext? = None,
) -> DocxParagraphScope {
  {
    frames: [],
    properties: Map([]),
    leases: [],
    context,
    collect_properties: true,
    depth: 0,
    pending: None,
  }
}

///|
fn paragraph_budget_scope(
  working~ : Int64? = None,
  metadata~ : Int64? = None,
) -> (@budget.BudgetContext, Array[@budget.BudgetLease]) {
  let account = @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=None,
      output_utf8_bytes=None,
      source_metadata_bytes=metadata,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes=working,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
  let retained : Array[@budget.BudgetLease] = []
  (
    @budget.BudgetContext::new(account, fn(kind, amount) {
      match account.reserve(kind, amount) {
        Ok(lease) => {
          retained.push(lease)
          Ok(())
        }
        Err(error) => Err(error)
      }
    }),
    retained,
  )
}

///|
test "paragraph raw UTF16 spans retain nonBMP CRLF entities comments and quoted delimiters" {
  for leading in ["", "😀\r\n", "<!--😀 >-->", " "] {
    let first = "<w:r note='>'><w:rPr><w:rStyle w:val='😀&amp;lt;'/></w:rPr><w:t>😀\r\n&amp;lt;</w:t></w:r>"
    let link_xml = "<w:hyperlink w:anchor='a>b'><w:r><w:t>second&amp;amp;</w:t></w:r></w:hyperlink>"
    let raw = leading + first + link_xml
    let scope = paragraph_test_scope()
    defer scope.close()
    scan_docx_paragraph_scope(scope, raw)
    assert_eq(scope.frames.length(), 2)
    let run = scope.frames[0]
    assert_eq(run.start, leading.length())
    assert_eq(raw[run.start:run.end].to_owned(), first)
    assert_eq(
      raw[run.open_end:run.close_start].to_owned(),
      "<w:rPr><w:rStyle w:val='😀&amp;lt;'/></w:rPr><w:t>😀\r\n&amp;lt;</w:t>",
    )
    assert_eq(run.style_id, Some("😀&lt;"))
    let link = scope.frames[1]
    assert_eq(link.start, leading.length() + first.length())
    assert_eq(raw[link.start:link.end].to_owned(), link_xml)
  }
}

///|
test "DOCX fragment compatibility preserves raw QName selection with bound and unbound prefixes" {
  for
    raw in [
      "<w:r><w:t>x</w:t></w:r>", "<w:r xmlns:w='urn:foreign'><w:t>x</w:t></w:r>",
      "<w:r xmlns:w='urn:outer'><w:t xmlns:w='urn:inner'>x</w:t></w:r>",
    ] {
    let scope = paragraph_test_scope()
    defer scope.close()
    scan_docx_paragraph_scope(scope, raw)
    assert_eq(scope.frames[0].tag, "w:r")
    assert_eq(scope.frames[0].start, 0)
    assert_eq(scope.frames[0].end, raw.length())
  }
}

///|
test "paragraph scope workspace and cursor failures release all local leases" {
  let raw = "<w:r><w:t>😀</w:t></w:r>"
  for cap in [0L, @input.validated_text_utf8_size(raw).unwrap()] {
    let (context, retained) = paragraph_budget_scope(working=Some(cap))
    let scope = paragraph_test_scope(context=Some(context))
    let failed = try {
      scan_docx_paragraph_scope(scope, raw)
      false
    } catch {
      Cursor(Budget(_)) => true
      _ => false
    }
    assert_true(failed)
    assert_true(
      context.account.failure()
      is Some(LimitExceeded(Resident(WorkingBytes), ..)),
    )
    scope.close()
    scope.close()
    assert_eq(context.account.snapshot().resident.working_bytes, 0L)
    assert_eq(retained.length(), 0)
    ignore(context.account.close())
  }
}

///|
test "paragraph property escaping charges UTF8 metadata and UTF16 cache once" {
  let (context, retained) = paragraph_budget_scope()
  let scope = paragraph_test_scope(context=Some(context))
  scan_docx_paragraph_scope(scope, "<w:pPr><w:pStyle w:val='😀'/></w:pPr>")
  let value = scope.properties.get("w:pStyle").unwrap()
  docx_paragraph_escape(scope, value)
  assert_eq(context.account.snapshot().cumulative.source_metadata_bytes, 4L)
  assert_eq(context.account.snapshot().resident.cache_bytes, 4L)
  scope.close()
  assert_eq(context.account.snapshot().resident.working_bytes, 0L)
  assert_eq(context.account.snapshot().resident.cache_bytes, 4L)
  for lease in retained {
    lease.release()
  }
  assert_true(context.account.close() is Ok(_))
}

///|
async test "paragraph budget failure is latched before any domain projection or later package read" {
  let (context, retained) = paragraph_budget_scope(metadata=Some(0L))
  defer {
    for lease in retained {
      lease.release()
    }
    ignore(context.account.close())
  }
  let archive = @dzip.open_zip(
    @dzip.build_store_zip_bytes([("[Content_Types].xml", b"<Types/>")]),
    budget_context=context,
  )
  let pkg = @ox.open_ooxml_archive(archive)
  let working_before = context.account.snapshot().resident.working_bytes
  let projected = analyze_docx_paragraph(
    "<w:pPr><w:pStyle w:val='😀'/></w:pPr><w:r><w:t>body</w:t></w:r>",
    docx_source_key("word/document.xml", 0, "p"),
    [],
    Some(pkg),
    [],
  )
  assert_eq(projected.runs.length(), 0)
  assert_eq(projected.style_id, None)
  assert_true(
    context.account.failure()
    is Some(LimitExceeded(Cumulative(SourceMetadataBytes), ..)),
  )
  assert_true(@dzip.archive_hard_failure(archive) is Some(_))
  let result = try parse_docx_source_from_package(pkg) |> Ok catch {
    error => Err(error)
  }
  assert_true(result is Err(OoxmlFailure(_)))
  assert_eq(context.account.snapshot().resident.working_bytes, working_before)
}

///|
async test "cancelling a paragraph opaque helper releases retained discovery fields and raw encoding" {
  let rels = b"<Relationships><Relationship Id='link' Type='hyperlink' Target='https://example.test/' TargetMode='External'/></Relationships>"
  let raw_zip = @dzip.build_store_zip_bytes([
    ("[Content_Types].xml", b"<Types/>"),
    ("word/_rels/document.xml.rels", rels),
  ])
  let slice = @dzip.read_entry_data_slice(
    @dzip.open_zip(raw_zip),
    "word/_rels/document.xml.rels",
  )
  let (context, retained) = paragraph_budget_scope()
  defer {
    for lease in retained {
      lease.release()
    }
    ignore(context.account.close())
  }
  let entered = Ref(false)
  let resumed = Ref(false)
  let enabled = Ref(false)
  let archive = @dzip.open_zip_reader(
    raw_zip.length(),
    async fn(offset, length) {
      if enabled.val && offset == slice.data_start {
        entered.val = true
        @async.sleep(60000)
        resumed.val = true
      }
      Ok(raw_zip[offset:offset + length].to_owned())
    },
    budget_context=context,
  )
  let pkg = @ox.open_ooxml_archive(archive)
  enabled.val = true
  let raw = "<w:pPr><w:pStyle w:val='😀'/></w:pPr><w:hyperlink r:id='link'><w:r><w:t>link</w:t></w:r></w:hyperlink>"
  let working_at_await = Ref(0L)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        analyze_docx_paragraph(
          raw,
          docx_source_key("word/document.xml", 0, "p"),
          [],
          Some(pkg),
          [],
        )
      })
    })
    while !entered.val {
      @async.pause()
    }
    working_at_await.val = context.account.snapshot().resident.working_bytes
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_true(!resumed.val)
  // The ZIP reader may retain its conservative scope buffer. Our complete
  // encoded paragraph and held field Strings must no longer be charged.
  assert_true(
    context.account.snapshot().resident.working_bytes <=
    working_at_await.val - @input.validated_text_utf8_size(raw).unwrap() - 4L,
  )
  assert_true(context.account.failure() is None)
}

///|
async test "direct DOCX String rejects invalid UTF16 before cursor encoding" {
  let invalid = String::from_array([(0xD800).unsafe_to_char()])
  let result = try
    parse_docx_source_document_xml(
      "word/document.xml",
      "<w:document><w:body><w:p><w:r><w:t>" +
      invalid +
      "</w:t></w:r></w:p></w:body></w:document>",
    )
    |> Ok
  catch {
    error => Err(error)
  }
  assert_true(result is Err(MalformedDocument(_)))
}
