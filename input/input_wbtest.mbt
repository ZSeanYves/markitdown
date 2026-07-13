///|
test "input detection honors explicit mime extension and heuristic priority" {
  let explicit = input_from_text_with_format(
      "plain",
      "fixture.pdf",
      Some(DetectedFormat::Markdown),
    )
    |> with_mime_type(Some("application/pdf"))
  let explicit_result = detect_format(explicit)
  assert_true(explicit_result.format == DetectedFormat::Markdown)
  assert_true(explicit_result.used_explicit_format)
  assert_true(!explicit_result.used_extension)

  let mime = input_from_text("plain", source_name="fixture.unknown")
    |> with_mime_type(Some(" image/png "))
  let mime_result = (default_format_detector().detect)(mime)
  assert_true(mime_result.format == DetectedFormat::Image(ImageFormat::Png))
  assert_true(mime_result.notes.contains("image_ocr_candidate"))

  let extension = detect_format(input_from_path("/tmp/report.DOCX"))
  assert_true(extension.format == DetectedFormat::Docx)
  assert_true(extension.used_extension && extension.binary_like)

  let text = detect_format(input_from_text("ordinary text"))
  assert_true(text.format == DetectedFormat::Txt)
  assert_true(text.text_like && text.notes == ["text_heuristic"])
  let binary = detect_format(input_from_bytes(Bytes::from_array([0, 1, 2])))
  assert_true(binary.format == DetectedFormat::Unknown)
  assert_true(binary.binary_like && binary.notes == ["binary_heuristic"])
}

///|
test "input detection covers binary magic signatures" {
  let fixtures : Array[(Array[Byte], DetectedFormat)] = [
    ([0x25, 0x50, 0x44, 0x46], DetectedFormat::Pdf),
    (
      [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45],
      DetectedFormat::Audio(AudioFormat::Wav),
    ),
    ([0x49, 0x44, 0x33], DetectedFormat::Audio(AudioFormat::Mp3)),
    ([0xFF, 0xE0], DetectedFormat::Audio(AudioFormat::Mp3)),
    ([0x89, 0x50, 0x4E, 0x47], DetectedFormat::Image(ImageFormat::Png)),
    ([0xFF, 0xD8, 0xFF], DetectedFormat::Image(ImageFormat::Jpeg)),
    ([0x42, 0x4D, 0, 0], DetectedFormat::Image(ImageFormat::Bmp)),
    (
      [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50],
      DetectedFormat::Image(ImageFormat::Webp),
    ),
    ([0x49, 0x49, 0x2A, 0], DetectedFormat::Image(ImageFormat::Tiff)),
    ([0x4D, 0x4D, 0, 0x2A], DetectedFormat::Image(ImageFormat::Tiff)),
  ]
  for fixture in fixtures {
    let result = detect_format(input_from_bytes(Bytes::from_array(fixture.0)))
    assert_true(result.format == fixture.1)
    assert_true(result.notes.contains("magic_bytes"))
  }
  let broken_zip = detect_format(
    input_from_bytes(Bytes::from_array([0x50, 0x4B, 0x03, 0x04, 0x00])),
  )
  assert_true(broken_zip.format == DetectedFormat::Zip)
}

///|
test "input detection covers structured text signatures" {
  let fixtures : Array[(String, DetectedFormat)] = [
    ("WEBVTT\n\n00:00.000 --> 00:01.000", DetectedFormat::Vtt),
    ("From: alice@example.test\nSubject: Hi\n\nBody", DetectedFormat::Eml),
    ("Title\n=====\n\nBody", DetectedFormat::Rst),
    ("= Document Title\nAuthor Name", DetectedFormat::Asciidoc),
    ("\\documentclass{article}\n\\begin{document}", DetectedFormat::Tex),
    ("1\n00:00:01,000 --> 00:00:02,000\nHello", DetectedFormat::Srt),
  ]
  for fixture in fixtures {
    let result = detect_format(input_from_text(fixture.0))
    assert_true(result.format == fixture.1)
    assert_true(result.notes.contains("magic_text"))
  }
  let notebook = detect_format(
    input_from_text(
      "{\"cells\":[{\"cell_type\":\"markdown\"}],\"metadata\":{},\"nbformat\":4}",
    ),
  )
  assert_true(notebook.format == DetectedFormat::Ipynb)
}

///|
test "input format labels include aliases media and unknown" {
  let aliases : Array[(String, DetectedFormat)] = [
    ("md", DetectedFormat::Markdown),
    ("yml", DetectedFormat::Yaml),
    ("htm", DetectedFormat::Html),
    ("latex", DetectedFormat::Tex),
    ("adoc", DetectedFormat::Asciidoc),
    ("msg", DetectedFormat::Eml),
    ("wav", DetectedFormat::Audio(AudioFormat::Wav)),
    ("m4a", DetectedFormat::Audio(AudioFormat::M4a)),
    ("jpeg", DetectedFormat::Image(ImageFormat::Jpeg)),
    ("tiff", DetectedFormat::Image(ImageFormat::Tiff)),
    ("unsupported", DetectedFormat::Unknown),
  ]
  for entry in aliases {
    assert_true(parse_detected_format(entry.0) == entry.1)
  }
  assert_eq(audio_format_name(AudioFormat::Mp3), "mp3")
  assert_eq(image_format_name(ImageFormat::Webp), "webp")
  assert_true(
    detected_format_is_image_candidate(DetectedFormat::Image(ImageFormat::Bmp)),
  )
  assert_true(!detected_format_is_image_candidate(DetectedFormat::Pdf))
}

///|
test "input readers prefer attached payloads and report controlled failures" {
  let source = input_from_path("/definitely/missing/markitdown-input")
    |> with_text_payload("attached")
    |> with_bytes_payload(Bytes::from_array([65, 66]))
  assert_true(input_text(source) is None)
  assert_true(input_bytes(source) is Some(_))
  assert_true(read_input_text(source) == Ok("AB"))
  assert_true(read_input_bytes(source).map(bytes => bytes.length()) == Ok(2))
  let invalid = input_from_bytes(Bytes::from_array([0x80]))
  assert_true(read_input_text(invalid) == Err("utf8 decode failed"))
  let failed = input_from_reader({
    size: None,
    read_at: fn(_offset, _length) { Err("unavailable") },
  })
  assert_true(read_input_text(failed) == Err("reader read failed: unavailable"))
  assert_true(
    read_input_bytes(failed) == Err("reader read failed: unavailable"),
  )
}

///|
test "reader payload supports bounded detection and complete materialization" {
  let payload = @utf8.encode("reader payload")
  let reader = make_input_reader(
    fn(offset, length) {
      let start = offset.to_int()
      let end = (start + length).min(payload.length())
      Ok(payload.view(start~, end~).to_owned())
    },
    size=payload.length().to_int64(),
  )
  let source = input_from_reader(reader, source_name="fixture.txt")
  assert_true(input_kind(source) == InputKind::Reader)
  assert_true(input_path(source) is None)
  assert_true(read_input_prefix(source, 6) == Ok(@utf8.encode("reader")))
  assert_true(read_input_text(source) == Ok("reader payload"))
  assert_true(read_input_bytes(source) == Ok(payload))
}

///|
test "source cursor borrows memory views and bounds random access" {
  let bytes = @utf8.encode("0123456789")
  let cursor = open_source_cursor(input_from_bytes(bytes), max_bytes=10L).unwrap()
  assert_true(cursor.size == Some(10L))
  assert_true(
    source_cursor_read_at(cursor, 3L, length=4) == Ok(@utf8.encode("3456")),
  )
  assert_true(
    source_cursor_view_at(cursor, 3, 4).map(view => view.to_owned()) ==
    Some(@utf8.encode("3456")),
  )
  assert_true(source_cursor_read_at(cursor, 10L) == Ok(Bytes::new(0)))
  assert_true(source_cursor_read_at(cursor, -1L) is Err(_))
  assert_true(
    open_source_cursor(input_from_bytes(bytes), max_bytes=9L) is Err(_),
  )
}

///|
test "input MIME registry covers every supported format family" {
  let fixtures : Array[(String, DetectedFormat)] = [
    ("text/plain", DetectedFormat::Txt),
    ("text/x-markdown", DetectedFormat::Markdown),
    ("text/csv", DetectedFormat::Csv),
    ("text/tab-separated-values", DetectedFormat::Tsv),
    ("application/x-subrip", DetectedFormat::Srt),
    ("text/vtt", DetectedFormat::Vtt),
    ("application/json", DetectedFormat::Json),
    ("application/x-jupyter-notebook+json", DetectedFormat::Ipynb),
    ("application/xml", DetectedFormat::Xml),
    ("application/x-yaml", DetectedFormat::Yaml),
    ("application/toml", DetectedFormat::Toml),
    ("text/html", DetectedFormat::Html),
    ("application/x-tex", DetectedFormat::Tex),
    ("text/x-rst", DetectedFormat::Rst),
    ("text/asciidoc", DetectedFormat::Asciidoc),
    ("message/rfc822", DetectedFormat::Eml),
    ("application/zip", DetectedFormat::Zip),
    ("application/epub+zip", DetectedFormat::Epub),
    ("application/vnd.oasis.opendocument.text", DetectedFormat::Odt),
    ("application/vnd.oasis.opendocument.spreadsheet", DetectedFormat::Ods),
    ("application/vnd.oasis.opendocument.presentation", DetectedFormat::Odp),
    ("application/pdf", DetectedFormat::Pdf),
    (
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      DetectedFormat::Docx,
    ),
    (
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      DetectedFormat::Pptx,
    ),
    (
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      DetectedFormat::Xlsx,
    ),
    ("audio/x-wav", DetectedFormat::Audio(AudioFormat::Wav)),
    ("audio/mpeg", DetectedFormat::Audio(AudioFormat::Mp3)),
    ("audio/x-m4a", DetectedFormat::Audio(AudioFormat::M4a)),
    ("image/jpeg", DetectedFormat::Image(ImageFormat::Jpeg)),
    ("image/bmp", DetectedFormat::Image(ImageFormat::Bmp)),
    ("image/webp", DetectedFormat::Image(ImageFormat::Webp)),
    ("image/tiff", DetectedFormat::Image(ImageFormat::Tiff)),
  ]
  for fixture in fixtures {
    let detected = detect_format_from_mime(
      Some(" " + fixture.0.to_upper() + " "),
    )
    assert_true(detected.unwrap().0 == fixture.1)
    assert_true(detected.unwrap().1.contains("mime_type"))
  }
  assert_true(detect_format_from_mime(None) is None)
  assert_true(detect_format_from_mime(Some("  ")) is None)
  assert_true(detect_format_from_mime(Some("application/unknown")) is None)
}

///|
test "input canonical labels round trip all detected formats" {
  let formats : Array[DetectedFormat] = [
    DetectedFormat::Txt,
    DetectedFormat::Markdown,
    DetectedFormat::Csv,
    DetectedFormat::Tsv,
    DetectedFormat::Srt,
    DetectedFormat::Vtt,
    DetectedFormat::Json,
    DetectedFormat::Jsonl,
    DetectedFormat::Ndjson,
    DetectedFormat::Ipynb,
    DetectedFormat::Xml,
    DetectedFormat::Yaml,
    DetectedFormat::Toml,
    DetectedFormat::Html,
    DetectedFormat::Tex,
    DetectedFormat::Rst,
    DetectedFormat::Asciidoc,
    DetectedFormat::Eml,
    DetectedFormat::Zip,
    DetectedFormat::Epub,
    DetectedFormat::Odt,
    DetectedFormat::Ods,
    DetectedFormat::Odp,
    DetectedFormat::Pdf,
    DetectedFormat::Docx,
    DetectedFormat::Pptx,
    DetectedFormat::Xlsx,
    DetectedFormat::Audio(AudioFormat::Wav),
    DetectedFormat::Audio(AudioFormat::Mp3),
    DetectedFormat::Audio(AudioFormat::M4a),
    DetectedFormat::Image(ImageFormat::Png),
    DetectedFormat::Image(ImageFormat::Jpg),
    DetectedFormat::Image(ImageFormat::Jpeg),
    DetectedFormat::Image(ImageFormat::Bmp),
    DetectedFormat::Image(ImageFormat::Webp),
    DetectedFormat::Image(ImageFormat::Tif),
    DetectedFormat::Image(ImageFormat::Tiff),
    DetectedFormat::Unknown,
  ]
  for format in formats {
    let name = detected_format_name(format)
    assert_true(parse_detected_format(name) == format)
  }
  assert_eq(input_source_name_from_path("/tmp/file.json"), "file.json")
  assert_true(format_from_extension("no-extension") == DetectedFormat::Unknown)
  assert_true(format_from_extension(" REPORT.PDF ") == DetectedFormat::Pdf)
}

///|
test "input text signature helpers reject malformed lookalikes" {
  assert_true(!detect_eml_text_signature("From: a\nBody"))
  assert_true(!detect_rst_text_signature("Title\n==x"))
  assert_true(!detect_asciidoc_text_signature("ordinary text"))
  assert_true(!detect_tex_text_signature("ordinary text"))
  assert_true(!detect_srt_text_signature("one\nnot a timestamp\ntext"))
  assert_true(ascii_digits_only("123"))
  assert_true(!ascii_digits_only("12a"))
  assert_true(!ascii_digits_only(""))
  assert_true(bytes_look_text_like(Bytes::from_array([])))
  assert_true(!bytes_look_text_like(Bytes::from_array([0])))
  assert_true(!bytes_look_text_like(Bytes::from_array([1, 2, 3, 4])))
  assert_true(decode_utf8_trimmed(Bytes::from_array([0x80])) is None)
  assert_eq(bytes_prefix_ascii([65, 66, 67], 1, 2), "BC")
}
