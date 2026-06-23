///|
test "micro.detector.smoke_formats" (b : @bench.T) {
  let rows = @shared.micro_detector_smoke_rows()
  if rows.length() == 0 {
    fail("expected smoke micro rows")
  }
  for row in rows {
    let name = "micro.detector.smoke_formats/" + row.format + "/" + row.bench_id
    b.bench(name~, fn() {
      let detected = @input.detect_format(
        @input.input_from_path(@shared.bench_row_payload_path(row)),
      )
      @shared.keep_string(b, @input.detected_format_name(detected.format))
    })
  }
}
