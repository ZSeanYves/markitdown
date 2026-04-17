///|
priv struct DocxPackage {
  _path : String
  pkg : @ox.OoxmlPackage
}

///|
fn open_docx(path : String) -> DocxPackage raise @fs.IOError {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise @fs.IOError("read docx failed: " + path + " : " + e.to_string())
  }

  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise @fs.IOError("open_ooxml_package failed: " + e.to_string())
  }

  { _path: path, pkg }
}

///|
fn DocxPackage::read_text_optional(
  p : DocxPackage,
  part_name : String,
) -> String {
  let b = @ox.read_part_bytes(p.pkg, part_name) catch { _ => return "" }
  @cor.utf8_bytes_to_string(b) catch {
    _ => return ""
  }
}

///|
fn DocxPackage::read_text_required(
  p : DocxPackage,
  part_name : String,
) -> String raise {
  let b = @ox.read_part_bytes(p.pkg, part_name) catch {
    e => fail("read_part_bytes failed: " + part_name + " : " + e.to_string())
  }
  @cor.utf8_bytes_to_string(b) catch {
    e => fail("utf8 decode failed: " + part_name + " : " + e.to_string())
  }
}

///|
fn DocxPackage::read_document_relationships(
  p : DocxPackage,
) -> Map[String, String] {
  let rels = @ox.read_part_relationships(p.pkg, "word/document.xml") catch {
    _ => return Map::new()
  }
  rels_to_target_map(rels)
}

///|
fn DocxPackage::extract_media_by_relationships(
  p : DocxPackage,
  rels : Map[String, String],
  asset_by_target : Map[String, String],
  out_dir : String,
) -> Unit raise @fs.IOError {
  if !@fs.path_exists(out_dir) {
    @fs.create_dir(out_dir)
  }

  for entry in rels {
    let (_, target) = entry
    let normalized = normalize_doc_part_target(target)
    if !normalized.has_prefix("word/media/") {
      continue
    }
    let rel_out = asset_by_target.get(normalized).unwrap_or("")
    if rel_out == "" || !rel_out.has_prefix("assets/") {
      continue
    }
    let name = rel_out["assets/".length():].to_string()

    let data = @ox.read_part_bytes(p.pkg, normalized) catch { _ => continue }
    @fs.write_bytes_to_file(out_dir + "/" + name, data)
  }
}

///|
fn DocxPackage::load_styles(p : DocxPackage) -> DocxStyles {
  let xml = p.read_text_optional("word/styles.xml")
  if xml == "" {
    return empty_styles()
  }
  parse_styles_xml(xml)
}

///|
fn DocxPackage::load_numbering(p : DocxPackage) -> DocxNumbering {
  let xml = p.read_text_optional("word/numbering.xml")
  if xml == "" {
    return empty_numbering()
  }
  parse_numbering_xml(xml)
}
