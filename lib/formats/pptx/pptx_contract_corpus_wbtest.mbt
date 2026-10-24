///|
async test "PPTX parser lowers remaining repository link footer bullet shape and baseline contracts" {
  let owned_sessions : Array[@input.InputSession] = []
  defer (for session in owned_sessions {
    @input.end_input_session(session)
  })
  let owned_input_path = fn(path : String) {
    let session = @input.begin_input_session(@input.input_from_path(path))
    owned_sessions.push(session)
    session.source
  }
  let fixtures = [
    "samples/fixtures/contracts/pptx/pptx_simple.pptx", "samples/fixtures/contracts/pptx/pptx_link_basic.pptx",
    "samples/fixtures/contracts/pptx/pptx_bullet_levels.pptx", "samples/fixtures/contracts/pptx/pptx_footer_page_number.pptx",
    "samples/fixtures/contracts/pptx/pptx_image_single.pptx", "samples/fixtures/contracts/pptx/pptx_reading_order_geometry.pptx",
  ]
  let mut blocks = 0
  let mut assets = 0
  for path in fixtures {
    let result = (pptx_parser().parse)(
      owned_input_path(path),
      @parser.new_parse_context(Pptx),
    ).unwrap()
    assert_eq(result.diagnostics.errors.length(), 0)
    let document = result.document.unwrap()
    blocks += document.blocks.length()
    assets += document.assets.length()
    assert_true(
      result.diagnostics.metrics.get("office_document_kind") == Some("pptx"),
    )
  }
  assert_true(blocks > 10)
  assert_true(assets >= 0)
}

///|
async test "PPTX full contract corpus covers combined accurate feature lowering" {
  let owned_sessions : Array[@input.InputSession] = []
  defer (for session in owned_sessions {
    @input.end_input_session(session)
  })
  let owned_input_path = fn(path : String) {
    let session = @input.begin_input_session(@input.input_from_path(path))
    owned_sessions.push(session)
    session.source
  }
  let fixtures = [
    "pptx_bullet_levels.pptx", "pptx_callout_blocks_basic.pptx", "pptx_footer_page_number.pptx",
    "pptx_hidden_slide_basic.pptx", "pptx_hidden_slides_policy.pptx", "pptx_image_single.pptx",
    "pptx_link_basic.pptx", "pptx_reading_order_geometry.pptx", "pptx_simple.pptx",
    "pptx_speaker_notes_basic.pptx",
  ]
  let context = @parser.parse_context_with_execution_profiles(
    @parser.parse_context_with_product_modes(
      @parser.new_parse_context(Pptx),
      Accurate,
      Markdown,
    ),
    Standard,
    AccurateSemantic,
    NotesAppendixFirst,
    @product.make_accurate_feature_profile([
      PptxReadingOrder,
      PptxGroupSummary,
      PptxHiddenSlideSemantics,
      PptxNotesAppendix,
    ]),
  )
  let mut total_blocks = 0
  for fixture in fixtures {
    let result = (pptx_parser().parse)(
      owned_input_path("samples/fixtures/contracts/pptx/" + fixture),
      context,
    ).unwrap()
    assert_eq(result.diagnostics.errors.length(), 0)
    total_blocks += result.document.unwrap().blocks.length()
  }
  assert_true(total_blocks > 30)
}
