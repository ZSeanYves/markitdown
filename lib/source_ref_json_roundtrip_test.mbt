///|
fn source_position_pdf(content : String) -> String {
  "%PDF-1.5\n1 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n" +
  "2 0 obj\n<< /Length " +
  content.length().to_string() +
  " >>\nstream\n" +
  content +
  "\nendstream\nendobj\n3 0 obj\n<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>\nendobj\n" +
  "4 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n5 0 obj\n<< /Type /Catalog /Pages 4 0 R >>\nendobj\ntrailer\n<< /Root 5 0 R /Size 6 >>\n%%EOF\n"
}

///|
fn source_json_field(value : Json, name : String) -> Json {
  match value {
    Object(fields) => fields.get(name).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn source_position_matches_facade(
  value : Json,
  source : @lib.SourceRef,
) -> Unit raise {
  guard value is Object(fields) else { fail("source ref object expected") }
  assert_eq(fields.get("page"), source.page.map(page => Json(page)))
  assert_eq(
    fields.get("byte_start"),
    source.byte_start.map(offset => Json(offset)),
  )
  assert_eq(fields.get("byte_end"), source.byte_end.map(offset => Json(offset)))
  assert_eq(fields.get("time_start"), source.time_start.map(time => Json(time)))
  assert_eq(fields.get("time_end"), source.time_end.map(time => Json(time)))
  assert_eq(
    fields.get("bbox"),
    source.bbox.map(box => {
      ({ "x0": box.x0, "y0": box.y0, "x1": box.x1, "y1": box.y1 } : Json)
    }),
  )
}

///|
async test "public JSON collector and Sink retain actual PDF bbox and SRT time fields" {
  let fixtures = [
    (
      "pdf",
      source_position_pdf("BT /F1 12 Tf 1 0 0 1 10 20 Tm (finite text) Tj ET"),
    ),
    (
      "srt", "1\n00:00:01,250 --> 00:00:02,500\nfirst cue\n\n2\n00:00:03,000 --> 00:00:04,750\nsecond cue\n",
    ),
  ]
  for (format, text) in fixtures {
    for mode in [@lib.OutputMode::Debug, Rag] {
      let options = @lib.ConvertOptions::default()
        .with_format_hint(Some(format))
        .with_mode(if format == "pdf" { Accurate } else { Balanced })
        .with_output_mode(mode)
      let output = @lib.convert(
        @lib.Input::from_text(text, source_name="source." + format),
        options~,
      ).unwrap()
      let parsed = @source_json.parse(
        output.content,
        reject_duplicate_keys=true,
      )
      let parts : Array[String] = []
      let finishes = Ref(0)
      let summary = @lib.convert_to_sink(
        @lib.Input::from_text(text, source_name="source." + format),
        @lib.OutputSink::new(
          async fn(part) {
            @async.pause()
            parts.push(part)
            Ok(())
          },
          () => {
            finishes.val += 1
            Ok(())
          },
        ),
        options~,
      ).unwrap()
      assert_eq(finishes.val, 1)
      assert_eq(summary.detected_format, format)
      // Timings and the sink-route diagnostic are per execution; compare the
      // complete source payload separately from those documented side channels.
      let sink_json = @source_json.parse(
        parts.join(""),
        reject_duplicate_keys=true,
      )
      if mode == Rag {
        guard source_json_field(parsed, "chunks") is Array(chunks) else {
          fail("chunks expected")
        }
        guard source_json_field(sink_json, "chunks") is Array(sink_chunks) else {
          fail("sink chunks expected")
        }
        assert_eq(chunks, sink_chunks)
        assert_eq(chunks.length(), output.chunks.length())
        let mut refs = 0
        for index in 0..<chunks.length() {
          guard source_json_field(chunks[index], "source_refs")
            is Array(sources) else {
            fail("source refs expected")
          }
          assert_eq(sources.length(), output.chunks[index].source_refs.length())
          for ref_index in 0..<sources.length() {
            let source = output.chunks[index].source_refs[ref_index]
            source_position_matches_facade(sources[ref_index], source)
            if format == "pdf" {
              assert_true(source.page is Some(_))
              assert_true(source.bbox is Some(_))
            }
            if format == "srt" {
              assert_true(source.time_start is Some(_))
              assert_true(source.time_end is Some(_))
            }
            refs += 1
          }
        }
        assert_true(refs > 0)
        assert_eq(
          source_json_field(parsed, "source_map"),
          source_json_field(sink_json, "source_map"),
        )
      } else {
        assert_eq(
          source_json_field(parsed, "blocks"),
          source_json_field(sink_json, "blocks"),
        )
        assert_eq(
          source_json_field(parsed, "events"),
          source_json_field(sink_json, "events"),
        )
      }
    }
  }
}

///|
async test "public JSON collector and Sink reject actual PDF nonfinite bbox without finish" {
  // Each operand is a valid finite decimal PDF number. The text-size
  // multiplication overflows; this fixture reaches the real PDF producer.
  let number = "1" + "0".repeat(308)
  let pdf = source_position_pdf(
    "BT /F1 " + number + " Tf 2 0 0 2 10 10 Tm (A) Tj ET",
  )
  for mode in [@lib.OutputMode::Debug, Rag] {
    let options = @lib.ConvertOptions::default()
      .with_format_hint(Some("pdf"))
      .with_mode(Accurate)
      .with_output_mode(mode)
    match
      @lib.convert(
        @lib.Input::from_text(pdf, source_name="overflow.pdf"),
        options~,
      ) {
      Err(RenderFailed(message)) =>
        assert_true(message.contains("SourceRef bbox"))
      _ => fail("nonfinite coordinates must fail public JSON conversion")
    }
    let writes = Ref(0)
    let finishes = Ref(0)
    let result = @lib.convert_to_sink(
      @lib.Input::from_text(pdf, source_name="overflow.pdf"),
      @lib.OutputSink::new(
        part => {
          assert_false(part.contains("Infinity") || part.contains("NaN"))
          writes.val += 1
          Ok(())
        },
        () => {
          finishes.val += 1
          Ok(())
        },
      ),
      options~,
    )
    match result {
      Err(RenderFailed(message)) =>
        assert_true(message.contains("SourceRef bbox"))
      _ => fail("nonfinite coordinates must fail the public JSON sink")
    }
    assert_eq(finishes.val, 0)
    // The sink is not transactional: a valid framing prefix can precede a
    // later encoding error, but the invalid coordinate is never emitted.
    assert_true(writes.val > 0)
  }
}
