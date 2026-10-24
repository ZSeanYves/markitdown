///|
fn light_probe_classic_pdf(content : String) -> Bytes {
  let objects = [
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>", content, "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 99 >>", "<< /Type /Catalog /Pages 4 0 R >>",
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
    "trailer\n<< /Size 6 /Root 5 0 R >>\nstartxref\n" +
    offset.to_string() +
    "\n%%EOF\n",
  )
  @utf8.encode(chunks.join(""))
}

///|
async test "PDF structural route probe does not interpret a corrupt content stream" {
  let bytes = light_probe_classic_pdf(
    "<< /Filter [ /ASCIIHexDecode /FlateDecode ] /Length 15 >>\nstream\n78010700000000>\nendstream",
  )
  let owner = @input.begin_input_session(
    @input.input_from_bytes_with_format(bytes, "corrupt-content.pdf", Some(Pdf)),
  )
  defer @input.end_input_session(owner)
  let outcome = pdf_preflight_probe(
    owner.source,
    balanced_markdown_options(Pdf),
  )
  assert_eq(outcome.probe_artifacts.length(), 1)
  assert_true(@input.input_source_failure(owner.source) is None)
  let context = @parser.new_parse_context(Pdf)
  match
    parse_with_route_probe_artifact(
      owner.source,
      Pdf,
      context,
      @formats.builtin_registry(),
      outcome.probe_artifacts,
    ) {
    Some(Err(_)) => ()
    _ => fail("content corruption must fail during parse")
  }
  assert_true(@input.input_source_failure(owner.source) is Some(InputError(_)))
}

///|
async test "PDF structural route probe preserves Reader and defers exact text classification" {
  let bytes = light_probe_classic_pdf(
    "<< /Length 35 >>\nstream\nBT /F1 12 Tf (reader text) Tj ET\nendstream",
  )
  let reader = @input.make_input_reader(
    fn(offset, length) {
      let start = offset.to_int()
      if start >= bytes.length() {
        return Ok(b"")
      }
      Ok(bytes[start:(start + length).min(bytes.length())].to_owned())
    },
    size=bytes.length().to_int64(),
  )
  let owner = @input.begin_input_session(
    @input.input_from_reader_with_format(reader, "reader.pdf", Some(Pdf)),
  )
  defer @input.end_input_session(owner)
  let outcome = pdf_preflight_probe(
    owner.source,
    balanced_markdown_options(Pdf),
  )
  assert_true(@input.input_kind(outcome.prepared_source) == Reader)
  assert_eq(outcome.probe_signals.length(), 1)
  assert_true(outcome.probe_signals[0].kind == PageCount)
  assert_eq(outcome.probe_signals[0].observed, 1)
  assert_true(outcome.summary_parts.contains("text_classification=deferred"))
}

///|
async test "PDF deferred content keeps hard-input error domain and concrete extraction reason" {
  let broken = @input.input_from_bytes_with_format(
    light_probe_classic_pdf(
      "<< /Filter [ /ASCIIHexDecode /FlateDecode ] /Length 15 >>\nstream\n78010700000000>\nendstream",
    ),
    "broken.pdf",
    Some(Pdf),
  )
  let options = balanced_markdown_options(Pdf)
  assert_true(
    plan_input(broken, options).unwrap().route_probe_summary.contains(
      "text_classification=deferred",
    ),
  )
  assert_true(convert_input(broken, options) is Err(DetectFailed(_)))
  let empty = @input.input_from_bytes_with_format(
    light_probe_classic_pdf("<< /Length 0 >>\nstream\n\nendstream"),
    "empty.pdf",
    Some(Pdf),
  )
  match convert_input(empty, options) {
    Err(ParseFailed(message)) =>
      assert_true(message.contains("PDF native text layer is empty"))
    _ => fail("ordinary extraction failure must preserve its concrete reason")
  }
}
