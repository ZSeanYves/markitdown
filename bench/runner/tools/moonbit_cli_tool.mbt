///|
pub fn moonbit_cli_tool() -> BenchTool {
  let built_path = "_build/native/release/build/cli/cli.exe"
  if @fs.path_exists(built_path) {
    return {
      name: "moonbit-cli",
      tool_version: Some("markitdown-mb"),
      availability_note: None,
      command_builder: fn(row, output_path, timeout_ms) {
        build_moonbit_cli_command(built_path, row, output_path, timeout_ms)
      },
    }
  }
  {
    name: "moonbit-cli",
    tool_version: Some("markitdown-mb"),
    availability_note: Some(
      "release cli.exe missing; formal benchmark requires _build/native/release/build/cli/cli.exe",
    ),
    command_builder: fn(_row, output_path, timeout_ms) {
      ignore(timeout_ms)
      {
        program: built_path,
        args: ["balance", "<input>", output_path],
        cwd: None,
        env: [],
        timeout_ms,
        command_kind: "cli-baseline",
        command_display: built_path + " balance <input> " + output_path,
      }
    },
  }
}

///|
fn build_moonbit_cli_command(
  program : String,
  row : @manifest.BenchRow,
  output_path : String,
  timeout_ms : Int,
) -> ToolCommand {
  let args : Array[String] = ["balance", row.input_path, output_path]
  {
    program,
    args,
    cwd: None,
    env: [],
    timeout_ms,
    command_kind: "cli-baseline",
    command_display: program + " balance " + row.input_path + " " + output_path,
  }
}
