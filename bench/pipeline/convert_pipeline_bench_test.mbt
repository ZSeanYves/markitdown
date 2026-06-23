///|
test "pipeline.convert_total.smoke_textlike" (b : @bench.T) {
  let rows = @shared.pipeline_smoke_textlike_rows()
  if rows.length() == 0 {
    fail("expected pipeline smoke textlike rows")
  }
  for row in rows {
    let name = "pipeline.convert_total.smoke/" + row.format + "/" + row.bench_id
    b.bench(name~, fn() {
      let result = match
        @convert.convert_input(
          @shared.bench_row_input_source(row),
          @shared.bench_row_default_convert_options(row),
        ) {
        Ok(value) => value
        Err(err) =>
          abort(
            "pipeline convert failed: " +
            row.bench_id +
            " :: " +
            err.to_string(),
          )
      }
      @shared.keep_string(b, result.content)
    })
  }
}

///|
test "pipeline.convert_total.smoke_office_pdf_container" (b : @bench.T) {
  let rows = @shared.pipeline_smoke_binary_rows()
  if rows.length() == 0 {
    fail("expected pipeline smoke binary rows")
  }
  for row in rows {
    let name = "pipeline.convert_total.smoke/" + row.format + "/" + row.bench_id
    b.bench(name~, fn() {
      let result = match
        @convert.convert_input(
          @shared.bench_row_input_source(row),
          @shared.bench_row_default_convert_options(row),
        ) {
        Ok(value) => value
        Err(err) =>
          abort(
            "pipeline convert failed: " +
            row.bench_id +
            " :: " +
            err.to_string(),
          )
      }
      @shared.keep_string(b, result.content)
    })
  }
}
