///|
pub fn moonbit_engine_tool() -> BenchTool {
  {
    name: "moonbit-engine",
    tool_version: Some("markitdown-mb/inprocess"),
    availability_note: None,
    command_builder: fn(row, output_path, timeout_ms) {
      ignore(row)
      ignore(timeout_ms)
      {
        program: "moonbit-engine",
        args: ["<input>", output_path],
        cwd: None,
        env: [],
        timeout_ms,
        command_kind: "engine-baseline",
        command_display: "convert_input <input> " + output_path,
      }
    },
  }
}
