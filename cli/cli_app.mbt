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
  let out_root = match out_dir {
    Some(d) => d
    None => "out"
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

  match output {
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
fn cmd_debug_pdf_events(input : String) -> Unit raise {
  if !@fs.path_exists(input) {
    exit_error("PDF file not found: " + input)
    return
  }

  let bytes = @fs.read_file_to_bytes(input) catch {
    e => {
      exit_error("read pdf failed: " + e.to_string())
      return
    }
  }

  let doc = @pdfc.open_pdf(bytes) catch {
    e => {
      exit_error("open pdf failed: " + e.to_string())
      return
    }
  }

  let pages = @pdfc.list_page_refs(doc) catch {
    e => {
      exit_error("list pages failed: " + e.to_string())
      return
    }
  }

  println("== pdf debug ==")
  println("file: " + input)
  println("pages: " + pages.length().to_string())
  println("")

  pages.eachi((i, p) => {
    let (page_obj, page_gen) = p
    println(
      @pdfc.debug_dump_pdf_page_text_ops_events_pretty(
        doc, page_obj, page_gen, i,
      ),
    )
  })
}
