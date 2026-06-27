///|
pub fn moonbit_cli_tool() -> BenchTool {
  let built_path = "_build/native/release/build/cli/cli.exe"
  if @fs.path_exists(built_path) {
    return {
      name: "moonbit-cli",
      tool_version: Some("markitdown-mb"),
      availability_note: None,
      command_builder: fn(
        row,
        output_path,
        timeout_ms,
        cli_output_mode,
        _engine_output_mode,
      ) {
        build_moonbit_cli_command(
          built_path, row, output_path, timeout_ms, cli_output_mode,
        )
      },
    }
  }
  {
    name: "moonbit-cli",
    tool_version: Some("markitdown-mb"),
    availability_note: Some(
      "release cli.exe missing; formal benchmark requires _build/native/release/build/cli/cli.exe",
    ),
    command_builder: fn(
      _row,
      output_path,
      timeout_ms,
      cli_output_mode,
      _engine_output_mode,
    ) {
      ignore(timeout_ms)
      ignore(cli_output_mode)
      {
        program: built_path,
        args: ["normal", "<input>", output_path],
        cwd: None,
        env: [],
        timeout_ms,
        command_kind: "cli-baseline",
        command_display: built_path + " normal <input> " + output_path,
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
  cli_output_mode : @command.CliOutputMode,
) -> ToolCommand {
  let args : Array[String] = ["normal", row.input_path]
  let command_display = match cli_output_mode {
    @command.CliOutputMode::File => {
      args.push(output_path)
      program + " normal " + row.input_path + " " + output_path
    }
    @command.CliOutputMode::StdoutCapture =>
      program + " normal " + row.input_path
  }
  {
    program,
    args,
    cwd: None,
    env: [],
    timeout_ms,
    command_kind: "cli-baseline",
    command_display,
  }
}
