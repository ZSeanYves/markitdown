///|
pub fn remap_subdoc_assets(
  subdoc : @cor.Document,
  entry_id : String,
  entry_out_dir : String,
  archive_out_dir : String,
  zip_source_name : String,
  entry_path : String,
) -> @cor.Document raise {
  let asset_paths = collect_subdoc_asset_paths(subdoc)
  if asset_paths.length() == 0 {
    return subdoc
  }

  let path_map : Map[String, String] = Map([])
  for old_path in asset_paths {
    path_map.set(old_path, namespaced_asset_path(old_path, entry_id))
  }

  for old_path in asset_paths {
    let new_path = path_map.get(old_path).unwrap_or(old_path)
    copy_remapped_asset_file(
      old_path, new_path, entry_out_dir, archive_out_dir, entry_path,
    )
  }

  let remapped = @cor.new_document()
  for i in 0..<subdoc.blocks.val.length() {
    @cor.push_with_origin(
      remapped,
      remap_block_asset_path(subdoc.blocks.val[i], path_map),
      origin_at(subdoc, i),
    )
  }

  for entry in subdoc.asset_origins.val {
    let (old_path, old_origin) = entry
    let new_path = path_map
      .get(old_path)
      .unwrap_or(namespaced_asset_path(old_path, entry_id))
    @cor.set_asset_origin(
      remapped,
      new_path,
      remap_asset_origin(old_origin, new_path, zip_source_name, entry_path),
    )
  }

  for old_path in asset_paths {
    let new_path = path_map.get(old_path).unwrap_or(old_path)
    if remapped.asset_origins.val.contains(new_path) {
      continue
    }
    @cor.set_asset_origin(
      remapped,
      new_path,
      synthesize_remapped_asset_origin(
        subdoc, old_path, new_path, zip_source_name, entry_path,
      ),
    )
  }

  remapped
}

///|
fn collect_subdoc_asset_paths(doc : @cor.Document) -> Array[String] {
  let seen : Map[String, Bool] = Map([])

  for entry in doc.asset_origins.val {
    let (path, _origin) = entry
    let normalized = path.trim().to_owned()
    if normalized != "" {
      seen.set(normalized, true)
    }
  }

  for block in doc.blocks.val {
    match block {
      @cor.Block::Image(_, path) => {
        let normalized = path.trim().to_owned()
        if normalized != "" {
          seen.set(normalized, true)
        }
      }
      @cor.Block::ImageBlock(img) => {
        let normalized = img.path.trim().to_owned()
        if normalized != "" {
          seen.set(normalized, true)
        }
      }
      _ => ()
    }
  }

  let out : Array[String] = []
  for entry in seen {
    out.push(entry.0)
  }
  out.sort_by((a, b) => compare_zip_path(a, b))
  out
}

///|
fn remap_block_asset_path(
  block : @cor.Block,
  path_map : Map[String, String],
) -> @cor.Block {
  match block {
    @cor.Block::Image(alt, path) =>
      @cor.Block::Image(alt, remap_asset_path(path, path_map))
    @cor.Block::ImageBlock(img) =>
      @cor.Block::ImageBlock({
        ..img,
        path: remap_asset_path(img.path, path_map),
      })
    _ => block
  }
}

///|
fn remap_asset_path(path : String, path_map : Map[String, String]) -> String {
  path_map.get(path).unwrap_or(path)
}

///|
fn namespaced_asset_path(path : String, entry_id : String) -> String {
  let trimmed = path.trim().to_owned()
  let suffix = if trimmed.has_prefix("assets/") {
    trimmed["assets/".length():].to_owned()
  } else {
    @cor.basename(trimmed)
  }
  "assets/archive/" + entry_id + "/" + suffix
}

///|
fn copy_remapped_asset_file(
  old_path : String,
  new_path : String,
  entry_out_dir : String,
  archive_out_dir : String,
  entry_path : String,
) -> Unit raise {
  let src = entry_out_dir + "/" + old_path
  let dst = archive_out_dir + "/" + new_path
  ensure_parent_dir(dst) catch {
    e =>
      raise @cor.AppError(
        "zip asset remap failed for " +
        entry_path +
        ": create destination failed: " +
        e.to_string(),
      )
  }
  let data = @fs.read_file_to_bytes(src) catch {
    e =>
      raise @cor.AppError(
        "zip asset remap failed for " +
        entry_path +
        ": read source asset failed: " +
        old_path +
        " : " +
        e.to_string(),
      )
  }
  @fs.write_bytes_to_file(dst, data) catch {
    e =>
      raise @cor.AppError(
        "zip asset remap failed for " +
        entry_path +
        ": write archive asset failed: " +
        new_path +
        " : " +
        e.to_string(),
      )
  }
}

///|
fn remap_asset_origin(
  origin : @cor.AssetOrigin,
  new_path : String,
  zip_source_name : String,
  entry_path : String,
) -> @cor.AssetOrigin {
  {
    ..origin,
    source_name: Some(zip_source_name),
    origin_id: Some(
      remap_asset_origin_id(origin.origin_id, new_path, entry_path),
    ),
    source_path: Some(entry_path),
    key_path: Some(entry_path),
  }
}

///|
fn remap_asset_origin_id(
  old_origin_id : String?,
  new_path : String,
  entry_path : String,
) -> String {
  let suffix = match old_origin_id {
    Some(v) => if v.trim() == "" { new_path } else { v }
    None => new_path
  }
  "zip:" + entry_path + ":" + suffix
}

///|
fn synthesize_remapped_asset_origin(
  doc : @cor.Document,
  old_path : String,
  new_path : String,
  zip_source_name : String,
  entry_path : String,
) -> @cor.AssetOrigin {
  let nearby_caption = match find_image_data_by_path(doc, old_path) {
    Some(img) => img.caption
    None => None
  }

  {
    source_name: Some(zip_source_name),
    page: None,
    slide: None,
    sheet: None,
    origin_id: Some(remap_asset_origin_id(None, new_path, entry_path)),
    nearby_caption,
    object_ref: None,
    relationship_id: None,
    source_path: Some(entry_path),
    row_index: None,
    column_index: None,
    key_path: Some(entry_path),
  }
}

///|
fn find_image_data_by_path(
  doc : @cor.Document,
  path : String,
) -> @cor.ImageData? {
  for block in doc.blocks.val {
    match block {
      @cor.Block::ImageBlock(img) => if img.path == path { return Some(img) }
      _ => ()
    }
  }
  None
}

///|
fn doc_has_assets(doc : @cor.Document) -> Bool {
  if doc.asset_origins.val.length() > 0 {
    return true
  }
  for block in doc.blocks.val {
    match block {
      @cor.Block::Image(_, _) | @cor.Block::ImageBlock(_) => return true
      _ => ()
    }
  }
  false
}
