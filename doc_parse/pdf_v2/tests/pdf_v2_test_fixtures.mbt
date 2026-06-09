///|
pub fn pdf_v2_minimal_text_pdf_bytes() -> Bytes {
  pdf_v2_bytes_from_ascii(
    "%PDF-1.4\n" +
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" +
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" +
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n" +
    "4 0 obj\n<< /Length 47 >>\nstream\nBT /F1 12 Tf 72 720 Td (Hello PDF v2) Tj ET\nendstream\nendobj\n" +
    "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n" +
    "xref\n0 6\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 6 >>\nstartxref\n0\n%%EOF\n",
  )
}

///|
pub fn pdf_v2_missing_font_pdf_bytes() -> Bytes {
  pdf_v2_bytes_from_ascii(
    "%PDF-1.4\n" +
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" +
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" +
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << >> /Contents 4 0 R >>\nendobj\n" +
    "4 0 obj\n<< /Length 47 >>\nstream\nBT /F1 12 Tf 72 720 Td (Missing Font) Tj ET\nendstream\nendobj\n" +
    "xref\n0 5\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 5 >>\nstartxref\n0\n%%EOF\n",
  )
}

///|
pub fn pdf_v2_flate_text_pdf_bytes() -> Bytes {
  pdf_v2_bytes_from_ascii(
    "%PDF-1.4\n" +
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" +
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" +
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n" +
    "4 0 obj\n<< /Length 8 /Filter /FlateDecode >>\nstream\nnotflate\nendstream\nendobj\n" +
    "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n" +
    "xref\n0 6\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 6 >>\nstartxref\n0\n%%EOF\n",
  )
}

///|
pub fn pdf_v2_flate_valid_text_pdf_bytes() -> Bytes raise {
  let content = pdf_v2_bytes_from_ascii(
    "BT /F1 12 Tf 72 720 Td (Hello Flate v2) Tj ET",
  )
  pdf_v2_pdf_bytes_with_stream(
    compress_pdf_v2_fixture_stream(content),
    "/Filter /FlateDecode",
  )
}

///|
pub fn pdf_v2_flate_array_valid_text_pdf_bytes() -> Bytes raise {
  let content = pdf_v2_bytes_from_ascii(
    "BT /F1 12 Tf 72 720 Td (Hello Flate Array v2) Tj ET",
  )
  pdf_v2_pdf_bytes_with_stream(
    compress_pdf_v2_fixture_stream(content),
    "/Filter [/FlateDecode]",
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
) -> Bytes raise {
  let content = "BT /F1 12 Tf 72 720 Td " + text_operand + " Tj ET"
  pdf_v2_tounicode_pdf_with_streams(
    pdf_v2_bytes_from_ascii(content),
    "",
    compress_pdf_v2_fixture_stream(pdf_v2_bytes_from_ascii(cmap_body)),
    "/Filter /FlateDecode",
  )
}

///|
pub fn pdf_v2_tounicode_missing_pdf_bytes() -> Bytes {
  pdf_v2_bytes_from_ascii(
    "%PDF-1.4\n" +
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" +
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" +
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n" +
    "4 0 obj\n<< /Length 38 >>\nstream\nBT /F1 12 Tf 72 720 Td (ABC) Tj ET\nendstream\nendobj\n" +
    "5 0 obj\n<< /Type /Font /Subtype /Type0 /BaseFont /FSubset >>\nendobj\n" +
    "xref\n0 6\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 6 >>\nstartxref\n0\n%%EOF\n",
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
  let out : Array[Byte] = []
  append_pdf_v2_ascii_bytes(
    out,
    "%PDF-1.4\n" +
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" +
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" +
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n" +
    "4 0 obj\n<< /Length " +
    stream.length().to_string() +
    " " +
    filter_dict +
    " >>\nstream\n",
  )
  out.append(stream.to_array())
  append_pdf_v2_ascii_bytes(
    out,
    "\nendstream\nendobj\n" +
    "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n" +
    "xref\n0 6\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 6 >>\nstartxref\n0\n%%EOF\n",
  )
  Bytes::from_array(out)
}

///|
fn append_pdf_v2_ascii_bytes(out : Array[Byte], text : String) -> Unit {
  for ch in text.to_array() {
    out.push(ch.to_int().to_byte())
  }
}

///|
fn compress_pdf_v2_fixture_stream(content : Bytes) -> Bytes raise {
  @zlib.compress(content)
}

///|
fn pdf_v2_tounicode_pdf_with_streams(
  content : Bytes,
  content_filter : String,
  cmap : Bytes,
  cmap_filter : String,
) -> Bytes {
  let out : Array[Byte] = []
  append_pdf_v2_ascii_bytes(
    out,
    "%PDF-1.4\n" +
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" +
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" +
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n" +
    "4 0 obj\n<< /Length " +
    content.length().to_string() +
    " " +
    content_filter +
    " >>\nstream\n",
  )
  out.append(content.to_array())
  append_pdf_v2_ascii_bytes(
    out,
    "\nendstream\nendobj\n" +
    "5 0 obj\n<< /Type /Font /Subtype /Type0 /BaseFont /FSubset /ToUnicode 6 0 R >>\nendobj\n" +
    "6 0 obj\n<< /Length " +
    cmap.length().to_string() +
    " " +
    cmap_filter +
    " >>\nstream\n",
  )
  out.append(cmap.to_array())
  append_pdf_v2_ascii_bytes(
    out,
    "\nendstream\nendobj\n" +
    "xref\n0 7\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 7 >>\nstartxref\n0\n%%EOF\n",
  )
  Bytes::from_array(out)
}
