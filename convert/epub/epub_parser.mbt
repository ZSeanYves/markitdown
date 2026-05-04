///|
const MAX_EPUB_ENTRIES : Int = 200

///|
const MAX_SINGLE_ENTRY_BYTES : Int = 128 * 1024 * 1024

///|
const MAX_TOTAL_ENTRY_BYTES : Int = 256 * 1024 * 1024

///|
pub fn parse_epub(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("epub: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("epub: read failed: " + e.to_string())
  }
  let epub_name = @cor.basename(input_path)
  let pkg = @epubpkg.open_epub_package(bytes, epub_name) catch {
    e => raise @cor.AppError("epub: open failed: " + e.to_string())
  }

  let doc = @cor.new_document()
  let tmp_root = allocate_archive_run_dir(epub_tmp_dir(input_path), "run")
  ensure_dir_tree(tmp_root) catch {
    e => raise @cor.AppError("epub: create temp dir failed: " + e.to_string())
  }
  let archive_out_dir = if out_dir.trim() == "" {
    tmp_root + "/archive-out"
  } else {
    out_dir
  }
  if out_dir.trim() != "" {
    defer ignore(try? cleanup_archive_run_dir(tmp_root))
  }
  ensure_dir_tree(archive_out_dir) catch {
    e =>
      raise @cor.AppError(
        "epub: create archive output dir failed: " + e.to_string(),
      )
  }

  let extracted_root = tmp_root + "/extracted"
  let materialization_skips = materialize_safe_archive_tree(pkg, extracted_root) catch {
    e => raise @cor.AppError("epub: " + e.to_string())
  }
  let entry_by_path : Map[String, @epubpkg.EpubArchiveEntry] = Map::new()
  for entry in pkg.entries {
    entry_by_path.set(entry.path, entry)
  }

  let final_md = StringBuilder::new()
  let used_ids : Map[String, Int] = Map::new()
  let nav_in_spine = nav_item_is_in_spine(pkg)

  emit_cover_if_present(
    doc, final_md, pkg, extracted_root, archive_out_dir, used_ids,
  )
  if !nav_in_spine {
    emit_nav_toc_if_present(doc, final_md, pkg)
  }

  for spine_item in pkg.spine {
    if !spine_item.linear {
      continue
    }

    let content_path = spine_item.resolved_path
    let is_nav_spine_item = match pkg.nav_item {
      Some(item) => item.resolved_path == content_path
      None => false
    }
    if is_nav_spine_item {
      continue
    }
    match materialization_skips.get(content_path) {
      Some(message) => {
        append_warning_entry(doc, final_md, epub_name, content_path, message)
        continue
      }
      None => ()
    }

    let ext = file_ext_lower(content_path)
    let media_type = spine_media_type_lower(spine_item)
    if !is_supported_spine_item(media_type, ext) {
      append_warning_entry(
        doc,
        final_md,
        epub_name,
        content_path,
        "Skipped: unsupported spine media type: " +
        show_spine_media_type(spine_item),
      )
      continue
    }

    let content_entry = match entry_by_path.get(content_path) {
      Some(v) => v
      None => {
        append_warning_entry(
          doc, final_md, epub_name, content_path, "Conversion failed: missing spine content entry",
        )
        continue
      }
    }

    if content_entry.uncompressed_size > MAX_SINGLE_ENTRY_BYTES {
      append_warning_entry(
        doc,
        final_md,
        epub_name,
        content_path,
        "Skipped: spine item too large: " +
        content_entry.uncompressed_size.to_string() +
        " bytes",
      )
      continue
    }

    let input_entry_path = extracted_entry_path(extracted_root, content_path) catch {
      e => {
        append_warning_entry(
          doc,
          final_md,
          epub_name,
          content_path,
          "Conversion failed: " + e.to_string(),
        )
        continue
      }
    }
    if !@fs.path_exists(input_entry_path) {
      append_warning_entry(
        doc, final_md, epub_name, content_path, "Conversion failed: extracted spine item missing",
      )
      continue
    }

    let entry_id = unique_entry_id(content_path, used_ids)
    let entry_out = tmp_root + "/out/" + entry_id
    recreate_clean_dir(entry_out) catch {
      e => {
        append_warning_entry(
          doc,
          final_md,
          epub_name,
          content_path,
          "Conversion failed: reset entry output dir failed: " + e.to_string(),
        )
        continue
      }
    }

    let subdoc = @html.parse_html(input_entry_path, entry_out, max_heading) catch {
      e => {
        append_warning_entry(
          doc,
          final_md,
          epub_name,
          content_path,
          "Conversion failed: " + e.to_string(),
        )
        continue
      }
    }

    let remapped_subdoc = if doc_has_assets(subdoc) {
      remap_subdoc_assets(
        subdoc, entry_id, entry_out, archive_out_dir, epub_name, content_path,
      ) catch {
        e => {
          append_warning_entry(
            doc,
            final_md,
            epub_name,
            content_path,
            "Conversion failed: " + e.to_string(),
          )
          continue
        }
      }
    } else {
      subdoc
    }

    append_converted_entry(
      doc,
      final_md,
      remapped_subdoc,
      epub_name,
      content_path,
      @cor.emit_markdown(remapped_subdoc),
    )
  }

  @cor.set_passthrough_markdown(doc, final_md.to_string())
  doc
}

///|
pub fn inspect_epub(input_path : String) -> @epubpkg.EpubInspectReport raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("epub: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("epub: read failed: " + e.to_string())
  }
  let epub_name = @cor.basename(input_path)
  let pkg = @epubpkg.open_epub_package(bytes, epub_name) catch {
    e => raise @cor.AppError("epub: open failed: " + e.to_string())
  }
  @epubpkg.inspect_epub_package(pkg)
}

///|
fn materialize_safe_archive_tree(
  pkg : @epubpkg.EpubPackage,
  extracted_root : String,
) -> Map[String, String] raise {
  recreate_clean_dir(extracted_root) catch {
    e =>
      raise @cor.AppError(
        "epub extracted tree failed: reset temp dir failed: " + e.to_string(),
      )
  }

  let skipped : Map[String, String] = Map::new()
  let mut total_materialized = 0
  for i in 0..<pkg.entries.length() {
    let entry = pkg.entries[i]
    if i >= MAX_EPUB_ENTRIES {
      skipped.set(entry.path, "Skipped: entry count limit exceeded")
      continue
    }
    if entry.uncompressed_size > MAX_SINGLE_ENTRY_BYTES {
      skipped.set(
        entry.path,
        "Skipped: entry too large: " +
        entry.uncompressed_size.to_string() +
        " bytes",
      )
      continue
    }
    if total_materialized + entry.uncompressed_size > MAX_TOTAL_ENTRY_BYTES {
      skipped.set(entry.path, "Skipped: total decoded size limit exceeded")
      continue
    }

    let dst = extracted_entry_path(extracted_root, entry.path)
    ensure_parent_dir(dst) catch {
      e =>
        raise @cor.AppError(
          "epub extracted tree failed: create parent dir failed for " +
          entry.path +
          ": " +
          e.to_string(),
        )
    }

    let entry_bytes = @epubpkg.read_part_bytes(pkg, entry.path) catch {
      e =>
        raise @cor.AppError(
          "epub extracted tree failed: read entry failed for " +
          entry.path +
          ": " +
          e.to_string(),
        )
    }
    total_materialized += entry_bytes.length()
    @fs.write_bytes_to_file(dst, entry_bytes) catch {
      e =>
        raise @cor.AppError(
          "epub extracted tree failed: write entry failed for " +
          entry.path +
          ": " +
          e.to_string(),
        )
    }
  }

  skipped
}

///|
fn nav_item_is_in_spine(pkg : @epubpkg.EpubPackage) -> Bool {
  match pkg.nav_item {
    Some(nav_item) => {
      for spine_item in pkg.spine {
        if spine_item.resolved_path == nav_item.resolved_path {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn emit_nav_toc_if_present(
  doc : @cor.Document,
  final_md : StringBuilder,
  pkg : @epubpkg.EpubPackage,
) -> Unit {
  if pkg.nav_points.length() == 0 {
    return
  }

  let heading_index = doc.blocks.val.length()
  final_md.write_string("# Table of Contents\n\n")
  @cor.push_with_origin(
    doc,
    @cor.Block::Heading(1, "Table of Contents"),
    Some({
      source_name: Some(pkg.source_name),
      page: None,
      slide: None,
      sheet: None,
      block_index: Some(heading_index),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref: None,
      relationship_id: None,
      key_path: pkg.nav_item.map(fn(item) { item.resolved_path }),
    }),
  )

  for point in pkg.nav_points {
    final_md.write_string("- [")
    final_md.write_string(point.label)
    final_md.write_string("](")
    final_md.write_string(rewrite_epub_href(point.href))
    final_md.write_string(")\n")
    @cor.push_with_origin(
      doc,
      @cor.Block::RichListItem(false, 0, [
        @cor.Inline::Link(point.label, rewrite_epub_href(point.href)),
      ]),
      Some({
        source_name: Some(pkg.source_name),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: Some(["Table of Contents"]),
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: pkg.nav_item.map(fn(item) { item.resolved_path }),
      }),
    )
  }
  final_md.write_string("\n")
}

///|
fn emit_cover_if_present(
  doc : @cor.Document,
  final_md : StringBuilder,
  pkg : @epubpkg.EpubPackage,
  extracted_root : String,
  archive_out_dir : String,
  used_ids : Map[String, Int],
) -> Unit {
  let cover_item = match pkg.cover_item {
    Some(v) => v
    None => return
  }

  let normalized_cover = cover_item.resolved_path
  let cover_src = extracted_entry_path(extracted_root, normalized_cover) catch {
    _ => return
  }
  if !@fs.path_exists(cover_src) {
    return
  }

  let ext = image_ext_from_src(normalized_cover)
  let entry_id = unique_entry_id(normalized_cover, used_ids)
  let rel_path = "assets/archive/" + entry_id + "/image01." + ext
  let out_path = archive_out_dir + "/" + rel_path
  ensure_parent_dir(out_path) catch {
    _ => return
  }
  let data = @fs.read_file_to_bytes(cover_src) catch { _ => return }
  @fs.write_bytes_to_file(out_path, data) catch {
    _ => return
  }

  let alt = cover_alt_text(normalized_cover)
  final_md.write_string("![")
  final_md.write_string(alt)
  final_md.write_string("](")
  final_md.write_string(rel_path)
  final_md.write_string(")\n\n")

  let origin : @cor.Origin = {
    source_name: Some(pkg.source_name),
    page: None,
    slide: None,
    sheet: None,
    block_index: Some(doc.blocks.val.length()),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: None,
    relationship_id: None,
    key_path: Some(normalized_cover),
  }
  @cor.push_with_origin(
    doc,
    @cor.Block::ImageBlock({
      path: rel_path,
      alt_text: Some(alt),
      title: None,
      caption: None,
      origin: Some(origin),
    }),
    Some(origin),
  )
  @cor.set_asset_origin(doc, rel_path, {
    source_name: Some(pkg.source_name),
    page: None,
    slide: None,
    sheet: None,
    origin_id: Some("epub:" + normalized_cover + ":cover"),
    nearby_caption: None,
    object_ref: None,
    relationship_id: None,
    source_path: Some(normalized_cover),
    row_index: None,
    column_index: None,
    key_path: Some(normalized_cover),
  })
}

///|
fn cover_alt_text(path : String) -> String {
  let base = @cor.basename(path)
  if base.trim() == "" {
    "cover image"
  } else {
    base
  }
}

///|
fn image_ext_from_src(src : String) -> String {
  let lower = src.to_lower()
  if lower.has_suffix(".png") {
    return "png"
  }
  if lower.has_suffix(".jpg") {
    return "jpg"
  }
  if lower.has_suffix(".jpeg") {
    return "jpeg"
  }
  if lower.has_suffix(".gif") {
    return "gif"
  }
  if lower.has_suffix(".bmp") {
    return "bmp"
  }
  if lower.has_suffix(".webp") {
    return "webp"
  }
  if lower.has_suffix(".tif") || lower.has_suffix(".tiff") {
    return "tiff"
  }
  "img"
}

///|
fn rewrite_epub_href(href : String) -> String {
  let trimmed = href.trim().to_owned()
  if trimmed == "" {
    return trimmed
  }
  if trimmed.has_prefix("#") {
    return trimmed
  }
  let lower = trimmed.to_lower()
  if lower.has_prefix("http://") ||
    lower.has_prefix("https://") ||
    lower.has_prefix("data:") ||
    lower.has_prefix("//") {
    return trimmed
  }
  trimmed
}

///|
fn append_converted_entry(
  doc : @cor.Document,
  final_md : StringBuilder,
  subdoc : @cor.Document,
  epub_name : String,
  entry_path : String,
  entry_md : String,
) -> Unit {
  append_entry_heading(doc, final_md, epub_name, entry_path)
  final_md.write_string(trim_trailing_newlines(entry_md))
  final_md.write_string("\n\n")

  for i in 0..<subdoc.blocks.val.length() {
    let final_index = doc.blocks.val.length()
    @cor.push_with_origin(
      doc,
      rewrite_block_for_epub(
        subdoc.blocks.val[i],
        epub_name,
        entry_path,
        final_index,
      ),
      Some(
        rewrite_block_origin(
          origin_at(subdoc, i),
          epub_name,
          entry_path,
          final_index,
        ),
      ),
    )
  }

  for entry in subdoc.asset_origins.val {
    let (path, origin) = entry
    @cor.set_asset_origin(doc, path, origin)
  }
}

///|
fn append_warning_entry(
  doc : @cor.Document,
  final_md : StringBuilder,
  epub_name : String,
  entry_path : String,
  message : String,
) -> Unit {
  append_entry_heading(doc, final_md, epub_name, entry_path)
  final_md.write_string("> ")
  final_md.write_string(message)
  final_md.write_string("\n\n")
  @cor.push_with_origin(
    doc,
    @cor.Block::BlockQuote(message),
    Some(epub_origin(epub_name, entry_path, doc.blocks.val.length())),
  )
}

///|
fn append_entry_heading(
  doc : @cor.Document,
  final_md : StringBuilder,
  epub_name : String,
  entry_path : String,
) -> Unit {
  final_md.write_string("# ")
  final_md.write_string(entry_path)
  final_md.write_string("\n\n")
  @cor.push_with_origin(
    doc,
    @cor.Block::Heading(1, entry_path),
    Some(epub_origin(epub_name, entry_path, doc.blocks.val.length())),
  )
}

///|
fn remap_subdoc_assets(
  subdoc : @cor.Document,
  entry_id : String,
  entry_out_dir : String,
  archive_out_dir : String,
  epub_source_name : String,
  entry_path : String,
) -> @cor.Document raise {
  let asset_paths = collect_subdoc_asset_paths(subdoc)
  if asset_paths.length() == 0 {
    return subdoc
  }

  let path_map : Map[String, String] = Map::new()
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
      remap_asset_origin(old_origin, new_path, epub_source_name, entry_path),
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
        subdoc, old_path, new_path, epub_source_name, entry_path,
      ),
    )
  }

  remapped
}

///|
fn collect_subdoc_asset_paths(doc : @cor.Document) -> Array[String] {
  let seen : Map[String, Bool] = Map::new()

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
  out.sort_by(fn(a, b) { a[:].lexical_compare(b[:]) })
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
        "epub asset remap failed for " +
        entry_path +
        ": create destination failed: " +
        e.to_string(),
      )
  }

  let data = @fs.read_file_to_bytes(src) catch {
    e =>
      raise @cor.AppError(
        "epub asset remap failed for " +
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
        "epub asset remap failed for " +
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
  epub_source_name : String,
  entry_path : String,
) -> @cor.AssetOrigin {
  {
    ..origin,
    source_name: Some(epub_source_name),
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
  "epub:" + entry_path + ":" + suffix
}

///|
fn synthesize_remapped_asset_origin(
  doc : @cor.Document,
  old_path : String,
  new_path : String,
  epub_source_name : String,
  entry_path : String,
) -> @cor.AssetOrigin {
  let nearby_caption = match find_image_data_by_path(doc, old_path) {
    Some(img) => img.caption
    None => None
  }

  {
    source_name: Some(epub_source_name),
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

///|
fn origin_at(doc : @cor.Document, index : Int) -> @cor.Origin? {
  if index < 0 || index >= doc.block_origins.val.length() {
    None
  } else {
    doc.block_origins.val[index]
  }
}

///|
fn epub_origin(
  epub_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Origin {
  {
    source_name: Some(epub_name),
    page: None,
    slide: None,
    sheet: None,
    block_index: Some(index),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: None,
    relationship_id: None,
    key_path: Some(entry_path),
  }
}

///|
fn rewrite_block_origin(
  origin : @cor.Origin?,
  epub_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Origin {
  match origin {
    Some(o) =>
      {
        source_name: Some(epub_name),
        page: o.page,
        slide: o.slide,
        sheet: o.sheet,
        block_index: Some(index),
        heading_path: o.heading_path,
        line_start: o.line_start,
        line_end: o.line_end,
        row_index: o.row_index,
        column_index: o.column_index,
        object_ref: o.object_ref,
        relationship_id: o.relationship_id,
        key_path: Some(entry_path),
      }
    None => epub_origin(epub_name, entry_path, index)
  }
}

///|
fn rewrite_block_for_epub(
  block : @cor.Block,
  epub_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Block {
  match block {
    @cor.Block::ImageBlock(img) =>
      @cor.Block::ImageBlock({
        ..img,
        origin: Some(
          rewrite_block_origin(img.origin, epub_name, entry_path, index),
        ),
      })
    _ => block
  }
}

///|
fn spine_media_type_lower(item : @epubpkg.EpubSpineItem) -> String {
  match item.manifest_item.media_type {
    Some(v) => v.trim().to_owned().to_lower()
    None => ""
  }
}

///|
fn show_spine_media_type(item : @epubpkg.EpubSpineItem) -> String {
  match item.manifest_item.media_type {
    Some(v) => if v.trim() == "" { "(empty)" } else { v.trim().to_owned() }
    None => "(missing)"
  }
}

///|
fn is_supported_spine_item(media_type : String, ext : String) -> Bool {
  match media_type {
    "application/xhtml+xml" | "text/html" => true
    _ =>
      match ext {
        "xhtml" | "html" | "htm" => true
        _ => false
      }
  }
}

///|
fn file_ext_lower(path : String) -> String {
  let n = path.length()
  if n == 0 {
    return ""
  }
  let mut i = n - 1
  while i >= 0 {
    if path[i] == '.' {
      if i == n - 1 {
        return ""
      }
      return path[i + 1:].to_owned().to_lower()
    }
    i -= 1
  }
  ""
}

///|
fn unique_entry_id(path : String, used : Map[String, Int]) -> String {
  let base = safe_entry_id(path)
  let count = used.get(base).unwrap_or(0) + 1
  used.set(base, count)
  if count == 1 {
    base
  } else {
    base + "_" + count.to_string()
  }
}

///|
fn safe_entry_id(path : String) -> String {
  let out : Array[Char] = []
  for ch in path.to_array() {
    if is_safe_id_char(ch) {
      out.push(ch)
    } else {
      out.push('_')
    }
  }
  let value = String::from_array(out).trim().to_owned()
  if value == "" {
    "entry"
  } else {
    value
  }
}

///|
fn is_safe_id_char(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '.' ||
  ch == '_' ||
  ch == '-'
}

///|
fn epub_tmp_dir(input_path : String) -> String {
  let root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
  root + "/epub/" + safe_entry_id(@cor.basename(input_path))
}

///|
let epub_archive_run_serial : Ref[Int] = { val: 0 }

///|
fn remove_dir_recursive(path : String) -> Unit raise {
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
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  ensure_dir_tree(path)
}

///|
fn allocate_archive_run_dir(base_root : String, prefix : String) -> String {
  epub_archive_run_serial.val += 1
  let serial = epub_archive_run_serial.val
  let stamp = @env.now().to_string()
  let trimmed_base = trim_trailing_slashes(base_root)
  let mut suffix = stamp + "-" + serial.to_string()
  let mut candidate = trimmed_base + "/" + prefix + "-" + suffix
  while true {
    if !@fs.path_exists(candidate) {
      return candidate
    }
    epub_archive_run_serial.val += 1
    suffix = stamp + "-" + epub_archive_run_serial.val.to_string()
    candidate = trimmed_base + "/" + prefix + "-" + suffix
  }
  candidate
}

///|
fn cleanup_archive_run_dir(path : String) -> Unit raise {
  let trimmed = trim_trailing_slashes(path)
  if trimmed == "" || trimmed == "." || trimmed == "/" {
    return
  }
  remove_dir_recursive(trimmed)
}

///|
fn ensure_parent_dir(path : String) -> Unit raise {
  let dir = dirname_of_path(path)
  if dir != "" && dir != "." {
    ensure_dir_tree(dir)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }
  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }
    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    if !@fs.path_exists(next) {
      @fs.create_dir(next)
    }
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }
  ignore(flush(part, current))
}

///|
fn dirname_of_path(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
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
fn normalize_entry_path(entry_path : String) -> String? {
  if entry_path.trim() == "" || entry_path.has_prefix("/") {
    return None
  }
  if entry_path.length() >= 2 && entry_path[1] == ':' {
    return None
  }

  let parts = entry_path.split("/")
  let clean : Array[String] = []
  for part in parts {
    let segment = part.trim().to_owned()
    if segment == "" || segment == "." || segment == ".." {
      return None
    }
    clean.push(segment)
  }

  if clean.length() == 0 {
    None
  } else {
    Some(clean.join("/"))
  }
}

///|
fn extracted_entry_path(
  extracted_root : String,
  entry_path : String,
) -> String raise {
  let normalized = match normalize_entry_path(entry_path) {
    Some(path) => path
    None =>
      raise @cor.AppError(
        "epub extracted tree failed: unsafe materialized path: " + entry_path,
      )
  }
  let root = trim_trailing_slashes(extracted_root)
  let out = root + "/" + normalized
  let prefix = if root.has_suffix("/") { root } else { root + "/" }
  if !out.has_prefix(prefix) {
    raise @cor.AppError(
      "epub extracted tree failed: materialized path escaped root: " +
      entry_path,
    )
  }
  out
}

///|
fn trim_trailing_slashes(path : String) -> String {
  let mut end = path.length()
  while end > 1 && path[end - 1] == '/' {
    end -= 1
  }
  path[:end].to_owned()
}

///|
fn trim_trailing_newlines(text : String) -> String {
  let mut end = text.length()
  while end > 0 && (text[end - 1] == '\n' || text[end - 1] == '\r') {
    end -= 1
  }
  text[:end].to_owned()
}
