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
fn zip_builder_bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn zip_builder_byte_to_unsigned_int(value : Byte) -> Int {
  let raw = value.to_int()
  if raw >= 0 {
    raw
  } else {
    raw + 256
  }
}

///|
fn zip_builder_crc32_update_uint(crc : UInt, value : UInt) -> UInt {
  let mut acc = UInt::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt::land(acc, 1) != 0 {
      acc = UInt::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i = i + 1
  }
  acc
}

///|
fn zip_builder_crc32(bytes : Bytes) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for value in bytes {
    crc = zip_builder_crc32_update_uint(
      crc,
      zip_builder_byte_to_unsigned_int(value).reinterpret_as_uint(),
    )
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn zip_builder_append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn zip_builder_append_u32_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn zip_builder_add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int, Int)],
  name : String,
  data : Bytes,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = zip_builder_bytes_of_string(name)
  let crc32 = zip_builder_crc32(data)
  let size = data.length()

  zip_builder_append_u32_le(out, 0x04034b50)
  zip_builder_append_u16_le(out, 20)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u32_le(out, crc32)
  zip_builder_append_u32_le(out, size)
  zip_builder_append_u32_le(out, size)
  zip_builder_append_u16_le(out, name_bytes.length())
  zip_builder_append_u16_le(out, 0)
  for b in name_bytes {
    out.push(b)
  }
  for b in data {
    out.push(b)
  }

  central.push((name, size, local_offset, crc32))
}

///|
pub fn build_store_zip_bytes(entries : Array[(String, Bytes)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []

  for entry in entries {
    let (name, data) = entry
    zip_builder_add_store_entry(out, central, name, data)
  }

  let cd_offset = out.length()
  for entry in central {
    let (name, size, local_offset, crc32) = entry
    let name_bytes = zip_builder_bytes_of_string(name)

    zip_builder_append_u32_le(out, 0x02014b50)
    zip_builder_append_u16_le(out, 20)
    zip_builder_append_u16_le(out, 20)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u32_le(out, crc32)
    zip_builder_append_u32_le(out, size)
    zip_builder_append_u32_le(out, size)
    zip_builder_append_u16_le(out, name_bytes.length())
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u32_le(out, 0)
    zip_builder_append_u32_le(out, local_offset)
    for b in name_bytes {
      out.push(b)
    }
  }
  let cd_size = out.length() - cd_offset

  zip_builder_append_u32_le(out, 0x06054b50)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, central.length())
  zip_builder_append_u16_le(out, central.length())
  zip_builder_append_u32_le(out, cd_size)
  zip_builder_append_u32_le(out, cd_offset)
  zip_builder_append_u16_le(out, 0)

  Bytes::from_array(out)
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
  "env/.venv-markitdown-accurate/bin/python"
}

///|
pub fn repo_local_runtime_python_dir() -> String {
  "env/.venv-markitdown-accurate/bin"
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
