///|
/// Read only the assets already selected by the pipeline. Prepared package
/// artifacts borrow the current execution's owner; only validated Bytes leave
/// this function, never an archive or a delayed callback.
async fn materialize_existing_output_assets(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  assets : Array[@core.AssetRef],
  artifacts : Array[RouteProbeArtifact],
  limits : ResourceLimits,
) -> Result[Array[@core.AssetRef], ConvertError] {
  let context = @parser.parse_context_with_input_source(
    @parser.parse_context_with_asset_limits(
      @parser.new_parse_context(format),
      limits.max_asset_bytes,
      limits.max_total_asset_bytes,
    ),
    source,
  )
  let archive = output_asset_archive(format, artifacts)
  let completed : Array[@core.AssetRef] = []
  let mut admitted = 0L
  for asset in assets {
    if @input.input_source_failure(source) is Some(_) {
      return Err(output_asset_error(source, "input owner failed"))
    }
    let owned_size = match asset.payload {
      Some(Bytes(bytes)) => Some(bytes.length().to_int64())
      Some(Utf8(text)) =>
        match @input.validated_text_utf8_size(text) {
          Ok(size) => Some(size)
          Err(message) => return Err(output_asset_error(source, message))
        }
      _ => None
    }
    if owned_size is Some(size) {
      if !@parser.require_asset_payload_within_limits(context, size, admitted) {
        return Err(output_asset_error(source, "asset payload exceeds limits"))
      }
      admitted += size
      completed.push(asset)
      continue
    }
    // Nested container producers already publish owned payloads. A lazy nested
    // marker cannot be resolved against the root package's similarly named part.
    if asset.attrs.get("zip_nested_archive_entry_path") is Some(_) {
      return Err(
        output_asset_error(
          source,
          "nested output asset lacks its verified payload: " + asset.asset_id,
        ),
      )
    }
    let path = match asset.attrs.get("zip_entry_path") {
      Some(value) =>
        match normalize_output_asset_entry(value) {
          Some(path) => path
          None =>
            return Err(
              output_asset_error(source, "unsafe output asset entry: " + value),
            )
        }
      None => {
        completed.push(asset)
        continue
      }
    }
    let archive = match archive {
      Some(value) => value
      None =>
        return Err(
          output_asset_error(
            source,
            "original prepared archive is unavailable for output asset: " +
            asset.asset_id,
          ),
        )
    }
    let info = match @asset_zip.find_entry_info(archive, path) {
      Some(value) if !value.is_unsafe_path => value
      _ =>
        return Err(
          output_asset_error(
            source,
            "output asset entry is missing or unsafe: " + path,
          ),
        )
    }
    let size = info.uncompressed_size.to_int64()
    if !@parser.require_asset_payload_within_limits(context, size, admitted) {
      return Err(output_asset_error(source, "asset payload exceeds limits"))
    }
    let cap = limits.max_asset_bytes
      .min(limits.max_total_asset_bytes - admitted)
      .min(2147483647L)
      .to_int()
    let bytes = @asset_zip.read_entry(
      archive,
      info.raw_name,
      max_output_size=cap,
    ) catch {
      error => return Err(output_asset_error(source, error.to_string()))
    }
    if @input.input_source_failure(source) is Some(_) {
      return Err(
        output_asset_error(
          source, "input owner failed while reading output asset",
        ),
      )
    }
    // read_entry has verified both declared size and CRC before publication.
    // Each logical AssetRef counts even when the checked archive cache hits.
    let actual = bytes.length().to_int64()
    if !@parser.require_asset_payload_within_limits(context, actual, admitted) {
      return Err(output_asset_error(source, "asset payload exceeds limits"))
    }
    admitted += actual
    completed.push({ ..asset, payload: Some(Bytes(bytes)), })
  }
  Ok(completed)
}

///|
fn normalize_output_asset_entry(path : String) -> String? {
  let normalized = path.replace_all(old="\\", new="/")
  if normalized.has_prefix("/") || normalized.contains(":") {
    return None
  }
  let parts : Array[String] = []
  for part in normalized.split("/") {
    if part == "" || part == "." {
      continue
    }
    if part == ".." {
      return None
    }
    parts.push(part.to_owned())
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join("/"))
  }
}

///|
fn output_asset_archive(
  format : @input.DetectedFormat,
  artifacts : Array[RouteProbeArtifact],
) -> @asset_zip.ZipArchive? {
  for artifact in artifacts {
    match (format, artifact) {
      (Docx, DocxPrepared(prepared, _)) =>
        return Some(prepared.opened_package.archive)
      (Pptx, PptxPrepared(prepared, _)) =>
        return Some(prepared.opened_package.archive)
      (Xlsx, XlsxPrepared(prepared)) =>
        return Some(prepared.opened_package.archive)
      _ => ()
    }
  }
  None
}

///|
fn output_asset_error(
  source : @input.InputSource,
  message : String,
) -> ConvertError {
  @input.record_input_failure(source, message)
  match @input.input_source_failure(source) {
    Some(InputError(first)) => OutputAssetFailure(first)
    Some(ResourceLimit(_)) | Some(BudgetFailure(_)) =>
      input_failure_convert_error(source).unwrap_or(OutputAssetFailure(message))
    None => OutputAssetFailure(message)
  }
}
