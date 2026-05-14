///|
/// HTML converter entrypoint.
///
/// Model boundary:
/// - uses a lightweight DOM-like semantic scan (not browser layout engine)
/// - focuses on robust structural blocks for markdown + metadata sidecar
/// - keeps provenance lightweight at block/asset level
pub fn parse_html(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("html: file not found: " + input_path)
  }

  let profile = if html_profile_enabled() {
    Some(new_html_profile_report(input_path))
  } else {
    None
  }

  let read_started = @env.now()
  let raw_bs = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("html: read failed: " + e.to_string())
  }
  html_profile_add_stage(
    profile,
    "html_file_read",
    @env.now() - read_started,
    Some("bytes=" + raw_bs.length().to_string()),
  )

  let normalize_started = @env.now()
  let bs = normalize_html_input_bytes(raw_bs)
  let scoped_bs = narrow_html_content_scope(bs)
  html_profile_add_stage(
    profile,
    "html_normalize_bytes",
    @env.now() - normalize_started,
    Some(
      "bytes=" +
      bs.length().to_string() +
      " scoped_bytes=" +
      scoped_bs.length().to_string(),
    ),
  )

  let doc = @cor.new_document()

  html_profile_set_active(profile)
  defer html_profile_set_active(None)

  let scan_started = @env.now()
  let nodes = scan_html_nodes(scoped_bs)
  html_profile_add_stage(
    profile,
    "html_dom_scan",
    @env.now() - scan_started,
    Some("nodes=" + nodes.length().to_string()),
  )

  let lowering_started = @env.now()
  let html_blocks = nodes_to_blocks(nodes, max_heading, input_path, out_dir)
  let local_asset_count = match profile {
    Some(rep) => rep.local_asset_count.val.to_string()
    None => "0"
  }
  let remote_asset_count = match profile {
    Some(rep) => rep.remote_asset_count.val.to_string()
    None => "0"
  }
  let unresolved_local_asset_count = match profile {
    Some(rep) => rep.unresolved_local_asset_count.val.to_string()
    None => "0"
  }
  let cached_asset_count = match profile {
    Some(rep) => rep.cached_asset_count.val.to_string()
    None => "0"
  }
  html_profile_add_stage(
    profile,
    "html_block_lowering",
    @env.now() - lowering_started,
    Some(
      "blocks=" +
      html_blocks.blocks.length().to_string() +
      " local_asset_count=" +
      local_asset_count +
      " remote_asset_count=" +
      remote_asset_count +
      " unresolved_local_asset_count=" +
      unresolved_local_asset_count +
      " cached_asset_count=" +
      cached_asset_count,
    ),
  )
  let blocks = html_blocks.blocks
  let src = @cor.basename(input_path)
  let mut asset_idx = 0

  for i in 0..<blocks.length() {
    match blocks[i] {
      @cor.Block::Image(_alt, path) => {
        asset_idx = asset_idx + 1
        @cor.set_asset_origin(doc, path, {
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: None,
          origin_id: Some("html-asset-" + asset_idx.to_string()),
          nearby_caption: None,
          object_ref: None,
          relationship_id: None,
          source_path: html_blocks.asset_source_paths.get(path),
          row_index: None,
          column_index: None,
          key_path: html_blocks.block_origins[i].map(fn(origin) {
            origin.key_path.unwrap_or("")
          }),
        })
      }
      @cor.Block::ImageBlock(img) => {
        asset_idx = asset_idx + 1
        @cor.set_asset_origin(doc, img.path, {
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: None,
          origin_id: Some("html-asset-" + asset_idx.to_string()),
          nearby_caption: img.caption,
          object_ref: None,
          relationship_id: None,
          source_path: html_blocks.asset_source_paths.get(img.path),
          row_index: None,
          column_index: None,
          key_path: html_blocks.block_origins[i].map(fn(origin) {
            origin.key_path.unwrap_or("")
          }),
        })
      }
      _ => ()
    }

    @cor.push_with_origin(
      doc,
      blocks[i],
      html_block_origin_with_index(
        html_blocks.block_origins[i],
        src,
        doc.blocks.val.length(),
      ),
    )
  }

  html_profile_add_stage(
    profile,
    "html_asset_discovery",
    match profile {
      Some(rep) => rep.asset_discovery_elapsed_ms.val
      None => 0
    },
    Some(
      "local_asset_count=" +
      local_asset_count +
      " remote_asset_count=" +
      remote_asset_count +
      " unresolved_local_asset_count=" +
      unresolved_local_asset_count,
    ),
  )
  html_profile_add_stage(
    profile,
    "html_asset_export",
    match profile {
      Some(rep) => rep.asset_export_elapsed_ms.val
      None => 0
    },
    Some(
      "local_asset_count=" +
      local_asset_count +
      " cached_asset_count=" +
      cached_asset_count,
    ),
  )
  html_profile_add_stage(
    profile,
    "html_document_build",
    0,
    Some("blocks=" + doc.blocks.val.length().to_string()),
  )

  maybe_write_html_profile_log(profile)
  doc
}

///|
fn normalize_html_input_bytes(bs : Bytes) -> Bytes {
  let n = bs.length()
  let mut start = 0
  if n >= 3 && bs[0] == 0xEF && bs[1] == 0xBB && bs[2] == 0xBF {
    start = 3
  }

  let out : Array[Byte] = []
  let mut i = start
  while i < n {
    let b = bs[i]
    if b == '\r'.to_int().to_byte() {
      out.push('\n'.to_int().to_byte())
      if i + 1 < n && bs[i + 1] == '\n'.to_int().to_byte() {
        i = i + 2
      } else {
        i = i + 1
      }
    } else {
      out.push(b)
      i = i + 1
    }
  }

  Bytes::from_array(out)
}

///|
fn narrow_html_content_scope(bs : Bytes) -> Bytes {
  match find_html_content_scope_inner(bs) {
    Some(inner) => inner
    None =>
      match find_tag_block_inner(bs, "body") {
        Some(inner) => inner
        None => bs
      }
  }
}

///|
fn find_html_content_scope_inner(bs : Bytes) -> Bytes? {
  match find_html_scope_inner_with_exact_root_token(bs) {
    Some(inner) => Some(inner)
    None =>
      match find_html_scope_inner_with_exact_content_id(bs) {
        Some(inner) => Some(inner)
        None =>
          match find_html_scope_inner_with_role_main(bs) {
            Some(inner) => Some(inner)
            None =>
              match find_html_scope_inner_with_strong_content_attr(bs) {
                Some(inner) => Some(inner)
                None =>
                  match find_tag_block_inner(bs, "article") {
                    Some(inner) => Some(inner)
                    None => find_tag_block_inner(bs, "main")
                  }
              }
          }
      }
  }
}

///|
fn find_html_scope_inner_with_exact_root_token(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) &&
    (
      html_scope_attr_contains_exact_root_token(tag, "id") ||
      html_scope_attr_contains_exact_root_token(tag, "class")
    )
  })
}

///|
fn find_html_scope_inner_with_strong_content_attr(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) &&
    !html_attr_value_has_noise_token(tag, "id") &&
    !html_attr_value_has_noise_token(tag, "class") &&
    (
      html_scope_attr_is_strong_content_root(tag, "id") ||
      html_scope_attr_is_strong_content_root(tag, "class")
    )
  })
}

///|
fn find_html_scope_inner_with_exact_content_id(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) &&
    html_scope_attr_is_exact_content_id(tag, "id")
  })
}

///|
fn find_html_scope_inner_with_role_main(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) && html_scope_role_is_main(tag)
  })
}

///|
fn find_html_container_block_inner_matching(
  bs : Bytes,
  matcher : (String, String) -> Bool,
) -> Bytes? {
  let lt = pat("<")
  let gt = pat(">")
  let mut pos = 0
  let n = bs.length()

  while pos < n {
    let open0 = find_bytes(bs, lt, pos)
    match open0 {
      None => return None
      Some(open_idx) =>
        match find_bytes(bs, gt, open_idx) {
          None => return None
          Some(gt_idx) => {
            let tag_bs = bs[open_idx:gt_idx + 1].to_owned()
            let tag = (@utf8.decode(tag_bs, ignore_bom=false) catch { _ => "" }).to_lower()
            match html_scope_open_tag_name(tag) {
              Some(tag_name) =>
                if matcher(tag_name, tag) {
                  let inner_start = gt_idx + 1
                  match find_matching_tag_end(bs, open_idx, tag_name) {
                    Some(close_idx) =>
                      return Some(bs[inner_start:close_idx].to_owned())
                    None => ()
                  }
                }
              None => ()
            }
            pos = gt_idx + 1
          }
        }
    }
  }

  None
}

///|
fn html_scope_open_tag_name(tag : String) -> String? {
  let lower = tag.to_lower()
  if !lower.has_prefix("<") ||
    lower.has_prefix("</") ||
    lower.has_prefix("<!") ||
    lower.has_prefix("<?") {
    return None
  }

  let n = lower.length()
  let mut i = 1
  while i < n && (lower[i] == ' ' || lower[i] == '\n' || lower[i] == '\t') {
    i += 1
  }
  let start = i
  while i < n {
    let ch = lower[i]
    if ch == ' ' || ch == '\n' || ch == '\t' || ch == '>' || ch == '/' {
      break
    }
    i += 1
  }

  if i > start {
    Some(lower[start:i].to_owned())
  } else {
    None
  }
}

///|
fn html_scope_is_candidate_tag(tag_name : String) -> Bool {
  tag_name == "div" ||
  tag_name == "section" ||
  tag_name == "article" ||
  tag_name == "main"
}

///|
fn html_scope_attr_contains_exact_root_token(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower()
      lower.contains("mw-content-text") || lower.contains("bodycontent")
    }
  }
}

///|
fn html_scope_attr_is_strong_content_root(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => {
      let words = html_scope_attr_words(value)
      let has_body = html_scope_words_contain(words, "body")
      let has_content = html_scope_words_contain(words, "content")
      (has_body && has_content) ||
      (html_scope_words_contain(words, "article") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "post") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "entry") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "story") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "chapter") && (has_body || has_content))
    }
  }
}

///|
fn html_scope_attr_is_exact_content_id(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower().trim().to_owned()
      lower == "content" || lower == "maincontent"
    }
  }
}

///|
fn html_scope_role_is_main(tag : String) -> Bool {
  read_html_attr_value(tag, "role")
  .map(fn(value) { value.to_lower().trim().to_owned() })
  .unwrap_or("") ==
  "main"
}

///|
fn html_scope_attr_words(value : String) -> Array[String] {
  let out : Array[String] = []
  let part : Array[Char] = []

  fn flush(out : Array[String], part : Array[Char]) -> Unit {
    if part.length() == 0 {
      return
    }
    out.push(String::from_array(part))
    part.clear()
  }

  for ch in value.to_lower() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      part.push(ch)
    } else {
      flush(out, part)
    }
  }
  flush(out, part)
  out
}

///|
fn html_scope_words_contain(words : Array[String], needle : String) -> Bool {
  for word in words {
    if word == needle {
      return true
    }
  }
  false
}

///|
fn html_block_origin_with_index(
  origin : @cor.Origin?,
  source_name : String,
  block_index : Int,
) -> @cor.Origin? {
  match origin {
    Some(v) =>
      Some({
        source_name: Some(source_name),
        page: v.page,
        slide: v.slide,
        sheet: v.sheet,
        block_index: Some(block_index),
        heading_path: v.heading_path,
        line_start: v.line_start,
        line_end: v.line_end,
        row_index: v.row_index,
        column_index: v.column_index,
        object_ref: v.object_ref,
        relationship_id: v.relationship_id,
        key_path: v.key_path,
      })
    None =>
      Some({
        source_name: Some(source_name),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(block_index),
        heading_path: None,
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      })
  }
}
