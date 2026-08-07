///|
fn monotonic_start() -> @bench.Timestamp {
  @bench.monotonic_clock_start()
}

///|
fn monotonic_elapsed_us(started : @bench.Timestamp) -> Double {
  @bench.monotonic_clock_end(started)
}
