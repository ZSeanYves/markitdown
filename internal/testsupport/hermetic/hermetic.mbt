///|
pub fn read_utf8_text(path : String) -> String {
  @fs.read_file_to_string(path, encoding="utf8") catch {
    e => abort("read failed: " + e.to_string())
  }
}

///|
pub fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write failed: " + e.to_string())
  }
}

///|
pub fn ensure_dir_tree(path : String) -> Unit raise {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." {
    return
  }
  if @fs.path_exists(normalized) {
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
    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
pub fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }
  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }
  @fs.remove_dir(path)
}

///|
pub fn cleanup_temp_dir(path : String) -> Unit {
  ignore(
    try remove_dir_recursive(path) |> Ok catch {
      _ => Err(())
    },
  )
}

///|
pub fn recreate_clean_dir(path : String) -> Unit raise {
  cleanup_temp_dir(path)
  ensure_dir_tree(path)
}

///|
pub fn with_env_var(
  name : String,
  value : String,
  body : () -> Unit raise,
) -> Unit raise {
  let previous = @env.get_env_var(name)
  @env.set_env_var(name, value)
  defer (match previous {
    Some(old) => @env.set_env_var(name, old)
    None => @env.unset_env_var(name)
  })
  body()
}

///|
pub fn with_unset_env_var(name : String, body : () -> Unit raise) -> Unit raise {
  let previous = @env.get_env_var(name)
  @env.unset_env_var(name)
  defer (match previous {
    Some(old) => @env.set_env_var(name, old)
    None => ()
  })
  body()
}

///|
#warnings("-deprecated")
pub fn run_process(cmd : String, args : Array[String]) -> Unit raise {
  @async.with_event_loop(_group => {
    let result = @process.collect_output(cmd, args) catch {
      e => abort("process failed: " + e.to_string())
    }
    match result {
      (0, _, _) => ()
      (code, _, _) =>
        abort("process exited with code " + code.to_string() + ": " + cmd)
    }
  }) catch {
    e => fail("process event loop failed: " + e.to_string())
  }
}

///|
pub fn chmod_plus_x(path : String) -> Unit raise {
  run_process("chmod", ["+x", path])
}

///|
pub fn move_path(from : String, to : String) -> Unit raise {
  run_process("mv", [from, to])
}

///|
pub fn remove_file_if_exists(path : String) -> Unit {
  if @fs.path_exists(path) && (@fs.is_file(path) catch { _ => false }) {
    ignore(
      try @fs.remove_file(path) |> Ok catch {
        _ => Err(())
      },
    )
  }
}

///|
pub fn restore_path_if_exists(from : String, to : String) -> Unit {
  if @fs.path_exists(from) {
    ignore(
      try move_path(from, to) |> Ok catch {
        _ => Err(())
      },
    )
  }
}

///|
pub fn restore_text_file(path : String, previous : String?) -> Unit {
  match previous {
    Some(text) =>
      ignore(
        try write_utf8_text(path, text) |> Ok catch {
          _ => Err(())
        },
      )
    None => remove_file_if_exists(path)
  }
}

///|
pub fn absolute_test_path(path : String) -> String {
  if path.has_prefix("/") {
    path
  } else {
    @env.get_env_var("PWD").unwrap_or(".") + "/" + path
  }
}

///|
pub fn managed_command_record_root() -> String {
  "env/managed-paths"
}

///|
pub fn managed_command_record_path(name : String) -> String {
  managed_command_record_root() + "/" + name
}

///|
pub fn with_managed_command_record(
  name : String,
  value : String?,
  body : () -> Unit raise,
) -> Unit raise {
  let path = managed_command_record_path(name)
  let previous = if @fs.path_exists(path) {
    Some(read_utf8_text(path))
  } else {
    None
  }
  ensure_dir_tree(managed_command_record_root())
  match value {
    Some(text) => write_utf8_text(path, text + "\n")
    None => remove_file_if_exists(path)
  }
  defer restore_text_file(path, previous)
  body()
}

///|
pub fn repo_local_runtime_python_path() -> String {
  "env/.venv-markitdown-runtime/bin/python"
}

///|
pub fn repo_local_runtime_python_dir() -> String {
  "env/.venv-markitdown-runtime/bin"
}

///|
pub fn with_executable_stub(
  path : String,
  parent_dir : String,
  script : String,
  body : () -> Unit raise,
) -> Unit raise {
  let existed = @fs.path_exists(path)
  if !existed {
    ensure_dir_tree(parent_dir)
    write_utf8_text(path, script)
    chmod_plus_x(path)
  }
  defer (if !existed { remove_file_if_exists(path) })
  body()
}

///|
pub fn with_hidden_path(path : String, body : () -> Unit raise) -> Unit raise {
  if !@fs.path_exists(path) {
    body()
    return
  }
  let backup = path + ".wbtest-backup"
  move_path(path, backup)
  defer restore_path_if_exists(backup, path)
  body()
}

///|
pub fn with_repo_local_runtime_python_stub(
  body : () -> Unit raise,
) -> Unit raise {
  with_executable_stub(
    repo_local_runtime_python_path(),
    repo_local_runtime_python_dir(),
    "#!/bin/sh\nexit 0\n",
    body,
  )
}

///|
pub fn with_repo_local_runtime_python_hidden(
  body : () -> Unit raise,
) -> Unit raise {
  with_hidden_path(repo_local_runtime_python_path(), body)
}
