///|
fn run_inprocess_engine_tool(
  request : @command.RunRequest,
  tool : @tools.BenchTool,
  rows : Array[@manifest.BenchRow],
  result_path : String,
) -> String {
  let result_rows : Array[@result.CliResult] = []
  for row in rows {
    for _ in 0..<request.warmup_count {
      ignore(
        @convert.convert_input(
          @input.input_from_path(row.input_path),
          @convert.default_convert_options(),
        ),
      )
    }
    for repeat_index in 0..<request.repeat_count {
      let output_path = @command.output_markdown_path(
        request.run_id,
        tool.name,
        row.bench_id,
        repeat_index,
        request.repeat_count,
      )
      let command = tool.build_command(
        row,
        output_path,
        request.timeout_ms,
        request.cli_output_mode,
        request.engine_output_mode,
      )
      let started = @measure.monotonic_start()
      let converted = @convert.convert_input(
        @input.input_from_path(row.input_path),
        @convert.default_convert_options(),
      )
      let rendered = match converted {
        Ok(value) => value
        Err(err) => {
          let wall_us = monotonic_elapsed_us_int64(started)
          result_rows.push(
            @result.make_inprocess_result(
              request.run_id,
              request.git_commit,
              request.runner,
              request.warmup_count,
              "row_major",
              tool,
              row,
              command.command_display,
              repeat_index,
              request.repeat_count,
              wall_us,
              0L,
              status="failed",
              error=Some(err.to_string()),
              output_write_mode=Some(
                @command.engine_output_mode_name(request.engine_output_mode),
              ),
            ),
          )
          continue
        }
      }
      let finalized = try
        finalize_engine_output(
          row.input_path,
          output_path,
          rendered,
          request.engine_output_mode,
        )
        |> Ok
      catch {
        err => Err(err.to_string())
      }
      let wall_us = monotonic_elapsed_us_int64(started)
      match finalized {
        Ok(output_bytes) =>
          result_rows.push(
            @result.make_inprocess_result(
              request.run_id,
              request.git_commit,
              request.runner,
              request.warmup_count,
              "row_major",
              tool,
              row,
              command.command_display,
              repeat_index,
              request.repeat_count,
              wall_us,
              output_bytes,
              output_write_mode=Some(
                @command.engine_output_mode_name(request.engine_output_mode),
              ),
            ),
          )
        Err(message) =>
          result_rows.push(
            @result.make_inprocess_result(
              request.run_id,
              request.git_commit,
              request.runner,
              request.warmup_count,
              "row_major",
              tool,
              row,
              command.command_display,
              repeat_index,
              request.repeat_count,
              wall_us,
              file_size(output_path),
              status="failed",
              error=Some("write output failed: " + message),
              output_write_mode=Some(
                @command.engine_output_mode_name(request.engine_output_mode),
              ),
            ),
          )
      }
    }
  }
  append_result_rows(result_path, result_rows)
  result_path
}

///|
fn persist_engine_output(
  input_path : String,
  output_path : String,
  rendered : @convert.ConvertResult,
) -> Int64 raise @syncfs.IOError {
  let persisted_content = normalized_written_content(rendered.content)
  ensure_dir_tree_sync(dirname_of_path_sync(output_path))
  @syncfs.write_string_to_file(output_path, persisted_content, encoding="utf8")
  persist_engine_assets(input_path, output_path, rendered.assets)
  file_size(output_path)
}

///|
fn finalize_engine_output(
  input_path : String,
  output_path : String,
  rendered : @convert.ConvertResult,
  mode : @command.EngineOutputMode,
) -> Int64 raise @syncfs.IOError {
  match mode {
    @command.EngineOutputMode::File =>
      persist_engine_output(input_path, output_path, rendered)
    @command.EngineOutputMode::Memory => rendered_output_bytes(rendered.content)
    @command.EngineOutputMode::None => rendered_output_bytes(rendered.content)
  }
}

///|
fn rendered_output_bytes(text : String) -> Int64 {
  @utf8.encode(normalized_written_content(text)).length().to_int64()
}

///|
fn normalized_written_content(text : String) -> String {
  if text == "" || text.has_suffix("\n") {
    text
  } else {
    text + "\n"
  }
}

///|
fn persist_engine_assets(
  input_path : String,
  output_path : String,
  assets : Array[@core.AssetRef],
) -> Unit raise @syncfs.IOError {
  if assets.length() == 0 {
    return
  }
  let output_dir = dirname_of_path_sync(output_path)
  let input_dir = dirname_of_path_sync(input_path)
  let zip_archive = load_zip_archive_for_assets(input_path, assets)
  for asset in assets {
    let rel_path = asset.path.unwrap_or("").trim().to_owned()
    if rel_path == "" {
      continue
    }
    if persist_zip_backed_asset(zip_archive, output_dir, rel_path, asset) {
      continue
    }
    match asset.attrs.get("source_path") {
      Some(source_rel) => {
        let src = join_dir_path_sync(input_dir, source_rel)
        if !@syncfs.path_exists(src) {
          continue
        }
        let dst = join_dir_path_sync(output_dir, rel_path)
        ensure_dir_tree_sync(dirname_of_path_sync(dst))
        let data = @syncfs.read_file_to_bytes(src) catch { _ => continue }
        @syncfs.write_bytes_to_file(dst, data)
      }
      None => ()
    }
  }
}

///|
fn load_zip_archive_for_assets(
  input_path : String,
  assets : Array[@core.AssetRef],
) -> @dzip.ZipArchive? {
  let mut needs_zip = false
  for asset in assets {
    if asset.attrs.get("zip_entry_path") is Some(_) {
      needs_zip = true
      break
    }
  }
  if !needs_zip {
    return None
  }
  let bytes = try @syncfs.read_file_to_bytes(input_path) |> Ok catch {
    _ => Err(())
  }
  let bytes = match bytes {
    Ok(value) => value
    Err(_) => return None
  }
  try @dzip.open_zip(bytes) |> Some catch {
    _ => None
  }
}

///|
fn persist_zip_backed_asset(
  archive : @dzip.ZipArchive?,
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @syncfs.IOError {
  let entry_path = match asset.attrs.get("zip_entry_path") {
    Some(value) => value
    None => return false
  }
  let archive = match archive {
    Some(value) => value
    None => return false
  }
  let data = try @dzip.read_entry(archive, entry_path) |> Ok catch {
    _ => Err(())
  }
  let data = match data {
    Ok(value) => value
    Err(_) => return true
  }
  let dst = join_dir_path_sync(output_dir, rel_path)
  ensure_dir_tree_sync(dirname_of_path_sync(dst))
  @syncfs.write_bytes_to_file(dst, data)
  true
}

///|
fn dirname_of_path_sync(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    path[:last].to_owned()
  }
}

///|
fn join_dir_path_sync(dir : String, rel : String) -> String {
  if dir == "" || dir == "." {
    rel
  } else if dir.has_suffix("/") {
    dir + rel
  } else {
    dir + "/" + rel
  }
}

///|
fn ensure_dir_tree_sync(path : String) -> Unit {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." {
    return
  }
  if @syncfs.path_exists(normalized) {
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
