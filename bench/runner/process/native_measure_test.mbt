///|
fn test_tmp_output_path(name : String) -> String {
  let base = ".tmp/tests/bench/native-measure"
  ensure_test_dir_tree(base)
  base + "/" + name
}

///|
fn ensure_test_dir_tree(path : String) -> Unit {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." || @syncfs.path_exists(normalized) {
    return
  }
  let parts = normalized.split("/")
  let mut current = if normalized.has_prefix("/") { "/" } else { "" }
  for raw in parts {
    let part = raw.trim().to_owned()
    if part == "" || part == "." {
      continue
    }
    if current == "" || current == "/" {
      current = if current == "/" { "/" + part } else { part }
    } else {
      current = current + "/" + part
    }
    if !@syncfs.path_exists(current) {
      @syncfs.create_dir(current) catch {
        _ => ()
      }
    }
  }
}

///|
fn make_process_command(
  program : String,
  args : Array[String],
  cwd : String?,
) -> @tools.ToolCommand {
  @tools.make_tool_command(
    program,
    args,
    cwd,
    [],
    5000,
    "native-measure-test",
    program + " " + args.join(" "),
  )
}

///|
test "native measure succeeds for process true" {
  let command = make_process_command("/usr/bin/true", [], None)
  let root = test_tmp_output_path("true")
  let measured = measure_command(command, root + ".stdout", root + ".stderr")
  assert_eq(measured.data.exit_code, 0)
  assert_true(!measured.data.measurement_error)
  assert_true(!measured.data.timed_out)
  assert_eq(measured.data.spawn_error, 0)
  assert_eq(measured.data.signal, 0)
}

///|
test "native measure reports missing executable without crashing" {
  let command = make_process_command(
    "/definitely/missing/markitdown-bench-command",
    [],
    None,
  )
  let root = test_tmp_output_path("missing")
  let measured = measure_command(command, root + ".stdout", root + ".stderr")
  assert_true(!measured.data.measurement_error)
  assert_true(!measured.data.timed_out)
  assert_eq(measured.data.exit_code, 127)
  assert_true(measured.data.spawn_error > 0)
}

///|
test "native measure reports invalid cwd without crashing" {
  let command = make_process_command(
    "/usr/bin/true",
    [],
    Some("/definitely/missing/markitdown-bench-cwd"),
  )
  let root = test_tmp_output_path("bad-cwd")
  let measured = measure_command(command, root + ".stdout", root + ".stderr")
  assert_true(!measured.data.measurement_error)
  assert_true(!measured.data.timed_out)
  assert_eq(measured.data.exit_code, 125)
  assert_true(measured.data.spawn_error < 0)
}
