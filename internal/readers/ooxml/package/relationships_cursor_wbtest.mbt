///|
async fn relationships_cursor_fixture(
  rels : Bytes,
) -> OoxmlPackage raise OoxmlError {
  open_ooxml_package(
    @zip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      ("word/document.xml", b"<doc/>"),
      ("word/_rels/document.xml.rels", rels),
    ]),
  )
}

///|
async test "relationships cursor keeps quoted greater-than in target values" {
  let pkg = relationships_cursor_fixture(
    b"<Relationships><Relationship Id='a' Type='link' Target='https://example.com/a>b' TargetMode='External'/></Relationships>",
  )
  let rels = read_part_relationships(pkg, "word/document.xml")
  assert_eq(rels.length(), 1)
  assert_eq(rels[0].target, "https://example.com/a>b")
  assert_eq(rels[0].resolved_target, rels[0].target)
}

///|
async test "relationships comments cannot add a fake relationship or validation issue" {
  let pkg = relationships_cursor_fixture(
    b"<Relationships><!-- <Relationship Target='../../evil'/> --><Relationship Id='real' Type='image' Target='image.png'/></Relationships>",
  )
  let rels = read_part_relationships(pkg, "word/document.xml")
  assert_eq(rels.map(rel => rel.id), ["real"])
  let validation = validate_ooxml_package(pkg)
  assert_eq(validation.issue_count, 0)
}

///|
async test "relationship fields decode entities exactly once and validation sees the same rows" {
  let pkg = relationships_cursor_fixture(
    b"<Relationships><Relationship Id='r&amp;lt;' Type='urn:&#x41;' Target='a&amp;amp;.xml'/></Relationships>",
  )
  let rels = read_part_relationships(pkg, "word/document.xml")
  assert_eq(rels[0].id, "r&lt;")
  assert_eq(rels[0].rel_type, "urn:A")
  assert_eq(rels[0].target, "a&amp;.xml")
  assert_eq(rels[0].resolved_target, "word/a&amp;.xml")
  assert_eq(validate_ooxml_package(pkg).issue_count, 0)
}

///|
async test "relationship namespaces follow the root and restore rebound prefixes" {
  let pkg = relationships_cursor_fixture(
    b"<p:Relationships xmlns:p='http://schemas.openxmlformats.org/package/2006/relationships' xmlns:f='urn:foreign'><p:Relationship Id='first' Type='image' Target='a.png'/><f:Relationship Id='foreign' Type='image' Target='b.png'/><p:Relationship xmlns:p='urn:foreign' Id='rebound' Type='image' Target='c.png'/><p:Relationship Id='restored' Type='image' Target='d.png'/></p:Relationships>",
  )
  assert_eq(
    read_part_relationships(pkg, "word/document.xml").map(rel => rel.id),
    ["first", "restored"],
  )
  assert_eq(validate_ooxml_package(pkg).issue_count, 0)
}

///|
async test "relationships cursor requires final XML EOF before publishing an index" {
  let pkg = relationships_cursor_fixture(
    b"<Relationships><Relationship Id='a' Type='image' Target='a.png'/></Wrong>",
  )
  let result = try
    read_part_relationships(pkg, "word/document.xml") |> Ok
  catch {
    error => Err(error)
  }
  assert_true(result is Err(InvalidXml(_)))
  assert_eq(pkg.relationship_cache.index_by_rels_part.length(), 0)
}

///|
async test "relationship reader and strict validation preserve distinct missing and duplicate contracts" {
  let pkg = relationships_cursor_fixture(
    b"<Relationships><Relationship Id='same' Type='image' Target='first.png'/><Relationship Id='same' Type='image' Target='second.png'/></Relationships>",
  )
  assert_eq(read_part_relationships(pkg, "word/document.xml").length(), 2)
  assert_eq(
    find_relationship_by_id(pkg, "word/document.xml", "same").unwrap().target,
    "first.png",
  )
  let validation = validate_ooxml_package(pkg)
  assert_eq(
    validation.issues
    .filter(issue => issue.kind == DuplicateRelationshipId)
    .length(),
    1,
  )
  assert_eq(read_part_relationships(pkg, "word/absent.xml").length(), 0)
  let invalid = relationships_cursor_fixture(
    b"<Relationships><Relationship Id='a' Target='a.png'/></Relationships>",
  )
  let validation = validate_ooxml_package(invalid)
  assert_eq(
    validation.issues
    .filter(issue => issue.kind == MissingRelationshipType)
    .length(),
    1,
  )
  let result = try
    read_part_relationships(invalid, "word/document.xml") |> Ok
  catch {
    error => Err(error)
  }
  assert_true(result is Err(InvalidXml(_)))
}

///|
async test "relationship parsing does not cache the complete XML text or bytes" {
  let pkg = relationships_cursor_fixture(
    b"<Relationships><Relationship Id='a' Type='image' Target='a.png'/></Relationships>",
  )
  ignore(read_part_relationships(pkg, "word/document.xml"))
  assert_true(
    !pkg.part_cache.bytes_by_part.contains("word/_rels/document.xml.rels"),
  )
  assert_true(
    !pkg.part_cache.text_by_part.contains("word/_rels/document.xml.rels"),
  )
  ignore(validate_ooxml_package(pkg))
  assert_true(
    !pkg.part_cache.bytes_by_part.contains("word/_rels/document.xml.rels"),
  )
  assert_true(
    !pkg.part_cache.text_by_part.contains("word/_rels/document.xml.rels"),
  )
}

///|
fn relationships_cursor_late_xml(invalid_utf8 : Bool) -> Bytes {
  let out = StringBuilder()
  out.write_string(
    "<Relationships><Relationship Id='a' Type='image' Target='a.png'/>",
  )
  for _ in 0..<70000 {
    out.write_char(' ')
  }
  @utf8.encode(out.to_string()) +
  (if invalid_utf8 { b"\xff" } else { b"" }) +
  b"</Relationships>"
}

///|
async test "late relationship encoding and CRC failures publish neither rows nor index" {
  for invalid_utf8 in [true, false] {
    let payload = relationships_cursor_late_xml(invalid_utf8)
    let raw = @zip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      ("word/_rels/document.xml.rels", payload),
    ])
    let raw = if invalid_utf8 {
      raw
    } else {
      let slice = @zip.read_entry_data_slice(
        @zip.open_zip(raw),
        "word/_rels/document.xml.rels",
      )
      let damaged = raw.to_array()
      damaged[slice.data_start + 65537] = b'\t'
      Bytes::from_array(damaged)
    }
    let pkg = open_ooxml_package(raw)
    let result = try
      read_part_relationships(pkg, "word/document.xml") |> Ok
    catch {
      error => Err(error)
    }
    if invalid_utf8 {
      assert_true(result is Err(InvalidEncoding(_)))
    } else {
      assert_true(result is Err(ZipError(_)))
    }
    assert_eq(pkg.relationship_cache.rows_by_rels_part.length(), 0)
    assert_eq(pkg.relationship_cache.index_by_rels_part.length(), 0)
    assert_true(@zip.archive_hard_failure(pkg.archive) is Some(_))
    assert_true(
      !pkg.part_cache.bytes_by_part.contains("word/_rels/document.xml.rels"),
    )
    assert_true(
      !pkg.part_cache.text_by_part.contains("word/_rels/document.xml.rels"),
    )
  }
}

///|
async test "relationship metadata cache budgets stop before publishing rows with typed errors" {
  for cache_limit in [true, false] {
    let (context, retained) = if cache_limit {
      content_types_scope(cache=Some(1L))
    } else {
      content_types_scope(metadata=Some(1L))
    }
    defer content_types_scope_end(context, retained)
    let archive = @zip.open_zip(
      @zip.build_store_zip_bytes([
        ("[Content_Types].xml", b"<Types/>"),
        (
          "word/_rels/document.xml.rels", b"<Relationships><Relationship Id='a' Type='image' Target='a.png'/></Relationships>",
        ),
      ]),
      budget_context=context,
    )
    let pkg = open_ooxml_archive(archive)
    let result = try
      read_part_relationships(pkg, "word/document.xml") |> Ok
    catch {
      error => Err(error)
    }
    let error = match result {
      Err(BudgetExceeded(error)) => error
      _ => fail("relationship budget must remain typed")
    }
    if cache_limit {
      assert_true(
        error
        is LimitExceeded(Resident(CacheBytes), used=0L, requested=22L, limit=1L),
      )
    } else {
      assert_true(
        error
        is LimitExceeded(
          Cumulative(SourceMetadataBytes),
          used=0L,
          requested=11L,
          limit=1L
        ),
      )
    }
    assert_eq(pkg.relationship_cache.rows_by_rels_part.length(), 0)
    assert_eq(pkg.relationship_cache.index_by_rels_part.length(), 0)
    assert_true(@zip.archive_hard_failure(archive) is Some(_))
  }
}

///|
async test "relationship partitions preserve raw rows and retained source metadata is not charged again by validation" {
  let xml = @utf8.encode(
    "<p:Relationships xmlns:p='http://schemas.openxmlformats.org/package/2006/relationships'><p:Relationship Id='😀' Type='image' Target='a&amp;lt;.png'/></p:Relationships>",
  )
  for chunk_size in [1, 2, 3, 7, 65536] {
    let rows = read_archive_relationship_rows(
      @zip.open_zip(@zip.build_store_zip_bytes([("r.rels", xml)])),
      "r.rels",
      chunk_size~,
    )
    assert_eq(rows.rows.length(), 1)
    assert_eq(rows.rows[0].id, "😀")
    assert_eq(rows.rows[0].target, "a&lt;.png")
    assert_eq(rows.stats.input_bytes, xml.length().to_int64())
    assert_eq(rows.stats.logical_tokens, 3L)
    assert_eq(rows.stats.max_depth, 2L)
  }
  let (context, retained) = content_types_scope()
  defer content_types_scope_end(context, retained)
  let archive = @zip.open_zip(
    @zip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      ("word/_rels/document.xml.rels", xml),
    ]),
    budget_context=context,
  )
  let pkg = open_ooxml_archive(archive)
  ignore(read_part_relationships(pkg, "word/document.xml"))
  let snapshot = context.account.snapshot()
  let stats = inspect_relationship_cursor(pkg, "word/document.xml").unwrap()
  let held = pkg.relationship_cache.rows_by_rels_part
    .get("word/_rels/document.xml.rels")
    .unwrap().rows[0].id
  assert_eq(validate_ooxml_package(pkg).issue_count, 0)
  let after = context.account.snapshot()
  assert_eq(after.cumulative.parse_work, snapshot.cumulative.parse_work)
  assert_eq(
    after.cumulative.source_metadata_bytes,
    snapshot.cumulative.source_metadata_bytes,
  )
  assert_eq(after.resident.cache_bytes, snapshot.resident.cache_bytes)
  assert_eq(
    inspect_relationship_cursor(pkg, "word/document.xml").unwrap().input_bytes,
    stats.input_bytes,
  )
  pkg.relationship_cache.rows_by_rels_part.clear()
  pkg.relationship_cache.index_by_rels_part.clear()
  assert_eq(held, "😀")
  assert_eq(
    context.account.snapshot().resident.cache_bytes,
    snapshot.resident.cache_bytes,
  )
}

///|
async test "relationship cache cannot hide an earlier typed account failure" {
  let (context, retained) = content_types_scope(cache=Some(1000L))
  defer content_types_scope_end(context, retained)
  let archive = @zip.open_zip(
    @zip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      (
        "word/_rels/document.xml.rels", b"<Relationships><Relationship Id='a' Type='image' Target='a.png'/></Relationships>",
      ),
    ]),
    budget_context=context,
  )
  let pkg = open_ooxml_archive(archive)
  assert_eq(read_part_relationships(pkg, "word/document.xml").length(), 1)
  assert_true(context.account.reserve(CacheBytes, 1001L) is Err(_))
  let result = try
    read_part_relationships(pkg, "word/document.xml") |> Ok
  catch {
    error => Err(error)
  }
  assert_true(result is Err(BudgetExceeded(_)))
  let missing = try
    read_part_relationships(pkg, "word/absent.xml") |> Ok
  catch {
    error => Err(error)
  }
  assert_true(missing is Err(BudgetExceeded(_)))
  let lookup = try
    find_relationship_by_id(pkg, "word/absent.xml", "absent") |> Ok
  catch {
    error => Err(error)
  }
  assert_true(lookup is Err(BudgetExceeded(_)))
}

///|
async test "cancelling an awaiting relationship body read releases cursor work and publishes no cache" {
  let payload = relationships_cursor_late_xml(false)
  let raw = @zip.build_store_zip_bytes([
    ("[Content_Types].xml", b"<Types/>"),
    ("word/_rels/document.xml.rels", payload),
  ])
  let slice = @zip.read_entry_data_slice(
    @zip.open_zip(raw),
    "word/_rels/document.xml.rels",
  )
  let (context, retained) = content_types_scope()
  defer content_types_scope_end(context, retained)
  let enabled = Ref(false)
  let entered = Ref(false)
  let resumed = Ref(false)
  let stopped_reads = Ref(0)
  let archive = @zip.open_zip_reader(
    raw.length(),
    async fn(offset, length) {
      if enabled.val && offset == slice.data_start + 65536 {
        stopped_reads.val += 1
        entered.val = true
        @async.sleep(60000)
        resumed.val = true
      }
      Ok(raw[offset:(offset + length).min(raw.length())].to_owned())
    },
    budget_context=context,
  )
  let pkg = open_ooxml_archive(archive)
  enabled.val = true
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        read_part_relationships(pkg, "word/document.xml")
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  @async.pause()
  assert_eq(stopped_reads.val, 1)
  assert_false(resumed.val)
  assert_eq(pkg.relationship_cache.rows_by_rels_part.length(), 0)
  assert_eq(pkg.relationship_cache.index_by_rels_part.length(), 0)
  // Only the ZIP visitor's documented scope-held owned chunks remain; cursor
  // namespace/token/input scratch must have been released by cancellation.
  assert_eq(
    context.account.snapshot().resident.working_bytes,
    b"<Types/>".length().to_int64() + 65536L,
  )
}

///|
async test "relationship reader retains raw whitespace and exact External while validation trims duplicate IDs" {
  let pkg = relationships_cursor_fixture(
    b"<Relationships><Relationship Id=' raw ' Type=' type ' Target=' image.png ' TargetMode='external'/><Relationship Id='raw' Type='type' Target='https://example.com/a' TargetMode='External'/></Relationships>",
  )
  let rows = read_part_relationships(pkg, "word/document.xml")
  assert_eq(rows[0].id, " raw ")
  assert_eq(rows[0].rel_type, " type ")
  assert_eq(rows[0].target, " image.png ")
  assert_true(rows[0].target_mode == Internal)
  assert_eq(rows[0].resolved_target, "word/image.png")
  assert_true(rows[1].target_mode == External)
  assert_eq(rows[1].resolved_target, "https://example.com/a")
  let validation = validate_ooxml_package(pkg)
  assert_eq(
    validation.issues
    .filter(issue => issue.kind == DuplicateRelationshipId)
    .length(),
    1,
  )
  assert_eq(
    validation.issues
    .filter(issue => issue.kind == ExternalRelationship)
    .length(),
    1,
  )
}

///|
async test "recoverable relationship syntax cannot hide later encoding or CRC failures" {
  let observed : Array[String] = []
  for invalid_utf8 in [true, false] {
    for validation_only in [false, true] {
      let out = StringBuilder()
      out.write_string("<Wrong>")
      for _ in 0..<70000 {
        out.write_char(' ')
      }
      let payload = @utf8.encode(out.to_string()) +
        (if invalid_utf8 { b"\xff" } else { b"" }) +
        b"</Wrong>"
      let raw = @zip.build_store_zip_bytes([
        ("[Content_Types].xml", b"<Types/>"),
        ("word/_rels/document.xml.rels", payload),
      ])
      let raw = if invalid_utf8 {
        raw
      } else {
        let slice = @zip.read_entry_data_slice(
          @zip.open_zip(raw),
          "word/_rels/document.xml.rels",
        )
        let damaged = raw.to_array()
        damaged[slice.data_start + 65537] = b'\t'
        Bytes::from_array(damaged)
      }
      let pkg = open_ooxml_package(raw)
      let kind = if validation_only {
        ignore(validate_ooxml_package(pkg))
        "validation"
      } else {
        let result = try
          read_part_relationships(pkg, "word/document.xml") |> Ok
        catch {
          error => Err(error)
        }
        match result {
          Err(InvalidEncoding(_)) => "encoding"
          Err(ZipError(_)) => "zip"
          Err(InvalidXml(_)) => "syntax"
          _ => "other"
        }
      }
      observed.push(
        (if invalid_utf8 { "utf8" } else { "crc" }) +
        ":" +
        kind +
        ":" +
        (@zip.archive_hard_failure(pkg.archive) is Some(_)).to_string(),
      )
      assert_eq(pkg.relationship_cache.rows_by_rels_part.length(), 0)
      assert_eq(pkg.relationship_cache.index_by_rels_part.length(), 0)
    }
  }
  assert_eq(observed, [
    "utf8:encoding:true", "utf8:validation:true", "crc:zip:true", "crc:validation:true",
  ])
}

///|
fn relationship_replay_working_scope(
  limit : Int64,
) -> (@budget.BudgetContext, Array[@budget.BudgetLease]) {
  let account = @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=None,
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes=Some(limit),
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
  let retained : Array[@budget.BudgetLease] = []
  let context = @budget.BudgetContext::new(account, (kind, bytes) => {
    match account.reserve(kind, bytes) {
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
fn relationship_replay_wrong_root(suffix : Bytes) -> Bytes {
  let out = StringBuilder()
  out.write_string("<Wrong>")
  for _ in 0..<70000 {
    out.write_char(' ')
  }
  @utf8.encode(out.to_string()) + suffix
}

///|
async test "relationship syntax replay validates EOF carry and accounts the explicit extra pass" {
  for incomplete_utf8 in [false, true] {
    let payload = relationship_replay_wrong_root(
      if incomplete_utf8 {
        b"\xf0\x9f"
      } else {
        b"</Wrong>"
      },
    )
    let (context, retained) = content_types_scope()
    defer content_types_scope_end(context, retained)
    let archive = @zip.open_zip(
      @zip.build_store_zip_bytes([
        ("[Content_Types].xml", b"<Types/>"),
        ("word/_rels/document.xml.rels", payload),
      ]),
      budget_context=context,
    )
    let pkg = open_ooxml_archive(archive)
    let result = try
      read_part_relationships(pkg, "word/document.xml") |> Ok
    catch {
      error => Err(error)
    }
    if incomplete_utf8 {
      assert_true(result is Err(InvalidEncoding(_)))
      assert_true(@zip.archive_hard_failure(archive) is Some(_))
    } else {
      assert_true(result is Err(InvalidXml(_)))
      assert_true(@zip.archive_hard_failure(archive) is None)
    }
    assert_eq(pkg.relationship_cache.rows_by_rels_part.length(), 0)
    assert_eq(pkg.relationship_cache.index_by_rels_part.length(), 0)
    let owned_zip_chunks = 8L + 65536L + payload.length().to_int64()
    assert_eq(
      context.account.snapshot().cumulative.inflate_bytes,
      owned_zip_chunks,
    )
    assert_eq(
      context.account.snapshot().resident.working_bytes,
      owned_zip_chunks,
    )
    assert_true(
      context.account.snapshot().cumulative.parse_work >
      payload.length().to_int64(),
    )
  }
}

///|
async test "relationship syntax replay cannot hide a typed working limit" {
  let payload = relationship_replay_wrong_root(b"</Wrong>")
  // Original ZIP scratch + 7N cursor feed fits. The explicit replay's 8N
  // decode bound, with both scope-held chunks, exceeds this ceiling.
  let (context, retained) = relationship_replay_working_scope(850000L)
  defer content_types_scope_end(context, retained)
  let archive = @zip.open_zip(
    @zip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      ("word/_rels/document.xml.rels", payload),
    ]),
    budget_context=context,
  )
  let pkg = open_ooxml_archive(archive)
  let result = try
    read_part_relationships(pkg, "word/document.xml") |> Ok
  catch {
    error => Err(error)
  }
  assert_true(
    result is Err(BudgetExceeded(LimitExceeded(Resident(WorkingBytes), ..))),
  )
  assert_true(@zip.archive_hard_failure(archive) is Some(_))
  assert_eq(pkg.relationship_cache.rows_by_rels_part.length(), 0)
  assert_eq(pkg.relationship_cache.index_by_rels_part.length(), 0)
  // The failed scratch admission must not be retained. Only the original
  // aborted chunk and first replay chunk remain under ZIP's scope owner.
  assert_eq(context.account.snapshot().resident.working_bytes, 8L + 2L * 65536L)
}

///|
async test "cancellation during syntax integrity replay releases private carry and scratch" {
  let payload = relationship_replay_wrong_root(b"</Wrong>")
  let raw = @zip.build_store_zip_bytes([
    ("[Content_Types].xml", b"<Types/>"),
    ("word/_rels/document.xml.rels", payload),
  ])
  let slice = @zip.read_entry_data_slice(
    @zip.open_zip(raw),
    "word/_rels/document.xml.rels",
  )
  let (context, retained) = content_types_scope()
  defer content_types_scope_end(context, retained)
  let enabled = Ref(false)
  let body_starts = Ref(0)
  let entered = Ref(false)
  let resumed = Ref(false)
  let second_reads = Ref(0)
  let archive = @zip.open_zip_reader(
    raw.length(),
    async fn(offset, length) {
      if enabled.val && offset == slice.data_start {
        body_starts.val += 1
      }
      if enabled.val && offset == slice.data_start + 65536 {
        second_reads.val += 1
        entered.val = true
        @async.sleep(60000)
        resumed.val = true
      }
      Ok(raw[offset:(offset + length).min(raw.length())].to_owned())
    },
    budget_context=context,
  )
  let pkg = open_ooxml_archive(archive)
  enabled.val = true
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        read_part_relationships(pkg, "word/document.xml")
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  @async.pause()
  assert_eq(body_starts.val, 2)
  assert_eq(second_reads.val, 1)
  assert_false(resumed.val)
  assert_eq(pkg.relationship_cache.rows_by_rels_part.length(), 0)
  assert_eq(pkg.relationship_cache.index_by_rels_part.length(), 0)
  assert_eq(context.account.snapshot().resident.working_bytes, 8L + 2L * 65536L)
}
