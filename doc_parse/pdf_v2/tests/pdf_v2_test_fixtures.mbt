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
