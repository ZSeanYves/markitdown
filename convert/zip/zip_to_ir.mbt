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
pub fn parse_zip(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
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
  plans.sort_by((a, b) => compare_zip_path(a.path, b.path))

  let final_md = StringBuilder::new()
  let used_ids : Map[String, Int] = Map::new()
  let mut total_decoded = 0

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
    if is_explicitly_deferred_ext(ext) {
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: unsupported file type for ZIP container phase 1: " + ext,
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

    let entry_id = unique_entry_id(plan.path, used_ids)
    let entry_root = tmp_root + "/entries/" + entry_id
    let entry_out = tmp_root + "/out/" + entry_id
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
    ensure_dir_tree(entry_out) catch {
      e => {
        append_warning_entry(
          doc,
          final_md,
          zip_name,
          plan.path,
          "Conversion failed: create entry output dir failed: " + e.to_string(),
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

    let subdoc = parse_supported_entry(entry_path, ext, entry_out, max_heading) catch {
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
    if doc_has_assets(subdoc) {
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: entry produced assets; ZIP asset namespacing is not enabled in this phase",
      )
      continue
    }
    append_converted_entry(
      doc,
      final_md,
      subdoc,
      zip_name,
      plan.path,
      @cor.emit_markdown(subdoc),
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
fn parse_supported_entry(
  input_path : String,
  ext : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  match ext {
    "html" => @html.parse_html(input_path, out_dir, max_heading)
    "htm" => @html.parse_html(input_path, out_dir, max_heading)
    "csv" => @csv.parse_csv(input_path, out_dir, max_heading)
    "tsv" => @csv.parse_tsv(input_path, out_dir, max_heading)
    "json" => @json.parse_json(input_path, out_dir, max_heading)
    "yaml" => @yaml.parse_yaml(input_path, out_dir, max_heading)
    "yml" => @yaml.parse_yaml(input_path, out_dir, max_heading)
    "md" => @md.parse_markdown(input_path, out_dir, max_heading)
    "markdown" => @md.parse_markdown(input_path, out_dir, max_heading)
    _ => raise @cor.AppError("unsupported zip entry type: " + ext)
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
    @cor.push_with_origin(
      doc,
      subdoc.blocks.val[i],
      Some(
        rewrite_block_origin(
          origin_at(subdoc, i),
          zip_name,
          entry_path,
          doc.blocks.val.length(),
        ),
      ),
    )
  }
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
    "md"
    | "markdown"
    | "csv"
    | "tsv"
    | "json"
    | "yaml"
    | "yml"
    | "html"
    | "htm" => true
    _ => false
  }
}

///|
fn is_explicitly_deferred_ext(ext : String) -> Bool {
  match ext {
    "docx" | "xlsx" | "pptx" | "pdf" => true
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
