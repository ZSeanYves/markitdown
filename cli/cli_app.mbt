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
    Some(p) =>
      @fs.write_string_to_file(p, md, encoding="utf8") catch {
        e => exit_error("write output failed: " + e.to_string())
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
  if !@fs.path_exists(path) {
    return false
  }
  let base = @cor.basename(path)
  !(base.has_suffix(".md") || base.has_suffix(".markdown"))
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
