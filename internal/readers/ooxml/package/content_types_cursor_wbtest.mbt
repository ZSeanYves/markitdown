///|
async fn content_types_fixture(xml : String) -> OoxmlPackage raise OoxmlError {
  open_ooxml_package(
    @zip.build_store_zip_bytes([
      ("[Content_Types].xml", @utf8.encode(xml)),
      ("document.xml", b"<r/>"),
    ]),
  )
}

///|
async test "content types quoted greater-than preserves the complete attribute" {
  let pkg = content_types_fixture(
    "<Types><Default Extension='xml' ContentType='application/x>a'/></Types>",
  )
  assert_eq(lookup_content_type_default(pkg, "xml"), Some("application/x>a"))
}

///|
async test "content types comments cannot inject a fake Default or Override" {
  let pkg = content_types_fixture(
    "<Types><!-- <Default Extension='xml' ContentType='fake'/><Override PartName='/document.xml' ContentType='fake'/> --><Default Extension='xml' ContentType='real'/></Types>",
  )
  assert_eq(lookup_content_type_default(pkg, "xml"), Some("real"))
  assert_eq(lookup_content_type_override(pkg, "document.xml"), None)
}

///|
async test "content types values decode predefined and numeric entities exactly once" {
  let pkg = content_types_fixture(
    "<Types><Default Extension='xml' ContentType='application/x-&amp;lt;&#x41;'/><Override PartName='/a&amp;b.xml' ContentType='once-&amp;amp;'/></Types>",
  )
  assert_eq(
    lookup_content_type_default(pkg, "xml"),
    Some("application/x-&lt;A"),
  )
  assert_eq(lookup_content_type_override(pkg, "a&b.xml"), Some("once-&amp;"))
}

///|
async test "content types match the root namespace and restore rebound prefixes" {
  let pkg = content_types_fixture(
    "<Types xmlns='http://schemas.openxmlformats.org/package/2006/content-types' xmlns:p='http://schemas.openxmlformats.org/package/2006/content-types' xmlns:f='urn:foreign'><Default Extension='plain' ContentType='plain'/><p:Default Extension='prefixed' ContentType='prefixed'/><f:Default Extension='foreign' ContentType='wrong'/><p:Default xmlns:p='urn:foreign' Extension='shadow' ContentType='wrong'/><p:Default Extension='restored' ContentType='restored'/><Default xmlns='urn:foreign' Extension='foreign-default' ContentType='wrong'/><Default xmlns='' Extension='unbound-default' ContentType='wrong'/></Types>",
  )
  assert_eq(lookup_content_type_default(pkg, "plain"), Some("plain"))
  assert_eq(lookup_content_type_default(pkg, "prefixed"), Some("prefixed"))
  assert_eq(lookup_content_type_default(pkg, "restored"), Some("restored"))
  for extension in ["foreign", "shadow", "foreign-default", "unbound-default"] {
    assert_eq(lookup_content_type_default(pkg, extension), None)
  }
  let legacy = content_types_fixture(
    "<Types><Default Extension='xml' ContentType='application/xml'/></Types>",
  )
  assert_eq(lookup_content_type_default(legacy, "xml"), Some("application/xml"))
}

///|
fn content_types_scope(
  cache~ : Int64? = None,
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
      cache_bytes=cache,
      working_bytes=None,
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
fn content_types_scope_end(
  context : @budget.BudgetContext,
  retained : Array[@budget.BudgetLease],
) -> Unit raise {
  for lease in retained {
    lease.release()
  }
  assert_true(context.account.close() is Ok(_))
  assert_eq(context.account.snapshot().active_leases, 0L)
}

///|
fn content_types_late_payload(invalid_utf8 : Bool) -> Bytes {
  let builder = StringBuilder()
  builder.write_string(
    "<Types><Default Extension='xml' ContentType='application/xml'/>",
  )
  for _ in 0..<70000 {
    builder.write_char(' ')
  }
  let prefix = @utf8.encode(builder.to_string())
  prefix + (if invalid_utf8 { b"\xff" } else { b"" }) + b"</Types>"
}

///|
async test "late content types UTF8 failure publishes no package or retained full XML cache" {
  let payload = content_types_late_payload(true)
  let (context, retained) = content_types_scope()
  defer content_types_scope_end(context, retained)
  let archive = @zip.open_zip(
    @zip.build_store_zip_bytes([("[Content_Types].xml", payload)]),
    budget_context=context,
  )
  let published : Ref[OoxmlPackage?] = Ref(None)
  let result = try {
    published.val = Some(open_ooxml_archive(archive))
    Ok(())
  } catch {
    error => Err(error)
  }
  assert_true(result is Err(InvalidEncoding(_)))
  assert_true(published.val is None)
  assert_true(@zip.archive_hard_failure(archive) is Some(_))
  assert_true(
    context.account.snapshot().resident.cache_bytes <
    payload.length().to_int64(),
  )
  assert_eq(context.account.snapshot().resident.cache_bytes, 36L)
}

///|
async test "late content types CRC failure publishes no package or retained full XML cache" {
  let payload = content_types_late_payload(false)
  let bytes = @zip.build_store_zip_bytes([("[Content_Types].xml", payload)])
  let slice = @zip.read_entry_data_slice(
    @zip.open_zip(bytes),
    "[Content_Types].xml",
  )
  let damaged = bytes.to_array()
  damaged[slice.data_start + 65537] = b'\t'
  let (context, retained) = content_types_scope()
  defer content_types_scope_end(context, retained)
  let archive = @zip.open_zip(
    Bytes::from_array(damaged),
    budget_context=context,
  )
  let published : Ref[OoxmlPackage?] = Ref(None)
  let result = try {
    published.val = Some(open_ooxml_archive(archive))
    Ok(())
  } catch {
    error => Err(error)
  }
  assert_true(result is Err(ZipError(_)))
  assert_true(published.val is None)
  assert_true(@zip.archive_hard_failure(archive) is Some(_))
  assert_true(
    context.account.snapshot().resident.cache_bytes <
    payload.length().to_int64(),
  )
  assert_eq(context.account.snapshot().resident.cache_bytes, 36L)
}

///|
async test "content types cursor partition matrix preserves decoded maps and profile statistics" {
  let payload = @utf8.encode(
    "<p:Types xmlns:p='http://schemas.openxmlformats.org/package/2006/content-types'><p:Default Extension='xml' ContentType='x>😀&amp;lt;'/><p:Override PartName='/a&amp;b.xml' ContentType='override'/></p:Types>",
  )
  let bytes = @zip.build_store_zip_bytes([("[Content_Types].xml", payload)])
  for chunk_size in [1, 2, 3, 7, 65536] {
    let parsed = read_archive_content_types(@zip.open_zip(bytes), chunk_size~)
    assert_eq(parsed.defaults.get("xml"), Some("x>😀&lt;"))
    assert_eq(parsed.overrides.get("/a&b.xml"), Some("override"))
    assert_eq(parsed.stats.input_bytes, payload.length().to_int64())
    assert_eq(parsed.stats.logical_tokens, 4L)
    assert_eq(parsed.stats.max_depth, 2L)
    assert_eq(parsed.stats.max_attributes, 2L)
    assert_eq(parsed.stats.max_namespace_bindings, 1L)
  }
}

///|
async test "content types escaped map strings keep scope-owned cache reservations after cursor EOF and map removal" {
  let payload = b"<Types><Default Extension='xml' ContentType='application/xml'/></Types>"
  let (context, retained) = content_types_scope(
    cache=Some(36L),
    metadata=Some(18L),
  )
  defer content_types_scope_end(context, retained)
  let archive = @zip.open_zip(
    @zip.build_store_zip_bytes([("[Content_Types].xml", payload)]),
    budget_context=context,
  )
  let pkg = open_ooxml_archive(archive)
  assert_eq(context.account.snapshot().resident.cache_bytes, 36L)
  assert_eq(context.account.snapshot().cumulative.source_metadata_bytes, 18L)
  assert_eq(
    context.account.snapshot().cumulative.inflate_bytes,
    payload.length().to_int64(),
  )
  // The ZIP visitor's owned Bytes callback conservatively retains delivered
  // chunks until scope cleanup. Cursor-private workspace is already released.
  assert_eq(
    context.account.snapshot().resident.working_bytes,
    payload.length().to_int64(),
  )
  assert_eq(pkg.part_cache.bytes_by_part.length(), 0)
  assert_eq(pkg.part_cache.text_by_part.length(), 0)
  let held = lookup_content_type_default(pkg, "xml")
  pkg.content_types_default.remove("xml")
  assert_eq(held, Some("application/xml"))
  assert_eq(context.account.snapshot().resident.cache_bytes, 36L)
  assert_eq(
    inspect_content_types_cursor(pkg).input_bytes,
    payload.length().to_int64(),
  )
}

///|
async test "content types cache and source metadata caps propagate typed ResourceLimit errors" {
  let payload = b"<Types><Default Extension='xml' ContentType='application/xml'/></Types>"
  for cache_limit in [true, false] {
    let (context, retained) = if cache_limit {
      content_types_scope(cache=Some(35L))
    } else {
      content_types_scope(metadata=Some(17L))
    }
    defer content_types_scope_end(context, retained)
    let archive = @zip.open_zip(
      @zip.build_store_zip_bytes([("[Content_Types].xml", payload)]),
      budget_context=context,
    )
    let result = try open_ooxml_archive(archive) |> Ok catch {
      error => Err(error)
    }
    let error = match result {
      Err(BudgetExceeded(error)) => error
      _ =>
        fail("content type metadata/cache limits must preserve BudgetExceeded")
    }
    if cache_limit {
      assert_true(
        error
        is LimitExceeded(
          Resident(CacheBytes),
          used=0L,
          requested=36L,
          limit=35L
        ),
      )
    } else {
      assert_true(
        error
        is LimitExceeded(
          Cumulative(SourceMetadataBytes),
          used=0L,
          requested=18L,
          limit=17L
        ),
      )
    }
    assert_true(
      @oxi.classify_ooxml_error(BudgetExceeded(error)).kind == ResourceLimit,
    )
    assert_true(@zip.archive_hard_failure(archive) is Some(_))
    assert_eq(context.account.snapshot().resident.cache_bytes, 0L)
  }
}

///|
async test "content types consumes each delivered chunk before requesting the next ZIP body range" {
  let payload = content_types_late_payload(false)
  let bytes = @zip.build_store_zip_bytes([("[Content_Types].xml", payload)])
  let slice = @zip.read_entry_data_slice(
    @zip.open_zip(bytes),
    "[Content_Types].xml",
  )
  let (context, retained) = content_types_scope()
  defer content_types_scope_end(context, retained)
  let at_second_range : Ref[(Int64, Int64)?] = Ref(None)
  let archive = @zip.open_zip_reader(
    bytes.length(),
    fn(offset, length) {
      if offset == slice.data_start + 64 * 1024 {
        let snapshot = context.account.snapshot()
        at_second_range.val = Some(
          (
            snapshot.cumulative.source_metadata_bytes,
            snapshot.resident.cache_bytes,
          ),
        )
      }
      Ok(bytes[offset:(offset + length).min(bytes.length())].to_owned())
    },
    budget_context=context,
  )
  let pkg = open_ooxml_archive(archive)
  assert_eq(at_second_range.val, Some((18L, 36L)))
  assert_eq(lookup_content_type_default(pkg, "xml"), Some("application/xml"))
}

///|
async test "content types preserves an earlier archive integrity failure before missing metadata" {
  let bytes = @zip.build_store_zip_bytes([("other.xml", b"<r/>")])
  let slice = @zip.read_entry_data_slice(@zip.open_zip(bytes), "other.xml")
  let damaged = bytes.to_array()
  damaged[slice.data_start] = b'!'
  let archive = @zip.open_zip(Bytes::from_array(damaged))
  let prior = try @zip.read_entry(archive, "other.xml") |> Ok catch {
    error => Err(error)
  }
  assert_true(prior is Err(ChecksumMismatch(_, _, _)))
  let opened = try open_ooxml_archive(archive) |> Ok catch {
    error => Err(error)
  }
  assert_true(opened is Err(ZipError(_)))
}
