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
      "built CLI binary missing; run `moon build cli --target native --release`",
    ),
    command_builder: fn(
      row,
      output_path,
      timeout_ms,
      cli_output_mode,
      _engine_output_mode,
    ) {
      build_moonbit_cli_command(
        "moon", row, output_path, timeout_ms, cli_output_mode,
      )
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
  let is_built_binary = program != "moon"
  let base_args = if is_built_binary {
    ["normal", row.input_path]
  } else {
    [
      "run",
      "cli",
      "--target",
      "native",
      "--release",
      "--",
      "normal",
      row.input_path,
    ]
  }
  let args = base_args.copy()
  let command_display = match cli_output_mode {
    @command.CliOutputMode::File => {
      args.push(output_path)
      if is_built_binary {
        program + " normal " + row.input_path + " " + output_path
      } else {
        "moon run cli --target native --release -- normal <input> <output>"
      }
    }
    @command.CliOutputMode::StdoutCapture =>
      if is_built_binary {
        program + " normal " + row.input_path
      } else {
        "moon run cli --target native --release -- normal <input>"
      }
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
