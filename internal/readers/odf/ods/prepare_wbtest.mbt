///|
async test "ODS seekable prepare rejects invalid and wrong-kind packages" {
  let owned_sessions : Array[@input.InputSession] = []
  defer (for session in owned_sessions {
    @input.end_input_session(session)
  })
  let owned_input_path = fn(path : String) {
    let session = @input.begin_input_session(@input.input_from_path(path))
    owned_sessions.push(session)
    session.source
  }
  assert_true(
    prepare_ods_document_from_source(
      @input.input_from_bytes(b"not-a-zip", source_name="invalid.ods"),
    )
    is Err(_),
  )
  assert_true(
    prepare_ods_document_from_source(
      owned_input_path("samples/fixtures/contracts/odt/odt_basic_sample.odt"),
    )
    is Err(_),
  )
}
