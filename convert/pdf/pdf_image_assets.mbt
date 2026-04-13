///|
priv struct PdfPageImage {
  page : Int
  alt : String
  path : String
}

///|
priv struct PdfImageExportResult {
  images : Array[PdfPageImage]
  warning : String?
}

///|
const PDF_IMAGE_MARKER_PREFIX = "__PDF_IMAGE__|"

///|
fn build_pdf_image_marker(img : PdfPageImage) -> String {
  PDF_IMAGE_MARKER_PREFIX + img.alt + "|" + img.path
}

///|
fn parse_pdf_image_marker(line : String) -> PdfPageImage? {
  if !line.has_prefix(PDF_IMAGE_MARKER_PREFIX) {
    return None
  }

  let body = line[PDF_IMAGE_MARKER_PREFIX.length():].to_string()
  let idx = find_first_pipe(body)
  if idx < 0 {
    return None
  }

  let alt = body[:idx].to_string().trim().to_string()
  let path = body[idx + 1:].to_string().trim().to_string()
  if alt == "" || path == "" {
    return None
  }

  Some({ page: 0, alt, path })
}

///|
fn find_first_pipe(s : String) -> Int {
  for i in 0..<s.length() {
    if s[i] == '|' {
      return i
    }
  }
  -1
}

///|
fn inject_page_image_markers(
  pages : Array[String],
  page_images : Array[PdfPageImage],
) -> Array[String] {
  if page_images.length() == 0 {
    return pages
  }

  let by_page : Map[Int, Array[PdfPageImage]] = Map::new()
  for img in page_images {
    let xs = by_page.get(img.page).unwrap_or([])
    xs.push(img)
    by_page.set(img.page, xs)
  }

  let out : Array[String] = []
  let n = pages.length()
  for i in 0..<n {
    let page_no = i + 1
    let buf : Array[String] = []
    for img in by_page.get(page_no).unwrap_or([]) {
      buf.push(build_pdf_image_marker(img))
    }
    let page = pages[i].trim().to_string()
    if page != "" {
      buf.push(page)
    }
    out.push(buf.join("\n"))
  }

  out
}

///|
async fn export_pdf_page_images(
  path : String,
  out_dir : String,
) -> PdfImageExportResult {
  if out_dir == "" {
    return { images: [], warning: None }
  }

  let assets_dir = out_dir + "/assets"
  if !@fs.path_exists(assets_dir) {
    @fs.create_dir(assets_dir) catch {
      e =>
        return {
          images: [],
          warning: Some("create assets dir failed: " + e.to_string()),
        }
    }
  }

  let list_res = run_command_capture("pdfimages", ["-list", path])
  let (status, listing, err_msg) = match list_res {
    Err(e) => return { images: [], warning: Some(e.to_string()) }
    Ok(v) => v
  }
  if status != 0 {
    let msg = if err_msg.trim() == "" {
      "pdfimages -list failed"
    } else {
      err_msg
    }
    return { images: [], warning: Some(msg) }
  }

  let page_counts = parse_pdfimages_page_counts(listing)
  if page_counts.length() == 0 {
    return { images: [], warning: None }
  }

  let prefix = out_dir +
    "/.pdf_img_tmp_" +
    sanitize_pdf_asset_base(@cor.basename(path))
  let _ = run_command_capture("rm", ["-rf", prefix])
  let _ = run_command_capture("mkdir", ["-p", prefix])

  let exported : Array[PdfPageImage] = []
  let next_image_idx : Ref[Int] = { val: 0 }

  for entry in page_counts {
    let (page_no, img_count) = entry
    if img_count <= 0 {
      continue
    }

    let page_prefix = prefix + "/page_" + pad2(page_no) + "_img"
    let extract_res = run_command_capture("pdfimages", [
      "-f",
      page_no.to_string(),
      "-l",
      page_no.to_string(),
      "-png",
      path,
      page_prefix,
    ])
    let (st, _, se) = match extract_res {
      Err(e) => {
        let _ = run_command_capture("rm", ["-rf", prefix])
        return { images: exported, warning: Some(e.to_string()) }
      }
      Ok(v) => v
    }
    if st != 0 {
      let _ = run_command_capture("rm", ["-rf", prefix])
      let msg = if se.trim() == "" { "pdfimages extraction failed" } else { se }
      return { images: exported, warning: Some(msg) }
    }

    let mut emitted = 0
    for idx in 0..<img_count {
      let src = page_prefix + "-" + pad3(idx) + ".png"
      if !@fs.path_exists(src) {
        continue
      }

      emitted += 1
      let rel_out = @cor.next_image_asset_rel_path_unique(
        next_image_idx, "png", out_dir,
      )
      let dst = out_dir + "/" + rel_out
      let bs = @fs.read_file_to_bytes(src) catch { _ => continue }
      @fs.write_bytes_to_file(dst, bs) catch {
        _ => continue
      }

      exported.push({
        page: page_no,
        alt: "page-" + page_no.to_string() + "-image-" + emitted.to_string(),
        path: rel_out,
      })
    }
  }

  let _ = run_command_capture("rm", ["-rf", prefix])
  { images: exported, warning: None }
}

///|
fn parse_pdfimages_page_counts(listing : String) -> Array[(Int, Int)] {
  let counts : Array[(Int, Int)] = []

  for sv in listing.split("\n") {
    let line = sv.to_string().trim().to_string()
    if line == "" || line.has_prefix("page") || line.has_prefix("-") {
      continue
    }

    let cols = split_whitespace(line)
    if cols.length() < 3 {
      continue
    }

    let page_no = parse_int_opt(cols[0]).unwrap_or(0)
    if page_no <= 0 {
      continue
    }

    let typ = cols[2]
    if typ != "image" {
      continue
    }

    let mut found = false
    for i in 0..<counts.length() {
      let (p, c) = counts[i]
      if p == page_no {
        counts[i] = (p, c + 1)
        found = true
        break
      }
    }
    if !found {
      counts.push((page_no, 1))
    }
  }
  counts
}

///|
fn split_whitespace(s : String) -> Array[String] {
  let out : Array[String] = []
  for sv in s.split(" ") {
    let t = sv.to_string().trim().to_string()
    if t != "" {
      out.push(t)
    }
  }
  out
}

///|
fn parse_int_opt(s : String) -> Int? {
  if s == "" {
    return None
  }
  let mut v = 0
  for c in s.to_array() {
    if c < '0' || c > '9' {
      return None
    }
    v = v * 10 + (c.to_int() - '0'.to_int())
  }
  Some(v)
}

///|
fn sanitize_pdf_asset_base(s : String) -> String {
  let out : Array[Char] = []
  for c in s.to_array() {
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') {
      out.push(c)
    } else {
      out.push('_')
    }
  }
  String::from_array(out)
}

///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn pad3(n : Int) -> String {
  if n < 10 {
    "00" + n.to_string()
  } else if n < 100 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}
