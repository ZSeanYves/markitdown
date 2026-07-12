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
fn pdf_wbtest_rgb_pixels_image_pdf_bytes() -> Bytes {
  let rgb_hex = "ff000000ff00>"
  pdf_wbtest_single_image_pdf_bytes([
    "1 0 obj",
    "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /ASCIIHexDecode /Length " +
    rgb_hex.length().to_string() +
    " >>",
    "stream",
    rgb_hex,
    "endstream",
    "endobj",
  ])
}

///|
fn pdf_wbtest_smask_image_pdf_bytes() -> Bytes {
  let rgb_hex = "ff000000ff00>"
  let alpha_hex = "40c0>"
  pdf_wbtest_single_image_pdf_bytes(
    [
      "1 0 obj",
      "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /SMask 9 0 R /Filter /ASCIIHexDecode /Length " +
      rgb_hex.length().to_string() +
      " >>",
      "stream",
      rgb_hex,
      "endstream",
      "endobj",
    ],
    extra_object_lines=[
      "9 0 obj",
      "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /ASCIIHexDecode /Length " +
      alpha_hex.length().to_string() +
      " >>",
      "stream",
      alpha_hex,
      "endstream",
      "endobj",
    ],
  )
}

///|
fn pdf_wbtest_color_key_image_pdf_bytes() -> Bytes {
  let rgb_hex = "ff000000ff00>"
  pdf_wbtest_single_image_pdf_bytes([
    "1 0 obj",
    "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Mask [255 255 0 0 0 0] /Filter /ASCIIHexDecode /Length " +
    rgb_hex.length().to_string() +
    " >>",
    "stream",
    rgb_hex,
    "endstream",
    "endobj",
  ])
}

///|
fn pdf_wbtest_cmyk_pixels_image_pdf_bytes() -> Bytes {
  let cmyk_hex = "00ffff0000ff00ff>"
  pdf_wbtest_single_image_pdf_bytes([
    "1 0 obj",
    "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceCMYK /BitsPerComponent 8 /Filter /ASCIIHexDecode /Length " +
    cmyk_hex.length().to_string() +
    " >>",
    "stream",
    cmyk_hex,
    "endstream",
    "endobj",
  ])
}

///|
fn pdf_wbtest_indexed_pixels_image_pdf_bytes() -> Bytes {
  let indexed_hex = "40>"
  pdf_wbtest_single_image_pdf_bytes([
    "1 0 obj",
    "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace [ /Indexed /DeviceRGB 1 <ff000000ff00> ] /BitsPerComponent 1 /Filter /ASCIIHexDecode /Length " +
    indexed_hex.length().to_string() +
    " >>",
    "stream",
    indexed_hex,
    "endstream",
    "endobj",
  ])
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
fn pdf_wbtest_bytes_from_hex(hex : String) -> Bytes {
  let bytes = match pdf_hex_byte_values(hex) {
    Some(value) => value
    None => abort("invalid wbtest hex payload")
  }
  let out : Array[Byte] = []
  for byte in bytes {
    out.push(byte.to_byte())
  }
  Bytes::from_array(out)
}

///|
priv struct PdfWbtestXrefEntry {
  object_id : Int
  entry_type : Int
  field1 : Int
  field2 : Int
}

///|
fn pdf_wbtest_indirect_object_text(object_id : Int, body : String) -> String {
  object_id.to_string() + " 0 obj\n" + body + "\nendobj\n"
}

///|
fn pdf_wbtest_hex_big_endian(value : Int, width : Int) -> String {
  let parts : Array[String] = []
  let mut shift = (width - 1) * 8
  while shift >= 0 {
    parts.push(pdf_hex_upper((value >> shift) & 0xFF, 2))
    shift -= 8
  }
  parts.join("")
}

///|
fn pdf_wbtest_xref_stream_entry_hex(
  entry_type : Int,
  field1 : Int,
  field2 : Int,
) -> String {
  pdf_wbtest_hex_big_endian(entry_type, 1) +
  pdf_wbtest_hex_big_endian(field1, 4) +
  pdf_wbtest_hex_big_endian(field2, 1)
}

///|
fn pdf_wbtest_xref_stream_pdf_bytes(
  direct_objects : Array[(Int, String)],
  root_object_id : Int,
  xref_object_id : Int,
  extra_entries? : Array[PdfWbtestXrefEntry] = [],
) -> Bytes {
  let chunks : Array[String] = ["%PDF-1.5\n"]
  let object_offsets : Map[Int, Int] = Map([])
  let mut current_offset = chunks[0].length()
  let mut max_object_id = xref_object_id
  for entry in direct_objects {
    let (object_id, body) = entry
    let object_text = pdf_wbtest_indirect_object_text(object_id, body)
    object_offsets.set(object_id, current_offset)
    chunks.push(object_text)
    current_offset += object_text.length()
    if object_id > max_object_id {
      max_object_id = object_id
    }
  }
  let xref_offset = current_offset
  let entry_overrides : Map[Int, PdfWbtestXrefEntry] = Map([])
  for entry in extra_entries {
    entry_overrides.set(entry.object_id, entry)
    if entry.object_id > max_object_id {
      max_object_id = entry.object_id
    }
  }
  let size = max_object_id + 1
  let xref_hex_parts : Array[String] = []
  for object_id in 0..<size {
    let entry : PdfWbtestXrefEntry = if object_id == 0 {
      { object_id, entry_type: 0, field1: 0, field2: 0xFF }
    } else if object_id == xref_object_id {
      { object_id, entry_type: 1, field1: xref_offset, field2: 0 }
    } else {
      match entry_overrides.get(object_id) {
        Some(value) => value
        None =>
          match object_offsets.get(object_id) {
            Some(offset) =>
              { object_id, entry_type: 1, field1: offset, field2: 0 }
            None => { object_id, entry_type: 0, field1: 0, field2: 0 }
          }
      }
    }
    xref_hex_parts.push(
      pdf_wbtest_xref_stream_entry_hex(
        entry.entry_type,
        entry.field1,
        entry.field2,
      ),
    )
  }
  let xref_stream = xref_hex_parts.join("") + ">"
  let xref_body = "<< /Type /XRef /Size " +
    size.to_string() +
    " /Root " +
    root_object_id.to_string() +
    " 0 R /W [1 4 1] /Index [0 " +
    size.to_string() +
    "] /Filter /ASCIIHexDecode /Length " +
    xref_stream.length().to_string() +
    " >>\nstream\n" +
    xref_stream +
    "\nendstream"
  chunks.push(pdf_wbtest_indirect_object_text(xref_object_id, xref_body))
  chunks.push("startxref\n" + xref_offset.to_string() + "\n%%EOF\n")
  @utf8.encode(chunks.join(""))
}

///|
fn pdf_wbtest_object_stream_body(entries : Array[(Int, String)]) -> String {
  let header_parts : Array[String] = []
  let body_parts : Array[String] = []
  let mut offset = 0
  for index in 0..<entries.length() {
    let (object_id, object_body) = entries[index]
    header_parts.push(object_id.to_string())
    header_parts.push(offset.to_string())
    body_parts.push(object_body)
    offset += object_body.length()
    if index + 1 < entries.length() {
      body_parts.push("\n")
      offset += 1
    }
  }
  let header = header_parts.join(" ") + " "
  let body = body_parts.join("")
  "<< /Type /ObjStm /N " +
  entries.length().to_string() +
  " /First " +
  header.length().to_string() +
  " /Length " +
  (header.length() + body.length()).to_string() +
  " >>\nstream\n" +
  header +
  body +
  "\nendstream"
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
test "pdf native backend normalizes decoded RGB pixels as PNG assets" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_rgb_pixels_image_pdf_bytes(),
    "rgb-pixels.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = extract_pdf_native_document(source).unwrap()
  match document.pages[0].image_candidates {
    [image] =>
      match image.asset_ref {
        Some(asset) => {
          assert_true(asset.mime_type == Some("image/png"))
          assert_true(asset.attrs.get("file_ext") == Some("png"))
          assert_true(
            asset.attrs.get("pdf_decode_mode") == Some("normalized_png"),
          )
          let payload = pdf_wbtest_inline_payload_bytes(asset).unwrap()
          assert_true(payload[0].to_int() == 0x89)
          assert_true(payload[1].to_int() == 0x50)
          assert_true(payload[2].to_int() == 0x4E)
          assert_true(payload[3].to_int() == 0x47)
        }
        None => fail("expected normalized PNG asset")
      }
    _ => fail("expected one RGB image candidate")
  }
}

///|
test "pdf native backend composes a matching soft mask into RGBA PNG" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_smask_image_pdf_bytes(),
    "smask-image.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = extract_pdf_native_document(source).unwrap()
  let asset = document.pages[0].image_candidates[0].asset_ref.unwrap()
  let payload = pdf_wbtest_inline_payload_bytes(asset).unwrap()
  assert_true(asset.mime_type == Some("image/png"))
  assert_true(payload[24].to_int() == 8)
  assert_true(payload[25].to_int() == 6)
}

///|
test "pdf native backend composes a color-key mask into RGBA PNG" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_color_key_image_pdf_bytes(),
    "color-key-image.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = extract_pdf_native_document(source).unwrap()
  let asset = document.pages[0].image_candidates[0].asset_ref.unwrap()
  let payload = pdf_wbtest_inline_payload_bytes(asset).unwrap()
  assert_true(payload[25].to_int() == 6)
}

///|
test "pdf native backend normalizes decoded CMYK pixels into RGB PNG" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_cmyk_pixels_image_pdf_bytes(),
    "cmyk-pixels.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = extract_pdf_native_document(source).unwrap()
  let asset = document.pages[0].image_candidates[0].asset_ref.unwrap()
  let payload = pdf_wbtest_inline_payload_bytes(asset).unwrap()
  assert_true(asset.mime_type == Some("image/png"))
  assert_true(payload[25].to_int() == 2)
}

///|
test "pdf native backend expands indexed palette pixels into RGB PNG" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_indexed_pixels_image_pdf_bytes(),
    "indexed-pixels.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = extract_pdf_native_document(source).unwrap()
  let asset = document.pages[0].image_candidates[0].asset_ref.unwrap()
  let payload = pdf_wbtest_inline_payload_bytes(asset).unwrap()
  assert_true(asset.mime_type == Some("image/png"))
  assert_true(payload[25].to_int() == 2)
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
test "pdf native backend decodes inline type0 font resources" {
  let content = "BT /F0 24 Tf 72 160 Td <6162632082A082A282A4> Tj ET"
  let source = @input.input_from_bytes_with_format(
    @utf8.encode(
      [
        "%PDF-1.4",
        "2 0 obj",
        "<< /Length " + content.length().to_string() + " >>",
        "stream",
        content,
        "endstream",
        "endobj",
        "3 0 obj",
        "<< /Type /Font /Subtype /CIDFontType0 /BaseFont /KozMinPr6N-Regular /CIDSystemInfo << /Registry (Adobe) /Ordering (Japan1) /Supplement 6 >> >>",
        "endobj",
        "4 0 obj",
        "<< /Type /Page /Parent 5 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F0 << /Type /Font /Subtype /Type0 /BaseFont /KozMinPro6N-Regular /Encoding /90ms-RKSJ-V /DescendantFonts [ 3 0 R ] >> >> >> /Contents 2 0 R >>",
        "endobj",
        "5 0 obj",
        "<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
        "endobj",
        "6 0 obj",
        "<< /Type /Catalog /Pages 5 0 R >>",
        "endobj",
        "trailer",
        "<< /Size 7 /Root 6 0 R >>",
        "%%EOF",
        "",
      ].join("\n"),
    ),
    "inline-type0-font.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("inline type0 font extract failed: " + err.to_string())
  }
  assert_eq(document.pages.length(), 1)
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "abc あいう",
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
test "pdf unijis ucs2 direct decode no longer requires static code2cid tables" {
  let cmap = match pdf_resolve_predefined_cmap("UniJIS-UCS2-H") {
    Some(value) => value
    None => fail("expected UniJIS-UCS2-H predefined cmap")
  }
  assert_true(cmap.direct_decode_kind == Some("utf16be"))
  assert_true(cmap.base_one_byte_ranges == [])
  assert_true(cmap.base_two_byte_ranges == [])
  let decoded = match
    pdf_predefined_cmap_decode_bytes([0x30, 0x42, 0x30, 0x44], cmap) {
    Some(value) => value
    None => fail("expected UniJIS-UCS2-H direct decode")
  }
  assert_eq(decoded.text, "あい")
}

///|
test "pdf predefined cmap range lookup honors vertical overrides and removals" {
  let cmap : PdfResolvedPredefinedCMap = {
    source_name: Some("test"),
    family: Some("Adobe-Japan1"),
    vertical_writing: true,
    code_width_mask: 0x3,
    base_one_byte_ranges: [32, 100, 3],
    base_two_byte_ranges: [0xA140, 200, 2],
    vertical_override_one_byte_ranges: [33, -1, 1],
    vertical_override_two_byte_ranges: [0xA141, 500, 1],
    range_blob: None,
    base_one_byte_range_offset: 0,
    base_one_byte_range_count: 0,
    base_two_byte_range_offset: 0,
    base_two_byte_range_count: 0,
    vertical_override_one_byte_range_offset: 0,
    vertical_override_one_byte_range_count: 0,
    vertical_override_two_byte_range_offset: 0,
    vertical_override_two_byte_range_count: 0,
    direct_decode_kind: None,
  }
  assert_true(pdf_predefined_cmap_lookup_cid(cmap, 1, 32) == Some(100))
  assert_true(pdf_predefined_cmap_lookup_cid(cmap, 1, 34) == Some(102))
  assert_true(pdf_predefined_cmap_lookup_cid(cmap, 1, 33) == None)
  assert_true(pdf_predefined_cmap_lookup_cid(cmap, 1, 35) == None)
  assert_true(pdf_predefined_cmap_lookup_cid(cmap, 2, 0xA140) == Some(200))
  assert_true(pdf_predefined_cmap_lookup_cid(cmap, 2, 0xA141) == Some(500))
  assert_true(pdf_predefined_cmap_lookup_cid(cmap, 2, 0xA142) == None)
}

///|
test "pdf predefined unicode runs handle boundaries and vertical overrides" {
  let runs = [10, 3, 0, 20, 2, 3]
  let codepoints = "ABCxy"
  assert_true(
    pdf_predefined_lookup_codepoint_in_runs(runs, codepoints, 10) == Some(65),
  )
  assert_true(
    pdf_predefined_lookup_codepoint_in_runs(runs, codepoints, 12) == Some(67),
  )
  assert_true(
    pdf_predefined_lookup_codepoint_in_runs(runs, codepoints, 13) == None,
  )
  assert_true(
    pdf_predefined_lookup_codepoint_in_runs(runs, codepoints, 21) == Some(121),
  )

  let vertical_cmap = match pdf_resolve_predefined_cmap("ETen-B5-V") {
    Some(value) => value
    None => fail("expected ETen-B5-V predefined cmap")
  }
  assert_true(
    pdf_predefined_cmap_lookup_cid(vertical_cmap, 2, 0xA15A) == Some(13743),
  )
  assert_true(pdf_predefined_cmap_lookup_cid(vertical_cmap, 2, 0xA159) == None)
  assert_true(
    pdf_predefined_cmap_lookup_cid(vertical_cmap, 2, 0xA14B) == Some(13646),
  )
  assert_true(
    pdf_predefined_family_unicode_value("Adobe-CNS1", true, 13743) ==
    Some(pdf_string_from_codepoints([9588])),
  )
  assert_true(
    pdf_predefined_family_unicode_value("Adobe-CNS1", true, 999999) == None,
  )
}

///|
test "pdf native backend resolves tounicode usecmap builtin parents" {
  let tounicode = [
    "/CIDInit /ProcSet findresource begin", "12 dict begin", "begincmap", "/Adobe-Japan1-UCS2 usecmap",
    "1 begincodespacerange", "<0000> <FFFF>", "endcodespacerange", "endcmap", "end",
    "end", "",
  ].join("\n")
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_single_page_text_pdf_bytes(
      [
        "1 0 obj", "<< /Type /Font /Subtype /Type0 /BaseFont /MS-Gothic /DescendantFonts [ 2 0 R ] /Encoding /Identity-H /ToUnicode 7 0 R >>",
        "endobj", "2 0 obj", "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /MS-Gothic /CIDSystemInfo << /Registry (Adobe) /Ordering (Japan1) /Supplement 2 >> /DW 1000 >>",
        "endobj",
      ],
      "BT /F1 24 Tf 72 160 Td <034B> Tj ET",
      extra_object_lines=[
        "7 0 obj",
        "<< /Length " + tounicode.length().to_string() + " >>",
        "stream",
        tounicode,
        "endstream",
        "endobj",
      ],
    ),
    "tounicode-usecmap.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("tounicode usecmap extract failed: " + err.to_string())
  }
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "あ",
  )
  assert_true(
    document.diagnostics.metrics
    .get("pdf_font_decode_path")
    .unwrap_or("")
    .contains("tounicode_builtin"),
  )
}

///|
test "pdf tounicode bfrange marks noncharacters invalid" {
  let info = pdf_parse_tounicode_cmap_info(
    [
      "/CIDInit /ProcSet findresource begin", "12 dict begin", "begincmap", "1 begincodespacerange",
      "<0000> <FFFF>", "endcodespacerange", "1 beginbfrange", "<1971> <1971> <FFFF>",
      "endbfrange", "endcmap", "end", "end",
    ].join("\n"),
  )
  assert_true(info.mapping.get("1971") == None)
  assert_true(info.invalid_keys.get("1971") == Some(true))
}

///|
test "pdf native backend applies simple font encoding differences" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_single_page_text_pdf_bytes(
      [
        "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding << /Type /Encoding /BaseEncoding /WinAnsiEncoding /Differences [ 65 /Agrave /Aacute ] >> >>",
        "endobj",
      ],
      "BT /F1 24 Tf 72 160 Td <4142> Tj ET",
    ),
    "differences-simple-font.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("differences extract failed: " + err.to_string())
  }
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "ÀÁ",
  )
  assert_true(
    document.diagnostics.metrics
    .get("pdf_font_decode_path")
    .unwrap_or("")
    .contains("encoding_differences"),
  )
}

///|
test "pdf native backend decodes ETen-B5 CID fonts without tounicode" {
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_single_page_text_pdf_bytes(
      [
        "1 0 obj", "<< /Type /Font /Subtype /Type0 /BaseFont /MingLiU /DescendantFonts [ 2 0 R ] /Encoding /ETen-B5-H >>",
        "endobj", "2 0 obj", "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /MingLiU /CIDSystemInfo << /Registry (Adobe) /Ordering (CNS1) /Supplement 4 >> /DW 1000 >>",
        "endobj",
      ],
      "BT /F1 24 Tf 72 160 Td <A440A441A442> Tj ET",
    ),
    "eten-b5-no-tounicode.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("eten-b5 extract failed: " + err.to_string())
  }
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "一乙丁",
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_predefined_cmap_used") == Some("true"),
  )
}

///|
test "pdf predefined cmap decodes ETen-B5 and KSC-EUC without raw heuristics" {
  let eten = match pdf_resolve_predefined_cmap("ETen-B5-H") {
    Some(value) => value
    None => fail("expected ETen-B5-H predefined cmap")
  }
  let eten_decoded = match
    pdf_predefined_cmap_decode_bytes([0xA4, 0x40, 0xA4, 0x41, 0xA4, 0x42], eten) {
    Some(value) => value
    None => fail("expected ETen-B5-H decode")
  }
  assert_eq(eten_decoded.text, "一乙丁")

  let ksc = match pdf_resolve_predefined_cmap("KSC-EUC-H") {
    Some(value) => value
    None => fail("expected KSC-EUC-H predefined cmap")
  }
  let ksc_decoded = match
    pdf_predefined_cmap_decode_bytes([0xB0, 0xA1, 0xB0, 0xA2, 0xB0, 0xA3], ksc) {
    Some(value) => value
    None => fail("expected KSC-EUC-H decode")
  }
  assert_eq(ksc_decoded.text, "가각간")
}

///|
test "pdf builtin adobe ucs2 tounicode maps surface cjk characters" {
  let info = match pdf_predefined_cmap_tounicode_info("Adobe-Japan1-UCS2") {
    Some(value) => value
    None => fail("expected Adobe-Japan1-UCS2 builtin map")
  }
  assert_true(info.mapping.get("034B") == Some("あ"))
  assert_true(info.widths == [2])
}

///|
test "pdf embedded sfnt parser recovers unicode cmap and hmtx widths" {
  let bytes = pdf_wbtest_bytes_from_hex(
    "000100000005004000020010636d6170000c00750000005c0000002c686561645f1040dd00000088000000366868656100010003000000c000000024686d747807080000000000e40000000c6d61787000040000000000f00000000600000001000300010000000c00040020000000040004000100000042ffff00000041ffffffc00001000000000001000000000000000000005f0f3cf5000003e800000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000301f400000258000002bc00000001000000030000",
  )
  let program = match pdf_parse_embedded_sfnt_font_program(bytes) {
    Some(value) => value
    None => fail("expected embedded sfnt program parse")
  }
  assert_true(pdf_embedded_font_program_unicode(program, 1) == Some("A"))
  assert_true(pdf_embedded_font_program_unicode(program, 2) == Some("B"))
  assert_true(
    pdf_lookup_flat_int_pairs(program.gid_advance_pairs, 1) == Some(600),
  )
  assert_true(
    pdf_lookup_flat_int_pairs(program.gid_advance_pairs, 2) == Some(700),
  )
}

///|
test "pdf embedded cid font decode uses cidtogidmap and explicit widths win" {
  let program = match
    pdf_parse_embedded_sfnt_font_program(
      pdf_wbtest_bytes_from_hex(
        "000100000005004000020010636d6170000c00750000005c0000002c686561645f1040dd00000088000000366868656100010003000000c000000024686d747807080000000000e40000000c6d61787000040000000000f00000000600000001000300010000000c00040020000000040004000100000042ffff00000041ffffffc00001000000000001000000000000000000005f0f3cf5000003e800000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000301f400000258000002bc00000001000000030000",
      ),
    ) {
    Some(value) => value
    None => fail("expected embedded sfnt program parse")
  }
  let info : PdfNativeFontInfo = {
    base_font: Some("Dummy"),
    normalized_base_font: Some("dummy"),
    descendant_subtype: Some("CIDFontType2"),
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    unicode_map: Map([]),
    tounicode_invalid_keys: Map([]),
    has_tounicode: false,
    tounicode_decode_failed: false,
    tounicode_builtin_name: None,
    predefined_cmap: pdf_resolve_predefined_cmap("Identity-H"),
    cid_collection_cmap: None,
    embedded_font_program: Some(program),
    cid_to_gid_map: Some([0, 1, 2]),
    simple_widths: Map([]),
    simple_default_width: None,
    cid_width_pairs: [1, 500, 2, 510],
    cid_default_width: None,
    cid_vertical_width_pairs: [],
    cid_default_vertical_width: None,
  }
  let decoded = match pdf_decode_hex_pdf_text_result("00010002", info) {
    Some(value) => value
    None => fail("expected identity-h embedded decode")
  }
  assert_eq(decoded.text, "AB")
  match decoded.units {
    [first, second] => {
      assert_true(pdf_font_unit_advance_1000(info, first) == (500, "pdf_dict"))
      assert_true(pdf_font_unit_advance_1000(info, second) == (510, "pdf_dict"))
    }
    _ => fail("expected two decoded units")
  }
}

///|
test "pdf invalid tounicode entries fail closed before fallback garbage" {
  let invalid_keys : Map[String, Bool] = Map([])
  invalid_keys.set("19D2", true)
  let info : PdfNativeFontInfo = {
    base_font: Some("Dummy"),
    normalized_base_font: Some("dummy"),
    descendant_subtype: Some("CIDFontType2"),
    encoding_name: Some("Identity-H"),
    code_hex_widths: [2],
    unicode_map: Map([]),
    tounicode_invalid_keys: invalid_keys,
    has_tounicode: true,
    tounicode_decode_failed: false,
    tounicode_builtin_name: None,
    predefined_cmap: pdf_resolve_predefined_cmap("Identity-H"),
    cid_collection_cmap: None,
    embedded_font_program: None,
    cid_to_gid_map: None,
    simple_widths: Map([]),
    simple_default_width: None,
    cid_width_pairs: [],
    cid_default_width: None,
    cid_vertical_width_pairs: [],
    cid_default_vertical_width: None,
  }
  match pdf_decode_hex_pdf_text_result("19D2", info) {
    None => ()
    Some(_) => fail("expected invalid ToUnicode decode to fail closed")
  }
}

///|
test "pdf direct cid family decode recovers identity h japan1 cids" {
  let cmap = match pdf_predefined_direct_cid_family("Adobe-Japan1", false) {
    Some(value) => value
    None => fail("expected Adobe-Japan1 cid family cmap")
  }
  let bytes : Array[Int] = []
  for byte in pdf_wbtest_bytes_from_hex("00350049004A0054").to_array() {
    bytes.push(byte.to_int())
  }
  let decoded = match pdf_predefined_cmap_decode_bytes(bytes, cmap) {
    Some(value) => value
    None => fail("expected identity-h cid family decode")
  }
  assert_eq(decoded.text, "This")
}

///|
test "pdf direct cid family decode recovers identity v japan1 cids" {
  let cmap = match pdf_predefined_direct_cid_family("Adobe-Japan1", true) {
    Some(value) => value
    None => fail("expected vertical Adobe-Japan1 cid family cmap")
  }
  let bytes : Array[Int] = []
  for byte in pdf_wbtest_bytes_from_hex("034B034D034F03510353").to_array() {
    bytes.push(byte.to_int())
  }
  let decoded = match pdf_predefined_cmap_decode_bytes(bytes, cmap) {
    Some(value) => value
    None => fail("expected identity-v cid family decode")
  }
  assert_eq(decoded.text, "あいうえお")
}

///|
test "pdf predefined cmap keeps single byte prefix on mixed width shift jis" {
  let cmap = match pdf_resolve_predefined_cmap("90ms-RKSJ-V") {
    Some(value) => value
    None => fail("expected 90ms-RKSJ-V predefined cmap")
  }
  let bytes : Array[Int] = []
  for byte in pdf_wbtest_bytes_from_hex("6162632082A082A282A4").to_array() {
    bytes.push(byte.to_int())
  }
  let decoded = match pdf_predefined_cmap_decode_bytes(bytes, cmap) {
    Some(value) => value
    None => fail("expected mixed-width predefined decode")
  }
  assert_eq(decoded.text, "abc あいう")
}

///|
test "pdf native backend reads xref stream documents without scan fallback" {
  let content = "BT /F1 12 Tf 1 0 0 1 50 150 Tm (XRef stream works) Tj ET"
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_xref_stream_pdf_bytes(
      [
        (1, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
        (
          2,
          "<< /Length " +
          content.length().to_string() +
          " >>\nstream\n" +
          content +
          "\nendstream",
        ),
        (
          3, "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
        ),
        (4, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
        (5, "<< /Type /Catalog /Pages 4 0 R >>"),
      ],
      5,
      6,
    ),
    "xref-stream.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("xref stream extract failed: " + err.to_string())
  }
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "XRef stream works",
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_xref_mode") == Some("xref_stream_v1"),
  )
}

///|
test "pdf native backend expands object streams referenced from xref streams" {
  let content = "BT /F1 12 Tf 1 0 0 1 50 150 Tm (ObjStm works) Tj ET"
  let object_stream = pdf_wbtest_object_stream_body([
    (1, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
    (
      3, "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    ),
  ])
  let source = @input.input_from_bytes_with_format(
    pdf_wbtest_xref_stream_pdf_bytes(
      [
        (
          2,
          "<< /Length " +
          content.length().to_string() +
          " >>\nstream\n" +
          content +
          "\nendstream",
        ),
        (4, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
        (5, "<< /Type /Catalog /Pages 4 0 R >>"),
        (6, object_stream),
      ],
      5,
      7,
      extra_entries=[
        { object_id: 1, entry_type: 2, field1: 6, field2: 0 },
        { object_id: 3, entry_type: 2, field1: 6, field2: 1 },
      ],
    ),
    "xref-stream-objstm.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  let document = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("xref stream objstm extract failed: " + err.to_string())
  }
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "ObjStm works",
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_xref_mode") ==
    Some("xref_stream_objstm_v1"),
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

///|
test "pdf native backend errors input kinds and ligatures remain diagnostic" {
  let errors = [
    PdfNativeError::BackendUnavailable("backend unavailable"),
    PdfNativeError::ReadFailed("read failed"),
    PdfNativeError::ParseFailed("parse failed"),
    PdfNativeError::EncryptedUnsupported("encrypted"),
    PdfNativeError::EmptyTextLayer("empty"),
    PdfNativeError::UnsupportedFeature("unsupported"),
  ]
  assert_true(errors.all(error => error.to_string() != ""))
  assert_eq(pdf_native_input_kind_name(@input.InputKind::Text), "text")
  assert_eq(pdf_native_input_kind_name(@input.InputKind::Bytes), "bytes")
  assert_eq(pdf_native_input_kind_name(@input.InputKind::Path), "path")
  match
    extract_pdf_native_document(
      @input.input_from_path("/definitely/missing/pdf-contract.pdf"),
    ) {
    Err(PdfNativeError::ReadFailed(message)) =>
      assert_true(message.contains("missing"))
    _ => fail("missing path must return ReadFailed")
  }
  match
    extract_pdf_native_document(
      @input.input_from_text("%PDF-1.7\ntruncated", source_name="text.pdf"),
    ) {
    Err(error) => assert_true(error.to_string() != "")
    Ok(_) => fail("truncated text PDF must fail closed")
  }
  assert_true(txt_ligature_expansion('\u{FB00}') == Some("ff"))
  assert_true(txt_ligature_expansion('\u{FB01}') == Some("fi"))
  assert_true(txt_ligature_expansion('\u{FB02}') == Some("fl"))
  assert_true(txt_ligature_expansion('\u{FB03}') == Some("ffi"))
  assert_true(txt_ligature_expansion('\u{FB04}') == Some("ffl"))
  assert_true(txt_ligature_expansion('\u{FB05}') == Some("ft"))
  assert_true(txt_ligature_expansion('\u{FB06}') == Some("st"))
  assert_true(txt_ligature_expansion('x') is None)
}

///|
test "pdf native line source reference falls back from line to span to empty" {
  let bbox = make_pdf_bbox(0.0, 0.0, 10.0, 10.0)
  let span_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some("span.pdf"),
    Some("pdf"),
    Some(4),
    Some(4),
  )
  let span = make_pdf_native_text_span("text", bbox, source_ref=Some(span_ref))
  let from_span = pdf_native_line_base_source_ref(
    make_pdf_native_text_line([span], bbox),
  )
  assert_true(from_span.file_id == Some("span.pdf"))
  let line_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some("line.pdf"),
    Some("pdf"),
    Some(5),
    Some(5),
  )
  let from_line = pdf_native_line_base_source_ref(
    make_pdf_native_text_line([span], bbox, source_ref=Some(line_ref)),
  )
  assert_true(from_line.file_id == Some("line.pdf"))
  let empty = pdf_native_line_base_source_ref(
    make_pdf_native_text_line([], bbox),
  )
  assert_true(empty.file_id is None)
}

///|
test "pdf xref helpers cover modes offsets trailer hints and object headers" {
  assert_eq(pdf_xref_mode_name(false, false), "classic_xref_table_v1")
  assert_eq(pdf_xref_mode_name(false, true), "classic_xref_table_objstm_v1")
  assert_eq(pdf_xref_mode_name(true, false), "xref_stream_v1")
  assert_eq(pdf_xref_mode_name(true, true), "xref_stream_objstm_v1")
  assert_true(
    pdf_find_startxref_offset("prefix\nstartxref\n42\n%%EOF") == Some(42),
  )
  assert_true(pdf_find_startxref_offset("startxref") is None)
  assert_true(pdf_find_startxref_offset("startxref\ninvalid") is None)
  assert_true(pdf_find_startxref_offset("no marker") is None)
  assert_true(
    pdf_collect_trailer_hints_from_view("trailer\n<< /Size 3 >>\n").length() ==
    1,
  )
  assert_true(pdf_collect_trailer_hints_from_view("no trailer").length() == 0)
  assert_true(pdf_collect_trailer_hints_from_view("trailer only").length() == 0)
  let bytes = @utf8.encode("noise\n2 0 obj\n<< /Type /Example >>\nendobj")
  let header = pdf_find_next_object_header_bytes(bytes, 0).unwrap()
  assert_eq(header.object_id, 2)
  assert_true(pdf_find_object_header_at(bytes, 0) is None)
  assert_true(pdf_find_object_header_at(bytes, 6).unwrap().object_id == 2)
  assert_true(
    pdf_find_next_object_header_bytes(@utf8.encode("none"), 0) is None,
  )
  assert_true(
    pdf_find_next_object_header_bytes(@utf8.encode("bad obj\n3 0 obj\nx"), 0).unwrap().object_id ==
    3,
  )
}

///|
test "pdf stream slicing covers absent malformed newline and length variants" {
  match pdf_extract_stream_slice(@utf8.encode("<< /Type /Example >>")) {
    Ok(None) => ()
    _ => fail("non-stream object must stay absent")
  }
  match pdf_extract_stream_slice(@utf8.encode("<< >> stream\npayload")) {
    Err(PdfNativeError::ParseFailed(message)) =>
      assert_true(message.contains("endstream"))
    _ => fail("unterminated stream must fail closed")
  }
  let cases = [
    "<< /Length 3 >> stream\nabc\nendstream", "<< /Length 3 >> stream\r\nabc\r\nendstream",
    "<< /Length 3 >> stream\rabc\rendstream", "<< /Length 3 >> streamabcendstream",
    "<< /Length 99 >> stream\nabc\nendstream", "<< /Length -1 >> stream\nabc\nendstream",
  ]
  for body in cases {
    match pdf_extract_stream_slice(@utf8.encode(body)) {
      Ok(Some((dict_text, stream))) => {
        assert_true(dict_text.contains("<<"))
        assert_eq(stream.primary_bytes.length(), 3)
        assert_eq(stream.endstream_bytes.length(), 3)
      }
      _ => fail("valid stream variant must parse")
    }
  }
}

///|
test "pdf classic xref parser covers valid free and malformed sections" {
  let valid = [
    "xref", "0 3", "0000000000 65535 f", "0000000017 00000 n", "0000000042 00002 n",
    "trailer", "<< /Size 3 /Prev 7 >>",
  ].join("\n")
  match pdf_parse_classic_xref_section(@utf8.encode(valid), valid, 0) {
    Ok(section) => {
      assert_eq(section.entries.length(), 2)
      assert_true(section.entries.get(0) is None)
      assert_true(section.entries.get(1) is Some(_))
      assert_true(section.next_offsets.contains(7))
      assert_true(!section.used_xref_stream)
    }
    Err(error) => fail("valid classic xref failed: " + error.to_string())
  }
  let malformed = [
    "xref\n0 1\n0000000000 65535 f", "xref\nbad\ntrailer\n<< /Size 1 >>", "xref\n-1 1\ntrailer\n<< /Size 1 >>",
    "xref\n0 -1\ntrailer\n<< /Size 1 >>", "xref\n0 1\nbad\ntrailer\n<< /Size 1 >>",
    "xref\n0 1\nnope 0 n\ntrailer\n<< /Size 1 >>", "xref\n0 1\n0 nope n\ntrailer\n<< /Size 1 >>",
    "xref\n0 0\ntrailer\nnot-a-dict",
  ]
  for input in malformed {
    match pdf_parse_classic_xref_section(@utf8.encode(input), input, 0) {
      Err(PdfNativeError::ParseFailed(message)) => assert_true(message != "")
      _ => fail("malformed classic xref must fail closed")
    }
  }
}

///|
test "pdf indirect object parser covers plain stream mismatch and truncation" {
  let plain = @utf8.encode("7 0 obj\n<< /Type /Example >>\nendobj")
  match pdf_parse_indirect_object_at(plain, 0) {
    Ok(object) => {
      assert_eq(object.object_id, 7)
      assert_true(object.stream is None)
    }
    Err(error) => fail("plain indirect object failed: " + error.to_string())
  }
  match pdf_parse_indirect_object_at(@utf8.encode("bad"), 0) {
    Err(PdfNativeError::ParseFailed(message)) => assert_true(message != "")
    _ => fail("invalid indirect header must fail closed")
  }
  match pdf_parse_indirect_object_at(@utf8.encode("7 0 obj\n<< >>"), 0) {
    Err(PdfNativeError::ParseFailed(message)) =>
      assert_true(message.contains("7"))
    _ => fail("unterminated indirect object must fail closed")
  }
}

///|
test "pdf raw CJK decode covers ASCII invalid bytes confidence and dispatch" {
  let ascii = pdf_decode_raw_cjk_bytes(
    ['A'.to_int(), '\t'.to_int(), '\n'.to_int(), '\r'.to_int(), 0x1F],
    PdfRawCjkEncodingKind::EucJp,
  )
  assert_eq(ascii.text, "A\t\n\r")
  assert_eq(ascii.invalid_byte_count, 1)
  assert_true(!ascii.has_high_bytes)
  let trailing = pdf_decode_raw_cjk_bytes([0xA4], PdfRawCjkEncodingKind::EucJp)
  assert_true(trailing.has_high_bytes && trailing.invalid_byte_count == 1)
  let invalid_pair = pdf_decode_raw_cjk_bytes(
    [0xFF, 0xFF],
    PdfRawCjkEncodingKind::ShiftJis,
  )
  assert_eq(invalid_pair.invalid_byte_count, 2)
  let hiragana = pdf_decode_raw_cjk_bytes(
    [0xA4, 0xA2],
    PdfRawCjkEncodingKind::EucJp,
  )
  assert_true(hiragana.text == "あ" && hiragana.decoded_cjk_count == 1)
  assert_true(pdf_raw_cjk_decode_result_is_confident(hiragana))
  assert_true(pdf_raw_cjk_decode_result_is_confident_gb2312(hiragana))
  assert_true(
    !pdf_raw_cjk_decode_result_is_confident({
      ..hiragana,
      invalid_byte_count: 1,
    }),
  )
  assert_true(
    pdf_raw_cjk_bytes_need_decode(
      ['A'.to_int(), 0xA4, 0xA2],
      PdfRawCjkEncodingKind::EucJp,
    ),
  )
  assert_true(
    !pdf_raw_cjk_bytes_need_decode(['A'.to_int()], PdfRawCjkEncodingKind::EucJp),
  )
  assert_true(
    !pdf_raw_cjk_bytes_need_decode([0xA4], PdfRawCjkEncodingKind::EucJp),
  )
  assert_true(
    !pdf_raw_cjk_bytes_need_decode([0xFF, 0xFF], PdfRawCjkEncodingKind::EucJp),
  )
  assert_true(
    pdf_raw_cjk_lookup_codepoint(PdfRawCjkEncodingKind::Gb2312, 0xD6, 0xD0) ==
    Some(0x4E2D),
  )
}

///|
test "pdf EUC-JP lookup covers punctuation digits letters kana and boundaries" {
  let punctuation = [
    0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD,
    0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA,
    0xBB, 0xBC,
  ]
  assert_true(
    punctuation.all(trail => pdf_native_euc_jp_row_a1(trail) is Some(_)),
  )
  assert_true(pdf_native_euc_jp_row_a1(0xA0) is None)
  assert_true(pdf_native_euc_jp_row_a1(0xBD) is None)
  let valid_pairs = [
    (0xA3, 0xB0),
    (0xA3, 0xB9),
    (0xA3, 0xC1),
    (0xA3, 0xDA),
    (0xA3, 0xE1),
    (0xA3, 0xFA),
    (0xA4, 0xA1),
    (0xA4, 0xF3),
    (0xA5, 0xA1),
    (0xA5, 0xF6),
  ]
  assert_true(
    valid_pairs.all(pair => {
      pdf_native_euc_jp_lookup_codepoint(pair.0, pair.1) is Some(_)
    }),
  )
  let invalid_pairs = [
    (0xA3, 0xAF),
    (0xA3, 0xBA),
    (0xA3, 0xE0),
    (0xA3, 0xFB),
    (0xA4, 0xA0),
    (0xA4, 0xF4),
    (0xA5, 0xA0),
    (0xA5, 0xF7),
    (0xA6, 0xA1),
  ]
  assert_true(
    invalid_pairs.all(pair => {
      pdf_native_euc_jp_lookup_codepoint(pair.0, pair.1) is None
    }),
  )
}

///|
test "pdf Shift-JIS lookup covers punctuation digits letters kana and boundaries" {
  let punctuation = [
    0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C,
    0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
    0x5A, 0x5B,
  ]
  assert_true(
    punctuation.all(trail => pdf_native_shift_jis_row_81(trail) is Some(_)),
  )
  assert_true(pdf_native_shift_jis_row_81(0x3F) is None)
  assert_true(pdf_native_shift_jis_row_81(0x5C) is None)
  let valid_pairs = [
    (0x82, 0x4F),
    (0x82, 0x58),
    (0x82, 0x60),
    (0x82, 0x79),
    (0x82, 0x81),
    (0x82, 0x9A),
    (0x82, 0x9F),
    (0x82, 0xF1),
    (0x83, 0x40),
    (0x83, 0x7E),
    (0x83, 0x80),
    (0x83, 0x96),
  ]
  assert_true(
    valid_pairs.all(pair => {
      pdf_native_shift_jis_lookup_codepoint(pair.0, pair.1) is Some(_)
    }),
  )
  let invalid_pairs = [
    (0x82, 0x4E),
    (0x82, 0x59),
    (0x82, 0x80),
    (0x82, 0x9B),
    (0x82, 0x9E),
    (0x82, 0xF2),
    (0x83, 0x3F),
    (0x83, 0x7F),
    (0x83, 0x97),
    (0x84, 0x40),
  ]
  assert_true(
    invalid_pairs.all(pair => {
      pdf_native_shift_jis_lookup_codepoint(pair.0, pair.1) is None
    }),
  )
}

///|
test "pdf CJK signal and safe ASCII classifiers cover all supported ranges" {
  assert_true(pdf_raw_cjk_is_safe_ascii_byte('\t'.to_int()))
  assert_true(pdf_raw_cjk_is_safe_ascii_byte(0x20))
  assert_true(pdf_raw_cjk_is_safe_ascii_byte(0x7E))
  assert_true(!pdf_raw_cjk_is_safe_ascii_byte(0x1F))
  assert_true(!pdf_raw_cjk_is_safe_ascii_byte(0x7F))
  let signals = [
    0x4E00, 0x9FFF, 0x3400, 0x4DBF, 0x3040, 0x30FF, 0x31F0, 0x31FF, 0xAC00, 0xD7AF,
    0xF900, 0xFAFF,
  ]
  assert_true(signals.all(pdf_raw_cjk_is_cjk_signal_codepoint))
  assert_true(!pdf_raw_cjk_is_cjk_signal_codepoint(0x3000))
  assert_true(pdf_raw_cjk_string_from_codepoints([0x41, 0x3042]) == "Aあ")
}

///|
fn pdf_wbtest_byte_ints(bytes : Bytes) -> Array[Int] {
  bytes.to_array().map(byte => byte.to_int())
}

///|
fn pdf_wbtest_decode_params(
  predictor? : Int? = None,
  colors? : Int? = None,
  bits_per_component? : Int? = None,
  columns? : Int? = None,
  early_change? : Int? = None,
) -> PdfStreamDecodeParams {
  { predictor, colors, bits_per_component, columns, early_change }
}

///|
test "pdf ASCII hex and ASCII85 codecs cover padding whitespace and errors" {
  assert_true(pdf_ascii_is_whitespace(0))
  assert_true(pdf_ascii_is_whitespace(9))
  assert_true(pdf_ascii_is_whitespace(32))
  assert_true(!pdf_ascii_is_whitespace('A'.to_int()))
  assert_true(pdf_hex_nibble('0'.to_int()) == Some(0))
  assert_true(pdf_hex_nibble('9'.to_int()) == Some(9))
  assert_true(pdf_hex_nibble('A'.to_int()) == Some(10))
  assert_true(pdf_hex_nibble('F'.to_int()) == Some(15))
  assert_true(pdf_hex_nibble('a'.to_int()) == Some(10))
  assert_true(pdf_hex_nibble('f'.to_int()) == Some(15))
  assert_true(pdf_hex_nibble('x'.to_int()) is None)
  match decode_pdf_ascii_hex_stream(@utf8.encode(" 41 42 4 > ignored")) {
    Ok(value) => assert_true(pdf_wbtest_byte_ints(value) == [0x41, 0x42, 0x40])
    Err(error) => fail(error)
  }
  match decode_pdf_ascii_hex_stream(@utf8.encode("0G>")) {
    Err(error) => assert_true(error.contains("non-hex"))
    Ok(_) => fail("invalid ASCII hex must fail")
  }
  assert_true(ascii85_value('!'.to_int()) == Some(0))
  assert_true(ascii85_value('u'.to_int()) == Some(84))
  assert_true(ascii85_value('v'.to_int()) is None)
  match decode_pdf_ascii85_stream(@utf8.encode("z~>")) {
    Ok(value) => assert_true(pdf_wbtest_byte_ints(value) == [0, 0, 0, 0])
    Err(error) => fail(error)
  }
  match decode_pdf_ascii85_stream(@utf8.encode("!!!!!~>")) {
    Ok(value) => assert_true(pdf_wbtest_byte_ints(value) == [0, 0, 0, 0])
    Err(error) => fail(error)
  }
  match decode_pdf_ascii85_stream(@utf8.encode("!!~>")) {
    Ok(value) => assert_eq(value.length(), 1)
    Err(error) => fail(error)
  }
  let malformed = ["~x", "!z~>", "{~>"]
  for value in malformed {
    match decode_pdf_ascii85_stream(@utf8.encode(value)) {
      Err(error) => assert_true(error != "")
      Ok(_) => fail("malformed ASCII85 must fail")
    }
  }
}

///|
test "pdf run length and LZW primitives cover literal repeat end and bounds" {
  match
    decode_pdf_run_length_stream(
      Bytes::from_array([2, 65, 66, 67, 254, 90, 128].map(Int::to_byte)),
    ) {
    Ok(value) =>
      assert_true(pdf_wbtest_byte_ints(value) == [65, 66, 67, 90, 90, 90])
    Err(error) => fail(error)
  }
  match
    decode_pdf_run_length_stream(Bytes::from_array([2, 65].map(Int::to_byte))) {
    Err(error) => assert_true(error.contains("literal"))
    Ok(_) => fail("truncated literal run must fail")
  }
  match
    decode_pdf_run_length_stream(Bytes::from_array([255].map(Int::to_byte))) {
    Err(error) => assert_true(error.contains("missing"))
    Ok(_) => fail("truncated repeat run must fail")
  }
  let dictionary = pdf_lzw_initial_dictionary()
  assert_eq(dictionary.length(), 256)
  assert_true(dictionary.get(65).unwrap()[0].to_int() == 65)
  assert_true(
    pdf_lzw_read_code(Bytes::from_array([0x80, 0].map(Int::to_byte)), 0, 9) ==
    Some(256),
  )
  assert_true(pdf_lzw_read_code(Bytes::new(0), 0, 9) is None)
  assert_true(pdf_lzw_read_code(Bytes::new(0), 0, 0) is None)
  assert_true(
    pdf_wbtest_byte_ints(
      Bytes::from_array(
        pdf_lzw_entry_with_suffix([65].map(Int::to_byte), (66).to_byte()),
      ),
    ) ==
    [65, 66],
  )
  match decode_pdf_lzw_stream(Bytes::new(0)) {
    Ok(value) => assert_eq(value.length(), 0)
    Err(error) => fail(error)
  }
}

///|
test "pdf predictor codecs cover TIFF PNG filters defaults and invalid params" {
  assert_eq(pdf_decode_param_or_default(Some(3), 1), 3)
  assert_eq(pdf_decode_param_or_default(None, 1), 1)
  let base = pdf_wbtest_decode_params(colors=Some(1), columns=Some(3))
  match pdf_predictor_row_bytes(base) {
    Ok(value) => assert_true(value == (1, 3))
    Err(error) => fail(error)
  }
  let invalid_params = [
    pdf_wbtest_decode_params(colors=Some(0)),
    pdf_wbtest_decode_params(columns=Some(0)),
    pdf_wbtest_decode_params(bits_per_component=Some(4)),
  ]
  for params in invalid_params {
    match pdf_predictor_row_bytes(params) {
      Err(error) => assert_true(error != "")
      Ok(_) => fail("invalid predictor params must fail")
    }
  }
  match
    pdf_apply_tiff_predictor(
      Bytes::from_array([10, 1, 1, 20, 2, 2].map(Int::to_byte)),
      base,
    ) {
    Ok(value) =>
      assert_true(pdf_wbtest_byte_ints(value) == [10, 11, 12, 20, 22, 24])
    Err(error) => fail(error)
  }
  match
    pdf_apply_tiff_predictor(Bytes::from_array([1, 2].map(Int::to_byte)), base) {
    Err(error) => assert_true(error.contains("row length"))
    Ok(_) => fail("mismatched TIFF row must fail")
  }
  assert_eq(pdf_png_paeth_predictor(10, 20, 5), 20)
  assert_eq(pdf_png_paeth_predictor(10, 5, 20), 5)
  assert_eq(pdf_png_paeth_predictor(10, 11, 10), 11)
  let rows = [
    (0, [1, 2, 3]),
    (1, [1, 3, 6]),
    (2, [1, 2, 3]),
    (3, [1, 2, 4]),
    (4, [1, 3, 6]),
  ]
  for row in rows {
    let out = [1, 2, 3].map(Int::to_byte)
    match pdf_apply_png_filter_row(out, 0, 3, 1, None, row.0) {
      Ok(_) => assert_true(out.map(byte => byte.to_int()) == row.1)
      Err(error) => fail(error)
    }
  }
  match pdf_apply_png_filter_row([0].map(Int::to_byte), 0, 1, 1, None, 9) {
    Err(error) => assert_true(error.contains("unsupported"))
    Ok(_) => fail("unsupported PNG row filter must fail")
  }
}

///|
test "pdf predictor and filter pipelines cover fixed adaptive and failures" {
  let fixed = pdf_wbtest_decode_params(
    predictor=Some(11),
    colors=Some(1),
    columns=Some(3),
  )
  match
    pdf_apply_png_predictor(
      Bytes::from_array([1, 2, 3].map(Int::to_byte)),
      fixed,
    ) {
    Ok(value) => assert_true(pdf_wbtest_byte_ints(value) == [1, 3, 6])
    Err(error) => fail(error)
  }
  let adaptive = { ..fixed, predictor: Some(15) }
  match
    pdf_apply_png_predictor(
      Bytes::from_array([0, 1, 2, 3, 2, 1, 1, 1].map(Int::to_byte)),
      adaptive,
    ) {
    Ok(value) => assert_true(pdf_wbtest_byte_ints(value) == [1, 2, 3, 2, 3, 4])
    Err(error) => fail(error)
  }
  match
    pdf_apply_png_predictor(
      Bytes::from_array([0, 1].map(Int::to_byte)),
      adaptive,
    ) {
    Err(error) => assert_true(error.contains("row length"))
    Ok(_) => fail("adaptive PNG row mismatch must fail")
  }
  match
    pdf_apply_png_predictor(Bytes::new(0), { ..fixed, predictor: Some(9) }) {
    Err(error) => assert_true(error.contains("unsupported"))
    Ok(_) => fail("unsupported predictor must fail")
  }
  let raw = Bytes::from_array([65, 66].map(Int::to_byte))
  match pdf_apply_stream_predictor(raw, None) {
    Ok(value) => assert_true(pdf_wbtest_byte_ints(value) == [65, 66])
    Err(error) => fail(error)
  }
  match
    pdf_apply_stream_predictor(
      raw,
      Some(pdf_wbtest_decode_params(predictor=Some(99))),
    ) {
    Err(error) => assert_true(error.contains("unsupported PDF predictor"))
    Ok(_) => fail("unsupported stream predictor must fail")
  }
  match decode_pdf_stream_filters(@utf8.encode("4142>"), ["ASCIIHexDecode"]) {
    Ok(value) => assert_true(pdf_wbtest_byte_ints(value) == [65, 66])
    Err(error) => fail(error)
  }
  match decode_pdf_stream_filters(@utf8.encode("4142>"), []) {
    Ok(value) =>
      assert_true(pdf_wbtest_byte_ints(value) == [52, 49, 52, 50, 62])
    Err(error) => fail(error)
  }
  match apply_pdf_stream_filter(Bytes::new(0), "Unknown") {
    Err(error) => assert_true(error.contains("unsupported PDF stream filter"))
    Ok(_) => fail("unknown filter must fail")
  }
  match inflate_pdf_stream(@utf8.encode("not-zlib")) {
    Err(error) => assert_true(error != "")
    Ok(_) => fail("invalid zlib payload must fail")
  }
}

///|
test "pdf predefined CMap resolution covers identity UTF and CID families" {
  let identity_h = pdf_resolve_predefined_cmap("Identity-H").unwrap()
  let identity_v = pdf_resolve_predefined_cmap("Identity-V").unwrap()
  assert_true(!identity_h.vertical_writing && identity_v.vertical_writing)
  assert_true(identity_h.direct_decode_kind == Some("identity"))
  let utf16 = pdf_resolve_predefined_cmap("UniJIS-UTF16-H").unwrap()
  let utf8 = pdf_resolve_predefined_cmap("UniJIS-UTF8-V").unwrap()
  let utf32 = pdf_resolve_predefined_cmap("UniKS-UTF32-H").unwrap()
  assert_true(utf16.direct_decode_kind == Some("utf16be"))
  assert_true(utf8.direct_decode_kind == Some("utf8") && utf8.vertical_writing)
  assert_true(utf32.direct_decode_kind == Some("utf32be"))
  assert_true(pdf_resolve_predefined_cmap("Unknown-CMap") is None)
  for
    family in [
      "Adobe-GB1-UCS2", "Adobe-Japan1-UCS2", "Adobe-CNS1-UCS2", "Adobe-Korea1-UCS2",
    ] {
    let cmap = pdf_resolve_predefined_cmap(family).unwrap()
    assert_true(cmap.direct_decode_kind == Some("cid_family"))
    assert_true(pdf_predefined_cmap_tounicode_info(family) is Some(_))
  }
  assert_true(pdf_predefined_cmap_tounicode_info("Identity-H") is Some(_))
  assert_true(pdf_predefined_cmap_tounicode_info("Identity-V") is Some(_))
  assert_true(pdf_predefined_cmap_tounicode_info("unknown") is None)
  assert_true(
    pdf_predefined_tounicode_from_family("x", "unknown", false) is None,
  )
}

///|
test "pdf predefined direct decoders cover valid partial and invalid sequences" {
  let identity = pdf_resolve_predefined_cmap("Identity-H").unwrap()
  assert_true(
    pdf_predefined_cmap_decode_bytes([0, 65, 0, 66], identity).unwrap().text ==
    "AB",
  )
  assert_true(pdf_predefined_cmap_decode_bytes([0, 0x80], identity) is None)
  let utf16 = pdf_resolve_predefined_cmap("UniJIS-UTF16-H").unwrap()
  assert_true(
    pdf_predefined_cmap_decode_bytes([0, 65, 0xD8, 0x3D, 0xDE, 0], utf16).unwrap().text ==
    "A😀",
  )
  assert_true(pdf_predefined_cmap_decode_bytes([], utf16) is None)
  let utf32 = pdf_resolve_predefined_cmap("UniKS-UTF32-H").unwrap()
  assert_true(
    pdf_predefined_cmap_decode_bytes([0, 0, 0, 65], utf32).unwrap().text == "A",
  )
  assert_true(pdf_predefined_cmap_decode_bytes([0, 0x11, 0, 0], utf32) is None)
  let utf8 = pdf_resolve_predefined_cmap("UniJIS-UTF8-H").unwrap()
  assert_true(
    pdf_predefined_cmap_decode_bytes([0x41, 0xE3, 0x81, 0x82], utf8).unwrap().text ==
    "Aあ",
  )
  assert_true(pdf_predefined_cmap_decode_bytes([0xFF], utf8) is None)
  assert_true(pdf_utf8_sequence_width(0x41) == 1)
  assert_true(pdf_utf8_sequence_width(0xC2) == 2)
  assert_true(pdf_utf8_sequence_width(0xE0) == 3)
  assert_true(pdf_utf8_sequence_width(0xF4) == 4)
  assert_true(pdf_utf8_sequence_width(0x80) == 0)
}

///|
test "pdf predefined width and codepoint helpers cover invalid boundaries" {
  assert_true(pdf_predefined_code_widths_from_mask(0xF) == [4, 3, 2, 1])
  assert_true(pdf_predefined_code_widths_from_mask(0) == [])
  assert_true(pdf_predefined_code_width_mask_contains(0x2, 2))
  assert_true(!pdf_predefined_code_width_mask_contains(0x2, 1))
  assert_true(!pdf_predefined_code_width_mask_contains(0xF, 0))
  assert_true(!pdf_predefined_code_width_mask_contains(0xF, 5))
  assert_true(pdf_predefined_name_has_utf16_direct_decode("UniCNS-UTF16-H"))
  assert_true(!pdf_predefined_name_has_utf16_direct_decode("Other-UTF16-H"))
  assert_true(pdf_predefined_name_has_utf8_direct_decode("UniKS-UTF8-H"))
  assert_true(!pdf_predefined_name_has_utf8_direct_decode("UniKS-UCS2-H"))
  assert_true(pdf_predefined_name_has_utf32_direct_decode("UniJIS-UTF32-H"))
  assert_true(!pdf_predefined_name_has_utf32_direct_decode("UniJIS-UTF8-H"))
  assert_true(pdf_predefined_bmp_codepoint_at("A", 0) == Some(65))
  assert_true(pdf_predefined_bmp_codepoint_at("A", -1) is None)
  assert_true(pdf_predefined_bmp_codepoint_at("A", 1) is None)
  assert_true(pdf_predefined_codepoint_text(-1) is None)
  assert_true(pdf_predefined_codepoint_text(0xD800) is None)
  assert_true(pdf_predefined_codepoint_text(0x110000) is None)
  assert_true(pdf_predefined_codepoint_text(0x41) == Some("A"))
}

///|
test "pdf font width dictionaries cover simple arrays descriptors and defaults" {
  let widths = pdf_collect_simple_font_widths(
    "<< /FirstChar 32 /Widths [250 333 408.0 invalid 500] >>",
  )
  assert_true(widths.get(32) == Some(250))
  assert_true(widths.get(33) == Some(333))
  assert_true(widths.get(34) == Some(408))
  assert_true(widths.get(35) == Some(500))
  assert_true(pdf_collect_simple_font_widths("<< /Widths [1] >>").length() == 0)
  assert_true(
    pdf_collect_simple_font_widths("<< /FirstChar 0 >>").length() == 0,
  )
  let descriptor : PdfNativeObject = {
    object_id: 7,
    dict_text: "<< /MissingWidth 600 >>",
    stream: None,
  }
  let objects : Map[Int, PdfNativeObject] = Map([(7, descriptor)])
  assert_true(
    pdf_collect_font_missing_width("<< /FontDescriptor 7 0 R >>", objects) ==
    Some(600),
  )
  assert_true(pdf_collect_font_missing_width("<< >>", objects) is None)
  assert_true(
    pdf_collect_font_missing_width("<< /FontDescriptor 8 0 R >>", objects)
    is None,
  )
  assert_true(pdf_collect_cid_default_width("<< /DW 900 >>") == Some(900))
  assert_true(pdf_collect_cid_default_width("<< >>") is None)
}

///|
test "pdf CID width arrays cover list range malformed and vertical forms" {
  assert_true(
    pdf_collect_cid_font_width_pairs(
      "<< /W [1 [500 510 bad 520] 10 12 600 20 20.5 700 invalid 30] >>",
    ) ==
    [1, 500, 2, 510, 3, 520, 10, 600, 11, 600, 12, 600],
  )
  assert_true(pdf_collect_cid_font_width_pairs("<< >>") == [])
  assert_true(pdf_collect_cid_font_width_pairs("<< /W [1] >>") == [])
  assert_true(
    pdf_collect_cid_vertical_width_pairs(
      "<< /W2 [1 [-880 0 0 -900 0 0 bad 0 0] 10 12 -1000 0 0] >>",
    ) ==
    [1, 880, 2, 900, 10, 1000, 11, 1000, 12, 1000],
  )
  assert_true(pdf_collect_cid_vertical_width_pairs("<< >>") == [])
  assert_true(pdf_collect_cid_vertical_width_pairs("<< /W2 [1] >>") == [])
  assert_true(
    pdf_collect_cid_default_vertical_width("<< /DW2 [-880 0] >>") == Some(880),
  )
  assert_true(pdf_collect_cid_default_vertical_width("<< /DW2 [] >>") is None)
  assert_true(
    pdf_collect_cid_default_vertical_width("<< /DW2 [1.5] >>") is None,
  )
}

///|
test "pdf flat width lookup and metric label helpers cover boundaries" {
  let pairs = [1, 500, 3, 700, 9, 900]
  assert_true(pdf_lookup_flat_int_pairs(pairs, 1) == Some(500))
  assert_true(pdf_lookup_flat_int_pairs(pairs, 3) == Some(700))
  assert_true(pdf_lookup_flat_int_pairs(pairs, 9) == Some(900))
  assert_true(pdf_lookup_flat_int_pairs(pairs, 0) is None)
  assert_true(pdf_lookup_flat_int_pairs(pairs, 4) is None)
  assert_true(pdf_lookup_flat_int_pairs([], 1) is None)
  assert_true(pdf_abs_int(-7) == 7)
  assert_true(pdf_abs_int(7) == 7)
  let labels : Map[String, Bool] = Map([
    ("z", true),
    ("a", true),
    ("skip", false),
  ])
  assert_true(pdf_sorted_metric_labels(labels) == ["a", "z"])
  assert_true(pdf_metric_labels_contain(["a", "b"], "b"))
  assert_true(!pdf_metric_labels_contain(["a", "b"], "c"))
}

///|
test "pdf embedded font byte and sfnt helpers cover bounds and selection ranks" {
  assert_true(
    pdf_embedded_font_charcode_from_bytes([0x12, 0x34], 0, 2) == 0x1234,
  )
  assert_true(pdf_embedded_font_charcode_from_bytes([0x12], 0, 2) == 0x12)
  assert_true(pdf_parse_sfnt_tables(Bytes::new(0)).length() == 0)
  assert_true(
    pdf_choose_sfnt_unicode_cmap_offset([
      (3, 0, 30),
      (3, 1, 20),
      (3, 10, 10),
      (0, 4, 5),
      (1, 0, 99),
    ]) ==
    Some(5),
  )
  assert_true(pdf_choose_sfnt_unicode_cmap_offset([(1, 0, 99)]) is None)
  let no_tables : Map[String, PdfSfntTableRecord] = Map([])
  assert_true(
    pdf_sfnt_table_head_units_per_em(Bytes::new(0), no_tables) is None,
  )
  assert_true(pdf_sfnt_table_num_glyphs(Bytes::new(0), no_tables) is None)
  assert_true(pdf_sfnt_table_num_h_metrics(Bytes::new(0), no_tables) is None)
  assert_true(
    pdf_sfnt_table_hmtx_advances(Bytes::new(0), no_tables, 1000, 2, 2) == [],
  )
  assert_true(pdf_scale_font_units_to_1000(500, 1000) == 500)
  assert_true(pdf_scale_font_units_to_1000(500, 2000) == 250)
  assert_true(pdf_scale_font_units_to_1000(500, 0) == 500)
}

///|
test "pdf CFF number index dictionary and lookup helpers cover all encodings" {
  let encoded = Bytes::from_array(
    [139, 247, 0, 251, 0, 28, 0xFF, 0xFE, 29, 0, 0, 1, 0].map(Int::to_byte),
  )
  assert_true(pdf_cff_read_number(encoded, 0) == Some((0, 1)))
  assert_true(pdf_cff_read_number(encoded, 1) == Some((108, 3)))
  assert_true(pdf_cff_read_number(encoded, 3) == Some((-108, 5)))
  assert_true(pdf_cff_read_number(encoded, 5) == Some((-2, 8)))
  assert_true(pdf_cff_read_number(encoded, 8) == Some((256, 13)))
  assert_true(pdf_cff_read_number(encoded, 13) is None)
  assert_true(
    pdf_cff_read_number(Bytes::from_array([31].map(Int::to_byte)), 0) is None,
  )
  let dict = pdf_cff_parse_dict_entries(
    Bytes::from_array([140, 141, 18, 142, 12, 3].map(Int::to_byte)),
  )
  assert_true(dict.get(18) == Some([1, 2]))
  assert_true(dict.get(1203) == Some([3]))
  assert_true(pdf_cff_read_index(Bytes::new(0), 0).0.length() == 0)
  assert_true(
    pdf_cff_read_index(Bytes::from_array([0, 0].map(Int::to_byte)), 0).1 == 2,
  )
  let index = [@utf8.encode("one"), @utf8.encode("two")]
  assert_true(pdf_cff_strings_from_index(index) == ["one", "two"])
  assert_true(
    pdf_lookup_sorted_int_string_pairs([1, 3, 9], ["a", "b", "c"], 3) ==
    Some("b"),
  )
  assert_true(pdf_lookup_sorted_int_string_pairs([1], [], 1) is None)
  assert_true(pdf_lookup_sorted_int_string_pairs([], [], 1) is None)
  assert_true(
    pdf_lookup_sorted_int_string_pairs([1, 3, 9], ["a", "b", "c"], 0) is None,
  )
  assert_true(
    pdf_lookup_sorted_int_string_pairs([1, 3, 9], ["a", "b", "c"], 10) is None,
  )
  assert_true(pdf_cff_top_dict_and_strings(Bytes::new(0)) is None)
  assert_true(pdf_cff_private_default_width(Bytes::new(0)) is None)
  assert_true(pdf_cff_private_nominal_width(Bytes::new(0)) is None)
}
