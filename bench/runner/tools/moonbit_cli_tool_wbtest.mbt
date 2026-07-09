///|
fn sample_bench_row() -> @manifest.BenchRow {
  @manifest.make_bench_row(
    "txt_medium_fixture_v1",
    "txt",
    "medium",
    "txt/medium/txt_medium_fixture_v1.txt",
    "fixture",
    "local",
    128,
    "sha",
    "regular",
    ["external_bench"],
    [],
    "reviewed",
    "",
    "/tmp/txt_medium_fixture_v1.txt",
  )
}

///|
test "moonbit cli tool uses balance mode for formal benchmark commands" {
  let command = build_moonbit_cli_command(
    "_build/native/release/build/cli/cli.exe",
    sample_bench_row(),
    ".tmp/out.md",
    60000,
  )
  assert_true(
    command.args == ["balance", "/tmp/txt_medium_fixture_v1.txt", ".tmp/out.md"],
  )
  assert_eq(
    command.command_display,
    "_build/native/release/build/cli/cli.exe balance /tmp/txt_medium_fixture_v1.txt .tmp/out.md",
  )
}
