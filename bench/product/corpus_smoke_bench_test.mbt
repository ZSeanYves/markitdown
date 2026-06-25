///|
test "product.corpus.smoke.convert_all" (b : @bench.T) {
  let rows = @shared.product_smoke_rows()
  if rows.length() == 0 {
    fail("expected product smoke rows")
  }
  for row in rows {
    let name = "product.corpus.smoke/" + row.bench_id
    b.bench(name~, fn() {
      let result = match
        @convert.convert_input(
          @shared.bench_row_input_source(row),
          @shared.bench_row_default_convert_options(row),
        ) {
        Ok(value) => value
        Err(err) =>
          abort(
            "product convert failed: " + row.bench_id + " :: " + err.to_string(),
          )
      }
      @shared.keep_string(b, result.content)
    })
  }
}
