///|
test "native process measurement reports isolated positive RSS" {
  let argv = ["/bin/sleep", "0.05"]
  let argv_blob = encode_c_string_blob(argv)
  let env_blob = encode_c_string_blob([])
  let measured = native_measure_command(
    make_native_measure_spec(
      argv_blob,
      argv_blob.length(),
      argv.length(),
      env_blob,
      env_blob.length(),
      0,
      "/dev/null",
      "/dev/null",
      None,
      10_000L,
    ),
  )
  assert_eq(measured.status, 0)
  assert_eq(measured.data.exit_code, 0)
  assert_true(!measured.data.measurement_error)
  assert_true(measured.data.wall_us > 0L)
  assert_true(measured.data.peak_rss_kb > 0L)
}
