///|
test "ODS seekable prepare rejects invalid and wrong-kind packages" {
  assert_true(
    prepare_ods_document_from_source(
      @input.input_from_bytes(b"not-a-zip", source_name="invalid.ods"),
    )
    is Err(_),
  )
  assert_true(
    prepare_ods_document_from_source(
      @input.input_from_path(
        "samples/fixtures/contracts/odt/odt_basic_sample.odt",
      ),
    )
    is Err(_),
  )
}
