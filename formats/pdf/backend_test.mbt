///|
fn pdf_test_ascii_bytes(text : String) -> Bytes {
  @utf8.encode(text)
}

///|
fn pdf_test_join_bytes(parts : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  for part in parts {
    out.append(part.to_array())
  }
  Bytes::from_array(out)
}

///|
test "pdf native backend extracts direct text and link facts from tiny synthetic pdf" {
  let pdf = [
    "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "endobj", "2 0 obj", "<< /Length 54 >>", "stream", "BT /F1 12 Tf 1 0 0 1 50 700 Tm (Hello PDF backend) Tj ET",
    "endstream", "endobj", "3 0 obj", "<< /Type /Annot /Subtype /Link /Rect [49 688 180 706] /Border [0 0 0] /A << /S /URI /URI (https://example.com) >> >>",
    "endobj", "4 0 obj", "<< /Type /Page /Parent 5 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R /Annots [3 0 R] >>",
    "endobj", "5 0 obj", "<< /Type /Pages /Kids [4 0 R] /Count 1 >>", "endobj", "6 0 obj",
    "<< /Type /Catalog /Pages 5 0 R >>", "endobj", "trailer", "<< /Size 7 /Root 6 0 R >>",
    "%%EOF", "",
  ].join("\n")
  let source = @input.input_from_bytes_with_format(
    @utf8.encode(pdf),
    "synthetic.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Ok(document) => {
      assert_eq(document.pages.length(), 1)
      let page = document.pages[0]
      assert_eq(page.text_blocks.length(), 1)
      assert_eq(page.text_blocks[0].lines.length(), 1)
      let line = page.text_blocks[0].lines[0]
      assert_eq(line.spans.length(), 1)
      assert_eq(line.spans[0].text, "Hello PDF backend")
      assert_true(line.spans[0].font_size.unwrap_or(0.0) >= 12.0)
      assert_true(
        line.spans[0].source_ref.unwrap_or(@core.empty_source_ref()).page ==
        Some(1),
      )
      assert_eq(page.link_candidates.length(), 1)
      assert_eq(page.link_candidates[0].href, "https://example.com")
      assert_true(page.link_candidates[0].annotation_index == Some(0))
      assert_true(page.link_candidates[0].annotation_object_id == Some(3))
      assert_true(
        document.metadata.get("pdf_native_backend") ==
        Some(@core.JsonValue::Bool(true)),
      )
      assert_true(
        document.metadata.get("pdf_native_text_baseline") ==
        Some(@core.JsonValue::Bool(true)),
      )
      assert_true(
        document.metadata.get("pdf_ocr_used") ==
        Some(@core.JsonValue::Bool(false)),
      )
      assert_true(
        document.metadata.get("pdf_v2_used") ==
        Some(@core.JsonValue::Bool(false)),
      )
      assert_true(
        document.metadata.get("pdf_page_count") ==
        Some(@core.JsonValue::Number("1")),
      )
      assert_true(
        document.metadata.get("pdf_text_block_count") ==
        Some(@core.JsonValue::Number("1")),
      )
      assert_true(
        document.metadata.get("pdf_text_line_count") ==
        Some(@core.JsonValue::Number("1")),
      )
      assert_true(
        document.metadata.get("pdf_text_span_count") ==
        Some(@core.JsonValue::Number("1")),
      )
      assert_true(
        document.metadata.get("pdf_link_candidate_count") ==
        Some(@core.JsonValue::Number("1")),
      )
      assert_true(
        document.diagnostics.metrics.get("product_path_enabled") ==
        Some("false"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_native_backend") == Some("true"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_native_text_baseline") ==
        Some("true"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_ocr_used") == Some("false"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_v2_used") == Some("false"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_page_count") == Some("1"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_text_block_count") == Some("1"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_text_line_count") == Some("1"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_text_span_count") == Some("1"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_link_candidate_count") ==
        Some("1"),
      )
    }
    Err(err) =>
      fail("expected synthetic pdf extraction success: " + err.to_string())
  }
}

///|
test "pdf native backend extracts table-like text lines from existing sample" {
  let source = @input.input_from_path_with_format(
    "samples/main_process/pdf/metadata/pdf_metadata_table_like.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Ok(document) => {
      assert_eq(document.pages.length(), 1)
      let page = document.pages[0]
      assert_eq(page.text_blocks.length(), 3)
      let header = page.text_blocks[0].lines[0].spans
        .map(span => span.text)
        .join("")
      let row1 = page.text_blocks[1].lines[0].spans
        .map(span => span.text)
        .join("")
      let row2 = page.text_blocks[2].lines[0].spans
        .map(span => span.text)
        .join("")
      assert_eq(header, "Product Region Status")
      assert_eq(row1, "Alpha East Open")
      assert_eq(row2, "Beta West Closed")
      assert_true(
        document.diagnostics.metrics.get("text_line_count") == Some("3"),
      )
    }
    Err(err) =>
      fail("expected table-like sample extraction success: " + err.to_string())
  }
}

///|
test "pdf native backend handles flate plus ToUnicode sample text" {
  let source = @input.input_from_path_with_format(
    "samples/main_process/pdf/text_simple.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Ok(document) => {
      assert_eq(document.pages.length(), 1)
      let page = document.pages[0]
      assert_true(page.text_blocks.length() >= 3)
      let joined = page.text_blocks
        .map(block => {
          block.lines
          .map(line => line.spans.map(span => span.text).join(""))
          .join(" ")
        })
        .join("\n")
      assert_true(joined.contains("MarkItDown MoonBit MVP"))
      assert_true(joined.to_lower().contains("pdf"))
      assert_true(joined.contains("English"))
    }
    Err(err) =>
      fail("expected flate/tounicode extraction success: " + err.to_string())
  }
}

///|
test "pdf native backend prefers valid ActualText and rejects malformed literal streams" {
  let actual_text_pdf = [
    "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "endobj", "2 0 obj", "<< /Length 88 >>", "stream", "/Span <</ActualText (Hello\\nWorld)>> BDC BT /F1 12 Tf 1 0 0 1 50 700 Tm (ignored) Tj ET EMC",
    "endstream", "endobj", "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj", "5 0 obj",
    "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
    "%%EOF", "",
  ].join("\n")
  let actual_text_source = @input.input_from_bytes_with_format(
    @utf8.encode(actual_text_pdf),
    "actual-text.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(actual_text_source) {
    Ok(document) => {
      let line = document.pages[0].text_blocks[0].lines[0]
      assert_eq(line.spans[0].text, "Hello World")
    }
    Err(err) =>
      fail(
        "expected ActualText synthetic pdf extraction success: " +
        err.to_string(),
      )
  }

  let malformed_pdf = [
    "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "endobj", "2 0 obj", "<< /Length 42 >>", "stream", "BT /F1 12 Tf 1 0 0 1 50 700 Tm (unterminated Tj ET",
    "endstream", "endobj", "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj", "5 0 obj",
    "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
    "%%EOF", "",
  ].join("\n")
  let malformed_source = @input.input_from_bytes_with_format(
    @utf8.encode(malformed_pdf),
    "malformed.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(malformed_source) {
    Err(PdfNativeError::ParseFailed(msg)) =>
      assert_true(msg.contains("unterminated PDF literal string"))
    Err(other) =>
      fail("unexpected malformed literal error: " + other.to_string())
    Ok(_) => fail("expected malformed literal stream to fail explicitly")
  }
}

///|
test "pdf native backend groups hard-wrapped native text conservatively" {
  let source = @input.input_from_path_with_format(
    "samples/main_process/pdf/hardwrap_en.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Ok(document) => {
      assert_eq(document.pages.length(), 1)
      let page = document.pages[0]
      assert_true(page.text_blocks.length() >= 2)
      let first_block_text = page.text_blocks[0].lines
        .map(line => {
          line.spans.map(span => span.text).join("").trim().to_owned()
        })
        .join(" ")
      assert_true(first_block_text.contains("Document Conversion Pipeline"))
      let second_block_text = page.text_blocks[1].lines
        .map(line => {
          line.spans.map(span => span.text).join("").trim().to_owned()
        })
        .join(" ")
      assert_true(
        second_block_text.contains(
          "This project aims to build a unified document conversion pipeline",
        ),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_grouping_strategy") ==
        Some("conservative_v1"),
      )
      assert_true(
        page.diagnostics.metrics.get("pdf_grouping_strategy") ==
        Some("conservative_v1"),
      )
    }
    Err(err) =>
      fail("expected hardwrap sample extraction success: " + err.to_string())
  }
}

///|
test "pdf native backend maps empty text layer and encrypted input explicitly" {
  let empty_pdf = [
    "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "endobj", "2 0 obj", "<< /Length 5 >>", "stream", "BT ET", "endstream", "endobj",
    "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj", "5 0 obj",
    "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
    "%%EOF", "",
  ].join("\n")
  let empty_source = @input.input_from_bytes_with_format(
    @utf8.encode(empty_pdf),
    "empty.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(empty_source) {
    Err(PdfNativeError::EmptyTextLayer(msg)) =>
      assert_true(msg.contains("empty"))
    Err(other) =>
      fail("unexpected empty text layer error: " + other.to_string())
    Ok(_) => fail("expected empty text layer to fail explicitly")
  }

  let encrypted_source = @input.input_from_bytes_with_format(
    @utf8.encode("%PDF-1.4\n1 0 obj\n<< /Encrypt 2 0 R >>\nendobj\n%%EOF\n"),
    "encrypted.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(encrypted_source) {
    Err(PdfNativeError::EncryptedUnsupported(msg)) =>
      assert_true(msg.contains("encrypted PDF"))
    Err(other) => fail("unexpected encrypted error: " + other.to_string())
    Ok(_) => fail("expected encrypted pdf to fail explicitly")
  }
}

///|
test "pdf native backend keeps unsupported feature taxonomy stable" {
  let unsupported_filter_pdf = [
    "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "endobj", "2 0 obj", "<< /Length 54 /Filter /ASCII85Decode >>", "stream", "BT /F1 12 Tf 1 0 0 1 50 700 Tm (Hello PDF backend) Tj ET",
    "endstream", "endobj", "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj", "5 0 obj",
    "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
    "%%EOF", "",
  ].join("\n")
  let source = @input.input_from_bytes_with_format(
    @utf8.encode(unsupported_filter_pdf),
    "unsupported-filter.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Err(PdfNativeError::UnsupportedFeature(msg)) =>
      assert_true(msg.contains("unsupported PDF stream filter"))
    Err(other) =>
      fail("unexpected unsupported feature error: " + other.to_string())
    Ok(_) => fail("expected unsupported filter to fail explicitly")
  }
}

///|
test "pdf native backend preserves line source refs reading order and grouping metrics for multipage samples" {
  let source = @input.input_from_path_with_format(
    "samples/main_process/pdf/text_multipage.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Ok(document) => {
      assert_true(document.pages.length() >= 2)
      let first_page = document.pages[0]
      let first_block = first_page.text_blocks[0]
      let first_line = first_block.lines[0]
      assert_true(first_block.reading_order_index is Some(_))
      assert_true(first_line.reading_order_index is Some(_))
      match first_line.source_ref {
        Some(source_ref) => {
          assert_true(source_ref.format == Some("pdf"))
          assert_true(source_ref.page == Some(1))
          assert_true(source_ref.extra.get("reading_order_index") is Some(_))
          assert_true(source_ref.line_start is Some(_))
          match source_ref.bbox {
            Some(_) => ()
            None => fail("expected line bbox on multipage sample source ref")
          }
        }
        None => fail("expected first line source ref on multipage sample")
      }
      assert_true(
        document.diagnostics.metrics.get("pdf_grouping_strategy") ==
        Some("conservative_v1"),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_grouping_paragraph_count")
        is Some(_),
      )
      assert_true(
        document.diagnostics.metrics.get("pdf_grouping_line_merge_count")
        is Some(_),
      )
      assert_true(document.metadata.get("pdf_text_block_count") is Some(_))
      assert_true(document.metadata.get("pdf_text_line_count") is Some(_))
      assert_true(document.metadata.get("pdf_text_span_count") is Some(_))
    }
    Err(err) =>
      fail("expected multipage extraction success: " + err.to_string())
  }
}

///|
test "pdf native backend accepts compact filter and compact page syntax" {
  let pdf_bytes = pdf_test_join_bytes([
    pdf_test_ascii_bytes(
      "%PDF-1.4\n1 0 obj\n<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>\nendobj\n2 0 obj\n<</Length 66/Filter/FlateDecode>>\nstream\n",
    ),
    Bytes::from_array([
      120, 156, 115, 10, 81, 208, 119, 51, 84, 48, 52, 82, 8, 73, 83, 48, 84, 48,
      0, 66, 67, 5, 83, 3, 5, 115, 3, 3, 133, 144, 92, 5, 13, 231, 252, 220, 130,
      196, 228, 18, 133, 180, 204, 156, 146, 212, 34, 133, 226, 202, 188, 146, 196,
      10, 77, 133, 144, 44, 5, 215, 16, 0, 181, 62, 16, 85,
    ]),
    pdf_test_ascii_bytes(
      "\nendstream\nendobj\n3 0 obj\n<</Type/Page/Parent 4 0 R/MediaBox[0 0 612 792]/Resources<</Font<</F1 1 0 R>>>>/Contents 2 0 R>>\nendobj\n4 0 obj\n<</Type/Pages/Kids[3 0 R]/Count 1>>\nendobj\n5 0 obj\n<</Type/Catalog/Pages 4 0 R>>\nendobj\ntrailer\n<</Size 6/Root 5 0 R>>\n%%EOF\n",
    ),
  ])
  let source = @input.input_from_bytes_with_format(
    pdf_bytes,
    "compact-filter.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Ok(document) => {
      assert_eq(document.pages.length(), 1)
      let line = document.pages[0].text_blocks[0].lines[0]
      assert_eq(line.spans[0].text, "Compact filter syntax")
    }
    Err(err) =>
      fail(
        "expected compact filter/pdf name syntax to succeed: " + err.to_string(),
      )
  }
}

///|
test "pdf native backend narrows direct contents refs without swallowing later refs" {
  let pdf = [
    "%PDF-1.4", "1 0 obj", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "endobj", "2 0 obj", "<< /Length 65 >>", "stream", "BT /F1 12 Tf 1 0 0 1 50 700 Tm (Compact order contents) Tj ET",
    "endstream", "endobj", "3 0 obj", "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R /Annots [7 0 R 8 0 R] >>",
    "endobj", "4 0 obj", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>", "endobj", "5 0 obj",
    "<< /Type /Catalog /Pages 4 0 R >>", "endobj", "trailer", "<< /Size 6 /Root 5 0 R >>",
    "%%EOF", "",
  ].join("\n")
  let source = @input.input_from_bytes_with_format(
    pdf_test_ascii_bytes(pdf),
    "contents-direct-ref.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Ok(document) => {
      assert_eq(document.pages.length(), 1)
      let line = document.pages[0].text_blocks[0].lines[0]
      assert_eq(line.spans[0].text, "Compact order contents")
    }
    Err(err) =>
      fail(
        "expected direct /Contents ref narrowing success: " + err.to_string(),
      )
  }
}

///|
test "pdf native backend expands page objects embedded in object streams" {
  let pdf_bytes = pdf_test_join_bytes([
    pdf_test_ascii_bytes(
      "%PDF-1.5\n1 0 obj\n<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>\nendobj\n2 0 obj\n<< /Length 56 >>\nstream\nBT /F1 12 Tf 1 0 0 1 50 700 Tm (ObjStm page) Tj ET\nendstream\nendobj\n3 0 obj\n<</Type/ObjStm/N 2/First 10/Length 125/Filter/FlateDecode>>\nstream\n",
    ),
    Bytes::from_array([
      120, 156, 51, 81, 48, 80, 48, 85, 48, 52, 52, 84, 176, 177, 81, 208, 15, 169,
      44, 72, 85, 208, 15, 72, 76, 7, 147, 69, 169, 121, 37, 64, 73, 3, 133, 32,
      5, 125, 223, 212, 148, 204, 68, 167, 252, 10, 133, 104, 3, 160, 128, 153, 161,
      145, 130, 185, 165, 81, 172, 130, 126, 80, 106, 113, 126, 105, 81, 114, 106,
      49, 88, 191, 91, 62, 80, 7, 152, 97, 168, 96, 8, 214, 104, 103, 7, 66, 250,
      206, 64, 9, 160, 105, 197, 10, 70, 48, 81, 84, 235, 138, 21, 244, 189, 51,
      83, 138, 21, 162, 77, 64, 242, 177, 32, 13, 165, 64, 163, 12, 129, 42, 1, 131,
      28, 43, 16,
    ]),
    pdf_test_ascii_bytes(
      "\nendstream\nendobj\n6 0 obj\n<</Type/Catalog/Pages 5 0 R>>\nendobj\ntrailer\n<</Size 7/Root 6 0 R>>\n%%EOF\n",
    ),
  ])
  let source = @input.input_from_bytes_with_format(
    pdf_bytes,
    "object-stream-page.pdf",
    Some(@input.DetectedFormat::Pdf),
  )
  match extract_pdf_native_document(source) {
    Ok(document) => {
      assert_eq(document.pages.length(), 1)
      let line = document.pages[0].text_blocks[0].lines[0]
      assert_eq(line.spans[0].text, "ObjStm page")
    }
    Err(err) =>
      fail(
        "expected object stream embedded page extraction success: " +
        err.to_string(),
      )
  }
}
