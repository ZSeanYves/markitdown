///|
async fn cmd_convert(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
  pdf_mode : String?,
  pdf_extract_debug : Bool,
  pdf_dump_selected_raw : Bool,
  pdf_pipeline_debug : Bool,
  with_metadata : Bool,
) -> Unit {
  let resolved_output = resolve_output_path(input, output)

  let out_root = match out_dir {
    Some(d) => d
    None =>
      match resolved_output {
        Some(p) => dirname_of_path(p)
        None => "out"
      }
  }

  // 确保 out_root 存在
  if !@fs.path_exists(out_root) {
    @fs.create_dir(out_root) catch {
      e => {
        exit_error(e.to_string())
        return
      }
    }
  }

  let opts : @conv.ConvertOptions = {
    out_dir: Some(out_root),
    max_heading: Some(max_heading),
    pdf_enhance_mode: pdf_mode,
    pdf_extract_debug,
    pdf_dump_selected_raw,
    pdf_pipeline_debug,
  }

  let doc_res = @conv.parse_to_ir(input, opts)
  let doc = match doc_res {
    Ok(d) => d
    Err(e) => {
      exit_error("parse failed: " + e.to_string())
      return
    }
  }

  let md = @cor.emit_markdown(doc)

  match resolved_output {
    Some(p) => {
      @fs.write_string_to_file(p, md, encoding="utf8") catch {
        e => {
          exit_error("write output failed: " + e.to_string())
          return
        }
      }

      if with_metadata {
        let format = detect_input_format(input)
        let markdown_file = @cor.basename(p)
        let metadata_json = @cor.emit_metadata_json(
          doc,
          @cor.basename(input),
          format,
          markdown_file,
        )
        let metadata_path = metadata_output_path(p)
        let metadata_dir = dirname_of_path(metadata_path)

        if !@fs.path_exists(metadata_dir) {
          @fs.create_dir(metadata_dir) catch {
            e => {
              exit_error("create metadata dir failed: " + e.to_string())
              return
            }
          }
        }

        @fs.write_string_to_file(metadata_path, metadata_json, encoding="utf8") catch {
          e => {
            exit_error("write metadata failed: " + e.to_string())
            return
          }
        }
      }
    }
    None => println(md)
  }
}

///|
fn exit_error(msg : String) -> Unit {
  println("error: " + msg)
}

///|
fn resolve_output_path(input : String, output : String?) -> String? {
  match output {
    None => None
    Some(raw) => {
      let out = raw.trim().to_string()
      if out == "" {
        None
      } else if looks_like_output_dir(out) {
        Some(join_path(out, input_stem(input) + ".md"))
      } else {
        Some(out)
      }
    }
  }
}

///|
fn looks_like_output_dir(path : String) -> Bool {
  if path.has_suffix("/") || path.has_suffix("\\") {
    return true
  }

  let base = @cor.basename(path)
  let base_lower = base.to_lower()
  if base_lower.has_suffix(".md") || base_lower.has_suffix(".markdown") {
    return false
  }

  if !@fs.path_exists(path) {
    // 对于不存在的路径，默认按目录处理，便于 `normal A/B.pdf C` 产出 `C/B.md`
    return true
  }

  true
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
    path[:last].to_string()
  }
}

///|
fn join_path(dir : String, file : String) -> String {
  if dir.has_suffix("/") {
    dir + file
  } else {
    dir + "/" + file
  }
}

///|
fn input_stem(path : String) -> String {
  let base = @cor.basename(path)
  let mut dot = -1
  for i in 0..<base.length() {
    if base[i] == '.' {
      dot = i
    }
  }
  if dot <= 0 {
    base
  } else {
    base[:dot].to_string()
  }
}

///|
fn metadata_output_path(markdown_path : String) -> String {
  let base = @cor.basename(markdown_path)
  let dir = dirname_of_path(markdown_path)

  let mut dot = -1
  for i in 0..<base.length() {
    if base[i] == '.' {
      dot = i
    }
  }

  let stem = if dot <= 0 { base } else { base[:dot].to_string() }

  join_path(join_path(dir, "metadata"), stem + ".metadata.json")
}

///|
fn detect_input_format(path : String) -> String {
  let base = @cor.basename(path).to_lower()
  if base.has_suffix(".docx") {
    "docx"
  } else if base.has_suffix(".pdf") {
    "pdf"
  } else if base.has_suffix(".xlsx") {
    "xlsx"
  } else if base.has_suffix(".pptx") {
    "pptx"
  } else if base.has_suffix(".html") || base.has_suffix(".htm") {
    "html"
  } else {
    "unknown"
  }
}
