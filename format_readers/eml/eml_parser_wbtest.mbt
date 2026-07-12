///|
test "EML reader parses folded headers and plain text defaults" {
  let message = parse_eml_message(
    [
      "From: Alice <alice@example.com>", "To: Bob <bob@example.com>", "Subject: A long",
      " folded subject", "", "Hello plain body.",
    ].join("\r\n"),
  ) catch {
    err => fail("plain EML should parse: " + err.to_string())
  }
  assert_true(message.header_map.subject == Some("A long folded subject"))
  assert_eq(message.text_plain.length(), 1)
  let plain_body = message.text_plain[0].body_text.map(body => {
    body.text.trim().to_owned()
  })
  assert_true(plain_body == Some("Hello plain body."))
  let inspect = inspect_eml_message(message)
  assert_eq(inspect.part_count, 1)
  assert_eq(inspect.text_part_count, 1)
}

///|
test "EML reader parses multipart alternative and transfer encodings" {
  let message = parse_eml_message(
    [
      "MIME-Version: 1.0", "Content-Type: multipart/alternative; boundary=alt", "",
      "--alt", "Content-Type: text/plain; charset=utf-8", "Content-Transfer-Encoding: quoted-printable",
      "", "Hello=20plain=2E", "--alt", "Content-Type: text/html; charset=utf-8",
      "Content-Transfer-Encoding: base64", "", "PHA+SGVsbG8gSFRNTDwvcD4=", "--alt--",
    ].join("\n"),
  ) catch {
    err => fail("multipart EML should parse: " + err.to_string())
  }
  assert_eq(message.children.length(), 2)
  assert_eq(message.text_plain.length(), 1)
  assert_eq(message.text_html.length(), 1)
  assert_true(
    message.text_plain[0].body_text
    .map(body => body.text.contains("Hello plain."))
    .unwrap_or(false),
  )
  assert_true(
    message.text_html[0].body_text
    .map(body => body.text.contains("<p>Hello HTML</p>"))
    .unwrap_or(false),
  )
  let inspect = inspect_eml_message(message)
  assert_eq(inspect.multipart_count, 0)
  assert_eq(inspect.text_part_count, 1)
  assert_eq(inspect.html_part_count, 1)
}

///|
test "EML reader honors common MIME charsets" {
  let latin = parse_eml_message(
    "Content-Type: text/plain; charset=iso-8859-1\r\n" +
    "Content-Transfer-Encoding: base64\r\n\r\nY2Fm6Q==",
  )
  assert_eq(latin.text_plain[0].body_text.unwrap().text, "caf\u{00E9}")
  assert_true(latin.text_plain[0].body_text.unwrap().decoded)
  let windows = parse_eml_message(
    "Content-Type: text/plain; charset=windows-1252\r\n" +
    "Content-Transfer-Encoding: base64\r\n\r\ngA==",
  )
  assert_eq(windows.text_plain[0].body_text.unwrap().text, "\u{20AC}")
  let utf16 = parse_eml_message(
    "Content-Type: text/plain; charset=utf-16le\r\n" +
    "Content-Transfer-Encoding: base64\r\n\r\naABpAA==",
  )
  assert_eq(utf16.text_plain[0].body_text.unwrap().text, "hi")
  let unknown = parse_eml_message(
    "Content-Type: text/plain; charset=x-unknown\r\n" +
    "Content-Transfer-Encoding: base64\r\n\r\naGk=",
  )
  assert_true(!unknown.text_plain[0].body_text.unwrap().decoded)
}

///|
test "EML reader decodes RFC 2047 headers and RFC 2231 filenames" {
  let message = parse_eml_message(
    "From: =?UTF-8?Q?Jos=C3=A9?= <jose@example.test>\r\n" +
    "Subject: =?UTF-8?B?5pel5pys6Kqe?=\r\n" +
    "MIME-Version: 1.0\r\n" +
    "Content-Type: multipart/mixed; boundary=mix\r\n\r\n" +
    "--mix\r\nContent-Type: text/plain\r\n\r\nBody\r\n" +
    "--mix\r\nContent-Type: application/octet-stream\r\n" +
    "Content-Disposition: attachment; filename*=UTF-8''report%20%C3%A9.txt\r\n" +
    "Content-Transfer-Encoding: base64\r\n\r\nAA==\r\n--mix--",
  )
  assert_true(message.header_map.from.unwrap_or("").contains("Jos\u{00E9}"))
  assert_eq(
    message.header_map.subject.unwrap_or(""),
    "\u{65E5}\u{672C}\u{8A9E}",
  )
  assert_eq(
    message.attachments[0].file_name.unwrap_or(""),
    "report \u{00E9}.txt",
  )
}

///|
test "EML reader classifies and lazily materializes inline attachments" {
  let message = parse_eml_message(
    [
      "MIME-Version: 1.0", "Content-Type: multipart/related; boundary=rel", "", "--rel",
      "Content-Type: text/plain", "", "Body", "--rel", "Content-Type: image/png; name=image.png",
      "Content-Disposition: inline; filename=image.png", "Content-ID: <hero>", "Content-Transfer-Encoding: base64",
      "", "aGVsbG8=", "--rel--",
    ].join("\n"),
  ) catch {
    err => fail("attachment EML should parse: " + err.to_string())
  }
  assert_eq(message.attachments.length(), 1)
  assert_eq(message.inline_images.length(), 1)
  let raw = message.attachments[0]
  assert_true(!raw.payload_decoded)
  assert_true(raw.bytes is None)
  let decoded = materialize_attachment_payload(raw, true, true)
  assert_true(decoded.payload_decoded)
  assert_true(decoded.decoded_text == Some("hello"))
  assert_true(decoded.bytes.map(bytes => bytes.length()) == Some(5))
  let reused = materialize_attachment_payload(decoded, true, true)
  assert_true(reused.decoded_text == Some("hello"))
}

///|
test "EML reader parses nested message and fails closed on malformed multipart" {
  let nested = parse_eml_message(
    [
      "Content-Type: message/rfc822", "", "From: nested@example.com", "Subject: Nested",
      "Content-Type: text/plain", "", "Nested body",
    ].join("\n"),
  ) catch {
    err => fail("nested EML should parse: " + err.to_string())
  }
  assert_true(nested.children[0].child_message is Some(_))
  assert_eq(inspect_eml_message(nested).nested_message_count, 1)

  let failed = try {
    ignore(parse_eml_message("Content-Type: multipart/mixed\n\nbody"))
    false
  } catch {
    ParseError(message) => message.contains("missing boundary")
    _ => false
  }
  assert_true(failed)
}

///|
fn deeply_nested_eml(depth : Int) -> String {
  if depth <= 0 {
    return "Content-Type: text/plain\n\nleaf"
  }
  let boundary = "b" + depth.to_string()
  [
    "Content-Type: multipart/mixed; boundary=" + boundary,
    "",
    "--" + boundary,
    deeply_nested_eml(depth - 1),
    "--" + boundary + "--",
  ].join("\n")
}

///|
test "EML reader enforces nesting depth and preserves invalid UTF-8 bytes" {
  let depth_failed = try {
    ignore(parse_eml_message(deeply_nested_eml(10)))
    false
  } catch {
    ParseError(message) => message.contains("maximum eml nesting depth")
    _ => false
  }
  assert_true(depth_failed)
  let decoded = decode_eml_source_text(Bytes::from_array([0x66, 0x80, 0x6F]))
  assert_eq(decoded.length(), 3)
  assert_true(decoded.has_prefix("f"))
}

///|
test "EML reader recovers one malformed MIME child without dropping siblings" {
  let message = parse_eml_message(
    [
      "MIME-Version: 1.0", "Content-Type: multipart/mixed; boundary=mix", "", "--mix",
      "Malformed header without colon", "", "raw child payload", "--mix", "Content-Type: text/plain; charset=utf-8",
      "", "valid sibling body", "--mix--",
    ].join("\n"),
  )
  assert_eq(message.children.length(), 2)
  assert_eq(
    message.children[0].summary.mime_type,
    "application/x-markitdown-recovered-mime-part",
  )
  assert_true(message.children[0].raw_body.contains("raw child payload"))
  assert_eq(message.text_plain.length(), 1)
  assert_eq(message.text_plain[0].body_text.unwrap().text, "valid sibling body")
}

///|
test "EML reader enforces multipart child count budget" {
  let parts : Array[String] = [
    "Content-Type: multipart/mixed; boundary=many", "",
  ]
  for i in 0..<1_025 {
    parts.push("--many")
    parts.push("Content-Type: text/plain")
    parts.push("")
    parts.push("part " + i.to_string())
  }
  parts.push("--many--")
  let failed = try {
    ignore(parse_eml_message(parts.join("\n")))
    false
  } catch {
    ParseError(message) => message.contains("multipart child count")
    _ => false
  }
  assert_true(failed)
}
