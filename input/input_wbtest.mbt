///|
test "input detection honors explicit mime extension and heuristic priority" {
  let explicit = input_from_text_with_format(
      "plain",
      "fixture.pdf",
      Some(Markdown),
    )
    |> with_mime_type(Some("application/pdf"))
  let explicit_result = detect_format(explicit)
  assert_true(explicit_result.format == Markdown)
  assert_true(explicit_result.used_explicit_format)
  assert_true(!explicit_result.used_extension)

  let mime = input_from_text("plain", source_name="fixture.unknown")
    |> with_mime_type(Some(" image/png "))
  let mime_result = (default_format_detector().detect)(mime)
  assert_true(mime_result.format == Image(Png))
  assert_true(mime_result.notes.contains("image_ocr_candidate"))

  let extension = detect_format(input_from_path("/tmp/report.DOCX"))
  assert_true(extension.format == Docx)
  assert_true(extension.used_extension && extension.binary_like)

  let text = detect_format(input_from_text("ordinary text"))
  assert_true(text.format == Txt)
  assert_true(text.text_like && text.notes == ["text_heuristic"])
  let binary = detect_format(input_from_bytes(Bytes::from_array([0, 1, 2])))
  assert_true(binary.format == Unknown)
  assert_true(binary.binary_like && binary.notes == ["binary_heuristic"])
}

///|
test "input detection covers binary magic signatures" {
  let fixtures : Array[(Array[Byte], DetectedFormat)] = [
    ([0x25, 0x50, 0x44, 0x46], Pdf),
    ([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45], Audio(Wav)),
    ([0x49, 0x44, 0x33], Audio(Mp3)),
    ([0xFF, 0xE0], Audio(Mp3)),
    ([0x89, 0x50, 0x4E, 0x47], Image(Png)),
    ([0xFF, 0xD8, 0xFF], Image(Jpeg)),
    ([0x42, 0x4D, 0, 0], Image(Bmp)),
    ([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50], Image(Webp)),
    ([0x49, 0x49, 0x2A, 0], Image(Tiff)),
    ([0x4D, 0x4D, 0, 0x2A], Image(Tiff)),
  ]
  for fixture in fixtures {
    let result = detect_format(input_from_bytes(Bytes::from_array(fixture.0)))
    assert_true(result.format == fixture.1)
    assert_true(result.notes.contains("magic_bytes"))
  }
  let broken_zip = detect_format(
    input_from_bytes(Bytes::from_array([0x50, 0x4B, 0x03, 0x04, 0x00])),
  )
  assert_true(broken_zip.format == Zip)
}

///|
test "input detection covers structured text signatures" {
  let fixtures : Array[(String, DetectedFormat)] = [
    ("WEBVTT\n\n00:00.000 --> 00:01.000", Vtt),
    ("From: alice@example.test\nSubject: Hi\n\nBody", Eml),
    ("Title\n=====\n\nBody", Rst),
    ("= Document Title\nAuthor Name", Asciidoc),
    ("\\documentclass{article}\n\\begin{document}", Tex),
    ("1\n00:00:01,000 --> 00:00:02,000\nHello", Srt),
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
  assert_true(notebook.format == Ipynb)
}

///|
test "input format labels include aliases media and unknown" {
  let aliases : Array[(String, DetectedFormat)] = [
    ("md", Markdown),
    ("yml", Yaml),
    ("htm", Html),
    ("latex", Tex),
    ("adoc", Asciidoc),
    ("msg", Eml),
    ("wav", Audio(Wav)),
    ("m4a", Audio(M4a)),
    ("jpeg", Image(Jpeg)),
    ("tiff", Image(Tiff)),
    ("unsupported", Unknown),
  ]
  for entry in aliases {
    assert_true(parse_detected_format(entry.0) == entry.1)
  }
  assert_eq(audio_format_name(Mp3), "mp3")
  assert_eq(image_format_name(Webp), "webp")
  assert_true(detected_format_is_image_candidate(Image(Bmp)))
  assert_true(!detected_format_is_image_candidate(Pdf))
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
  assert_true(input_kind(source) == Reader)
  assert_true(input_path(source) is None)
  assert_true(read_input_prefix(source, 6) == Ok(@utf8.encode("reader")))
  assert_true(read_input_text(source) == Ok("reader payload"))
  assert_true(read_input_bytes(source) == Ok(payload))
}

///|
test "input payload branches enforce reader size and request contracts" {
  let raw_path : InputSource = {
    source_name: "raw.txt",
    payload: Path("/tmp/raw.txt"),
    origin_path: None,
    mime_type: None,
    explicit_format: None,
  }
  assert_true(input_kind(raw_path) == Path)
  assert_true(input_path(raw_path) == Some("/tmp/raw.txt"))
  assert_true(read_input_text(input_from_text("attached")) == Ok("attached"))
  assert_true(
    read_input_prefix(input_from_text("attached"), 0) == Ok(Bytes::new(0)),
  )
  let sized = input_from_reader(
    make_input_reader(fn(_offset, _length) { Ok(Bytes::new(0)) }, size=4L),
  )
  assert_true(input_size(sized) == Some(4L))
  assert_true(
    read_input_bytes(sized) == Err("reader ended before declared size"),
  )
  let oversized = input_from_reader(
    make_input_reader(fn(_offset, length) { Ok(Bytes::new(length + 1)) }),
  )
  assert_true(
    read_input_bytes(oversized) ==
    Err("reader returned more bytes than requested"),
  )
  let beyond = input_from_reader(
    make_input_reader(
      fn(_offset, _length) { Ok(@utf8.encode("toolong")) },
      size=3L,
    ),
  )
  assert_true(
    read_input_bytes(beyond) ==
    Err("reader returned bytes beyond declared size"),
  )
}

///|
test "input detection identifies real ZIP package families without extensions" {
  let fixtures : Array[(String, DetectedFormat)] = [
    ("samples/fixtures/contracts/docx/golden.docx", Docx),
    ("samples/fixtures/contracts/pptx/pptx_simple.pptx", Pptx),
    ("samples/fixtures/contracts/xlsx/sheet_simple.xlsx", Xlsx),
    (
      "samples/fixtures/contracts/epub/epub_spine_missing_item_boundary.epub",
      Epub,
    ),
    ("samples/fixtures/contracts/odt/odt_basic_sample.odt", Odt),
    ("samples/fixtures/contracts/ods/ods_basic_sample.ods", Ods),
    ("samples/fixtures/contracts/odp/odp_basic_sample.odp", Odp),
  ]
  for fixture in fixtures {
    let bytes = @fs.read_file_to_bytes(fixture.0)
    let result = detect_format(input_from_bytes(bytes, source_name="payload"))
    assert_true(result.format == fixture.1)
    assert_true(result.notes.contains("container_inspection"))
  }
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
  assert_true(source_cursor_view_at(cursor, -1, 1) is None)
  assert_true(source_cursor_view_at(cursor, 11, 1) is None)
  assert_true(
    open_source_cursor(input_from_bytes(bytes), max_bytes=9L) is Err(_),
  )
}

///|
test "input MIME registry covers every supported format family" {
  let fixtures : Array[(String, DetectedFormat)] = [
    ("text/plain", Txt),
    ("text/x-markdown", Markdown),
    ("text/csv", Csv),
    ("text/tab-separated-values", Tsv),
    ("application/x-subrip", Srt),
    ("text/vtt", Vtt),
    ("application/json", Json),
    ("application/x-jupyter-notebook+json", Ipynb),
    ("application/xml", Xml),
    ("application/x-yaml", Yaml),
    ("application/toml", Toml),
    ("text/html", Html),
    ("application/x-tex", Tex),
    ("text/x-rst", Rst),
    ("text/asciidoc", Asciidoc),
    ("message/rfc822", Eml),
    ("application/zip", Zip),
    ("application/epub+zip", Epub),
    ("application/vnd.oasis.opendocument.text", Odt),
    ("application/vnd.oasis.opendocument.spreadsheet", Ods),
    ("application/vnd.oasis.opendocument.presentation", Odp),
    ("application/pdf", Pdf),
    (
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      Docx,
    ),
    (
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      Pptx,
    ),
    ("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", Xlsx),
    ("audio/x-wav", Audio(Wav)),
    ("audio/mpeg", Audio(Mp3)),
    ("audio/x-m4a", Audio(M4a)),
    ("image/jpeg", Image(Jpeg)),
    ("image/bmp", Image(Bmp)),
    ("image/webp", Image(Webp)),
    ("image/tiff", Image(Tiff)),
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
    Txt,
    Markdown,
    Csv,
    Tsv,
    Srt,
    Vtt,
    Json,
    Jsonl,
    Ndjson,
    Ipynb,
    Xml,
    Yaml,
    Toml,
    Html,
    Tex,
    Rst,
    Asciidoc,
    Eml,
    Zip,
    Epub,
    Odt,
    Ods,
    Odp,
    Pdf,
    Docx,
    Pptx,
    Xlsx,
    Audio(Wav),
    Audio(Mp3),
    Audio(M4a),
    Image(Png),
    Image(Jpg),
    Image(Jpeg),
    Image(Bmp),
    Image(Webp),
    Image(Tif),
    Image(Tiff),
    Unknown,
  ]
  for format in formats {
    let name = detected_format_name(format)
    assert_true(parse_detected_format(name) == format)
  }
  assert_eq(input_source_name_from_path("/tmp/file.json"), "file.json")
  assert_true(format_from_extension("no-extension") == Unknown)
  assert_true(format_from_extension(" REPORT.PDF ") == Pdf)
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
