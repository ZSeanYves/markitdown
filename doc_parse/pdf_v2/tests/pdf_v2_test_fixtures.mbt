///|
pub fn pdf_v2_minimal_text_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes(
    pdf_v2_bytes_from_ascii("BT /F1 12 Tf 72 720 Td (Hello PDF v2) Tj ET"),
    "",
    pdf_v2_type1_font_object(),
  )
}

///|
pub fn pdf_v2_tm_position_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes(
    pdf_v2_bytes_from_ascii(
      "BT /F1 10 Tf 1 0 0 1 100 650 Tm 1 Tc 2 Tw 95 Tz 14 TL 1 Tr 3 Ts (Matrix Pos) Tj ET",
    ),
    "",
    pdf_v2_type1_font_object(),
  )
}

///|
pub fn pdf_v2_missing_font_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes_with_resource(
    pdf_v2_bytes_from_ascii("BT /F1 12 Tf 72 720 Td (Missing Font) Tj ET"),
    "",
    "",
    [],
  )
}

///|
pub fn pdf_v2_inherited_resources_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes_with_page_and_pages_resource(
    pdf_v2_bytes_from_ascii("BT /F1 12 Tf 72 720 Td (Inherited Font) Tj ET"),
    "",
    "<< /Font << /F1 5 0 R >> >>",
    "",
    [(5, pdf_v2_type1_font_object())],
  )
}

///|
pub fn pdf_v2_resource_ops_missing_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes_with_resource(
    pdf_v2_bytes_from_ascii("q /Image1 Do /GS1 gs /CS1 CS /CS1 cs Q"),
    "",
    "<< /Font << /F1 5 0 R >> /Pattern << /P1 6 0 R >> >>",
    [(5, pdf_v2_type1_font_object()), (6, "<< /Type /Pattern >>")],
  )
}

///|
pub fn pdf_v2_subset_font_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes(
    pdf_v2_bytes_from_ascii("BT /F1 12 Tf 72 720 Td (Subset Font) Tj ET"),
    "",
    "<< /Type /Font /Subtype /Type1 /BaseFont /ABCDEE+MyFont /Encoding /WinAnsiEncoding >>",
  )
}

///|
pub fn pdf_v2_flate_text_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes(
    pdf_v2_bytes_from_ascii("notflate"),
    "/Filter /FlateDecode",
    pdf_v2_type1_font_object(),
  )
}

///|
pub fn pdf_v2_flate_valid_text_pdf_bytes() -> Bytes {
  let content = @zlib.compress(
    pdf_v2_bytes_from_ascii("BT /F1 12 Tf 72 720 Td (Hello Flate v2) Tj ET"),
  ) catch {
    _ => Bytes::from_array([])
  }
  pdf_v2_pdf_bytes_with_stream(content, "/Filter /FlateDecode")
}

///|
pub fn pdf_v2_flate_array_valid_text_pdf_bytes() -> Bytes {
  let content = @zlib.compress(
    pdf_v2_bytes_from_ascii(
      "BT /F1 12 Tf 72 720 Td (Hello Flate Array v2) Tj ET",
    ),
  ) catch {
    _ => Bytes::from_array([])
  }
  pdf_v2_pdf_bytes_with_stream(content, "/Filter [/FlateDecode]")
}

///|
pub fn pdf_v2_flate_decode_params_pdf_bytes() -> Bytes {
  let content = @zlib.compress(
    pdf_v2_bytes_from_ascii("BT /F1 12 Tf 72 720 Td (Decode Params) Tj ET"),
  ) catch {
    _ => Bytes::from_array([])
  }
  pdf_v2_pdf_bytes_with_stream(
    content, "/Filter [/FlateDecode] /DecodeParms [<< /Predictor 1 >>]",
  )
}

///|
pub fn pdf_v2_extra_objstm_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes_with_resource(
    pdf_v2_bytes_from_ascii("BT /F1 12 Tf 72 720 Td (ObjStm Marker) Tj ET"),
    "",
    "<< /Font << /F1 5 0 R >> >>",
    [
      (5, pdf_v2_type1_font_object()),
      (
        6,
        pdf_v2_stream_object(
          Bytes::from_array([]),
          "/Type /ObjStm /N 0 /First 0",
        ),
      ),
    ],
  )
}

///|
pub fn pdf_v2_encrypted_marker_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes_with_trailer_extra(
    pdf_v2_bytes_from_ascii("BT /F1 12 Tf 72 720 Td (Encrypted) Tj ET"),
    "",
    "<< /Font << /F1 5 0 R >> >>",
    [(5, pdf_v2_type1_font_object()), (6, "<< /Filter /Standard /V 1 >>")],
    "/Encrypt 6 0 R",
  )
}

///|
pub fn pdf_v2_tounicode_pdf_bytes(
  text_operand : String,
  cmap_body : String,
) -> Bytes {
  let content = "BT /F1 12 Tf 72 720 Td " + text_operand + " Tj ET"
  pdf_v2_tounicode_pdf_with_streams(
    pdf_v2_bytes_from_ascii(content),
    "",
    pdf_v2_bytes_from_ascii(cmap_body),
    "",
  )
}

///|
pub fn pdf_v2_tounicode_flate_cmap_pdf_bytes(
  text_operand : String,
  cmap_body : String,
) -> Bytes {
  let content = "BT /F1 12 Tf 72 720 Td " + text_operand + " Tj ET"
  let compressed_cmap = @zlib.compress(pdf_v2_bytes_from_ascii(cmap_body)) catch {
    _ => Bytes::from_array([])
  }
  pdf_v2_tounicode_pdf_with_streams(
    pdf_v2_bytes_from_ascii(content),
    "",
    compressed_cmap,
    "/Filter /FlateDecode",
  )
}

///|
pub fn pdf_v2_tounicode_missing_pdf_bytes() -> Bytes {
  pdf_v2_basic_pdf_bytes(
    pdf_v2_bytes_from_ascii("BT /F1 12 Tf 72 720 Td (ABC) Tj ET"),
    "",
    "<< /Type /Font /Subtype /Type0 /BaseFont /FSubset /Encoding /Identity-H >>",
  )
}

///|
pub fn pdf_v2_type0_cid_tounicode_pdf_bytes(
  text_operand : String,
  cmap_body : String,
) -> Bytes {
  let content = "BT /F1 12 Tf 72 720 Td " + text_operand + " Tj ET"
  pdf_v2_basic_pdf_bytes_with_resource(
    pdf_v2_bytes_from_ascii(content),
    "",
    "<< /Font << /F1 5 0 R >> >>",
    [
      (
        5, "<< /Type /Font /Subtype /Type0 /BaseFont /ABCDEE+StageTwoCID /Encoding /Identity-H /DescendantFonts [7 0 R] /ToUnicode 6 0 R >>",
      ),
      (6, pdf_v2_stream_object(pdf_v2_bytes_from_ascii(cmap_body), "")),
      (
        7, "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /ABCDEE+StageTwoCID /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor 8 0 R >>",
      ),
      (
        8, "<< /Type /FontDescriptor /FontName /ABCDEE+StageTwoCID /FontFile2 9 0 R >>",
      ),
      (9, pdf_v2_stream_object(Bytes::from_array([]), "")),
    ],
  )
}

///|
fn pdf_v2_bytes_from_ascii(text : String) -> Bytes {
  let out : Array[Byte] = []
  for ch in text.to_array() {
    out.push(ch.to_int().to_byte())
  }
  Bytes::from_array(out)
}

///|
fn pdf_v2_pdf_bytes_with_stream(stream : Bytes, filter_dict : String) -> Bytes {
  pdf_v2_basic_pdf_bytes(stream, filter_dict, pdf_v2_type1_font_object())
}

///|
fn append_pdf_v2_ascii_bytes(out : Array[Byte], text : String) -> Unit {
  for ch in text.to_array() {
    out.push(ch.to_int().to_byte())
  }
}

///|
fn pdf_v2_tounicode_pdf_with_streams(
  content : Bytes,
  content_filter : String,
  cmap : Bytes,
  cmap_filter : String,
) -> Bytes {
  pdf_v2_basic_pdf_bytes_with_resource(
    content,
    content_filter,
    "<< /Font << /F1 5 0 R >> >>",
    [
      (
        5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /FirstChar 0 /LastChar 255 /Widths [500] /ToUnicode 6 0 R >>",
      ),
      (6, pdf_v2_stream_object(cmap, cmap_filter)),
    ],
  )
}

///|
fn pdf_v2_type1_font_object() -> String {
  "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"
}

///|
fn pdf_v2_basic_pdf_bytes(
  content : Bytes,
  content_filter : String,
  font_object : String,
) -> Bytes {
  pdf_v2_basic_pdf_bytes_with_resource(
    content,
    content_filter,
    "<< /Font << /F1 5 0 R >> >>",
    [(5, font_object)],
  )
}

///|
fn pdf_v2_basic_pdf_bytes_with_resource(
  content : Bytes,
  content_filter : String,
  resources : String,
  extra_objects : Array[(Int, String)],
) -> Bytes {
  pdf_v2_basic_pdf_bytes_with_trailer_extra(
    content, content_filter, resources, extra_objects, "",
  )
}

///|
fn pdf_v2_basic_pdf_bytes_with_trailer_extra(
  content : Bytes,
  content_filter : String,
  resources : String,
  extra_objects : Array[(Int, String)],
  trailer_extra : String,
) -> Bytes {
  let out : Array[Byte] = []
  let offsets : Array[Int] = []
  append_pdf_v2_ascii_bytes(out, "%PDF-1.4\n")
  pdf_v2_append_object(out, offsets, 1, "<< /Type /Catalog /Pages 2 0 R >>")
  pdf_v2_append_object(
    out, offsets, 2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let resource_value = if resources == "" { "<< >>" } else { resources }
  pdf_v2_append_object(
    out,
    offsets,
    3,
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources " +
    resource_value +
    " /Contents 4 0 R >>",
  )
  pdf_v2_append_object(
    out,
    offsets,
    4,
    pdf_v2_stream_object(content, content_filter),
  )
  for extra in extra_objects {
    pdf_v2_append_object(out, offsets, extra.0, extra.1)
  }
  let size = pdf_v2_max_object_number(extra_objects) + 1
  let xref_offset = out.length()
  append_pdf_v2_ascii_bytes(
    out,
    "xref\n0 " + size.to_string() + "\n0000000000 65535 f \n",
  )
  for obj_num in 1..<size {
    let offset = if obj_num - 1 < offsets.length() {
      offsets[obj_num - 1]
    } else {
      0
    }
    append_pdf_v2_ascii_bytes(out, pdf_v2_xref_offset(offset) + " 00000 n \n")
  }
  append_pdf_v2_ascii_bytes(
    out,
    "trailer\n<< /Root 1 0 R /Size " +
    size.to_string() +
    (if trailer_extra == "" { "" } else { " " + trailer_extra }) +
    " >>\nstartxref\n" +
    xref_offset.to_string() +
    "\n%%EOF\n",
  )
  Bytes::from_array(out)
}

///|
fn pdf_v2_basic_pdf_bytes_with_page_and_pages_resource(
  content : Bytes,
  content_filter : String,
  pages_resources : String,
  page_resources : String,
  extra_objects : Array[(Int, String)],
) -> Bytes {
  let out : Array[Byte] = []
  let offsets : Array[Int] = []
  append_pdf_v2_ascii_bytes(out, "%PDF-1.4\n")
  pdf_v2_append_object(out, offsets, 1, "<< /Type /Catalog /Pages 2 0 R >>")
  pdf_v2_append_object(
    out,
    offsets,
    2,
    "<< /Type /Pages /Kids [3 0 R] /Count 1 /Resources " +
    pages_resources +
    " >>",
  )
  let page_resource_entry = if page_resources == "" {
    ""
  } else {
    " /Resources " + page_resources
  }
  pdf_v2_append_object(
    out,
    offsets,
    3,
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]" +
    page_resource_entry +
    " /Contents 4 0 R >>",
  )
  pdf_v2_append_object(
    out,
    offsets,
    4,
    pdf_v2_stream_object(content, content_filter),
  )
  for extra in extra_objects {
    pdf_v2_append_object(out, offsets, extra.0, extra.1)
  }
  let size = pdf_v2_max_object_number(extra_objects) + 1
  let xref_offset = out.length()
  append_pdf_v2_ascii_bytes(
    out,
    "xref\n0 " + size.to_string() + "\n0000000000 65535 f \n",
  )
  for obj_num in 1..<size {
    let offset = if obj_num - 1 < offsets.length() {
      offsets[obj_num - 1]
    } else {
      0
    }
    append_pdf_v2_ascii_bytes(out, pdf_v2_xref_offset(offset) + " 00000 n \n")
  }
  append_pdf_v2_ascii_bytes(
    out,
    "trailer\n<< /Root 1 0 R /Size " +
    size.to_string() +
    " >>\nstartxref\n" +
    xref_offset.to_string() +
    "\n%%EOF\n",
  )
  Bytes::from_array(out)
}

///|
fn pdf_v2_stream_object(stream : Bytes, filter_dict : String) -> String {
  "<< /Length " +
  stream.length().to_string() +
  (if filter_dict == "" { "" } else { " " + filter_dict }) +
  " >>\nstream\n" +
  pdf_v2_ascii_from_bytes(stream) +
  "\nendstream"
}

///|
fn pdf_v2_append_object(
  out : Array[Byte],
  offsets : Array[Int],
  object_number : Int,
  body : String,
) -> Unit {
  while offsets.length() < object_number {
    offsets.push(0)
  }
  offsets[object_number - 1] = out.length()
  append_pdf_v2_ascii_bytes(
    out,
    object_number.to_string() + " 0 obj\n" + body + "\nendobj\n",
  )
}

///|
fn pdf_v2_max_object_number(extra_objects : Array[(Int, String)]) -> Int {
  let mut max_object = 4
  for extra in extra_objects {
    if extra.0 > max_object {
      max_object = extra.0
    }
  }
  max_object
}

///|
fn pdf_v2_xref_offset(offset : Int) -> String {
  let raw = offset.to_string()
  let builder = StringBuilder::new()
  for _ in 0..<(10 - raw.length()) {
    builder.write_char('0')
  }
  builder.write_string(raw)
  builder.to_string()
}

///|
fn pdf_v2_ascii_from_bytes(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for byte in bytes.to_array() {
    chars.push(byte.to_char())
  }
  String::from_array(chars)
}
