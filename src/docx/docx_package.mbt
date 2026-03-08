///|
priv struct DocxZip {
  path : String
  zip : @cor.ZipReader
}

///|
fn open_docx(path : String) -> DocxZip raise @fs.IOError {
  let z = @cor.open_zip(path) catch {
    e => raise @fs.IOError("open_zip failed: " + e.to_string())
  }
  { path, zip: z }
}

///|
async fn DocxZip::read_text_optional(
  z : DocxZip,
  entry_path : String,
) -> String {
  let b = z.zip.read_entry_bytes(entry_path) catch { _ => return "" }
  @cor.utf8_bytes_to_string(b) catch {
    _ => return ""
  }
}

///|
async fn DocxZip::read_text_required(
  z : DocxZip,
  entry_path : String,
) -> String {
  let b = z.zip.read_entry_bytes(entry_path) catch {
    e => fail("read_entry_bytes failed: " + entry_path + " : " + e.to_string())
  }
  @cor.utf8_bytes_to_string(b) catch {
    e => fail("utf8 decode failed: " + entry_path + " : " + e.to_string())
  }
}

///|
async fn DocxZip::extract_prefix(
  z : DocxZip,
  prefix : String,
  out_dir : String,
) -> Unit raise @fs.IOError {
  if !@fs.path_exists(out_dir) {
    @fs.create_dir(out_dir)
  }

  let names = z.zip.list_entries()
  for p in names {
    if !p.has_prefix(prefix) {
      continue
    }

    let name = @cor.basename(p)
    if name == "" {
      continue
    }

    let dest = out_dir + "/" + name
    let b = z.zip.read_entry_bytes(p) catch { _ => continue }

    @fs.write_bytes_to_file(dest, b)
  }
}

///|
/// 读取 word/styles.xml；缺失时返回空样式映射
async fn DocxZip::load_styles(z : DocxZip) -> DocxStyles {
  let xml = z.read_text_optional("word/styles.xml")
  if xml == "" {
    return empty_styles()
  }
  parse_styles_xml(xml)
}
