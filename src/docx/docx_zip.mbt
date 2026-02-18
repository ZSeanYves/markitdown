///|
pub struct DocxZip {
  path : String
  zip : ZipReader
}

///|
pub fn open_docx(path : String) -> DocxZip raise @fs.IOError {
  let z = open_zip(path) catch {
    e => raise @fs.IOError("open_zip failed: " + e.to_string())
  }
  { path, zip: z }
}

///|
pub fn DocxZip::read_text_optional(
  z : DocxZip,
  entry_path : String,
) -> String  {
  let b = z.zip.read_entry_bytes(entry_path) catch { _ => return "" }
  @cor.utf8_bytes_to_string(b) catch {
    _ => return ""
  }
}

///|
pub fn DocxZip::read_text_required(
  z : DocxZip,
  entry_path : String,
) -> String raise {
  let b = z.zip.read_entry_bytes(entry_path) catch {
    e => fail("read_entry_bytes failed: " + entry_path + " : " + e.to_string())
  }
  @cor.utf8_bytes_to_string(b) catch {
    e => fail("utf8 decode failed: " + entry_path + " : " + e.to_string())
  }
}


///|
pub fn DocxZip::extract_prefix(
  z : DocxZip,
  prefix : String,
  out_dir : String,
) -> Unit raise @fs.IOError {
  if !@fs.path_exists(out_dir) {
    @fs.create_dir(out_dir)
  }

  // 遍历 central directory 的 entry 名单
  let names = z.zip.list_entries()
  for p in names {
    if !p.has_prefix(prefix) { continue }

    // 取文件名（避免 split/iter 问题）
    let name = @cor.basename(p)
    if name == "" { continue }

    let dest = out_dir + "/" + name

    // 读取 entry bytes（已自动解压）
    let b = z.zip.read_entry_bytes(p) catch { _ => continue }

    @fs.write_bytes_to_file(dest, b)
  }
}
