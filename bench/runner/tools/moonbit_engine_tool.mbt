///|
pub fn moonbit_engine_tool() -> BenchTool {
  {
    name: "moonbit-engine",
    tool_version: Some("markitdown-mb/inprocess"),
    availability_note: None,
    command_builder: fn(
      row,
      output_path,
      timeout_ms,
      _cli_output_mode,
      engine_output_mode,
    ) {
      ignore(row)
      ignore(timeout_ms)
      let mode = @command.engine_output_mode_name(engine_output_mode)
      {
        program: "moonbit-engine",
        args: ["<input>", output_path],
        cwd: None,
        env: [],
        timeout_ms,
        command_kind: "engine-baseline",
        command_display: "convert_input <input> " +
        output_path +
        " [" +
        mode +
        "]",
      }
    },
  }
}
