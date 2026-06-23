///|
test "micro.reader.textlike.smoke" (b : @bench.T) {
  let rows = @shared.micro_textlike_smoke_rows()
  if rows.length() == 0 {
    fail("expected smoke textlike rows")
  }
  for row in rows {
    let name = "micro.reader.textlike.smoke/" + row.format + "/" + row.bench_id
    b.bench(name~, fn() {
      let text = @shared.bench_row_text(row)
      @shared.keep_int(b, text.length())
    })
  }
}
