///|
// Frozen old splitter is a test oracle only. Production has one range path.
fn legacy_multipart_oracle(body : String, boundary : String) -> Array[String] {
  let current : Array[String] = []
  let parts : Array[String] = []
  let mut active = false
  for line in eml_normalize_newlines(body).split("\n") {
    if line == "--" + boundary || line.trim() == "--" + boundary {
      if active && current.length() > 0 {
        parts.push(current.join("\n").trim().to_owned())
        current.clear()
      }
      active = true
    } else if line == "--" + boundary + "--" ||
      line.trim() == "--" + boundary + "--" {
      if active && current.length() > 0 {
        parts.push(current.join("\n").trim().to_owned())
      }
      current.clear()
      break
    } else if active {
      current.push(line.to_owned())
    }
  }
  if active && current.length() > 0 {
    parts.push(current.join("\n").trim().to_owned())
  }
  parts.filter(part => part.trim() != "")
}

///|
test "MIME whole line ranges preserve newline trim prefix and EOF legacy contracts" {
  let cases = [
    "preamble\n--b\nContent-Type: text/plain\n\n😀 & body\n--b--\nepilogue", "--b\n\n\n--b\nContent-Type: text/plain\n\n next \t\n--b--",
    "--boundary\nnot this boundary\n--b\nContent-Type: text/plain\n\nbody\n--b--",
    "--b\nContent-Type: text/plain\n\nbody\n--b", "--b\nContent-Type: text/plain\n\nbody",
    "--b--\n--b\nno child", " \t--b \t\nContent-Type: text/plain\n\nbody\n \t--b-- \t",
    "no delimiters\nnot--b\n--bExtra",
  ]
  for eol in ["\n", "\r\n", "\r"] {
    for body in cases {
      let raw = body.replace_all(old="\n", new=eol)
      let whole = eml_wire_whole(eml_wire_from_text(raw))
      let ranges = eml_multipart_ranges(whole, "b")
      assert_eq(ranges.map(eml_wire_text), legacy_multipart_oracle(raw, "b"))
      let cursor = new_eml_multipart_cursor(whole, "b")
      let actual : Array[String] = []
      while cursor.next() is Some(range) {
        actual.push(eml_wire_text(range))
      }
      assert_eq(actual, legacy_multipart_oracle(raw, "b"))
      assert_true(cursor.next() is None)
    }
  }
}

///|
test "MIME raw half open ranges never reuse normalized UTF16 indices" {
  let prefix = "😀 preamble\r\n--b\r\n"
  let child = "Content-Type: text/plain\r\n\r\n😀 café"
  let owner = eml_wire_from_text(prefix + child + "\r\n--b--")
  let range = eml_multipart_ranges(eml_wire_whole(owner), "b")[0]
  assert_eq(range.start, @utf8.encode(prefix).length())
  assert_eq(range.end - range.start, @utf8.encode(child).length())
  let (header, body) = eml_wire_headers_body(range)
  assert_eq(eml_wire_text(header), "Content-Type: text/plain")
  assert_eq(eml_wire_text(body), "😀 café")
  assert_eq(eml_wire_text(range), "Content-Type: text/plain\n\n😀 café")
}

///|
test "MIME owner keeps one global mixed byte mode and legacy boundary mapping" {
  let wire = @utf8.encode(
      "Subject: café\nContent-Type: multipart/mixed; boundary=é\n\n--é\nContent-Type: text/plain\n\ncafé\n--é--\n",
    ) +
    b"\xff"
  let (text, owner) = eml_wire_text_and_owner(wire)
  assert_true(text.contains("cafÃ©"))
  let message = eml_parse_wire_message(owner, eml_normalize_newlines(text))
  assert_eq(message.header_map.subject, Some("cafÃ©"))
  assert_eq(message.children[0].body_text.unwrap().text, "cafÃ©")
  // A boundary decoded from an encoded parameter can exceed the wire mode's
  // byte repertoire. It must not accidentally match UTF8 bytes in Latin1 mode.
  assert_eq(eml_multipart_ranges(eml_wire_whole(owner), "😀").length(), 0)
}

///|
test "MIME bounded mode validation carries UTF8 and rejects late invalid sequences globally" {
  // The four-byte scalar starts at each of the last three byte positions of
  // the bounded validation window. BOM bytes remain ordinary retained text.
  for start in [65533, 65534, 65535] {
    let text = "\u{FEFF}" + "a".repeat(start - 3) + "😀é\r\nlast"
    let wire = @utf8.encode(text)
    assert_true(eml_wire_valid_utf8(wire))
    let (decoded, owner) = eml_wire_text_and_owner(wire)
    assert_eq(decoded, text)
    assert_eq(
      eml_wire_text(eml_wire_whole(owner)),
      eml_normalize_newlines(text),
    )
    for
      bad in [
        b"\xff", b"\xc0\xaf", b"\xed\xa0\x80", b"\xf4\x90\x80\x80", b"\xf0\x9f\x98",
      ] {
      let invalid = wire + bad
      assert_false(eml_wire_valid_utf8(invalid))
      let (preserved, _) = eml_wire_text_and_owner(invalid)
      assert_eq(preserved.length(), invalid.length())
      // Even valid earlier UTF8 must follow the single byte-preserving mode.
      assert_true(preserved.contains("ð\u{009F}\u{0098}\u{0080}Ã©"))
    }
  }
  assert_true(eml_wire_valid_utf8(b""))
}

///|
test "MIME structural count precedes child encoding and depth propagates typed" {
  let bad = "--b\nContent-Type: text/plain; charset=utf-16le\nContent-Transfer-Encoding: base64\n\nANg=\n"
  for count in [1024, 1025] {
    let input = "Content-Type: multipart/mixed; boundary=b\n\n" +
      bad +
      "--b\nContent-Type: text/plain\n\nleaf\n".repeat(count - 1) +
      "--b--"
    let result = try parse_eml_message(input) |> Ok catch {
      error => Err(error)
    }
    if count == 1025 {
      assert_true(
        result
        is Err(LimitExceeded(MultipartParts, observed=1025L, limit=1024L)),
      )
    } else {
      assert_true(result is Err(InvalidEncoding(_)))
    }
  }
  let depth9 = "Content-Type: message/rfc822\n\n".repeat(9) +
    "Content-Type: text/plain\n\nleaf"
  let result = try parse_eml_message(depth9) |> Ok catch {
    error => Err(error)
  }
  assert_true(result is Err(LimitExceeded(NestingDepth, observed=9L, limit=8L)))
}

///|
test "MIME direct invalid String is controlled before raw owner encoding" {
  let invalid = String::from_array([(0xD800).unsafe_to_char()])
  let result = try
    parse_eml_message("Subject: " + invalid + "\n\nbody") |> Ok
  catch {
    error => Err(error)
  }
  assert_true(result is Err(InvalidEncoding(_)))
}

///|
test "transfer decoded rfc822 owns local Unicode BOM CRLF ranges and preserves DTO pointers" {
  let prefix = "Content-Type: multipart/mixed; boundary=é\r\n\r\n\u{FEFF}😀 preamble\r\n--é\r\n"
  let child = "Content-Type: text/plain\r\n\r\n😀 café"
  let nested = prefix + child + "\r\n--é--\r\nepilogue"
  let bytes = @utf8.encode(nested)
  let outer = "Content-Type: message/rfc822\r\nContent-Transfer-Encoding: base64\r\n\r\n" +
    @base64.encode(bytes[:], url_safe=false)
  let parsed = parse_eml_message(outer)
  let message = parsed.children[0].child_message.unwrap()
  assert_eq(parsed.raw_source, eml_normalize_newlines(outer))
  assert_eq(message.raw_source, eml_normalize_newlines(nested))
  assert_eq(message.children.length(), 1)
  assert_eq(message.children[0].summary.json_pointer, "//message/parts/0")
  assert_eq(message.children[0].raw_body, "😀 café")
  assert_eq(message.children[0].body_text.unwrap().text, "😀 café")
  let local_wire = eml_wire_whole(eml_wire_from_text(nested))
  assert_eq(local_wire.start, 0)
  assert_eq(local_wire.end, bytes.length())
  let (_, body) = eml_wire_headers_body(local_wire)
  let ranges = eml_multipart_ranges(body, "é")
  assert_eq(ranges[0].start, @utf8.encode(prefix).length())
  assert_eq(ranges[0].end - ranges[0].start, @utf8.encode(child).length())
}

///|
async test "MIME prepare records exact structural failure and standalone preparation cannot fallback" {
  let cases : Array[(String, @input.ResourceLimitKind, Int64, Int64)] = [
    (
      "Content-Type: message/rfc822\n\n".repeat(9) +
      "Content-Type: text/plain\n\nleaf",
      MimeNestingDepth,
      9L,
      8L,
    ),
    (
      "Content-Type: multipart/mixed; boundary=b\n\n" +
      "--b\nContent-Type: text/plain\n\nleaf\n".repeat(1025) +
      "--b--",
      MimeMultipartParts,
      1025L,
      1024L,
    ),
  ]
  for (text, kind, observed, limit) in cases {
    let source = @input.input_from_text(text, source_name="limit.eml")
    assert_true(prepare_eml_message_from_source(source) is Err(_))
    let session = @input.begin_input_session(source)
    defer @input.end_input_session(session)
    assert_true(prepare_eml_message_from_source(session.source) is Err(_))
    @input.record_input_failure(session.source, "later ordinary failure")
    match @input.input_source_failure(session.source) {
      Some(ResourceLimit(failure)) => {
        assert_true(failure.kind == kind)
        assert_eq((failure.observed, failure.limit), (observed, limit))
      }
      _ => fail("MIME preparation must retain its exact typed first failure")
    }
  }
}
