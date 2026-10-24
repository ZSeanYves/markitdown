///|
async fn core_app_fixture(
  xml : String,
  app~ : Bool = false,
) -> OoxmlPackage raise OoxmlError {
  open_ooxml_package(
    @zip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      (
        if app {
          "docProps/app.xml"
        } else {
          "docProps/core.xml"
        },
        @utf8.encode(xml),
      ),
    ]),
  )
}

///|
async fn core_app_first_value(
  pkg : OoxmlPackage,
  app : Bool,
) -> String? raise OoxmlError {
  if app {
    read_app_properties(pkg).application
  } else {
    read_core_properties(pkg).title
  }
}

///|
async test "core app cursor preserves localname urn first empty selfclosing and trim contracts" {
  for app in [false, true] {
    let name = if app { "Application" } else { "title" }
    for
      (inner, expected) in [
        (
          "<x:" +
          name +
          ">  😀 first  </x:" +
          name +
          "><x:" +
          name +
          ">second</x:" +
          name +
          ">",
          Some("😀 first"),
        ),
        ("<x:" + name + "/><x:" + name + ">second</x:" + name + ">", None),
        (
          "<x:" +
          name +
          "></x:" +
          name +
          "><x:" +
          name +
          ">second</x:" +
          name +
          ">",
          Some(""),
        ),
        ("<irrelevant/>", None),
        (
          "<x:" + name + ">\u{a0}value\u{a0}</x:" + name + ">",
          Some("\u{a0}value\u{a0}"),
        ),
      ] {
      let pkg = core_app_fixture(
        "<r xmlns:x='urn:legacy'>" + inner + "</r>",
        app~,
      )
      assert_eq(core_app_first_value(pkg, app), expected)
    }
  }
}

///|
async test "core app cursor ignores greater-than inside quoted attributes" {
  let observed : Array[String?] = []
  for app in [false, true] {
    let name = if app { "Application" } else { "title" }
    let pkg = core_app_fixture(
      "<r><" + name + " note='a>b'>value</" + name + "></r>",
      app~,
    )
    observed.push(core_app_first_value(pkg, app))
  }
  assert_eq(observed, [Some("value"), Some("value")])
}

///|
async test "core app cursor comments cannot manufacture an earlier property" {
  let observed : Array[String?] = []
  for app in [false, true] {
    let name = if app { "Application" } else { "title" }
    let pkg = core_app_fixture(
      "<r><!-- <" +
      name +
      ">fake</" +
      name +
      "> --><" +
      name +
      ">real</" +
      name +
      "></r>",
      app~,
    )
    observed.push(core_app_first_value(pkg, app))
  }
  assert_eq(observed, [Some("real"), Some("real")])
}

///|
async test "core app character values decode named and numeric entities once" {
  let observed : Array[String?] = []
  for app in [false, true] {
    let name = if app { "Application" } else { "title" }
    let pkg = core_app_fixture(
      "<r><" + name + ">&amp;lt; &#x1F600; &#65;</" + name + "></r>",
      app~,
    )
    observed.push(core_app_first_value(pkg, app))
  }
  assert_eq(observed, [Some("&lt; 😀 A"), Some("&lt; 😀 A")])
}

///|
async test "core app nested markup contributes only its character content in document order" {
  let observed : Array[String?] = []
  for app in [false, true] {
    let name = if app { "Application" } else { "title" }
    let pkg = core_app_fixture(
      "<r><" + name + "> A<b q='x'>B&amp;lt;</b>C </" + name + "></r>",
      app~,
    )
    observed.push(core_app_first_value(pkg, app))
  }
  assert_eq(observed, [Some("AB&lt;C"), Some("AB&lt;C")])
}

///|
async test "core app CDATA contributes literal characters without delimiters or entity decoding" {
  let observed : Array[String?] = []
  for app in [false, true] {
    let name = if app { "Application" } else { "title" }
    let pkg = core_app_fixture(
      "<r><" + name + ">x<![CDATA[A &amp; <b>]]>y</" + name + "></r>",
      app~,
    )
    observed.push(core_app_first_value(pkg, app))
  }
  assert_eq(observed, [Some("xA &amp; <b>y"), Some("xA &amp; <b>y")])
}

///|
async test "core app cursor keeps completed fields on malformed tail but not an unclosed field" {
  for app in [false, true] {
    let name = if app { "Application" } else { "title" }
    for
      (xml, expected) in [
        ("<r><" + name + ">kept</" + name + "><broken", Some("kept")),
        ("<r><" + name + ">not closed", None),
      ] {
      assert_eq(
        core_app_first_value(core_app_fixture(xml, app~), app),
        expected,
      )
    }
  }
}

///|
async test "core app cursor caches projected values instead of complete part bytes and text" {
  for app in [false, true] {
    let name = if app { "Application" } else { "title" }
    let part = if app { "docProps/app.xml" } else { "docProps/core.xml" }
    let pkg = core_app_fixture(
      "<r><" + name + ">value</" + name + "></r>",
      app~,
    )
    assert_eq(core_app_first_value(pkg, app), Some("value"))
    assert_false(pkg.part_cache.bytes_by_part.contains(part))
    assert_false(pkg.part_cache.text_by_part.contains(part))
  }
}

///|
async test "core app explicitly preserves undeclared prefix localname compatibility" {
  let core = core_app_fixture(
    "<cp:r><dc:title p:a='1' q:a='2'>value</dc:title></cp:r>",
  )
  assert_eq(read_core_properties(core).title, Some("value"))
  let app = core_app_fixture(
    "<p:r><q:Application>value</q:Application></p:r>",
    app=true,
  )
  assert_eq(read_app_properties(app).application, Some("value"))
}

///|
async test "core app character values normalize CR and CRLF according to XML input rules" {
  for app in [false, true] {
    let name = if app { "Application" } else { "title" }
    let pkg = core_app_fixture(
      "<r><" + name + ">a\rb\r\nc\nd</" + name + "></r>",
      app~,
    )
    assert_eq(core_app_first_value(pkg, app), Some("a\nb\nc\nd"))
  }
}

///|
async test "core app fragmented text CDATA and overlapping selected fields have the same values" {
  let xml = "\u{feff}<cp:r xmlns:cp='urn:cp'><dc:title> 😀\r\nA<dc:creator>B&amp;lt;</dc:creator><![CDATA[C &amp;]]> </dc:title></cp:r>"
  let pkg = core_app_fixture(xml)
  for chunk_size in [1, 2, 3, 7, 65536] {
    let fields = read_core_app_values(
      pkg,
      "docProps/core.xml",
      ["title", "creator"],
      chunk_size~,
    )
    assert_eq(fields.get("title"), Some(Some("😀\nAB&lt;C &amp;")))
    assert_eq(fields.get("creator"), Some(Some("B&lt;")))
  }
}

///|
fn core_app_late_xml(
  app : Bool,
  syntax_error : Bool,
  invalid_utf8 : Bool,
) -> Bytes {
  let name = if app { "Application" } else { "title" }
  let prefix = "<r><" +
    name +
    ">kept</" +
    name +
    ">" +
    (if syntax_error { "</wrong>" } else { "" })
  @utf8.encode(prefix) +
  Bytes::from_array(Array::make(70000, b' ')) +
  (if invalid_utf8 { b"\xff" } else { b"" }) +
  b"</r>"
}

///|
async test "core app early syntax and completed values cannot hide later UTF8 or CRC failure" {
  for app in [false, true] {
    for syntax_error in [false, true] {
      for invalid_utf8 in [false, true] {
        let part = if app { "docProps/app.xml" } else { "docProps/core.xml" }
        let raw = @zip.build_store_zip_bytes([
          ("[Content_Types].xml", b"<Types/>"),
          (part, core_app_late_xml(app, syntax_error, invalid_utf8)),
        ])
        let raw = if invalid_utf8 {
          raw
        } else {
          let slice = @zip.read_entry_data_slice(@zip.open_zip(raw), part)
          let bytes = raw.to_array()
          bytes[slice.data_start + 65537] = b'\t'
          Bytes::from_array(bytes)
        }
        let pkg = open_ooxml_package(raw)
        let result = try core_app_first_value(pkg, app) |> Ok catch {
          error => Err(error)
        }
        if invalid_utf8 {
          assert_true(result is Err(InvalidEncoding(_)))
        } else {
          assert_true(result is Err(ZipError(_)))
        }
        assert_true(@zip.archive_hard_failure(pkg.archive) is Some(_))
        assert_true(pkg.core_properties_cache.val is None)
        assert_true(pkg.app_properties_cache.val is None)
      }
    }
  }
}

///|
async test "core app projected cache is admitted once and hard budget remains typed" {
  for app in [false, true] {
    for cache_cap in [false, true] {
      let (context, retained) = if cache_cap {
        content_types_scope(cache=Some(1L))
      } else {
        content_types_scope(metadata=Some(1L))
      }
      defer content_types_scope_end(context, retained)
      let part = if app { "docProps/app.xml" } else { "docProps/core.xml" }
      let name = if app { "Application" } else { "title" }
      let archive = @zip.open_zip(
        @zip.build_store_zip_bytes([
          ("[Content_Types].xml", b"<Types/>"),
          (part, @utf8.encode("<r><" + name + ">value</" + name + "></r>")),
        ]),
        budget_context=context,
      )
      let pkg = open_ooxml_archive(archive)
      let result = try core_app_first_value(pkg, app) |> Ok catch {
        error => Err(error)
      }
      assert_true(result is Err(BudgetExceeded(_)))
      assert_true(@zip.archive_hard_failure(archive) is Some(_))
      assert_true(pkg.core_properties_cache.val is None)
      assert_true(pkg.app_properties_cache.val is None)
      assert_eq(
        context.account.snapshot().resident.working_bytes,
        8L + part_declared_size(pkg, part).unwrap().to_int64(),
      )
    }
  }
  let (context, retained) = content_types_scope()
  defer content_types_scope_end(context, retained)
  let raw = @zip.build_store_zip_bytes([
    ("[Content_Types].xml", b"<Types/>"),
    (
      "docProps/core.xml",
      @utf8.encode("<r><title>😀</title><creator>A</creator></r>"),
    ),
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
  assert_eq(read_core_properties(pkg).title, Some("😀"))
  let before = context.account.snapshot()
  let reads_before = reads.val
  assert_eq(read_core_properties(pkg).creator, Some("A"))
  assert_eq(reads.val, reads_before)
  assert_true(context.account.snapshot() == before)
  assert_eq(before.cumulative.source_metadata_bytes, 5L)
  assert_eq(before.resident.cache_bytes, 6L)
  assert_true(context.account.charge(ParseWork, 9223372036854775807L) is Err(_))
  let result = try read_core_properties(pkg) |> Ok catch {
    error => Err(error)
  }
  assert_true(result is Err(BudgetExceeded(_)))
}

///|
async test "cancelling a core property body read releases value buffers and publishes no cache" {
  let payload = b"<r><title>" +
    Bytes::from_array(Array::make(70000, b'x')) +
    b"</title></r>"
  let raw = @zip.build_store_zip_bytes([
    ("[Content_Types].xml", b"<Types/>"),
    ("docProps/core.xml", payload),
  ])
  let slice = @zip.read_entry_data_slice(
    @zip.open_zip(raw),
    "docProps/core.xml",
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
      @async.handle_cancellation(() => read_core_properties(pkg))
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
  assert_true(pkg.core_properties_cache.val is None)
  assert_eq(context.account.snapshot().resident.working_bytes, 8L + 65536L)
}

///|
async test "core app prefix compatibility does not relax relationships or content types" {
  let rels = relationships_cursor_fixture(
    b"<p:Relationships><p:Relationship Id='a' Type='image' Target='a.png'/></p:Relationships>",
  )
  let read = try
    read_part_relationships(rels, "word/document.xml") |> Ok
  catch {
    error => Err(error)
  }
  assert_true(read is Err(InvalidXml(_)))
  let opened = try
    open_ooxml_package(
      @zip.build_store_zip_bytes([("[Content_Types].xml", b"<p:Types/>")]),
    )
    |> Ok
  catch {
    error => Err(error)
  }
  assert_true(opened is Err(InvalidXml(_)))
}

///|
async test "core app malformed recovery returns only fields completed before the cursor error" {
  for
    xml in [
      "<r/><title>after-error</title>", "<r><title>outer<title>inner</title></r>",
    ] {
    assert_eq(read_core_properties(core_app_fixture(xml)).title, None)
  }
}
