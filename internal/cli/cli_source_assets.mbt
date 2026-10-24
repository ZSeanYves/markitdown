///|
fn cli_asset_io_failure(
  source : @input.InputSource,
  message : String,
) -> CliFailure {
  let kind = match @input.input_source_failure(source) {
    Some(ResourceLimit(_)) | Some(BudgetFailure(LimitExceeded(_, ..))) =>
      ResourceFailure
    _ => OutputFailure
  }
  cli_failure(kind, message)
}

///|
fn cli_admit_asset_size(
  source : @input.InputSource,
  size : Int64,
  total : Int64,
  limits : @convert.ResourceLimits,
) -> Result[Unit, CliFailure] {
  let failure = if size > limits.max_asset_bytes {
    Some(
      @input.make_resource_limit_failure(
        SingleAssetBytes,
        size,
        limits.max_asset_bytes,
      ),
    )
  } else if size > limits.max_total_asset_bytes - total {
    Some(
      @input.make_resource_limit_failure(
        TotalAssetBytes,
        total + size,
        limits.max_total_asset_bytes,
      ),
    )
  } else {
    None
  }
  match failure {
    None => Ok(())
    Some(failure) => {
      @input.record_input_resource_failure(source, failure)
      Err(
        cli_asset_io_failure(
          source,
          @input.input_source_error(source).unwrap_or(
            "asset resource admission failed",
          ),
        ),
      )
    }
  }
}

///|
// Metadata opens and pins the same safe descriptor in the conversion session.
// The bounded content read then uses that descriptor, not a second path open.
async fn cli_read_source_asset(
  child : @input.InputSource,
  size : Int64,
  limits : @convert.ResourceLimits,
) -> Result[Bytes, CliFailure] {
  let context = match @input.input_source_budget_context(child) {
    Some(value) => value
    None =>
      return Err(
        cli_failure(
          OutputFailure,
          "asset materialization requires its conversion session",
        ),
      )
  }
  let cursor = match
    @input.open_source_cursor(child, max_bytes=limits.max_asset_bytes) {
    Ok(value) => value
    Err(message) =>
      return Err(
        cli_asset_io_failure(child, "open source asset failed: " + message),
      )
  }
  // Buffer(size_hint=0) still allocates one byte. An admitted empty extent
  // has no content payload or collection workspace to reserve or read.
  if size == 0L {
    return Ok(b"")
  }
  // Account for the admitted collection buffer plus the native driver's
  // bounded FixedArray and returned Bytes payloads during one read.
  // The final immutable Bytes gets its own scope-held payload reservation.
  let working = match
    context.account.reserve(WorkingBytes, size + 2L * size.min(64L * 1024L)) {
    Ok(value) => value
    Err(error) => {
      @input.record_input_budget_failure(child, error)
      return Err(
        cli_asset_io_failure(child, @budget.budget_error_message(error)),
      )
    }
  }
  defer working.release()
  let out = @buffer.Buffer(size_hint=size.to_int())
  let mut offset = 0L
  while offset < size {
    let bytes = match
      @input.source_cursor_read_at(
        cursor,
        offset,
        length=(size - offset).min(64L * 1024L).to_int(),
      ) {
      Ok(value) => value
      Err(message) =>
        return Err(
          cli_asset_io_failure(child, "read source asset failed: " + message),
        )
    }
    if bytes.is_empty() {
      @input.record_input_failure(
        child, "source asset ended before admitted extent",
      )
      return Err(
        cli_asset_io_failure(child, "source asset ended before admitted extent"),
      )
    }
    out.write_bytes(bytes)
    offset += bytes.length().to_int64()
  }
  match (context.retain_resident)(CacheBytes, size) {
    Ok(_) => Ok(out.to_bytes())
    Err(error) => {
      @input.record_input_budget_failure(child, error)
      Err(cli_asset_io_failure(child, @budget.budget_error_message(error)))
    }
  }
}

///|
// Only CLI output owns external SourcePath materialization. Parsing libraries
// continue returning SourcePath; owned Bytes/Utf8 retain their prior priority.
async fn cli_prepare_source_assets(
  input_path : String,
  source : @input.InputSource,
  assets : Array[@core.AssetRef],
  limits : @convert.ResourceLimits,
  diagnostics : @core.Diagnostics,
) -> Result[Array[@core.AssetRef], CliFailure] {
  if @input.input_source_budget_context(source) is None {
    return Err(
      cli_failure(
        OutputFailure,
        "asset materialization requires its conversion session",
      ),
    )
  }
  let borrowed = @input.begin_input_session(source)
  defer @input.end_input_session(borrowed)
  if @input.input_source_error(source) is Some(message) {
    return Err(cli_asset_io_failure(source, message))
  }
  let input_dir = dirname_of_path(input_path)
  let cached : Map[String, Bytes] = Map([])
  let prepared : Array[@core.AssetRef] = []
  let mut total = 0L
  let mut source_bytes = 0L
  let mut source_count = 0
  for asset in assets {
    match asset.payload {
      Some(Bytes(bytes)) => {
        match
          cli_admit_asset_size(source, bytes.length().to_int64(), total, limits) {
          Ok(_) => ()
          Err(failure) => return Err(failure)
        }
        total += bytes.length().to_int64()
        prepared.push(asset)
      }
      Some(Utf8(text)) => {
        let size = match @input.validated_text_utf8_size(text) {
          Ok(value) => value
          Err(message) => return Err(cli_failure(OutputFailure, message))
        }
        match cli_admit_asset_size(source, size, total, limits) {
          Ok(_) => ()
          Err(failure) => return Err(failure)
        }
        total += size
        prepared.push(asset)
      }
      Some(SourcePath(relative)) => {
        // Conversion owns archive materialization. Leave a remaining lazy
        // archive reference for validation to reject; never open it as an
        // unrelated outer filesystem pathname.
        if asset.attrs.get("zip_entry_path") is Some(_) ||
          asset.attrs.get("zip_nested_archive_entry_path") is Some(_) {
          prepared.push(asset)
          continue
        }
        if !cli_asset_relative_path_is_safe(relative) {
          return Err(
            cli_failure(OutputFailure, "unsafe source asset path: " + relative),
          )
        }
        let path = join_dir_path(input_dir, relative)
        // The async filesystem probe returns false only for typed ENOENT.
        // EACCES/ELOOP/ENOTDIR and other actual probe errors remain hard IO;
        // cancellation stays in the separate async cancellation channel.
        let exists = if cached.contains(path) {
          true
        } else {
          @asset_fs.exists(path) catch {
            error => {
              let message = "inspect source asset failed: " + error.to_string()
              @input.record_input_failure(source, message)
              return Err(cli_asset_io_failure(source, message))
            }
          }
        }
        if !exists {
          let attrs = asset.attrs.copy()
          attrs.set("source_path", relative)
          // Freeze the missing decision for this output operation. A later
          // file appearance must not re-enter the old unbounded path reader.
          prepared.push({ ..asset, payload: None, attrs, })
          continue
        }
        let bytes = match cached.get(path) {
          Some(bytes) => {
            match
              cli_admit_asset_size(
                source,
                bytes.length().to_int64(),
                total,
                limits,
              ) {
              Ok(_) => ()
              Err(failure) => return Err(failure)
            }
            bytes
          }
          None => {
            let child = @input.input_from_asset_path(
              source,
              path,
              asset_limit=limits.max_asset_bytes,
            )
            let size = match @input.input_source_size(child) {
              Ok(Some(value)) => value
              Ok(None) =>
                return Err(
                  cli_failure(
                    OutputFailure,
                    "source asset has no opened extent: " + relative,
                  ),
                )
              Err(message) =>
                return Err(
                  cli_asset_io_failure(
                    child,
                    "inspect source asset failed: " + message,
                  ),
                )
            }
            match cli_admit_asset_size(source, size, total, limits) {
              Ok(_) => ()
              Err(failure) => return Err(failure)
            }
            let bytes = match cli_read_source_asset(child, size, limits) {
              Ok(value) => value
              Err(failure) => return Err(failure)
            }
            cached.set(path, bytes)
            source_bytes += bytes.length().to_int64()
            source_count += 1
            bytes
          }
        }
        total += bytes.length().to_int64()
        prepared.push({ ..asset, payload: Some(Bytes(bytes)), })
      }
      None => prepared.push(asset)
    }
  }
  diagnostics.metrics.set("asset_payload_bytes", total.to_string())
  diagnostics.metrics.set(
    "cli_source_asset_read_bytes",
    source_bytes.to_string(),
  )
  diagnostics.metrics.set(
    "cli_source_asset_read_count",
    source_count.to_string(),
  )
  if source_count > 0 {
    // The unified partial policy names this CLI-only payload scope even
    // when a particular conversion has no external assets to materialize.
    diagnostics.metrics.set(
      "cli_source_asset_budget_coverage", "opened_extent_admission,read_traffic,scope_retained_payload_cache,collection_buffer_and_bounded_read_payload_working",
    )
  }
  Ok(prepared)
}
