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
  let part_cache = new_epub_part_cache(MAX_SINGLE_ENTRY_BYTES)

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
  let materialization_skips = materialize_safe_archive_tree(
    pkg, part_cache, extracted_root,
  ) catch {
    e => raise @cor.AppError("epub: " + e.to_string())
  }
  let entry_by_path : Map[String, @epubpkg.EpubArchiveEntry] = Map([])
  for entry in pkg.entries {
    entry_by_path.set(entry.path, entry)
  }

  let final_md = StringBuilder::new()
  let used_ids : Map[String, Int] = Map([])
  let nav_in_spine = nav_item_is_in_spine(pkg)

  emit_cover_if_present(
    doc, final_md, pkg, part_cache, extracted_root, archive_out_dir, used_ids,
  )
  if !nav_in_spine {
    emit_nav_toc_if_present(doc, final_md, pkg)
  }

  for spine_item in pkg.spine {
    if !spine_item.linear {
      continue
    }

    let content_path = match spine_item.resolved_path {
      Some(v) => v
      None => {
        match spine_item.manifest_item {
          Some(manifest_item) =>
            append_warning_entry(
              doc,
              final_md,
              epub_name,
              non_package_spine_entry_path(spine_item, manifest_item.href),
              "Skipped: spine item targets non-package resource: " +
              manifest_item.href,
            )
          None => {
            let missing_entry_path = missing_manifest_entry_path(spine_item)
            append_warning_entry(
              doc,
              final_md,
              epub_name,
              missing_entry_path,
              "Skipped: spine item references missing manifest item: " +
              spine_item.idref,
            )
          }
        }
        continue
      }
    }
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

    let ext = @cor.file_ext_lower(content_path)
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

    let note_remapped_subdoc = namespace_epub_subdoc_notes(subdoc, entry_id)

    let remapped_subdoc = if doc_has_assets(note_remapped_subdoc) {
      remap_subdoc_assets(
        note_remapped_subdoc, entry_id, entry_out, archive_out_dir, epub_name, content_path,
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
      note_remapped_subdoc
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
fn nav_item_is_in_spine(pkg : @epubpkg.EpubPackage) -> Bool {
  match pkg.nav_item {
    Some(nav_item) => {
      for spine_item in pkg.spine {
        match spine_item.resolved_path {
          Some(path) => if path == nav_item.resolved_path { return true }
          None => ()
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
  part_cache : EpubPartCache,
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
  let data = read_epub_part_bytes_cached(part_cache, pkg, normalized_cover) catch {
    _ =>
      @fs.read_file_to_bytes(cover_src) catch {
        _ => return
      }
  }
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
fn missing_manifest_entry_path(spine_item : @epubpkg.EpubSpineItem) -> String {
  "(missing manifest item #" +
  spine_item.spine_index.to_string() +
  ": " +
  spine_item.idref +
  ")"
}

///|
fn non_package_spine_entry_path(
  spine_item : @epubpkg.EpubSpineItem,
  href : String,
) -> String {
  "(non-package spine target #" +
  spine_item.spine_index.to_string() +
  ": " +
  href +
  ")"
}

///|
fn spine_media_type_lower(item : @epubpkg.EpubSpineItem) -> String {
  match item.manifest_item {
    Some(manifest_item) =>
      match manifest_item.media_type {
        Some(v) => v.trim().to_owned().to_lower()
        None => ""
      }
    None => ""
  }
}

///|
fn show_spine_media_type(item : @epubpkg.EpubSpineItem) -> String {
  match item.manifest_item {
    Some(manifest_item) =>
      match manifest_item.media_type {
        Some(v) => if v.trim() == "" { "(empty)" } else { v.trim().to_owned() }
        None => "(missing)"
      }
    None => "(missing manifest item)"
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
