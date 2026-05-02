///|
const MAX_ZIP_ENTRIES : Int = 200

///|
const MAX_SINGLE_ENTRY_BYTES : Int = 128 * 1024 * 1024

///|
const MAX_TOTAL_ENTRY_BYTES : Int = 256 * 1024 * 1024

///|
priv struct PlannedEntry {
  raw_path : String
  path : String
  uncompressed_size : Int
}

///|
pub async fn parse_zip(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("zip: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("zip: read failed: " + e.to_string())
  }
  let archive = @zipraw.open_zip(bytes) catch {
    e => raise @cor.AppError("zip: open failed: " + e.to_string())
  }

  let doc = @cor.new_document()
  let zip_name = @cor.basename(input_path)
  let tmp_root = zip_tmp_dir(input_path)
  ensure_dir_tree(tmp_root) catch {
    e => raise @cor.AppError("zip: create temp dir failed: " + e.to_string())
  }
  let archive_out_dir = if out_dir.trim() == "" {
    tmp_root + "/archive-out"
  } else {
    out_dir
  }
  ensure_dir_tree(archive_out_dir) catch {
    e =>
      raise @cor.AppError(
        "zip: create archive output dir failed: " + e.to_string(),
      )
  }

  let plans : Array[PlannedEntry] = []
  let unsafe_warnings : Map[String, String] = Map::new()
  for meta in @zipraw.list_entries(archive) {
    match plan_entry(meta.name) {
      EntryPlan::Directory => ()
      EntryPlan::Hidden => ()
      EntryPlan::Unsafe(display) =>
        unsafe_warnings.set(display, "Skipped: unsafe archive path")
      EntryPlan::Visible(path) =>
        plans.push({
          raw_path: meta.name,
          path,
          uncompressed_size: meta.uncompressed_size,
        })
    }
  }
  ensure_no_normalized_path_collisions(plans)
  plans.sort_by((a, b) => compare_zip_path(a.path, b.path))

  let final_md = StringBuilder::new()
  let used_ids : Map[String, Int] = Map::new()
  let mut total_decoded = 0
  let extracted_root = tmp_root + "/extracted"
  let mut shared_extracted_ready = false

  for i in 0..<plans.length() {
    let plan = plans[i]
    if i >= MAX_ZIP_ENTRIES {
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: entry count limit exceeded",
      )
      continue
    }

    let ext = file_ext_lower(plan.path)
    if is_nested_archive_ext(ext) {
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: nested archive is not supported: " + ext,
      )
      continue
    }
    if !is_supported_entry_ext(ext) {
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: unsupported file type: " + ext,
      )
      continue
    }
    if plan.uncompressed_size > MAX_SINGLE_ENTRY_BYTES {
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: entry too large: " +
        plan.uncompressed_size.to_string() +
        " bytes",
      )
      continue
    }
    if total_decoded + plan.uncompressed_size > MAX_TOTAL_ENTRY_BYTES {
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: total decoded size limit exceeded",
      )
      continue
    }

    let entry_bytes = @zipraw.read_entry(
      archive,
      plan.raw_path,
      max_output_size=MAX_SINGLE_ENTRY_BYTES,
    ) catch {
      e => {
        append_warning_entry(
          doc,
          final_md,
          zip_name,
          plan.path,
          "Conversion failed: zip read failed: " + e.to_string(),
        )
        continue
      }
    }
    total_decoded += entry_bytes.length()

    let use_shared_extracted_input = is_html_entry_ext(ext) &&
      html_entry_has_local_image_refs(entry_bytes)
    if use_shared_extracted_input && !shared_extracted_ready {
      materialize_safe_archive_tree(archive, plans, extracted_root) catch {
        e => {
          append_warning_entry(
            doc,
            final_md,
            zip_name,
            plan.path,
            "Conversion failed: " + e.to_string(),
          )
          continue
        }
      }
      shared_extracted_ready = true
    }

    let entry_id = unique_entry_id(plan.path, used_ids)
    let entry_root = tmp_root + "/entries/" + entry_id
    let entry_out = tmp_root + "/out/" + entry_id
    recreate_clean_dir(entry_root) catch {
      e => {
        append_warning_entry(
          doc,
          final_md,
          zip_name,
          plan.path,
          "Conversion failed: reset entry temp dir failed: " + e.to_string(),
        )
        continue
      }
    }
    recreate_clean_dir(entry_out) catch {
      e => {
        append_warning_entry(
          doc,
          final_md,
          zip_name,
          plan.path,
          "Conversion failed: reset entry output dir failed: " + e.to_string(),
        )
        continue
      }
    }
    let input_path = if use_shared_extracted_input {
      extracted_entry_path(extracted_root, plan.path) catch {
        e => {
          append_warning_entry(
            doc,
            final_md,
            zip_name,
            plan.path,
            "Conversion failed: " + e.to_string(),
          )
          continue
        }
      }
    } else {
      let entry_path = entry_root + "/" + plan.path
      ensure_parent_dir(entry_path) catch {
        e => {
          append_warning_entry(
            doc,
            final_md,
            zip_name,
            plan.path,
            "Conversion failed: create temp path failed: " + e.to_string(),
          )
          continue
        }
      }
      @fs.write_bytes_to_file(entry_path, entry_bytes) catch {
        e => {
          append_warning_entry(
            doc,
            final_md,
            zip_name,
            plan.path,
            "Conversion failed: write temp entry failed: " + e.to_string(),
          )
          continue
        }
      }
      entry_path
    }

    let subdoc = parse_supported_entry(input_path, ext, entry_out, max_heading) catch {
      e => {
        append_warning_entry(
          doc,
          final_md,
          zip_name,
          plan.path,
          "Conversion failed: " + e.to_string(),
        )
        continue
      }
    }

    let remapped_subdoc = if doc_has_assets(subdoc) {
      remap_subdoc_assets(
        subdoc,
        entry_id,
        entry_out,
        archive_out_dir,
        zip_name,
        plan.path,
      ) catch {
        e => {
          append_warning_entry(
            doc,
            final_md,
            zip_name,
            plan.path,
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
      zip_name,
      plan.path,
      @cor.emit_markdown(remapped_subdoc),
    )
  }

  let unsafe_paths = sorted_warning_keys(unsafe_warnings)
  for path in unsafe_paths {
    match unsafe_warnings.get(path) {
      Some(message) =>
        append_warning_entry(doc, final_md, zip_name, path, message)
      None => ()
    }
  }

  @cor.set_passthrough_markdown(doc, final_md.to_string())
  doc
}

///|
async fn parse_supported_entry(
  input_path : String,
  ext : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document {
  match ext {
    "docx" => @doc.parse_docx(input_path, out_dir, max_heading)
    "pdf" =>
      @pdf.parse_pdf(
        input_path,
        out_dir,
        max_heading,
        None,
        false,
        false,
        false,
      )
    "xlsx" => @xlsx.parse_xlsx(input_path, out_dir, max_heading)
    "pptx" => @pptx.parse_pptx(input_path, out_dir, max_heading)
    "html" => @html.parse_html(input_path, out_dir, max_heading)
    "htm" => @html.parse_html(input_path, out_dir, max_heading)
    "csv" => @csv.parse_csv(input_path, out_dir, max_heading)
    "tsv" => @csv.parse_tsv(input_path, out_dir, max_heading)
    "txt" => @txt.parse_txt(input_path, out_dir, max_heading)
    "xml" => @xml.parse_xml(input_path, out_dir, max_heading)
    "json" => @json.parse_json(input_path, out_dir, max_heading)
    "yaml" => @yaml.parse_yaml(input_path, out_dir, max_heading)
    "yml" => @yaml.parse_yaml(input_path, out_dir, max_heading)
    "md" => @md.parse_markdown(input_path, out_dir, max_heading)
    "markdown" => @md.parse_markdown(input_path, out_dir, max_heading)
    _ => raise @cor.AppError("unsupported zip entry type: " + ext)
  }
}

///|
fn remap_subdoc_assets(
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
fn materialize_safe_archive_tree(
  archive : @zipraw.ZipArchive,
  plans : Array[PlannedEntry],
  extracted_root : String,
) -> Unit raise {
  recreate_clean_dir(extracted_root) catch {
    e =>
      raise @cor.AppError(
        "zip extracted tree failed: reset temp dir failed: " + e.to_string(),
      )
  }

  let mut total_materialized = 0
  for i in 0..<plans.length() {
    let plan = plans[i]
    if i >= MAX_ZIP_ENTRIES {
      continue
    }
    if plan.uncompressed_size > MAX_SINGLE_ENTRY_BYTES {
      continue
    }
    if total_materialized + plan.uncompressed_size > MAX_TOTAL_ENTRY_BYTES {
      continue
    }

    let dst = extracted_entry_path(extracted_root, plan.path)
    ensure_parent_dir(dst) catch {
      e =>
        raise @cor.AppError(
          "zip extracted tree failed: create parent dir failed for " +
          plan.path +
          ": " +
          e.to_string(),
        )
    }

    let entry_bytes = @zipraw.read_entry(
      archive,
      plan.raw_path,
      max_output_size=MAX_SINGLE_ENTRY_BYTES,
    ) catch {
      e =>
        raise @cor.AppError(
          "zip extracted tree failed: read entry failed for " +
          plan.path +
          ": " +
          e.to_string(),
        )
    }
    total_materialized += entry_bytes.length()
    @fs.write_bytes_to_file(dst, entry_bytes) catch {
      e =>
        raise @cor.AppError(
          "zip extracted tree failed: write entry failed for " +
          plan.path +
          ": " +
          e.to_string(),
        )
    }
  }
}

///|
fn append_subdoc_asset_origins(
  doc : @cor.Document,
  subdoc : @cor.Document,
) -> Unit {
  for entry in subdoc.asset_origins.val {
    let (path, origin) = entry
    @cor.set_asset_origin(doc, path, origin)
  }
}

///|
fn append_converted_entry(
  doc : @cor.Document,
  final_md : StringBuilder,
  subdoc : @cor.Document,
  zip_name : String,
  entry_path : String,
  entry_md : String,
) -> Unit {
  append_entry_heading(doc, final_md, zip_name, entry_path)
  final_md.write_string(trim_trailing_newlines(entry_md))
  final_md.write_string("\n\n")
  for i in 0..<subdoc.blocks.val.length() {
    let final_index = doc.blocks.val.length()
    @cor.push_with_origin(
      doc,
      rewrite_block_for_zip(
        subdoc.blocks.val[i],
        zip_name,
        entry_path,
        final_index,
      ),
      Some(
        rewrite_block_origin(
          origin_at(subdoc, i),
          zip_name,
          entry_path,
          final_index,
        ),
      ),
    )
  }
  append_subdoc_asset_origins(doc, subdoc)
}

///|
fn append_warning_entry(
  doc : @cor.Document,
  final_md : StringBuilder,
  zip_name : String,
  entry_path : String,
  message : String,
) -> Unit {
  append_entry_heading(doc, final_md, zip_name, entry_path)
  final_md.write_string("> ")
  final_md.write_string(message)
  final_md.write_string("\n\n")
  @cor.push_with_origin(
    doc,
    @cor.Block::BlockQuote(message),
    Some(zip_origin(zip_name, entry_path, doc.blocks.val.length())),
  )
}

///|
fn append_entry_heading(
  doc : @cor.Document,
  final_md : StringBuilder,
  zip_name : String,
  entry_path : String,
) -> Unit {
  final_md.write_string("# ")
  final_md.write_string(entry_path)
  final_md.write_string("\n\n")
  @cor.push_with_origin(
    doc,
    @cor.Block::Heading(1, entry_path),
    Some(zip_origin(zip_name, entry_path, doc.blocks.val.length())),
  )
}

///|
fn zip_origin(
  zip_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Origin {
  {
    source_name: Some(zip_name),
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
fn origin_at(doc : @cor.Document, index : Int) -> @cor.Origin? {
  if index < 0 || index >= doc.block_origins.val.length() {
    None
  } else {
    doc.block_origins.val[index]
  }
}

///|
fn rewrite_block_origin(
  origin : @cor.Origin?,
  zip_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Origin {
  match origin {
    Some(o) =>
      {
        source_name: Some(zip_name),
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
    None => zip_origin(zip_name, entry_path, index)
  }
}

///|
fn rewrite_block_for_zip(
  block : @cor.Block,
  zip_name : String,
  entry_path : String,
  index : Int,
) -> @cor.Block {
  match block {
    @cor.Block::ImageBlock(img) =>
      @cor.Block::ImageBlock({
        ..img,
        origin: Some(
          rewrite_block_origin(img.origin, zip_name, entry_path, index),
        ),
      })
    _ => block
  }
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

///|
fn html_entry_has_local_image_refs(entry_bytes : Bytes) -> Bool {
  let html = @cor.utf8_bytes_to_string(entry_bytes) catch { _ => return false }
  let mut pos = 0

  while true {
    let img0 = find_ascii_case_insensitive(html, "<img", pos)
    match img0 {
      None => break
      Some(start) =>
        match find_substring(html, ">", start + 4) {
          None => break
          Some(end_) => {
            let tag = html[start:end_ + 1].to_owned()
            match read_html_attr_value(tag, "src") {
              Some(src) => if is_local_html_image_src(src) { return true }
              None => ()
            }
            pos = end_ + 1
          }
        }
    }
  }

  false
}

///|
fn find_substring(s : String, pat : String, start : Int) -> Int? {
  let n = s.length()
  let m = pat.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n || n < m {
    return None
  }

  let last = n - m
  let mut i = start
  while i <= last {
    if s[i:i + m] == pat {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn find_ascii_case_insensitive(s : String, pat : String, start : Int) -> Int? {
  let s_chars = s.to_array()
  let pat_chars = pat.to_array()
  let n = s_chars.length()
  let m = pat_chars.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n || n < m {
    return None
  }

  let last = n - m
  let mut i = start
  while i <= last {
    let mut matched = true
    let mut j = 0
    while j < m {
      if ascii_lower_char(s_chars[i + j]) != ascii_lower_char(pat_chars[j]) {
        matched = false
        break
      }
      j += 1
    }
    if matched {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn ascii_lower_char(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    Int::unsafe_to_char(ch.to_int() + ('a'.to_int() - 'A'.to_int()))
  } else {
    ch
  }
}

///|
fn read_html_attr_value(tag : String, key : String) -> String? {
  let chars = tag.to_array()
  let key_lower = ascii_lower_string(key)
  let mut i = 0

  while i < chars.length() {
    while i < chars.length() && is_html_attr_space(chars[i]) {
      i += 1
    }
    while i < chars.length() &&
          (chars[i] == '<' || chars[i] == '>' || chars[i] == '/') {
      i += 1
    }

    let name_start = i
    while i < chars.length() && is_html_attr_name_char(chars[i]) {
      i += 1
    }
    if name_start == i {
      i += 1
      continue
    }

    let name = ascii_lower_string(String::from_array(chars[name_start:i]))
    while i < chars.length() && is_html_attr_space(chars[i]) {
      i += 1
    }
    if i >= chars.length() || chars[i] != '=' {
      continue
    }
    i += 1
    while i < chars.length() && is_html_attr_space(chars[i]) {
      i += 1
    }
    if i >= chars.length() {
      return None
    }

    let value = if chars[i] == '"' || chars[i] == '\'' {
      let quote = chars[i]
      i += 1
      let value_start = i
      while i < chars.length() && chars[i] != quote {
        i += 1
      }
      let out = String::from_array(chars[value_start:i])
      if i < chars.length() {
        i += 1
      }
      out
    } else {
      let value_start = i
      while i < chars.length() &&
            !is_html_attr_space(chars[i]) &&
            chars[i] != '>' {
        i += 1
      }
      String::from_array(chars[value_start:i])
    }

    if name == key_lower {
      return Some(value)
    }
  }

  None
}

///|
fn ascii_lower_string(s : String) -> String {
  let out : Array[Char] = []
  for ch in s.to_array() {
    out.push(ascii_lower_char(ch))
  }
  String::from_array(out)
}

///|
fn is_html_attr_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' || ch == '\f'
}

///|
fn is_html_attr_name_char(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == ':' ||
  ch == '.'
}

///|
fn is_local_html_image_src(src : String) -> Bool {
  let trimmed = normalize_html_src(src)
  if trimmed == "" {
    return false
  }
  let lower = trimmed.to_lower()
  !(trimmed.contains("\\") ||
  lower.has_prefix("http://") ||
  lower.has_prefix("https://") ||
  lower.has_prefix("data:") ||
  lower.has_prefix("//") ||
  lower.has_prefix("/") ||
  trimmed.contains("..") ||
  has_scheme_like_prefix(lower))
}

///|
fn normalize_html_src(src : String) -> String {
  let trimmed = src.trim()
  let mut end = trimmed.length()
  for i in 0..<trimmed.length() {
    if trimmed[i] == '?' || trimmed[i] == '#' {
      end = i
      break
    }
  }
  trimmed[:end].trim().to_owned()
}

///|
fn has_scheme_like_prefix(src : String) -> Bool {
  for i in 0..<src.length() {
    match src[i] {
      ':' => return i > 0
      '/' | '?' | '#' => return false
      _ => ()
    }
  }
  false
}

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
priv enum EntryPlan {
  Directory
  Hidden
  Unsafe(String)
  Visible(String)
}

///|
fn plan_entry(raw_path : String) -> EntryPlan {
  if raw_path.has_suffix("/") || raw_path.has_suffix("\\") {
    return EntryPlan::Directory
  }
  match normalize_zip_entry_path(raw_path) {
    None => EntryPlan::Unsafe(display_path(raw_path))
    Some(path) =>
      if is_hidden_or_macos_metadata(path) {
        EntryPlan::Hidden
      } else {
        EntryPlan::Visible(path)
      }
  }
}

///|
fn ensure_no_normalized_path_collisions(
  plans : Array[PlannedEntry],
) -> Unit raise {
  let seen : Map[String, String] = Map::new()
  for plan in plans {
    match seen.get(plan.path) {
      Some(first_raw_path) =>
        raise @cor.AppError(
          "zip: normalized path collision: " +
          plan.path +
          " (" +
          display_path(first_raw_path) +
          " vs " +
          display_path(plan.raw_path) +
          ")",
        )
      None => seen.set(plan.path, plan.raw_path)
    }
  }
}

///|
fn normalize_zip_entry_path(raw_path : String) -> String? {
  let p = raw_path.replace(old="\\", new="/")
  if p.trim() == "" || p.has_prefix("/") {
    return None
  }
  if p.length() >= 2 && p[1] == ':' {
    return None
  }
  let parts = p.split("/")
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
fn display_path(raw_path : String) -> String {
  let p = raw_path.replace(old="\\", new="/")
  if p.trim() == "" {
    "(empty path)"
  } else {
    p
  }
}

///|
fn is_hidden_or_macos_metadata(path : String) -> Bool {
  if path == "__MACOSX" || path.has_prefix("__MACOSX/") {
    return true
  }
  let base = @cor.basename(path)
  base == ".DS_Store" || base.has_prefix("._")
}

///|
fn is_supported_entry_ext(ext : String) -> Bool {
  match ext {
    "docx"
    | "pdf"
    | "xlsx"
    | "pptx"
    | "md"
    | "markdown"
    | "csv"
    | "tsv"
    | "txt"
    | "xml"
    | "json"
    | "yaml"
    | "yml"
    | "html"
    | "htm" => true
    _ => false
  }
}

///|
fn is_html_entry_ext(ext : String) -> Bool {
  match ext {
    "html" | "htm" => true
    _ => false
  }
}

///|
fn is_nested_archive_ext(ext : String) -> Bool {
  match ext {
    "zip" | "jar" | "epub" => true
    _ => false
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
fn sorted_warning_keys(warnings : Map[String, String]) -> Array[String] {
  let keys : Array[String] = []
  for pair in warnings {
    keys.push(pair.0)
  }
  keys.sort_by((a, b) => compare_zip_path(a, b))
  keys
}

///|
fn compare_zip_path(a : String, b : String) -> Int {
  a[:].lexical_compare(b[:])
}

///|
fn zip_tmp_dir(input_path : String) -> String {
  let root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
  root + "/zip/" + safe_entry_id(@cor.basename(input_path))
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
fn trim_trailing_newlines(text : String) -> String {
  let mut end = text.length()
  while end > 0 && (text[end - 1] == '\n' || text[end - 1] == '\r') {
    end -= 1
  }
  text[:end].to_owned()
}

///|
fn extracted_entry_path(
  extracted_root : String,
  entry_path : String,
) -> String raise {
  let normalized = match normalize_zip_entry_path(entry_path) {
    Some(path) => path
    None =>
      raise @cor.AppError(
        "zip extracted tree failed: unsafe materialized path: " +
        display_path(entry_path),
      )
  }
  let root = trim_trailing_slashes(extracted_root)
  let out = root + "/" + normalized
  let prefix = if root.has_suffix("/") { root } else { root + "/" }
  if !out.has_prefix(prefix) {
    raise @cor.AppError(
      "zip extracted tree failed: materialized path escaped root: " +
      display_path(entry_path),
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
