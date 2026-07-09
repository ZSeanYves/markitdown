///|
fn pdf_wbtest_tiny_pdf_bytes() -> Bytes {
  @utf8.encode(
    [
      "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      "endobj", "2 0 obj", "<< /Length 54 >>", "stream", "BT /F1 12 Tf 1 0 0 1 50 700 Tm (Hello PDF backend) Tj ET",
      "endstream", "endobj", "4 0 obj", "<< /Type /Page /Parent 5 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
      "endobj", "5 0 obj", "<< /Type /Pages /Kids [4 0 R] /Count 1 >>", "endobj",
      "6 0 obj", "<< /Type /Catalog /Pages 5 0 R >>", "endobj", "trailer", "<< /Size 7 /Root 6 0 R >>",
      "%%EOF", "",
    ].join("\n"),
  )
}

///|
fn pdf_wbtest_image_only_pdf_bytes() -> Bytes {
  let jpeg_hex = "ffd8ffe000104a46494600010100000000000000ffdb004300030202020202030202020303030304060404040404080606050609080a0a090809090a" +
    "0c0f0c0a0b0e0b09090d110d0e0f101011100a0c12131210130f101010ffdb00430103030304030408040408100b090b101010101010101010101010" +
    "1010101010101010101010101010101010101010101010101010101010101010101010101010ffc00011080001000103011100021101031101ffc400" +
    "14000100000000000000000000000000000009ffc40014100100000000000000000000000000000000ffc40014010100000000000000000000000000" +
    "000005ffc40014110100000000000000000000000000000000ffda000c03010002110311003f003f0e847fffd9>"
  let content = ["q", "32 0 0 24 72 120 cm", "/Im0 Do", "Q", ""].join("\n")
  @utf8.encode(
    [
      "%PDF-1.4",
      "1 0 obj",
      "<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter [ /ASCIIHexDecode /DCTDecode ] /Length " +
      jpeg_hex.length().to_string() +
      " >>",
      "stream",
      jpeg_hex,
      "endstream",
      "endobj",
      "2 0 obj",
      "<< /Length " + content.length().to_string() + " >>",
      "stream",
      content,
      "endstream",
      "endobj",
      "3 0 obj",
      "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /ProcSet [ /PDF /ImageC ] /XObject << /Im0 1 0 R >> >> /Contents 2 0 R >>",
      "endobj",
      "4 0 obj",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "endobj",
      "5 0 obj",
      "<< /Type /Catalog /Pages 4 0 R >>",
      "endobj",
      "trailer",
      "<< /Size 6 /Root 5 0 R >>",
      "%%EOF",
      "",
    ].join("\n"),
  )
}

///|
fn pdf_wbtest_single_image_pdf_bytes(
  image_object_lines : Array[String],
  extra_object_lines? : Array[String] = [],
) -> Bytes {
  let content = ["q", "32 0 0 24 72 120 cm", "/Im0 Do", "Q", ""].join("\n")
  let lines : Array[String] = ["%PDF-1.4"]
  lines.append(image_object_lines[:])
  lines.append([
    "2 0 obj",
    "<< /Length " + content.length().to_string() + " >>",
    "stream",
    content,
    "endstream",
    "endobj",
    "3 0 obj",
    "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /ProcSet [ /PDF /ImageC ] /XObject << /Im0 1 0 R >> >> /Contents 2 0 R >>",
    "endobj",
    "4 0 obj",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "endobj",
    "5 0 obj",
    "<< /Type /Catalog /Pages 4 0 R >>",
    "endobj",
  ])
  lines.append(extra_object_lines[:])
  lines.append(["trailer", "<< /Size 10 /Root 5 0 R >>", "%%EOF", ""])
  @utf8.encode(lines.join("\n"))
}

///|
fn pdf_wbtest_single_page_text_pdf_bytes(
  font_object_lines : Array[String],
  content : String,
  extra_object_lines? : Array[String] = [],
) -> Bytes {
  let lines : Array[String] = ["%PDF-1.4"]
  lines.append(font_object_lines[:])
  lines.append([
    "3 0 obj",
    "<< /Length " + content.length().to_string() + " >>",
    "stream",
    content,
    "endstream",
    "endobj",
    "4 0 obj",
    "<< /Type /Page /Parent 5 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >> /Contents 3 0 R >>",
    "endobj",
    "5 0 obj",
    "<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
    "endobj",
    "6 0 obj",
    "<< /Type /Catalog /Pages 5 0 R >>",
    "endobj",
  ])
  lines.append(extra_object_lines[:])
  lines.append(["trailer", "<< /Size 7 /Root 6 0 R >>", "%%EOF", ""])
  @utf8.encode(lines.join("\n"))
}

///|
fn pdf_wbtest_ccitt_image_pdf_bytes() -> Bytes {
  let fax_hex = "0000>"
  pdf_wbtest_single_image_pdf_bytes([
    "1 0 obj",
    "<< /Type /XObject /Subtype /Image /Width 16 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 1 /Filter [ /ASCIIHexDecode /CCITTFaxDecode ] /DecodeParms [ null << /K -1 /Columns 16 /Rows 1 /BlackIs1 true /EncodedByteAlign true >> ] /Length " +
    fax_hex.length().to_string() +
    " >>",
    "stream",
    fax_hex,
    "endstream",
    "endobj",
  ])
}

///|
fn pdf_wbtest_jpx_image_pdf_bytes() -> Bytes {
  let jpx_hex = "0000000c6a5020200d0a870a00000014667479706a703220000000006a7032>"
  pdf_wbtest_single_image_pdf_bytes([
    "1 0 obj",
    "<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter [ /ASCIIHexDecode /JPXDecode ] /Length " +
    jpx_hex.length().to_string() +
    " >>",
    "stream",
    jpx_hex,
    "endstream",
    "endobj",
  ])
}

///|
fn pdf_wbtest_jbig2_image_pdf_bytes() -> Bytes {
  let jbig2_hex = "974a42320d0a1a0a00000000>"
  pdf_wbtest_single_image_pdf_bytes(
    [
      "1 0 obj",
      "<< /Type /XObject /Subtype /Image /Width 64 /Height 64 /ColorSpace /DeviceGray /BitsPerComponent 1 /Filter [ /ASCIIHexDecode /JBIG2Decode ] /DecodeParms [ null << /JBIG2Globals 9 0 R >> ] /Length " +
      jbig2_hex.length().to_string() +
      " >>",
      "stream",
      jbig2_hex,
      "endstream",
      "endobj",
    ],
    extra_object_lines=[
      "9 0 obj", "<< /Length 0 >>", "stream", "endstream", "endobj",
    ],
  )
}

///|
fn pdf_wbtest_inline_payload_bytes(asset : @core.AssetRef) -> Bytes? {
  let payload = match asset.attrs.get("inline_payload") {
    Some(value) => value
    None => return None
  }
  try @base64.decode(payload, url_safe=false) |> Some catch {
    _ => None
  }
}

///|
test "pdf native backend repeated extraction stays cache-free and artifact-neutral" {
  let bytes = pdf_wbtest_tiny_pdf_bytes()
  let source = @input.input_from_bytes_with_format(
    bytes,
    "cache-hit.pdf",
    Some(@input.DetectedFormat::Pdf),
  )

  let first = match extract_pdf_native_document(source) {
    Ok(document) => document
    Err(err) => fail("first extract failed: " + err.to_string())
  }
  let second = match extract_pdf_native_document(source) {
    Ok(document) => document
    Err(err) => fail("second extract failed: " + err.to_string())
  }

  assert_true(
    first.diagnostics.metrics.get("probe_artifact_reused") == Some("false"),
  )
  assert_true(
    second.diagnostics.metrics.get("probe_artifact_reused") == Some("false"),
  )
  assert_true(
    first.diagnostics.metrics.get("process_cache_hit") == Some("false"),
  )
  assert_true(
    second.diagnostics.metrics.get("process_cache_hit") == Some("false"),
  )
}

///|
test "pdf native backend extracts exportable image xobjects without empty text failures" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_image_only_pdf_bytes(),
    "image-only.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("image-only extract failed: " + err.to_string())
  }
  assert_eq(document.pages.length(), 1)
  assert_true(
    document.diagnostics.metrics.get("pdf_empty_text_layer") == Some("true"),
  )
  assert_true(document.diagnostics.metrics.get("image_count") == Some("1"))
  assert_true(document.diagnostics.metrics.get("asset_count") == Some("1"))
  match document.pages[0].image_candidates {
    [image] =>
      match image.asset_ref {
        Some(asset) => {
          assert_true(asset.asset_id == "pdf:1")
          assert_true(asset.mime_type == Some("image/jpeg"))
          assert_true(asset.attrs.get("file_ext") == Some("jpg"))
          assert_true(asset.attrs.get("inline_payload_kind") == Some("base64"))
        }
        None => fail("expected exportable image asset ref")
      }
    _ => fail("expected one image candidate")
  }
}

///|
test "pdf native backend exports ccitt fax images as tracked tiff assets" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_ccitt_image_pdf_bytes(),
    "ccitt-image.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("ccitt image extract failed: " + err.to_string())
  }
  match document.pages[0].image_candidates {
    [image] =>
      match image.asset_ref {
        Some(asset) => {
          assert_true(asset.mime_type == Some("image/tiff"))
          assert_true(asset.attrs.get("file_ext") == Some("tif"))
          assert_true(
            asset.attrs.get("pdf_filter_chain") ==
            Some("ASCIIHexDecode,CCITTFaxDecode"),
          )
          assert_true(
            asset.attrs.get("pdf_decode_mode") == Some("container_passthrough"),
          )
          assert_true(
            asset.attrs.get("pdf_source_encoding") == Some("CCITTFaxDecode"),
          )
          match pdf_wbtest_inline_payload_bytes(asset) {
            Some(decoded) => {
              let payload = decoded.to_array()
              assert_true(payload.length() > 4)
              assert_true(payload[0].to_int() == 'I'.to_int())
              assert_true(payload[1].to_int() == 'I'.to_int())
              assert_true(payload[2].to_int() == 42)
              assert_true(payload[3].to_int() == 0)
            }
            None => fail("expected decodable ccitt inline payload")
          }
        }
        None => fail("expected exportable ccitt image asset ref")
      }
    _ => fail("expected one ccitt image candidate")
  }
}

///|
test "pdf native backend preserves jpx images after prefix filter decode" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_jpx_image_pdf_bytes(),
    "jpx-image.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("jpx image extract failed: " + err.to_string())
  }
  match document.pages[0].image_candidates {
    [image] =>
      match image.asset_ref {
        Some(asset) => {
          assert_true(asset.mime_type == Some("image/jp2"))
          assert_true(asset.attrs.get("file_ext") == Some("jp2"))
          assert_true(
            asset.attrs.get("pdf_filter_chain") ==
            Some("ASCIIHexDecode,JPXDecode"),
          )
          assert_true(
            asset.attrs.get("pdf_decode_mode") == Some("container_passthrough"),
          )
          assert_true(
            asset.attrs.get("pdf_source_encoding") == Some("JPXDecode"),
          )
        }
        None => fail("expected exportable jpx image asset ref")
      }
    _ => fail("expected one jpx image candidate")
  }
}

///|
test "pdf native backend preserves jbig2 globals and raw asset metadata" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_jbig2_image_pdf_bytes(),
    "jbig2-image.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("jbig2 image extract failed: " + err.to_string())
  }
  match document.pages[0].image_candidates {
    [image] =>
      match image.asset_ref {
        Some(asset) => {
          assert_true(asset.mime_type == Some("image/x-jbig2"))
          assert_true(asset.attrs.get("file_ext") == Some("jb2"))
          assert_true(
            asset.attrs.get("pdf_filter_chain") ==
            Some("ASCIIHexDecode,JBIG2Decode"),
          )
          assert_true(
            asset.attrs.get("pdf_decode_mode") == Some("raw_preserved"),
          )
          assert_true(
            asset.attrs.get("pdf_source_encoding") == Some("JBIG2Decode"),
          )
          assert_true(
            asset.attrs.get("pdf_jbig2_globals_object_id") == Some("9"),
          )
        }
        None => fail("expected exportable jbig2 image asset ref")
      }
    _ => fail("expected one jbig2 image candidate")
  }
}

///|
test "pdf native backend keeps vertical fragments in right-to-left top-down order" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_tiny_pdf_bytes(),
    "vertical-order.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let geometry = make_pdf_page_geometry(1, 200.0, 200.0)
  let fragments : Array[PdfNativeTextFragment] = [
    {
      text: "乙",
      preserves_outer_space: false,
      x: 100.0,
      y: 150.0,
      font_name: Some("F0"),
      font_size: Some(12.0),
      bbox: make_pdf_bbox(100.0, 138.0, 12.0, 12.0),
      vertical_writing: true,
    },
    {
      text: "丙",
      preserves_outer_space: false,
      x: 80.0,
      y: 180.0,
      font_name: Some("F0"),
      font_size: Some(12.0),
      bbox: make_pdf_bbox(80.0, 168.0, 12.0, 12.0),
      vertical_writing: true,
    },
    {
      text: "甲",
      preserves_outer_space: false,
      x: 100.0,
      y: 180.0,
      font_name: Some("F0"),
      font_size: Some(12.0),
      bbox: make_pdf_bbox(100.0, 168.0, 12.0, 12.0),
      vertical_writing: true,
    },
  ]
  let lines = pdf_group_text_fragments_into_lines(source, geometry, fragments)
  assert_eq(lines.length(), 2)
  assert_eq(pdf_native_line_text(lines[0]), "甲乙")
  assert_eq(pdf_native_line_text(lines[1]), "丙")
}

///|
test "pdf native backend decodes euc-h raw text without tounicode" {
  let content = "BT /F1 24 Tf 72 160 Td <A4A2A4A4A4A6A4A8A4AA> Tj ET"
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_single_page_text_pdf_bytes(
      [
        "1 0 obj", "<< /Type /Font /Subtype /Type0 /BaseFont /MS-Gothic /DescendantFonts [ 2 0 R ] /Encoding /EUC-H >>",
        "endobj", "2 0 obj", "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /MS-Gothic /CIDSystemInfo << /Registry (Adobe) /Ordering (Japan1) /Supplement 2 >> /DW 1000 >>",
        "endobj",
      ],
      content,
    ),
    "euc-h-noembed.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("euc-h extract failed: " + err.to_string())
  }
  assert_eq(document.pages.length(), 1)
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "あいうえお",
  )
}

///|
test "pdf native backend decodes shift-jis raw text without tounicode" {
  let content = "BT /F1 24 Tf 72 160 Td <82A082A282A482A682A8> Tj ET"
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_single_page_text_pdf_bytes(
      [
        "1 0 obj", "<< /Type /Font /Subtype /Type0 /BaseFont /MS-Gothic /DescendantFonts [ 2 0 R ] /Encoding /90ms-RKSJ-H >>",
        "endobj", "2 0 obj", "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /MS-Gothic /CIDSystemInfo << /Registry (Adobe) /Ordering (Japan1) /Supplement 2 >> /DW 1000 >>",
        "endobj",
      ],
      content,
    ),
    "sjis-noembed.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("shift-jis extract failed: " + err.to_string())
  }
  assert_eq(document.pages.length(), 1)
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "あいうえお",
  )
}

///|
test "pdf native backend decodes raw gb text when chinese font names are hex escaped" {
  let content = "BT /F1 24 Tf 72 160 Td <C4BFC2BC20> Tj ET"
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_single_page_text_pdf_bytes(
      [
        "1 0 obj", "<< /Type /Font /Subtype /TrueType /BaseFont /#CB#CE#CC#E5 /Encoding /WinAnsiEncoding >>",
        "endobj", "2 0 obj", "<< >>", "endobj",
      ],
      content,
    ),
    "raw-gb-fontname.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("raw gb extract failed: " + err.to_string())
  }
  assert_eq(document.pages.length(), 1)
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "目录",
  )
}

///|
test "pdf native backend handles unicode terminal punctuation without crashing" {
  let line = make_pdf_native_text_line(
    [
      make_pdf_native_text_span(
        "段落。",
        make_pdf_bbox(0.0, 0.0, 12.0, 12.0),
      ),
    ],
    make_pdf_bbox(0.0, 0.0, 12.0, 12.0),
  )
  assert_true(pdf_line_has_strong_terminal_punctuation(line))
}

///|
test "pdf native backend malformed input stays fail closed" {
  let source = @input.input_from_bytes_with_format(
    @utf8.encode("not-a-pdf"),
    "broken.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Err(err) => assert_true(err.to_string() != "")
    Ok(_) => fail("expected malformed PDF input to fail closed")
  }
}
