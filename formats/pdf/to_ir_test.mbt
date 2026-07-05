///|
fn pdf_test_core_bbox(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @core.BBox {
  { x0, y0, x1, y1 }
}

///|
fn pdf_test_source_ref(
  file_id : String,
  page : Int,
  line : Int,
  bbox : @core.BBox,
) -> @core.SourceRef {
  {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(file_id),
      Some("pdf"),
      Some(line),
      Some(line),
    ),
    page: Some(page),
    bbox: Some(bbox),
  }
}

///|
fn pdf_test_line(
  text : String,
  x : Double,
  y : Double,
  width? : Double = 90.0,
  height? : Double = 12.0,
  file_id? : String = "synthetic.pdf",
  page? : Int = 1,
  line? : Int = 1,
  reading_order_index? : Int? = None,
) -> PdfNativeTextLine {
  let bbox = make_pdf_bbox(x, y, width, height)
  make_pdf_native_text_line(
    [make_pdf_native_text_span(text, bbox)],
    bbox,
    source_ref=Some(
      pdf_test_source_ref(
        file_id,
        page,
        line,
        pdf_test_core_bbox(x, y, x + width, y + height),
      ),
    ),
    reading_order_index~,
  )
}

///|
test "pdf native unit bridge lowers paragraphs with source refs and metadata only links" {
  let bbox1 = make_pdf_bbox(10.0, 20.0, 80.0, 12.0)
  let bbox2 = make_pdf_bbox(10.0, 40.0, 60.0, 12.0)
  let bbox3 = make_pdf_bbox(10.0, 60.0, 70.0, 12.0)
  let bbox4 = make_pdf_bbox(12.0, 18.0, 30.0, 8.0)
  let line1_source = @core.source_ref_with_extra(
    pdf_test_source_ref(
      "synthetic.pdf",
      1,
      7,
      pdf_test_core_bbox(10.0, 20.0, 90.0, 32.0),
    ),
    "existing_source",
    "true",
  )
  let line1 = make_pdf_native_text_line(
    [
      make_pdf_native_text_span("Hello", bbox1),
      make_pdf_native_text_span(" PDF", bbox1),
    ],
    bbox1,
    source_ref=Some(line1_source),
    reading_order_index=Some(7),
  )
  let empty_line = make_pdf_native_text_line(
    [make_pdf_native_text_span("   ", bbox2)],
    bbox2,
    reading_order_index=Some(2),
  )
  let line3 = make_pdf_native_text_line(
    [make_pdf_native_text_span("Second line", bbox3)],
    bbox3,
    reading_order_index=Some(3),
  )
  let page1 = make_pdf_native_page(
    make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[
      make_pdf_native_text_block(
        [line1, empty_line, line3],
        make_pdf_bbox(10.0, 20.0, 80.0, 52.0),
        reading_order_index=Some(1),
      ),
    ],
    image_candidates=[make_pdf_native_image_candidate(bbox1)],
    link_candidates=[
      make_pdf_native_link_candidate(
        bbox4,
        "https://example.com",
        text=Some("Hello PDF"),
        source_ref=Some(
          @core.source_ref_with_extra(
            pdf_test_source_ref(
              "synthetic.pdf",
              1,
              1,
              pdf_test_core_bbox(12.0, 18.0, 42.0, 26.0),
            ),
            "reading_order_index",
            "1",
          ),
        ),
        annotation_index=Some(0),
        annotation_object_id=Some(42),
      ),
    ],
    table_candidates=[make_pdf_native_table_candidate(bbox2, row_count=Some(2))],
    artifact_candidates=[
      make_pdf_native_artifact_candidate("header_candidate", bbox4),
    ],
  )
  let page2 = make_pdf_native_page(make_pdf_page_geometry(2, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        make_pdf_native_text_line(
          [make_pdf_native_text_span("Page 2 line", bbox1)],
          bbox1,
        ),
      ],
      bbox1,
    ),
  ])
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("parser_name", "pdf_native_backend")
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(
      pages=[page1, page2],
      metadata=Map([("producer", @core.JsonValue::String("test"))]),
      diagnostics~,
    ),
  )
  assert_eq(document.blocks.length(), 2)
  assert_eq(document.blocks[0].text, "Hello PDF Second line")
  assert_eq(document.blocks[1].text, "Page 2 line")
  let first_ref = document.blocks[0].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(first_ref.file_id == Some("synthetic.pdf"))
  assert_true(first_ref.format == Some("pdf"))
  assert_true(first_ref.page == Some(1))
  assert_true(first_ref.line_start == Some(7))
  assert_true(first_ref.line_end is Some(_))
  match first_ref.bbox {
    Some(value) => {
      assert_eq(value.x0, 10.0)
      assert_eq(value.y0, 20.0)
      assert_eq(value.x1, 90.0)
      assert_true(value.y1 >= 32.0)
    }
    None => fail("expected first paragraph bbox to survive")
  }
  assert_true(first_ref.extra.get("existing_source") == Some("true"))
  assert_true(first_ref.extra.get("page_no") == Some("1"))
  assert_true(first_ref.extra.get("pdf_text_block_index") == Some("1"))
  assert_true(first_ref.extra.get("pdf_line_index") == Some("7"))
  assert_true(first_ref.extra.get("pdf_line_end_index") is Some(_))
  assert_true(first_ref.extra.get("reading_order_index") is Some(_))
  let second_ref = document.blocks[1].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(second_ref.page == Some(2))
  assert_true(second_ref.line_start == Some(1))
  assert_true(second_ref.line_end == Some(1))
  assert_true(document.blocks[0].text == "Hello PDF Second line")
  assert_true(!document.blocks[0].text.contains("]("))
  assert_true(document.assets.length() == 0)
  assert_true(document.signals.length() == 0)
  assert_true(document.diagnostics.metrics.get("renderer_name") == None)
  assert_true(
    document.diagnostics.pass_trace.contains("pdf_native:to_document_ir"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_native_ir_projection") ==
    Some("unit_path"),
  )
  assert_true(document.diagnostics.metrics.get("block_count") == Some("2"))
  assert_true(document.diagnostics.metrics.get("paragraph_count") == Some("2"))
  assert_true(
    document.diagnostics.metrics.get("pdf_grouping_strategy") ==
    Some("conservative_v1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_grouping_paragraph_count") ==
    Some("2"),
  )
  assert_true(document.diagnostics.metrics.get("link_count") == Some("1"))
  assert_true(
    document.diagnostics.degraded_features.contains(
      "pdf_link_candidates_metadata_only",
    ),
  )
  assert_true(
    document.diagnostics.degraded_features.contains(
      "pdf_image_candidates_not_lowered",
    ),
  )
  assert_true(
    document.diagnostics.degraded_features.contains(
      "pdf_table_candidates_not_lowered",
    ),
  )
  assert_true(
    document.diagnostics.degraded_features.contains(
      "pdf_artifact_candidates_not_lowered",
    ),
  )
  match document.metadata.get("producer") {
    Some(@core.JsonValue::String(value)) => assert_eq(value, "test")
    _ => fail("expected producer metadata")
  }
  match document.metadata.get("pdf_native_projection") {
    Some(@core.JsonValue::String(value)) => assert_eq(value, "unit_path")
    _ => fail("expected unit bridge metadata")
  }
  assert_true(
    document.metadata.get("pdf_link_candidate_count") ==
    Some(@core.JsonValue::Number("1")),
  )
  assert_true(
    document.metadata.get("page_count") == Some(@core.JsonValue::Number("2")),
  )
  assert_true(
    document.metadata.get("pdf_grouping_strategy") ==
    Some(@core.JsonValue::String("conservative_v1")),
  )
  assert_true(
    document.metadata.get("pdf_grouping_paragraph_count") ==
    Some(@core.JsonValue::Number("2")),
  )
  match document.metadata.get("pdf_link_candidates") {
    Some(@core.JsonValue::Array(items)) => {
      assert_eq(items.length(), 1)
      match items[0] {
        @core.JsonValue::Object(payload) => {
          assert_true(
            payload.get("href") ==
            Some(@core.JsonValue::String("https://example.com")),
          )
          assert_true(
            payload.get("target") ==
            Some(@core.JsonValue::String("https://example.com")),
          )
          assert_true(payload.get("page") == Some(@core.JsonValue::Number("1")))
          assert_true(
            payload.get("source_page") == Some(@core.JsonValue::Number("1")),
          )
          assert_true(
            payload.get("annotation_index") ==
            Some(@core.JsonValue::Number("0")),
          )
          assert_true(
            payload.get("annotation_object_id") ==
            Some(@core.JsonValue::Number("42")),
          )
          assert_true(
            payload.get("reading_order_index") ==
            Some(@core.JsonValue::Number("1")),
          )
          match payload.get("bbox") {
            Some(@core.JsonValue::Object(_)) => ()
            _ => fail("expected link bbox object")
          }
          match payload.get("source_bbox") {
            Some(@core.JsonValue::Object(source_bbox)) => {
              assert_true(
                source_bbox.get("x0") == Some(@core.JsonValue::Number("12")),
              )
              assert_true(
                source_bbox.get("y0") == Some(@core.JsonValue::Number("18")),
              )
            }
            _ => fail("expected source bbox object")
          }
        }
        _ => fail("expected link candidate object")
      }
    }
    _ => fail("expected link candidate metadata array")
  }
}

///|
test "pdf native unit bridge composes with backend extraction without enabling renderer or parser success path" {
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
  let extracted = match extract_pdf_native_document(source) {
    Ok(value) => value
    Err(err) => fail("expected native extraction success: " + err.to_string())
  }
  let document = pdf_native_document_to_ir(extracted)
  assert_eq(document.blocks.length(), 1)
  assert_eq(document.blocks[0].text, "Hello PDF backend")
  let source_ref = document.blocks[0].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(source_ref.file_id == Some("synthetic.pdf"))
  assert_true(source_ref.format == Some("pdf"))
  assert_true(source_ref.page == Some(1))
  match source_ref.bbox {
    Some(_) => ()
    None => fail("expected bbox on lowered paragraph source ref")
  }
  assert_true(document.diagnostics.metrics.get("renderer_name") == None)
  assert_true(
    document.diagnostics.metrics.get("product_path_enabled") == Some("false"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_link_candidate_count") == Some("1"),
  )
  match document.metadata.get("pdf_link_candidates") {
    Some(@core.JsonValue::Array(items)) => assert_eq(items.length(), 1)
    _ => fail("expected link candidate metadata from backend extraction")
  }
}

///|
test "pdf native unit bridge keeps page and block boundaries conservative" {
  let bbox1 = make_pdf_bbox(10.0, 20.0, 90.0, 12.0)
  let bbox2 = make_pdf_bbox(10.0, 38.0, 90.0, 12.0)
  let bbox3 = make_pdf_bbox(80.0, 56.0, 90.0, 12.0)
  let bbox4 = make_pdf_bbox(10.0, 74.0, 90.0, 12.0)
  let page1 = make_pdf_native_page(make_pdf_page_geometry(1, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        make_pdf_native_text_line(
          [make_pdf_native_text_span("First sentence", bbox1)],
          bbox1,
          source_ref=Some(
            pdf_test_source_ref(
              "grouping.pdf",
              1,
              1,
              pdf_test_core_bbox(10.0, 20.0, 100.0, 32.0),
            ),
          ),
          reading_order_index=Some(1),
        ),
        make_pdf_native_text_line(
          [make_pdf_native_text_span("continues here", bbox2)],
          bbox2,
          source_ref=Some(
            pdf_test_source_ref(
              "grouping.pdf",
              1,
              2,
              pdf_test_core_bbox(10.0, 38.0, 100.0, 50.0),
            ),
          ),
          reading_order_index=Some(2),
        ),
      ],
      make_pdf_bbox(10.0, 20.0, 90.0, 30.0),
      reading_order_index=Some(1),
    ),
    make_pdf_native_text_block(
      [
        make_pdf_native_text_line(
          [make_pdf_native_text_span("- bullet line", bbox3)],
          bbox3,
          source_ref=Some(
            pdf_test_source_ref(
              "grouping.pdf",
              1,
              3,
              pdf_test_core_bbox(80.0, 56.0, 170.0, 68.0),
            ),
          ),
          reading_order_index=Some(3),
        ),
      ],
      bbox3,
      reading_order_index=Some(3),
    ),
  ])
  let page2 = make_pdf_native_page(make_pdf_page_geometry(2, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        make_pdf_native_text_line(
          [make_pdf_native_text_span("Second page line", bbox4)],
          bbox4,
          source_ref=Some(
            pdf_test_source_ref(
              "grouping.pdf",
              2,
              1,
              pdf_test_core_bbox(10.0, 74.0, 100.0, 86.0),
            ),
          ),
          reading_order_index=Some(1),
        ),
      ],
      bbox4,
      reading_order_index=Some(1),
    ),
  ])
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(pages=[page1, page2]),
  )
  assert_eq(document.blocks.length(), 3)
  assert_eq(document.blocks[0].text, "First sentence continues here")
  assert_eq(document.blocks[1].text, "- bullet line")
  assert_eq(document.blocks[2].text, "Second page line")
  let merged_ref = document.blocks[0].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(merged_ref.page == Some(1))
  assert_true(merged_ref.line_start == Some(1))
  assert_true(merged_ref.line_end == Some(2))
  match merged_ref.bbox {
    Some(value) => {
      assert_eq(value.x0, 10.0)
      assert_eq(value.y0, 20.0)
      assert_eq(value.x1, 100.0)
      assert_true(value.y1 >= 32.0)
    }
    None => fail("expected merged paragraph bbox")
  }
  let bullet_ref = document.blocks[1].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(bullet_ref.page == Some(1))
  assert_true(bullet_ref.line_start == Some(3))
  assert_true(bullet_ref.line_end == Some(3))
  let next_page_ref = document.blocks[2].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(next_page_ref.page == Some(2))
}

///|
test "pdf native unit bridge preserves CJK spacing conservatively" {
  let bbox = make_pdf_bbox(10.0, 20.0, 40.0, 12.0)
  let page = make_pdf_native_page(make_pdf_page_geometry(1, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        make_pdf_native_text_line(
          [
            make_pdf_native_text_span("中", bbox),
            make_pdf_native_text_span("文", bbox),
            make_pdf_native_text_span("测试", bbox),
          ],
          bbox,
          source_ref=Some(
            pdf_test_source_ref(
              "cjk.pdf",
              1,
              1,
              pdf_test_core_bbox(10.0, 20.0, 50.0, 32.0),
            ),
          ),
          reading_order_index=Some(1),
        ),
      ],
      bbox,
      reading_order_index=Some(1),
    ),
  ])
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(pages=[page]),
  )
  assert_eq(document.blocks.length(), 1)
  assert_eq(document.blocks[0].text, "中文测试")
}

///|
test "pdf native unit bridge keeps paragraph grouping matrix and source refs stable" {
  let merge_line1 = pdf_test_line(
    "First sentence",
    10.0,
    20.0,
    file_id="grouping-matrix.pdf",
    line=1,
    reading_order_index=Some(2),
  )
  let merge_line2 = pdf_test_line(
    "continues here",
    12.0,
    34.0,
    file_id="grouping-matrix.pdf",
    line=2,
    reading_order_index=Some(3),
  )
  let punctuation_line = pdf_test_line(
    "Ends here.",
    10.0,
    56.0,
    file_id="grouping-matrix.pdf",
    line=3,
    reading_order_index=Some(4),
  )
  let continuation_after_punctuation = pdf_test_line(
    "should stay separate",
    12.0,
    70.0,
    file_id="grouping-matrix.pdf",
    line=4,
    reading_order_index=Some(5),
  )
  let numbered_line = pdf_test_line(
    "1. numbered item",
    10.0,
    92.0,
    file_id="grouping-matrix.pdf",
    line=5,
    reading_order_index=Some(6),
  )
  let cjk_line = pdf_test_line(
    "中文段落",
    10.0,
    114.0,
    width=60.0,
    file_id="grouping-matrix.pdf",
    line=6,
    reading_order_index=Some(7),
  )
  let page = make_pdf_native_page(
    make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[
      make_pdf_native_text_block(
        [merge_line1, merge_line2],
        make_pdf_bbox(10.0, 20.0, 92.0, 26.0),
        reading_order_index=Some(2),
      ),
      make_pdf_native_text_block(
        [punctuation_line],
        make_pdf_bbox(10.0, 56.0, 90.0, 12.0),
        reading_order_index=Some(4),
      ),
      make_pdf_native_text_block(
        [continuation_after_punctuation],
        make_pdf_bbox(12.0, 70.0, 90.0, 12.0),
        reading_order_index=Some(5),
      ),
      make_pdf_native_text_block(
        [numbered_line],
        make_pdf_bbox(10.0, 92.0, 90.0, 12.0),
        reading_order_index=Some(6),
      ),
      make_pdf_native_text_block(
        [cjk_line],
        make_pdf_bbox(10.0, 114.0, 60.0, 12.0),
        reading_order_index=Some(7),
      ),
    ],
    link_candidates=[
      make_pdf_native_link_candidate(
        make_pdf_bbox(12.0, 18.0, 28.0, 8.0),
        "https://example.com/merge",
        text=Some("First sentence"),
        source_ref=Some(
          @core.source_ref_with_extra(
            pdf_test_source_ref(
              "grouping-matrix.pdf",
              1,
              1,
              pdf_test_core_bbox(12.0, 18.0, 40.0, 26.0),
            ),
            "reading_order_index",
            "2",
          ),
        ),
        annotation_index=Some(0),
        annotation_object_id=Some(9),
      ),
    ],
  )
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("pdf_grouping_line_merge_count", "1")
  diagnostics.metrics.set("pdf_grouping_paragraph_count", "5")
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(pages=[page], diagnostics~),
  )
  assert_eq(document.blocks.length(), 5)
  assert_eq(document.blocks[0].text, "First sentence continues here")
  assert_eq(document.blocks[1].text, "Ends here.")
  assert_eq(document.blocks[2].text, "should stay separate")
  assert_eq(document.blocks[3].text, "1. numbered item")
  assert_eq(document.blocks[4].text, "中文段落")
  assert_true(!document.blocks[0].text.contains("]("))
  let merged_ref = document.blocks[0].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(merged_ref.file_id == Some("grouping-matrix.pdf"))
  assert_true(merged_ref.page == Some(1))
  assert_true(merged_ref.line_start == Some(1))
  assert_true(merged_ref.line_end == Some(2))
  assert_true(merged_ref.extra.get("pdf_text_block_index") == Some("1"))
  assert_true(merged_ref.extra.get("reading_order_index") == Some("2"))
  match merged_ref.bbox {
    Some(value) => {
      assert_eq(value.x0, 10.0)
      assert_eq(value.y0, 20.0)
      assert_eq(value.x1, 100.0)
      assert_eq(value.y1, 32.0)
    }
    None => fail("expected merged bbox to survive")
  }
  let punctuation_ref = document.blocks[1].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(punctuation_ref.line_start == Some(3))
  assert_true(punctuation_ref.line_end == Some(3))
  let numbered_ref = document.blocks[3].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(numbered_ref.line_start == Some(5))
  assert_true(numbered_ref.line_end == Some(5))
  assert_true(
    document.diagnostics.metrics.get("pdf_grouping_strategy") ==
    Some("conservative_v1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_grouping_paragraph_count") ==
    Some("5"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_grouping_line_merge_count") ==
    Some("1"),
  )
  assert_true(
    document.metadata.get("pdf_grouping_paragraph_count") ==
    Some(@core.JsonValue::Number("5")),
  )
  match document.metadata.get("pdf_link_candidates") {
    Some(@core.JsonValue::Array(items)) => {
      assert_eq(items.length(), 1)
      match items[0] {
        @core.JsonValue::Object(payload) => {
          assert_true(
            payload.get("target") ==
            Some(@core.JsonValue::String("https://example.com/merge")),
          )
          assert_true(payload.get("page") == Some(@core.JsonValue::Number("1")))
          assert_true(
            payload.get("reading_order_index") ==
            Some(@core.JsonValue::Number("2")),
          )
        }
        _ => fail("expected object payload for metadata-only link")
      }
    }
    _ => fail("expected pdf_link_candidates metadata array")
  }
}

///|
test "pdf native unit bridge records repeated header and footer candidates as metadata only" {
  let header_text = "ACME Quarterly Report"
  let footer_text = "Confidential - Internal Use"
  let page1 = make_pdf_native_page(make_pdf_page_geometry(1, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        pdf_test_line(
          header_text,
          40.0,
          760.0,
          width=160.0,
          file_id="hf.pdf",
          page=1,
          line=1,
          reading_order_index=Some(1),
        ),
      ],
      make_pdf_bbox(40.0, 760.0, 160.0, 12.0),
      reading_order_index=Some(1),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Body page one",
          40.0,
          420.0,
          width=120.0,
          file_id="hf.pdf",
          page=1,
          line=2,
          reading_order_index=Some(2),
        ),
      ],
      make_pdf_bbox(40.0, 420.0, 120.0, 12.0),
      reading_order_index=Some(2),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          footer_text,
          40.0,
          18.0,
          width=180.0,
          file_id="hf.pdf",
          page=1,
          line=3,
          reading_order_index=Some(3),
        ),
      ],
      make_pdf_bbox(40.0, 18.0, 180.0, 12.0),
      reading_order_index=Some(3),
    ),
  ])
  let page2 = make_pdf_native_page(make_pdf_page_geometry(2, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        pdf_test_line(
          header_text,
          42.0,
          760.0,
          width=160.0,
          file_id="hf.pdf",
          page=2,
          line=1,
          reading_order_index=Some(1),
        ),
      ],
      make_pdf_bbox(42.0, 760.0, 160.0, 12.0),
      reading_order_index=Some(1),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Body page two",
          40.0,
          420.0,
          width=120.0,
          file_id="hf.pdf",
          page=2,
          line=2,
          reading_order_index=Some(2),
        ),
      ],
      make_pdf_bbox(40.0, 420.0, 120.0, 12.0),
      reading_order_index=Some(2),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          footer_text,
          42.0,
          18.0,
          width=180.0,
          file_id="hf.pdf",
          page=2,
          line=3,
          reading_order_index=Some(3),
        ),
      ],
      make_pdf_bbox(42.0, 18.0, 180.0, 12.0),
      reading_order_index=Some(3),
    ),
  ])
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(pages=[page1, page2]),
  )
  assert_eq(document.blocks.length(), 6)
  assert_eq(document.blocks[0].text, header_text)
  assert_eq(document.blocks[1].text, "Body page one")
  assert_eq(document.blocks[2].text, footer_text)
  assert_eq(document.blocks[3].text, header_text)
  assert_eq(document.blocks[4].text, "Body page two")
  assert_eq(document.blocks[5].text, footer_text)
  assert_true(
    document.metadata.get("pdf_header_footer_candidate_strategy") ==
    Some(@core.JsonValue::String("conservative_v1")),
  )
  assert_true(
    document.metadata.get("pdf_header_candidate_count") ==
    Some(@core.JsonValue::Number("1")),
  )
  assert_true(
    document.metadata.get("pdf_footer_candidate_count") ==
    Some(@core.JsonValue::Number("1")),
  )
  assert_true(
    document.metadata.get("pdf_header_footer_candidate_count") ==
    Some(@core.JsonValue::Number("2")),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_candidate_strategy") ==
    Some("conservative_v1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_candidate_count") == Some("1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_footer_candidate_count") == Some("1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_candidate_count") ==
    Some("2"),
  )
  match document.metadata.get("pdf_header_footer_candidates") {
    Some(@core.JsonValue::Array(items)) => {
      assert_eq(items.length(), 2)
      match items[0] {
        @core.JsonValue::Object(payload) => {
          assert_true(
            payload.get("kind") == Some(@core.JsonValue::String("footer")),
          )
          assert_true(
            payload.get("normalized_text") ==
            Some(@core.JsonValue::String("confidential - internal use")),
          )
          assert_true(
            payload.get("page_count") == Some(@core.JsonValue::Number("2")),
          )
          assert_true(
            payload.get("confidence") == Some(@core.JsonValue::String("high")),
          )
          assert_true(
            payload.get("reason") ==
            Some(@core.JsonValue::String("repeated_bottom_band")),
          )
        }
        _ => fail("expected footer candidate object")
      }
      match items[1] {
        @core.JsonValue::Object(payload) => {
          assert_true(
            payload.get("kind") == Some(@core.JsonValue::String("header")),
          )
          assert_true(
            payload.get("normalized_text") ==
            Some(@core.JsonValue::String("acme quarterly report")),
          )
          assert_true(
            payload.get("page_count") == Some(@core.JsonValue::Number("2")),
          )
          assert_true(
            payload.get("reason") ==
            Some(@core.JsonValue::String("repeated_top_band")),
          )
          match payload.get("source_ref") {
            Some(@core.JsonValue::Object(source_ref)) => {
              assert_true(
                source_ref.get("page") == Some(@core.JsonValue::Number("1")),
              )
              assert_true(
                source_ref.get("line_start") ==
                Some(@core.JsonValue::Number("1")),
              )
            }
            _ => fail("expected source_ref object for header candidate")
          }
        }
        _ => fail("expected header candidate object")
      }
    }
    _ => fail("expected header/footer candidate metadata array")
  }

  assert_eq(
    document.blocks.map(block => block.text).join("\n"),
    [
      header_text, "Body page one", footer_text, header_text, "Body page two", footer_text,
    ].join("\n"),
  )
}

///|
test "pdf native unit bridge does not mark single-page or out-of-band repeated lines as header footer candidates" {
  let repeated_text = "Repeated body line"
  let page = make_pdf_native_page(make_pdf_page_geometry(1, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Single page heading",
          40.0,
          760.0,
          file_id="single.pdf",
          page=1,
          line=1,
          reading_order_index=Some(1),
        ),
      ],
      make_pdf_bbox(40.0, 760.0, 140.0, 12.0),
      reading_order_index=Some(1),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          repeated_text,
          40.0,
          420.0,
          file_id="single.pdf",
          page=1,
          line=2,
          reading_order_index=Some(2),
        ),
      ],
      make_pdf_bbox(40.0, 420.0, 140.0, 12.0),
      reading_order_index=Some(2),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          repeated_text,
          40.0,
          438.0,
          file_id="single.pdf",
          page=1,
          line=3,
          reading_order_index=Some(3),
        ),
      ],
      make_pdf_bbox(40.0, 438.0, 140.0, 12.0),
      reading_order_index=Some(3),
    ),
  ])
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(pages=[page]),
  )
  assert_true(
    document.metadata.get("pdf_header_candidate_count") ==
    Some(@core.JsonValue::Number("0")),
  )
  assert_true(
    document.metadata.get("pdf_footer_candidate_count") ==
    Some(@core.JsonValue::Number("0")),
  )
  assert_true(
    document.metadata.get("pdf_header_footer_candidate_count") ==
    Some(@core.JsonValue::Number("0")),
  )
  assert_true(document.metadata.get("pdf_header_footer_candidates") == None)
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_candidate_count") ==
    Some("0"),
  )
  assert_true(
    document.blocks.map(block => block.text).join("\n").contains(repeated_text),
  )
}

///|
test "pdf native unit bridge records skipped header footer candidate diagnostics when page geometry is unavailable" {
  let page1 = make_pdf_native_page(make_pdf_page_geometry(1, 0.0, 0.0), text_blocks=[
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Maybe header",
          40.0,
          10.0,
          file_id="nogeo.pdf",
          page=1,
          line=1,
          reading_order_index=Some(1),
        ),
      ],
      make_pdf_bbox(40.0, 10.0, 100.0, 12.0),
      reading_order_index=Some(1),
    ),
  ])
  let page2 = make_pdf_native_page(make_pdf_page_geometry(2, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Maybe header",
          40.0,
          760.0,
          file_id="nogeo.pdf",
          page=2,
          line=1,
          reading_order_index=Some(1),
        ),
      ],
      make_pdf_bbox(40.0, 760.0, 100.0, 12.0),
      reading_order_index=Some(1),
    ),
  ])
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(pages=[page1, page2]),
  )
  assert_true(
    document.metadata.get("pdf_header_footer_candidate_strategy") ==
    Some(@core.JsonValue::String("conservative_v1")),
  )
  assert_true(
    document.metadata.get("pdf_header_footer_candidate_count") ==
    Some(@core.JsonValue::Number("0")),
  )
  assert_true(document.metadata.get("pdf_header_footer_candidates") == None)
  assert_true(
    document.diagnostics.metrics.get("pdf_header_footer_candidate_skipped") ==
    Some("no_page_geometry"),
  )
}

///|
test "pdf native unit bridge records conservative table candidates as metadata only" {
  let header = make_pdf_native_text_line(
    [
      make_pdf_native_text_span(
        "Product",
        make_pdf_bbox(40.0, 620.0, 40.0, 12.0),
      ),
      make_pdf_native_text_span(
        " Region",
        make_pdf_bbox(120.0, 620.0, 40.0, 12.0),
      ),
      make_pdf_native_text_span(
        " Status",
        make_pdf_bbox(220.0, 620.0, 40.0, 12.0),
      ),
    ],
    make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
    source_ref=Some(
      pdf_test_source_ref(
        "table-candidates.pdf",
        1,
        1,
        pdf_test_core_bbox(40.0, 620.0, 260.0, 632.0),
      ),
    ),
    reading_order_index=Some(1),
  )
  let row1 = make_pdf_native_text_line(
    [
      make_pdf_native_text_span("Alpha", make_pdf_bbox(40.0, 602.0, 40.0, 12.0)),
      make_pdf_native_text_span(
        " East",
        make_pdf_bbox(120.0, 602.0, 36.0, 12.0),
      ),
      make_pdf_native_text_span(
        " Open",
        make_pdf_bbox(220.0, 602.0, 36.0, 12.0),
      ),
    ],
    make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
    source_ref=Some(
      pdf_test_source_ref(
        "table-candidates.pdf",
        1,
        2,
        pdf_test_core_bbox(40.0, 602.0, 256.0, 614.0),
      ),
    ),
    reading_order_index=Some(2),
  )
  let row2 = make_pdf_native_text_line(
    [
      make_pdf_native_text_span("Beta", make_pdf_bbox(40.0, 584.0, 36.0, 12.0)),
      make_pdf_native_text_span(
        " West",
        make_pdf_bbox(120.0, 584.0, 36.0, 12.0),
      ),
      make_pdf_native_text_span(
        " Closed",
        make_pdf_bbox(220.0, 584.0, 52.0, 12.0),
      ),
    ],
    make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
    source_ref=Some(
      pdf_test_source_ref(
        "table-candidates.pdf",
        1,
        3,
        pdf_test_core_bbox(40.0, 584.0, 272.0, 596.0),
      ),
    ),
    reading_order_index=Some(3),
  )
  let paragraph = pdf_test_line(
    "Body paragraph remains unchanged",
    40.0,
    520.0,
    width=180.0,
    file_id="table-candidates.pdf",
    page=1,
    line=4,
    reading_order_index=Some(4),
  )
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(pages=[
      make_pdf_native_page(make_pdf_page_geometry(1, 612.0, 792.0), text_blocks=[
        make_pdf_native_text_block(
          [header],
          make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
          reading_order_index=Some(1),
        ),
        make_pdf_native_text_block(
          [row1],
          make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
          reading_order_index=Some(2),
        ),
        make_pdf_native_text_block(
          [row2],
          make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
          reading_order_index=Some(3),
        ),
        make_pdf_native_text_block(
          [paragraph],
          make_pdf_bbox(40.0, 520.0, 180.0, 12.0),
          reading_order_index=Some(4),
        ),
      ]),
    ]),
  )
  assert_eq(document.blocks.length(), 4)
  assert_eq(document.blocks[0].text, "Product Region Status")
  assert_eq(document.blocks[1].text, "Alpha East Open")
  assert_eq(document.blocks[2].text, "Beta West Closed")
  assert_eq(document.blocks[3].text, "Body paragraph remains unchanged")
  assert_true(
    document.metadata.get("pdf_table_candidate_strategy") ==
    Some(@core.JsonValue::String("conservative_v1")),
  )
  assert_true(
    document.metadata.get("pdf_table_candidate_count") ==
    Some(@core.JsonValue::Number("1")),
  )
  assert_true(
    document.metadata.get("pdf_table_row_candidate_count") ==
    Some(@core.JsonValue::Number("3")),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_candidate_strategy") ==
    Some("conservative_v1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_candidate_count") == Some("1"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_row_candidate_count") ==
    Some("3"),
  )
  match document.metadata.get("pdf_table_candidates") {
    Some(@core.JsonValue::Array(items)) => {
      assert_eq(items.length(), 1)
      match items[0] {
        @core.JsonValue::Object(payload) => {
          assert_true(payload.get("page") == Some(@core.JsonValue::Number("1")))
          assert_true(
            payload.get("row_count") == Some(@core.JsonValue::Number("3")),
          )
          assert_true(
            payload.get("column_alignment_count") ==
            Some(@core.JsonValue::Number("3")),
          )
          assert_true(
            payload.get("confidence") == Some(@core.JsonValue::String("high")),
          )
          assert_true(
            payload.get("reason") ==
            Some(@core.JsonValue::String("repeated_column_alignment")),
          )
          assert_true(
            payload.get("line_start") == Some(@core.JsonValue::Number("1")),
          )
          assert_true(
            payload.get("line_end") == Some(@core.JsonValue::Number("3")),
          )
          match payload.get("source_refs") {
            Some(@core.JsonValue::Array(source_refs)) =>
              assert_eq(source_refs.length(), 3)
            _ => fail("expected source_refs array")
          }
          match payload.get("reading_order_indices") {
            Some(@core.JsonValue::Array(indices)) => {
              assert_eq(indices.length(), 3)
              assert_true(indices[0] == @core.JsonValue::Number("1"))
            }
            _ => fail("expected reading order indices")
          }
        }
        _ => fail("expected table candidate object")
      }
    }
    _ => fail("expected metadata-only table candidate array")
  }
}

///|
test "pdf native unit bridge does not mark bullets single-row key-value or header footer lines as table candidates" {
  let page1 = make_pdf_native_page(make_pdf_page_geometry(1, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Repeated Header",
          40.0,
          760.0,
          file_id="table-negative.pdf",
          page=1,
          line=1,
          reading_order_index=Some(1),
        ),
      ],
      make_pdf_bbox(40.0, 760.0, 120.0, 12.0),
      reading_order_index=Some(1),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "- bullet item",
          40.0,
          620.0,
          file_id="table-negative.pdf",
          page=1,
          line=2,
          reading_order_index=Some(2),
        ),
      ],
      make_pdf_bbox(40.0, 620.0, 100.0, 12.0),
      reading_order_index=Some(2),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Owner  Alice",
          40.0,
          602.0,
          file_id="table-negative.pdf",
          page=1,
          line=3,
          reading_order_index=Some(3),
        ),
      ],
      make_pdf_bbox(40.0, 602.0, 100.0, 12.0),
      reading_order_index=Some(3),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Body paragraph line",
          40.0,
          584.0,
          file_id="table-negative.pdf",
          page=1,
          line=4,
          reading_order_index=Some(4),
        ),
      ],
      make_pdf_bbox(40.0, 584.0, 120.0, 12.0),
      reading_order_index=Some(4),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Repeated Footer",
          40.0,
          18.0,
          file_id="table-negative.pdf",
          page=1,
          line=5,
          reading_order_index=Some(5),
        ),
      ],
      make_pdf_bbox(40.0, 18.0, 120.0, 12.0),
      reading_order_index=Some(5),
    ),
  ])
  let page2 = make_pdf_native_page(make_pdf_page_geometry(2, 612.0, 792.0), text_blocks=[
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Repeated Header",
          42.0,
          760.0,
          file_id="table-negative.pdf",
          page=2,
          line=1,
          reading_order_index=Some(1),
        ),
      ],
      make_pdf_bbox(42.0, 760.0, 120.0, 12.0),
      reading_order_index=Some(1),
    ),
    make_pdf_native_text_block(
      [
        pdf_test_line(
          "Repeated Footer",
          42.0,
          18.0,
          file_id="table-negative.pdf",
          page=2,
          line=2,
          reading_order_index=Some(2),
        ),
      ],
      make_pdf_bbox(42.0, 18.0, 120.0, 12.0),
      reading_order_index=Some(2),
    ),
  ])
  let document = pdf_native_document_to_ir(
    make_pdf_native_document(pages=[page1, page2]),
  )
  assert_true(
    document.metadata.get("pdf_table_candidate_strategy") ==
    Some(@core.JsonValue::String("conservative_v1")),
  )
  assert_true(
    document.metadata.get("pdf_table_candidate_count") ==
    Some(@core.JsonValue::Number("0")),
  )
  assert_true(
    document.metadata.get("pdf_table_row_candidate_count") ==
    Some(@core.JsonValue::Number("0")),
  )
  assert_true(document.metadata.get("pdf_table_candidates") == None)
  assert_true(
    document.diagnostics.metrics.get("pdf_table_candidate_count") == Some("0"),
  )
  assert_true(
    document.diagnostics.metrics.get("pdf_table_row_candidate_count") ==
    Some("0"),
  )
  assert_true(
    document.blocks.map(block => block.text).contains("- bullet item"),
  )
  assert_true(document.blocks.map(block => block.text).contains("Owner  Alice"))
  assert_true(
    document.blocks.map(block => block.text).contains("Repeated Header"),
  )
  assert_true(
    document.blocks.map(block => block.text).contains("Repeated Footer"),
  )
}
