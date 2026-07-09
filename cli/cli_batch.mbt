///|
fn dirname_of_path(path : String) -> String {
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
fn ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
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
fn persist_cli_provenance(
  opts : CliOptions,
  provenance : @convert.ConvertProvenance,
) -> Unit raise @fs.IOError {
  match opts.provenance_output {
    Some(path) => {
      let parent = dirname_of_path(path)
      ensure_dir_tree(parent)
      @fs.write_string_to_file(
        path,
        @convert.convert_provenance_to_json(provenance).stringify(indent=2) +
        "\n",
        encoding="utf8",
      )
    }
    None => ()
  }
}

///|
fn run_batch_cli_app(cli_args : Array[String]) -> Int {
  let parsed = parse_batch_cli_options(cli_args, 1)
  let (opts, output_dir) = match parsed {
    Ok(value) => value
    Err(msg) => return exit_cli_error(msg, true)
  }
  let input_path = opts.input
  let tasks = if fs_is_dir(input_path) {
    collect_batch_input_paths(input_path, input_path)
  } else if @fs.path_exists(input_path) {
    [input_path]
  } else {
    return exit_cli_error("batch input path not found: " + input_path, false)
  }
  ensure_dir_tree(output_dir) catch {
    err =>
      return exit_cli_error(
        "create batch output dir failed: " + err.to_string(),
        false,
      )
  }
  let results : Array[BatchTaskResult] = []
  for task_input in tasks {
    let relative_path = batch_relative_path(input_path, task_input)
    let result = run_single_batch_task(
      opts, output_dir, task_input, relative_path,
    )
    results.push(result)
  }
  let manifest_path = output_dir + "/manifest.json"
  let manifest = Json::object({
    "task_count": results.length().to_json(),
    "results": results.map(batch_task_result_to_json).to_json(),
  })
  @fs.write_string_to_file(
    manifest_path,
    manifest.stringify(indent=2) + "\n",
    encoding="utf8",
  ) catch {
    err =>
      return exit_cli_error(
        "write batch manifest failed: " + err.to_string(),
        false,
      )
  }
  0
}

///|
fn parse_batch_cli_options(
  args : Array[String],
  start_index : Int,
) -> Result[(CliOptions, String), String] {
  let mut parsed_index = start_index
  let mut mode = @convert.ConvertMode::Balanced
  if parsed_index < args.length() {
    let first = args[parsed_index].trim().to_owned().to_lower()
    match cli_mode_from_name(first) {
      Some(parsed_mode) => {
        mode = parsed_mode
        parsed_index += 1
      }
      None =>
        if first == "convert" || first == "normal" {
          return Err(removed_batch_mode_message(first))
        }
    }
  }
  let parsed = parse_cli_options_from_index(
    args,
    parsed_index,
    mode~,
    allow_batch_audio_language_without_explicit_format=true,
  )
  let opts = match parsed {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  if opts.provenance_output is Some(_) {
    return Err("batch does not support --provenance-out; use manifest.json")
  }
  if opts.audio_options.language is Some(_) &&
    !(match opts.explicit_format {
      Some(
        @input.DetectedFormat::Audio(
          @input.AudioFormat::Wav
          | @input.AudioFormat::Mp3
          | @input.AudioFormat::M4a
        )
      ) => true
      _ => false
    }) {
    return Err("batch --audio-lang requires explicit --format wav|mp3|m4a")
  }
  if opts.output is None {
    return Err("batch requires <input> <output_dir>")
  }
  match opts.output {
    Some(output_dir) => Ok(({ ..opts, output: None }, output_dir))
    None => Err("batch requires <input> <output_dir>")
  }
}

///|
fn collect_batch_input_paths(root : String, path : String) -> Array[String] {
  ignore(root)
  if fs_is_file(path) {
    return [path]
  }
  let collected : Array[String] = []
  for name in fs_read_dir(path) {
    let child = join_dir_path(path, name)
    if fs_is_dir(child) {
      collected.append(collect_batch_input_paths(root, child)[:])
    } else if fs_is_file(child) {
      collected.push(child)
    }
  }
  collected
}

///|
fn batch_relative_path(root_input : String, path : String) -> String {
  if root_input == path {
    return basename_of_path(path)
  }
  if !fs_is_dir(root_input) {
    return basename_of_path(path)
  }
  let prefix = if root_input.has_suffix("/") {
    root_input
  } else {
    root_input + "/"
  }
  if path.has_prefix(prefix) {
    path[prefix.length():].to_owned()
  } else {
    basename_of_path(path)
  }
}

///|
fn fs_is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
fn fs_is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
fn fs_read_dir(path : String) -> Array[String] {
  @fs.read_dir(path) catch {
    _ => []
  }
}

///|
fn basename_of_path(path : String) -> String {
  let normalized = path.trim().to_owned()
  let chars = normalized.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
      last = i
    }
  }
  if last < 0 {
    normalized
  } else {
    normalized[last + 1:].to_owned()
  }
}

///|
fn batch_output_suffix(output_format : @convert.OutputFormat) -> String {
  match output_format {
    @convert.OutputFormat::Markdown => ".md"
    @convert.OutputFormat::DebugJson => ".debug.json"
    @convert.OutputFormat::RagJson => ".rag.json"
  }
}

///|
fn batch_output_path(
  output_dir : String,
  relative_path : String,
  output_format : @convert.OutputFormat,
) -> String {
  join_dir_path(output_dir, relative_path) + batch_output_suffix(output_format)
}

///|
fn run_single_batch_task(
  base_opts : CliOptions,
  output_dir : String,
  task_input : String,
  relative_path : String,
) -> BatchTaskResult {
  let requested_format = cli_requested_format_from_input(
    task_input,
    base_opts.explicit_format,
  )
  let output_path = batch_output_path(
    output_dir,
    relative_path,
    base_opts.output_format,
  )
  let opts = { ..base_opts, input: task_input, output: Some(output_path) }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_format,
    opts.explicit_format,
    opts.ocr_options,
    @convert.default_resource_limits(),
    audio_options=opts.audio_options,
    fidelity_mode=opts.fidelity_mode,
    output_mode=opts.output_mode,
    stream_requested=opts.stream_requested,
    rag_options=opts.rag_options,
  )
  match
    @convert.convert_input_with_provenance_and_image_ocr_provider(
      @input.input_from_path(task_input),
      convert_options,
      @focr.run_ocr_provider,
    ) {
    Ok(execution) =>
      match cli_render_convert_result(opts, execution.result) {
        Ok(_) =>
          {
            input_path: task_input,
            relative_path,
            status: BatchTaskStatus::Success,
            detected_format: @input.detected_format_name(requested_format),
            convert_mode: @convert.convert_mode_name(
              execution.result.convert_mode,
            ),
            fidelity_mode: @convert.fidelity_mode_name(
              execution.result.fidelity_mode,
            ),
            output_mode: @convert.output_mode_name(execution.result.output_mode),
            output_path: Some(output_path),
            selected_route: Some(execution.provenance.route_plan.selected_route),
            parser_mode: Some(@parser.mode_name(execution.result.parser_mode)),
            route_reason: Some(execution.provenance.route_plan.route_reason),
            warning_count: execution.result.diagnostics.warnings.length(),
            degraded_features: execution.result.diagnostics.degraded_features.copy(),
            error: None,
          }
        Err(msg) =>
          {
            input_path: task_input,
            relative_path,
            status: BatchTaskStatus::Failed,
            detected_format: @input.detected_format_name(requested_format),
            convert_mode: @convert.convert_mode_name(opts.convert_mode),
            fidelity_mode: @convert.fidelity_mode_name(opts.fidelity_mode),
            output_mode: @convert.output_mode_name(opts.output_mode),
            output_path: Some(output_path),
            selected_route: Some(execution.provenance.route_plan.selected_route),
            parser_mode: Some(@parser.mode_name(execution.result.parser_mode)),
            route_reason: Some(execution.provenance.route_plan.route_reason),
            warning_count: execution.result.diagnostics.warnings.length(),
            degraded_features: execution.result.diagnostics.degraded_features.copy(),
            error: Some(msg),
          }
      }
    Err(err) =>
      {
        input_path: task_input,
        relative_path,
        status: BatchTaskStatus::Failed,
        detected_format: @input.detected_format_name(requested_format),
        convert_mode: @convert.convert_mode_name(opts.convert_mode),
        fidelity_mode: @convert.fidelity_mode_name(opts.fidelity_mode),
        output_mode: @convert.output_mode_name(opts.output_mode),
        output_path: None,
        selected_route: None,
        parser_mode: None,
        route_reason: None,
        warning_count: 0,
        degraded_features: [],
        error: Some(err.to_string()),
      }
  }
}

///|
fn path_extension_label(path : String) -> String? {
  let trimmed = path.trim().to_owned().to_lower()
  let chars = trimmed.to_array()
  let mut last_dot : Int? = None
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = Some(i)
    }
  }
  match last_dot {
    Some(index) if index + 1 < trimmed.length() => {
      let label = trimmed[index + 1:].to_owned()
      if label == "" {
        None
      } else {
        Some(label)
      }
    }
    _ => None
  }
}

///|
fn normalize_format_label(label : String) -> String {
  let parsed = @input.parse_detected_format(label)
  if parsed == @input.DetectedFormat::Unknown {
    label
  } else {
    @input.detected_format_name(parsed)
  }
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
fn persist_cli_assets(
  input_path : String,
  output_path : String,
  assets : Array[@core.AssetRef],
) -> Unit raise @fs.IOError {
  if assets.length() == 0 {
    return
  }
  let output_dir = dirname_of_path(output_path)
  let input_dir = dirname_of_path(input_path)
  let zip_archive = load_zip_archive_for_assets(input_path, assets)
  for asset in assets {
    let rel_path = asset.path.unwrap_or("").trim().to_owned()
    if rel_path == "" {
      continue
    }
    if persist_nested_zip_backed_asset(zip_archive, output_dir, rel_path, asset) {
      continue
    }
    if persist_zip_backed_asset(zip_archive, output_dir, rel_path, asset) {
      continue
    }
    if persist_inline_asset(output_dir, rel_path, asset) {
      continue
    }
    match asset.attrs.get("source_path") {
      Some(source_rel) => {
        let src = join_dir_path(input_dir, source_rel)
        if !@fs.path_exists(src) {
          continue
        }
        let dst = join_dir_path(output_dir, rel_path)
        ensure_dir_tree(dirname_of_path(dst))
        let data = @fs.read_file_to_bytes(src) catch { _ => continue }
        @fs.write_bytes_to_file(dst, data)
      }
      None => ()
    }
  }
}

///|
fn persist_inline_asset(
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @fs.IOError {
  let inline_kind = match asset.attrs.get("inline_payload_kind") {
    Some(value) => value
    None => return false
  }
  let data = match inline_kind {
    "base64" =>
      match asset.attrs.get("inline_payload") {
        Some(payload) =>
          try @base64.decode(payload, url_safe=false) |> Some catch {
            _ => None
          }
        None => None
      }
    "utf8" =>
      match asset.attrs.get("inline_payload") {
        Some(payload) => Some(@utf8.encode(payload))
        None => None
      }
    _ => None
  }
  let bytes = match data {
    Some(value) => value
    None => return false
  }
  let dst = join_dir_path(output_dir, rel_path)
  ensure_dir_tree(dirname_of_path(dst))
  @fs.write_bytes_to_file(dst, bytes)
  true
}

///|
fn load_zip_archive_for_assets(
  input_path : String,
  assets : Array[@core.AssetRef],
) -> @dzip.ZipArchive? {
  let mut needs_zip = false
  for asset in assets {
    if asset.attrs.get("zip_entry_path") is Some(_) ||
      asset.attrs.get("zip_nested_archive_entry_path") is Some(_) {
      needs_zip = true
      break
    }
  }
  if !needs_zip {
    return None
  }
  let bytes = try @fs.read_file_to_bytes(input_path) |> Ok catch {
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
fn persist_nested_zip_backed_asset(
  archive : @dzip.ZipArchive?,
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @fs.IOError {
  let outer_entry_path = match
    asset.attrs.get("zip_nested_archive_entry_path") {
    Some(value) => value
    None => return false
  }
  let inner_entry_path = match asset.attrs.get("zip_nested_asset_entry_path") {
    Some(value) => value
    None => return false
  }
  let archive = match archive {
    Some(value) => value
    None => return false
  }
  let nested_bytes = try
    @dzip.read_entry(archive, outer_entry_path) |> Ok
  catch {
    _ => Err(())
  }
  let nested_bytes = match nested_bytes {
    Ok(value) => value
    Err(_) => return true
  }
  let nested_archive = try @dzip.open_zip(nested_bytes) |> Ok catch {
    _ => Err(())
  }
  let nested_archive = match nested_archive {
    Ok(value) => value
    Err(_) => return true
  }
  let data = try
    @dzip.read_entry(nested_archive, inner_entry_path) |> Ok
  catch {
    _ => Err(())
  }
  let data = match data {
    Ok(value) => value
    Err(_) => return true
  }
  let dst = join_dir_path(output_dir, rel_path)
  ensure_dir_tree(dirname_of_path(dst))
  @fs.write_bytes_to_file(dst, data)
  true
}

///|
fn persist_zip_backed_asset(
  archive : @dzip.ZipArchive?,
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @fs.IOError {
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
  let dst = join_dir_path(output_dir, rel_path)
  ensure_dir_tree(dirname_of_path(dst))
  @fs.write_bytes_to_file(dst, data)
  true
}

///|
fn join_dir_path(dir : String, rel : String) -> String {
  if dir == "" || dir == "." {
    rel
  } else if dir.has_suffix("/") {
    dir + rel
  } else {
    dir + "/" + rel
  }
}
