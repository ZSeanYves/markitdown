///|
fn bounded_pdf_test_limits(inflate : Int64?) -> @budget.BudgetLimits {
  @budget.BudgetLimits::new(
    MeasurementOnly,
    inflate_bytes=inflate,
    parse_work=None,
    output_utf8_bytes=None,
    source_metadata_bytes=None,
    rag_metadata_bytes=None,
    read_traffic_bytes=None,
    cache_bytes=None,
    working_bytes=None,
    temporary_bytes=None,
    ir_bytes=None,
  ).unwrap()
}

///|
fn bounded_pdf_test_stream(payload : Bytes, extra~ : String = "") -> String {
  let hex = payload
    .to_array()
    .map(byte => pdf_hex_upper(byte.to_int(), 2))
    .join("") +
    ">"
  "<< " +
  extra +
  " /Filter [ /ASCIIHexDecode /FlateDecode ] /Length " +
  hex.length().to_string() +
  " >>\nstream\n" +
  hex +
  "\nendstream"
}

///|
fn bounded_pdf_test_document(kind : String, corrupt : Bool) -> Bytes {
  let decoded = match kind {
    "content" | "form" => b"BT /F1 12 Tf 1 0 0 1 50 100 Tm (bounded PDF) Tj ET"
    "cmap" => b"1 beginbfchar <41> <0041> endbfchar"
    "font" => b"not-an-embedded-font"
    "cid" => b"\x00\x00\x00\x01"
    "lookup" => b"\xff\x00\x00\x00\xff\x00"
    _ => b"\xff"
  }
  let payload = if corrupt {
    b"\x78\x01\x07\x00\x00\x00\x00"
  } else {
    @zlib.zlib_compress(decoded)
  }
  let content = "BT /F1 12 Tf 1 0 0 1 50 100 Tm (bounded PDF) Tj ET"
  let objects : Array[(Int32, String)] = [
    (1, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
    (
      2,
      if kind == "content" {
        bounded_pdf_test_stream(payload)
      } else {
        let text = content +
          (if ["image", "mask", "lookup", "form"].contains(kind) {
            "\n/Im0 Do"
          } else {
            ""
          })
        "<< /Length " +
        text.length().to_string() +
        " >>\nstream\n" +
        text +
        "\nendstream"
      },
    ),
    (
      3, "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> /XObject << /Im0 6 0 R >> >> /Contents 2 0 R >>",
    ),
    (4, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    (5, "<< /Type /Catalog /Pages 4 0 R >>"),
  ]
  match kind {
    "cmap" => {
      objects.push((6, bounded_pdf_test_stream(payload)))
      objects.push(
        (
          7, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /ToUnicode 6 0 R >>",
        ),
      )
    }
    "font" => {
      objects.push((6, bounded_pdf_test_stream(payload)))
      objects.push(
        (
          7, "<< /Type /Font /Subtype /TrueType /BaseFont /Unused /FontDescriptor 8 0 R >>",
        ),
      )
      objects.push((8, "<< /Type /FontDescriptor /FontFile2 6 0 R >>"))
    }
    "cid" => {
      objects.push((6, bounded_pdf_test_stream(payload)))
      objects.push(
        (
          7, "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Unused /CIDToGIDMap 6 0 R >>",
        ),
      )
    }
    "image" =>
      objects.push(
        (
          6,
          bounded_pdf_test_stream(
            payload,
            extra="/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8",
          ),
        ),
      )
    "mask" => {
      objects.push(
        (
          6, "<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /SMask 7 0 R /Filter /ASCIIHexDecode /Length 7 >>\nstream\nff0000>\nendstream",
        ),
      )
      objects.push(
        (
          7,
          bounded_pdf_test_stream(
            payload,
            extra="/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8",
          ),
        ),
      )
    }
    "lookup" => {
      objects.push(
        (
          6, "<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace [ /Indexed /DeviceRGB 1 7 0 R ] /BitsPerComponent 8 /Filter /ASCIIHexDecode /Length 3 >>\nstream\n00>\nendstream",
        ),
      )
      objects.push((7, bounded_pdf_test_stream(payload)))
    }
    "form" =>
      objects.push(
        (
          6,
          bounded_pdf_test_stream(
            payload,
            extra="/Type /XObject /Subtype /Form /BBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >>",
          ),
        ),
      )
    _ => ()
  }
  pdf_wbtest_xref_stream_pdf_bytes(objects, 5, 9)
}

///|
async fn bounded_pdf_expect_hard_failure(kind : String, corrupt : Bool) -> Unit {
  let bytes = bounded_pdf_test_document(kind, corrupt)
  let account = @budget.Budget::new(
    bounded_pdf_test_limits(if corrupt { None } else { Some(0L) }),
  )
  let session = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  defer @input.end_input_session(session)
  let result = extract_pdf_native_document(session.source)
  assert_true(
    result is Err(_),
    msg=kind +
      ": " +
      (if corrupt {
        "corrupt zlib must be a hard error"
      } else {
        "zero inflate budget must stop decode"
      }),
  )
  if !corrupt {
    assert_true(account.failure() is Some(_))
  }
}

///|
async test "bounded PDF budget rejects content decode" {
  bounded_pdf_expect_hard_failure("content", false)
}

///|
async test "bounded PDF budget rejects cmap decode" {
  bounded_pdf_expect_hard_failure("cmap", false)
}

///|
async test "bounded PDF budget rejects font decode" {
  bounded_pdf_expect_hard_failure("font", false)
}

///|
async test "bounded PDF budget rejects cid decode" {
  bounded_pdf_expect_hard_failure("cid", false)
}

///|
async test "bounded PDF budget rejects image decode" {
  bounded_pdf_expect_hard_failure("image", false)
}

///|
async test "bounded PDF budget rejects mask decode" {
  bounded_pdf_expect_hard_failure("mask", false)
}

///|
async test "bounded PDF budget rejects lookup decode" {
  bounded_pdf_expect_hard_failure("lookup", false)
}

///|
async test "bounded PDF budget rejects form decode" {
  bounded_pdf_expect_hard_failure("form", false)
}

///|
async test "bounded PDF integrity rejects cmap decode" {
  bounded_pdf_expect_hard_failure("cmap", true)
}

///|
async test "bounded PDF integrity rejects font decode" {
  bounded_pdf_expect_hard_failure("font", true)
}

///|
async test "bounded PDF integrity rejects cid decode" {
  bounded_pdf_expect_hard_failure("cid", true)
}

///|
async test "bounded PDF integrity rejects image decode" {
  bounded_pdf_expect_hard_failure("image", true)
}

///|
async test "bounded PDF integrity rejects mask decode" {
  bounded_pdf_expect_hard_failure("mask", true)
}

///|
async test "bounded PDF integrity rejects lookup decode" {
  bounded_pdf_expect_hard_failure("lookup", true)
}

///|
fn bounded_pdf_test_broken_xref(later : Bool) -> Bytes {
  let base = bounded_pdf_test_document("unused", false)
  let base_text = pdf_byte_string(base)
  let prior = pdf_find_startxref_offset(base_text).unwrap()
  let bad_offset = base.length()
  let bad = pdf_wbtest_indirect_object_text(
    10,
    bounded_pdf_test_stream(
      b"\x78\x01\x07\x00\x00\x00\x00",
      extra="/Type /XRef /Size 1 /Root 5 0 R /W [1 4 1]",
    ),
  )
  let suffix = if later {
    let latest = bad_offset + bad.length()
    "xref\n0 1\n0000000000 65535 f\ntrailer\n<< /Size 11 /Root 5 0 R /Prev " +
    bad_offset.to_string() +
    " /XRefStm " +
    prior.to_string() +
    " >>\nstartxref\n" +
    latest.to_string() +
    "\n%%EOF\n"
  } else {
    "startxref\n" + bad_offset.to_string() + "\n%%EOF\n"
  }
  @utf8.encode(base_text + bad + suffix)
}

///|
async test "bounded PDF integrity bypasses later xref section continue" {
  let result = extract_pdf_native_document(
    @input.input_from_bytes(bounded_pdf_test_broken_xref(true)),
  )
  assert_true(result is Err(_), msg="later xref integrity must not be ignored")
}

///|
async test "bounded PDF integrity bypasses bytes xref materialize scan recovery" {
  let bytes = bounded_pdf_test_broken_xref(false)
  let source = @input.input_from_reader(
    @input.make_input_reader(fn(offset, length) {
      let start = offset.to_int()
      if start >= bytes.length() {
        Ok(b"")
      } else {
        Ok(bytes[start:(start + length).min(bytes.length())].to_owned())
      }
    }),
  )
  let result = extract_pdf_native_document(source)
  assert_true(
    result is Err(_),
    msg="bad xref integrity must not recover by scanning",
  )
}

///|
fn bounded_pdf_test_objstm(
  corrupt : Bool,
  embedded_stream~ : Bool = false,
) -> (Bytes, Int64) {
  let content = "BT /F1 12 Tf (ObjStm bounded) Tj ET" +
    (if embedded_stream { "\n/Im0 Do" } else { "" })
  let entries : Array[(Int32, String)] = [
    (1, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
    (
      3, "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> /XObject << /Im0 8 0 R >> >> /Contents 2 0 R >>",
    ),
  ]
  if embedded_stream {
    entries.push(
      (
        8,
        bounded_pdf_test_stream(
          @zlib.zlib_compress(b"\xff"),
          extra="/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8",
        ),
      ),
    )
  }
  let unfiltered = pdf_wbtest_object_stream_body(entries)
  let first = pdf_extract_int_after(unfiltered, "/First").unwrap()
  let start = pdf_find_substring(unfiltered, "\nstream\n", 0).unwrap() +
    "\nstream\n".length()
  let body = unfiltered[start:unfiltered.length() - "\nendstream".length()].to_owned()
  let decoded = @utf8.encode(body)
  let payload = if corrupt {
    b"\x78\x01\x07\x00\x00\x00\x00"
  } else {
    @zlib.zlib_compress(decoded)
  }
  let extra_entries : Array[PdfWbtestXrefEntry] = [
    { object_id: 1, entry_type: 2, field1: 6, field2: 0, },
    { object_id: 3, entry_type: 2, field1: 6, field2: 1, },
  ]
  if embedded_stream {
    extra_entries.push({ object_id: 8, entry_type: 2, field1: 6, field2: 2, })
  }
  (
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
        (
          6,
          bounded_pdf_test_stream(
            payload,
            extra="/Type /ObjStm /N " +
              entries.length().to_string() +
              " /First " +
              first.to_string(),
          ),
        ),
      ],
      5,
      7,
      extra_entries~,
    ),
    decoded.length().to_int64(),
  )
}

///|
async test "bounded PDF ObjStm output shares the conversion inflate budget" {
  let bytes = bounded_pdf_test_objstm(false).0
  let account = @budget.Budget::new(bounded_pdf_test_limits(Some(0L)))
  let session = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  defer @input.end_input_session(session)
  assert_true(extract_pdf_native_document(session.source) is Err(_))
  assert_true(account.failure() is Some(_))
}

///|
async test "bounded PDF corrupt ObjStm must not recover by materialized scan" {
  let result = extract_pdf_native_document(
    @input.input_from_bytes(bounded_pdf_test_objstm(true).0),
  )
  assert_true(result is Err(_))
}

///|
async test "bounded PDF permissive embedded ObjStm stream inherits its parent budget" {
  let (bytes, outer_decoded) = bounded_pdf_test_objstm(
    false,
    embedded_stream=true,
  )
  let account = @budget.Budget::new(
    bounded_pdf_test_limits(Some(outer_decoded)),
  )
  let session = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  defer @input.end_input_session(session)
  assert_true(extract_pdf_native_document(session.source) is Err(_))
  assert_true(account.failure() is Some(_))
}
