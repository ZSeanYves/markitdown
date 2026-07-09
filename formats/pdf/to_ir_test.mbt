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
) -> @dpdfnative.PdfNativeTextLine {
  let bbox = @dpdfnative.make_pdf_bbox(x, y, width, height)
  @dpdfnative.make_pdf_native_text_line(
    [@dpdfnative.make_pdf_native_text_span(text, bbox)],
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
fn pdf_test_inline_image_asset(
  file_id : String,
  page : Int,
  bbox : @core.BBox,
  asset_id : String,
) -> @core.AssetRef {
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    asset_id,
    source_ref=pdf_test_source_ref(file_id, page, 1, bbox),
  )
  let next_asset = { ..asset, mime_type: Some("image/jpeg") }
  next_asset.attrs.set("alt", "image")
  next_asset.attrs.set("file_ext", "jpg")
  next_asset.attrs.set("inline_payload_kind", "utf8")
  next_asset.attrs.set("inline_payload", "jpeg-bytes")
  next_asset
}

///|
test "pdf native header footer candidate scan tolerates unicode punctuation" {
  let header_text = "Journal OF Research。"
  let page1 = @dpdfnative.make_pdf_native_page(
    @dpdfnative.make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[
      @dpdfnative.make_pdf_native_text_block(
        [
          pdf_test_line(
            header_text,
            36.0,
            760.0,
            width=160.0,
            file_id="unicode-hf.pdf",
            page=1,
            line=1,
            reading_order_index=Some(1),
          ),
        ],
        @dpdfnative.make_pdf_bbox(36.0, 760.0, 160.0, 12.0),
        reading_order_index=Some(1),
      ),
      @dpdfnative.make_pdf_native_text_block(
        [
          pdf_test_line(
            "Body page one",
            40.0,
            420.0,
            width=100.0,
            file_id="unicode-hf.pdf",
            page=1,
            line=2,
            reading_order_index=Some(2),
          ),
        ],
        @dpdfnative.make_pdf_bbox(40.0, 420.0, 100.0, 12.0),
        reading_order_index=Some(2),
      ),
    ],
  )
  let page2 = @dpdfnative.make_pdf_native_page(
    @dpdfnative.make_pdf_page_geometry(2, 612.0, 792.0),
    text_blocks=[
      @dpdfnative.make_pdf_native_text_block(
        [
          pdf_test_line(
            header_text,
            36.0,
            760.0,
            width=160.0,
            file_id="unicode-hf.pdf",
            page=2,
            line=1,
            reading_order_index=Some(1),
          ),
        ],
        @dpdfnative.make_pdf_bbox(36.0, 760.0, 160.0, 12.0),
        reading_order_index=Some(1),
      ),
      @dpdfnative.make_pdf_native_text_block(
        [
          pdf_test_line(
            "Body page two",
            40.0,
            420.0,
            width=100.0,
            file_id="unicode-hf.pdf",
            page=2,
            line=2,
            reading_order_index=Some(2),
          ),
        ],
        @dpdfnative.make_pdf_bbox(40.0, 420.0, 100.0, 12.0),
        reading_order_index=Some(2),
      ),
    ],
  )
  let document = pdf_native_document_to_ir(
    @dpdfnative.make_pdf_native_document(pages=[page1, page2]),
  )
  assert_true(
    document.metadata.get("pdf_header_footer_candidate_count") ==
    Some(@core.JsonValue::Number("1")),
  )
}

///|
test "pdf native unit bridge lowers paragraphs with source refs and metadata only links" {
  let bbox1 = @dpdfnative.make_pdf_bbox(10.0, 20.0, 80.0, 12.0)
  let bbox2 = @dpdfnative.make_pdf_bbox(10.0, 40.0, 60.0, 12.0)
  let bbox3 = @dpdfnative.make_pdf_bbox(10.0, 60.0, 70.0, 12.0)
  let bbox4 = @dpdfnative.make_pdf_bbox(12.0, 18.0, 30.0, 8.0)
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
  let line1 = @dpdfnative.make_pdf_native_text_line(
    [
      @dpdfnative.make_pdf_native_text_span("Hello", bbox1),
      @dpdfnative.make_pdf_native_text_span(" PDF", bbox1),
    ],
    bbox1,
    source_ref=Some(line1_source),
    reading_order_index=Some(7),
  )
  let empty_line = @dpdfnative.make_pdf_native_text_line(
    [@dpdfnative.make_pdf_native_text_span("   ", bbox2)],
    bbox2,
    reading_order_index=Some(2),
  )
  let line3 = @dpdfnative.make_pdf_native_text_line(
    [@dpdfnative.make_pdf_native_text_span("Second line", bbox3)],
    bbox3,
    reading_order_index=Some(3),
  )
  let page1 = @dpdfnative.make_pdf_native_page(
    @dpdfnative.make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[
      @dpdfnative.make_pdf_native_text_block(
        [line1, empty_line, line3],
        @dpdfnative.make_pdf_bbox(10.0, 20.0, 80.0, 52.0),
        reading_order_index=Some(1),
      ),
    ],
    image_candidates=[@dpdfnative.make_pdf_native_image_candidate(bbox1)],
    link_candidates=[
      @dpdfnative.make_pdf_native_link_candidate(
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
    table_candidates=[
      @dpdfnative.make_pdf_native_table_candidate(bbox2, row_count=Some(2)),
    ],
    artifact_candidates=[
      @dpdfnative.make_pdf_native_artifact_candidate("header_candidate", bbox4),
    ],
  )
  let page2 = @dpdfnative.make_pdf_native_page(
    @dpdfnative.make_pdf_page_geometry(2, 612.0, 792.0),
    text_blocks=[
      @dpdfnative.make_pdf_native_text_block(
        [
          @dpdfnative.make_pdf_native_text_line(
            [@dpdfnative.make_pdf_native_text_span("Page 2 line", bbox1)],
            bbox1,
          ),
        ],
        bbox1,
      ),
    ],
  )
  let document = pdf_native_document_to_ir(
    @dpdfnative.make_pdf_native_document(pages=[page1, page2]),
  )
  assert_eq(document.blocks.length(), 2)
  assert_eq(document.blocks[0].text, "Hello PDF Second line")
  assert_eq(document.blocks[1].text, "Page 2 line")
  let first_ref = document.blocks[0].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(first_ref.file_id == Some("synthetic.pdf"))
  assert_true(first_ref.page == Some(1))
  assert_true(first_ref.line_start == Some(7))
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
  match document.metadata.get("pdf_link_candidates") {
    Some(@core.JsonValue::Array(items)) => {
      assert_eq(items.length(), 1)
      match items[0] {
        @core.JsonValue::Object(payload) =>
          assert_true(
            payload.get("href") ==
            Some(@core.JsonValue::String("https://example.com")),
          )
        _ => fail("expected link candidate object")
      }
    }
    _ => fail("expected link candidate metadata array")
  }
}

///|
test "pdf native unit bridge lowers exportable image candidates into assets" {
  let bbox = @dpdfnative.make_pdf_bbox(24.0, 36.0, 32.0, 24.0)
  let asset = pdf_test_inline_image_asset(
    "image-only.pdf",
    1,
    pdf_test_core_bbox(24.0, 36.0, 56.0, 60.0),
    "pdf:17",
  )
  let page = @dpdfnative.make_pdf_native_page(
    @dpdfnative.make_pdf_page_geometry(1, 200.0, 200.0),
    image_candidates=[
      @dpdfnative.make_pdf_native_image_candidate(
        bbox,
        source_ref=Some(
          @core.source_ref_with_extra(
            pdf_test_source_ref(
              "image-only.pdf",
              1,
              1,
              pdf_test_core_bbox(24.0, 36.0, 56.0, 60.0),
            ),
            "pdf_object_id",
            "17",
          ),
        ),
        asset_ref=Some(asset),
      ),
    ],
  )
  let document = pdf_native_document_to_ir(
    @dpdfnative.make_pdf_native_document(pages=[page]),
  )
  assert_eq(document.blocks.length(), 1)
  assert_true(document.blocks[0].kind == @core.BlockKind::Image)
  assert_true(
    document.blocks[0].attrs.get("path") == Some("assets/image01.jpg"),
  )
  assert_true(document.assets.length() == 1)
  assert_true(document.assets[0].asset_id == "pdf:17")
  assert_true(document.assets[0].mime_type == Some("image/jpeg"))
}

///|
test "pdf native unit bridge records repeated header and footer candidates as metadata only" {
  let header_text = "ACME Quarterly Report"
  let footer_text = "Confidential - Internal Use"
  let page1 = @dpdfnative.make_pdf_native_page(
    @dpdfnative.make_pdf_page_geometry(1, 612.0, 792.0),
    text_blocks=[
      @dpdfnative.make_pdf_native_text_block(
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
        @dpdfnative.make_pdf_bbox(40.0, 760.0, 160.0, 12.0),
        reading_order_index=Some(1),
      ),
      @dpdfnative.make_pdf_native_text_block(
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
        @dpdfnative.make_pdf_bbox(40.0, 420.0, 120.0, 12.0),
        reading_order_index=Some(2),
      ),
      @dpdfnative.make_pdf_native_text_block(
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
        @dpdfnative.make_pdf_bbox(40.0, 18.0, 180.0, 12.0),
        reading_order_index=Some(3),
      ),
    ],
  )
  let page2 = @dpdfnative.make_pdf_native_page(
    @dpdfnative.make_pdf_page_geometry(2, 612.0, 792.0),
    text_blocks=[
      @dpdfnative.make_pdf_native_text_block(
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
        @dpdfnative.make_pdf_bbox(42.0, 760.0, 160.0, 12.0),
        reading_order_index=Some(1),
      ),
      @dpdfnative.make_pdf_native_text_block(
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
        @dpdfnative.make_pdf_bbox(40.0, 420.0, 120.0, 12.0),
        reading_order_index=Some(2),
      ),
      @dpdfnative.make_pdf_native_text_block(
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
        @dpdfnative.make_pdf_bbox(42.0, 18.0, 180.0, 12.0),
        reading_order_index=Some(3),
      ),
    ],
  )
  let document = pdf_native_document_to_ir(
    @dpdfnative.make_pdf_native_document(pages=[page1, page2]),
  )
  assert_eq(document.blocks.length(), 6)
  assert_true(
    document.metadata.get("pdf_header_footer_candidate_count") ==
    Some(@core.JsonValue::Number("2")),
  )
  match document.metadata.get("pdf_header_footer_candidates") {
    Some(@core.JsonValue::Array(items)) => assert_eq(items.length(), 2)
    _ => fail("expected header/footer candidate metadata array")
  }
}

///|
test "pdf native unit bridge records conservative table candidates as metadata only" {
  let header = @dpdfnative.make_pdf_native_text_line(
    [
      @dpdfnative.make_pdf_native_text_span(
        "Product",
        @dpdfnative.make_pdf_bbox(40.0, 620.0, 40.0, 12.0),
      ),
      @dpdfnative.make_pdf_native_text_span(
        " Region",
        @dpdfnative.make_pdf_bbox(120.0, 620.0, 40.0, 12.0),
      ),
      @dpdfnative.make_pdf_native_text_span(
        " Status",
        @dpdfnative.make_pdf_bbox(220.0, 620.0, 40.0, 12.0),
      ),
    ],
    @dpdfnative.make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
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
  let row1 = @dpdfnative.make_pdf_native_text_line(
    [
      @dpdfnative.make_pdf_native_text_span(
        "Alpha",
        @dpdfnative.make_pdf_bbox(40.0, 602.0, 40.0, 12.0),
      ),
      @dpdfnative.make_pdf_native_text_span(
        " East",
        @dpdfnative.make_pdf_bbox(120.0, 602.0, 36.0, 12.0),
      ),
      @dpdfnative.make_pdf_native_text_span(
        " Open",
        @dpdfnative.make_pdf_bbox(220.0, 602.0, 36.0, 12.0),
      ),
    ],
    @dpdfnative.make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
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
  let row2 = @dpdfnative.make_pdf_native_text_line(
    [
      @dpdfnative.make_pdf_native_text_span(
        "Beta",
        @dpdfnative.make_pdf_bbox(40.0, 584.0, 36.0, 12.0),
      ),
      @dpdfnative.make_pdf_native_text_span(
        " West",
        @dpdfnative.make_pdf_bbox(120.0, 584.0, 36.0, 12.0),
      ),
      @dpdfnative.make_pdf_native_text_span(
        " Closed",
        @dpdfnative.make_pdf_bbox(220.0, 584.0, 52.0, 12.0),
      ),
    ],
    @dpdfnative.make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
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
    @dpdfnative.make_pdf_native_document(pages=[
      @dpdfnative.make_pdf_native_page(
        @dpdfnative.make_pdf_page_geometry(1, 612.0, 792.0),
        text_blocks=[
          @dpdfnative.make_pdf_native_text_block(
            [header],
            @dpdfnative.make_pdf_bbox(40.0, 620.0, 220.0, 12.0),
            reading_order_index=Some(1),
          ),
          @dpdfnative.make_pdf_native_text_block(
            [row1],
            @dpdfnative.make_pdf_bbox(40.0, 602.0, 216.0, 12.0),
            reading_order_index=Some(2),
          ),
          @dpdfnative.make_pdf_native_text_block(
            [row2],
            @dpdfnative.make_pdf_bbox(40.0, 584.0, 232.0, 12.0),
            reading_order_index=Some(3),
          ),
          @dpdfnative.make_pdf_native_text_block(
            [paragraph],
            @dpdfnative.make_pdf_bbox(40.0, 520.0, 180.0, 12.0),
            reading_order_index=Some(4),
          ),
        ],
      ),
    ]),
  )
  assert_eq(document.blocks.length(), 4)
  assert_eq(document.blocks[0].text, "Product Region Status")
  assert_eq(document.blocks[3].text, "Body paragraph remains unchanged")
  assert_true(
    document.metadata.get("pdf_table_candidate_count") ==
    Some(@core.JsonValue::Number("1")),
  )
  match document.metadata.get("pdf_table_candidates") {
    Some(@core.JsonValue::Array(items)) => {
      assert_eq(items.length(), 1)
      match items[0] {
        @core.JsonValue::Object(payload) =>
          assert_true(
            payload.get("row_count") == Some(@core.JsonValue::Number("3")),
          )
        _ => fail("expected table candidate object")
      }
    }
    _ => fail("expected metadata-only table candidate array")
  }
}
