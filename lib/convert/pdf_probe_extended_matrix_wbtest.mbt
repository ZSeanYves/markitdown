///|
fn pdf_extended_fixture(content : String, variant : String) -> Bytes {
  let image = variant == "image_only"
  let objects = [
    if image {
      "<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /ASCIIHexDecode /Length 7 >>\nstream\nFF0000>\nendstream"
    } else {
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    },
    content,
    "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << " +
    (if image { "/XObject << /Im0 1 0 R >>" } else { "/Font << /F1 1 0 R >>" }) +
    " >> /Contents 2 0 R >>",
    "<< /Type /Pages /Kids [" +
    (if variant == "cycle" { "4" } else { "3" }) +
    " 0 R] /Count 99 >>",
    "<< /Type /Catalog /Pages 4 0 R >>",
  ]
  let chunks = ["%PDF-1.4\n"]
  let offsets : Array[Int32] = []
  let mut offset = chunks[0].length()
  for i in 0..<objects.length() {
    offsets.push(offset)
    let chunk = (i + 1).to_string() + " 0 obj\n" + objects[i] + "\nendobj\n"
    chunks.push(chunk)
    offset += chunk.length()
  }
  chunks.push("xref\n0 6\n0000000000 65535 f \n")
  for offset in offsets {
    let value = offset.to_string()
    chunks.push(
      "0000000000"[:10 - value.length()].to_owned() + value + " 00000 n \n",
    )
  }
  chunks.push(
    "trailer\n<< /Size 6 /Root 5 0 R " +
    (if variant == "encrypted" { "/Encrypt 99 0 R " } else { "" }) +
    ">>\nstartxref\n" +
    offset.to_string() +
    "\n%%EOF\n",
  )
  @utf8.encode(chunks.join(""))
}

///|
fn pdf_extended_stream(payload : String, extra : String) -> String {
  "<< /Length " +
  payload.length().to_string() +
  " " +
  extra +
  " >>\nstream\n" +
  payload +
  "\nendstream"
}

///|
fn pdf_extended_domain(result : Result[ConvertResult, ConvertError]) -> String {
  match result {
    Ok(_) => "Ok"
    Err(DetectFailed(_)) => "DetectFailed"
    Err(ParseFailed(_)) => "ParseFailed"
    Err(ResourceLimitExceeded(..)) => "ResourceLimitExceeded"
    Err(UnsupportedCapability(_)) => "UnsupportedCapability"
    Err(RenderFailed(_)) => "RenderFailed"
  }
}

///|
async test "PDF image encryption unsupported syntax and page-tree classification are deferred precisely" {
  let content = "BT /F1 12 Tf (matrix text) Tj ET"
  let cases = [
    ("false_count", pdf_extended_stream(content, ""), "Ok"),
    ("cycle", pdf_extended_stream(content, ""), "Ok"),
    (
      "image_only",
      pdf_extended_stream("q 32 0 0 24 72 120 cm /Im0 Do Q", ""),
      "Ok",
    ),
    ("encrypted", pdf_extended_stream(content, ""), "ParseFailed"),
    (
      "unsupported_filter",
      pdf_extended_stream("opaque", "/Filter /NoSuchFilter"),
      "ParseFailed",
    ),
    (
      "unsupported_predictor",
      pdf_extended_stream(
        "7801010300FCFF414243018D00C7>", "/Filter [ /ASCIIHexDecode /FlateDecode ] /DecodeParms [ null << /Predictor 99 /Columns 1 /Colors 1 /BitsPerComponent 8 >> ]",
      ),
      "ParseFailed",
    ),
  ]
  for (label, stream, domain) in cases {
    let bytes = pdf_extended_fixture(stream, label)
    let source = @input.input_from_bytes_with_format(
      bytes,
      label + ".pdf",
      Some(Pdf),
    )
    let options = balanced_markdown_options(Pdf)
    let plan = plan_input(source, options).unwrap()
    if label == "encrypted" {
      assert_true(plan.route_probe_summary.contains("native_probe=failed"))
    } else {
      assert_true(
        plan.route_probe_summary.contains("text_classification=deferred"),
      )
      assert_true(
        plan.route_probe_summary.contains(
          if label == "cycle" {
            "page_tree_repair_deferred"
          } else {
            "indexed_page_tree"
          },
        ),
      )
    }
    let converted = convert_input(source, options)
    assert_eq(pdf_extended_domain(converted), domain)
    match converted {
      Ok(value) => {
        assert_eq(value.diagnostics.metrics.get("page_count"), Some("1"))
        assert_eq(
          value.diagnostics.metrics.get("pdf_text_classification_phase"),
          Some("completed"),
        )
        assert_eq(
          value.diagnostics.metrics.get("pdf_native_text_page_count"),
          Some(if label == "image_only" { "0" } else { "1" }),
        )
        assert_eq(
          value.diagnostics.metrics.get("pdf_scanned_page_count"),
          Some(if label == "image_only" { "1" } else { "0" }),
        )
      }
      Err(ParseFailed(message)) if label == "unsupported_filter" =>
        assert_true(
          message.contains("unsupported PDF stream filter: NoSuchFilter"),
        )
      Err(ParseFailed(message)) if label == "unsupported_predictor" =>
        assert_true(message.contains("unsupported PDF predictor: 99"))
      _ => ()
    }
  }
}
