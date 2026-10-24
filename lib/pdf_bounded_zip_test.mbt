///|
fn pdf_nested_zip_u16(out : Array[Byte], value : Int32) -> Unit {
  out.push((value & 255).to_byte())
  out.push(((value >> 8) & 255).to_byte())
}

///|
fn pdf_nested_zip_u32(out : Array[Byte], value : UInt32) -> Unit {
  for shift in [0, 8, 16, 24] {
    out.push(((value >> shift) & 255U).to_byte())
  }
}

///|
fn pdf_nested_zip_fixture() -> Bytes {
  let text = "BT /F1 12 Tf (nested PDF text) Tj ET"
  let pdf = "%PDF-1.5\n1 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n" +
    "2 0 obj\n<< /Length " +
    text.length().to_string() +
    " >>\nstream\n" +
    text +
    "\nendstream\nendobj\n" +
    "3 0 obj\n<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>\nendobj\n" +
    "4 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" +
    "5 0 obj\n<< /Type /Catalog /Pages 4 0 R >>\nendobj\n" +
    "6 0 obj\n<< /Filter [ /ASCIIHexDecode /FlateDecode ] /Length 15 >>\nstream\n78010700000000>\nendstream\nendobj\n" +
    "7 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /ToUnicode 6 0 R >>\nendobj\n" +
    "trailer\n<< /Root 5 0 R /Size 8 >>\n%%EOF\n"
  // The fixture is ASCII, so these are its exact UTF8 bytes.
  let payload = Bytes::from_array(
    pdf.to_array().map(ch => ch.to_int().to_byte()),
  )
  let name = b"inner.pdf"
  let mut crc = 0xffffffffU
  for byte in payload {
    crc = crc ^ byte.to_uint()
    for _ in 0..<8 {
      crc = if (crc & 1U) == 1U { (crc >> 1) ^ 0xedb88320U } else { crc >> 1 }
    }
  }
  crc = crc ^ 0xffffffffU
  let out : Array[Byte] = []
  pdf_nested_zip_u32(out, 0x04034b50U)
  for value in [20, 0, 0, 0, 0] {
    pdf_nested_zip_u16(out, value)
  }
  pdf_nested_zip_u32(out, crc)
  pdf_nested_zip_u32(out, payload.length().reinterpret_as_uint())
  pdf_nested_zip_u32(out, payload.length().reinterpret_as_uint())
  pdf_nested_zip_u16(out, name.length())
  pdf_nested_zip_u16(out, 0)
  out.append(name.to_array())
  out.append(payload.to_array())
  let central_offset = out.length()
  pdf_nested_zip_u32(out, 0x02014b50U)
  for value in [20, 20, 0, 0, 0, 0] {
    pdf_nested_zip_u16(out, value)
  }
  pdf_nested_zip_u32(out, crc)
  pdf_nested_zip_u32(out, payload.length().reinterpret_as_uint())
  pdf_nested_zip_u32(out, payload.length().reinterpret_as_uint())
  for value in [name.length(), 0, 0, 0, 0] {
    pdf_nested_zip_u16(out, value)
  }
  pdf_nested_zip_u32(out, 0U)
  pdf_nested_zip_u32(out, 0U)
  out.append(name.to_array())
  let central_size = out.length() - central_offset
  pdf_nested_zip_u32(out, 0x06054b50U)
  for value in [0, 0, 1, 1] {
    pdf_nested_zip_u16(out, value)
  }
  pdf_nested_zip_u32(out, central_size.reinterpret_as_uint())
  pdf_nested_zip_u32(out, central_offset.reinterpret_as_uint())
  pdf_nested_zip_u16(out, 0)
  Bytes::from_array(out)
}

///|
async test "public ZIP conversion rejects corrupt optional PDF stream through the parent session" {
  match
    @lib.convert(
      @lib.Input::from_bytes(
        pdf_nested_zip_fixture(),
        source_name="nested-pdf.zip",
      ),
    ) {
    Err(error) =>
      assert_true(error.message().contains("zlib: invalid DEFLATE stream"))
    Ok(output) => {
      assert_true(
        output.content.contains("nested PDF text"),
        msg="before fixture must reach the PDF child text",
      )
      fail("a corrupt child PDF stream must reject the parent conversion")
    }
  }
}
