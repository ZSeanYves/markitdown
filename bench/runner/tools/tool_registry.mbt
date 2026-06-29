///|
pub struct ToolCommand {
  program : String
  args : Array[String]
  cwd : String?
  env : Array[(String, String)]
  timeout_ms : Int
  command_kind : String
  command_display : String
} derive(Eq)

///|
pub struct BenchTool {
  name : String
  tool_version : String?
  availability_note : String?
  command_builder : (@manifest.BenchRow, String, Int) -> ToolCommand
}

///|
pub struct ToolRegistryConfig {
  markitdown_path : String?
} derive(Eq)

///|
pub fn BenchTool::is_available(self : BenchTool) -> Bool {
  self.availability_note is None
}

///|
pub fn BenchTool::build_command(
  self : BenchTool,
  row : @manifest.BenchRow,
  output_path : String,
  timeout_ms : Int,
) -> ToolCommand {
  (self.command_builder)(row, output_path, timeout_ms)
}

///|
pub fn make_tool_command(
  program : String,
  args : Array[String],
  cwd : String?,
  env : Array[(String, String)],
  timeout_ms : Int,
  command_kind : String,
  command_display : String,
) -> ToolCommand {
  { program, args, cwd, env, timeout_ms, command_kind, command_display }
}

///|
pub fn default_tool_registry_config() -> ToolRegistryConfig {
  { markitdown_path: None }
}

///|
pub fn make_tool_registry_config(
  markitdown_path : String?,
) -> ToolRegistryConfig {
  { markitdown_path, }
}

///|
pub fn find_tool(
  name : String,
  config? : ToolRegistryConfig = default_tool_registry_config(),
) -> BenchTool? {
  match name.trim().to_lower() {
    "moonbit-cli" => Some(moonbit_cli_tool())
    "moonbit-engine" => Some(moonbit_engine_tool())
    "markitdown" => Some(markitdown_tool(explicit_path=config.markitdown_path))
    _ => None
  }
}
