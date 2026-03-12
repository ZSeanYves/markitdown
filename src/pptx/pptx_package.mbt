///|
/// fallback
fn list_slide_entries(z : @cor.ZipReader) -> Array[String] {
  let all = @cor.ZipReader::list_entries(z)
  let out : Array[String] = []
  for name in all {
    if name.has_prefix("ppt/slides/slide") && name.has_suffix(".xml") {
      out.push(name)
    }
  }
  // 简单字典序排序会让 slide10 排在 slide2 前；MVP 先这样也行
  out.sort()
  out
}

///|
async fn list_slide_entries_in_presentation_order(
  z : @cor.ZipReader,
) -> Array[String] {
  let pres_xml = read_zip_text_optional(z, "ppt/presentation.xml")
  let rels_xml = read_zip_text_optional(z, "ppt/_rels/presentation.xml.rels")

  if pres_xml == "" || rels_xml == "" {
    return list_slide_entries(z)
  }

  let rid_order = parse_presentation_slide_rids(pres_xml)
  if rid_order.length() == 0 {
    return list_slide_entries(z)
  }

  let rels = parse_presentation_rels(rels_xml)
  let out : Array[String] = []

  for rid in rid_order {
    match rels.get(rid) {
      Some(target) => {
        let full = normalize_ppt_target(target)
        if full.has_prefix("ppt/slides/slide") && full.has_suffix(".xml") {
          out.push(full)
        }
      }
      None => ()
    }
  }

  if out.length() == 0 {
    list_slide_entries(z)
  } else {
    out
  }
}

///|
async fn read_zip_bytes(z : @cor.ZipReader, name : String) -> Bytes {
  @cor.ZipReader::read_entry_bytes(z, name) catch {
    e =>
      raise @cor.AppError(
        "pptx: read zip entry failed: " + name + ": " + e.to_string(),
      )
  }
}

///|
async fn read_zip_text_optional(z : @cor.ZipReader, name : String) -> String {
  let bs = @cor.ZipReader::read_entry_bytes(z, name) catch { _ => return "" }
  @cor.utf8_bytes_to_string(bs) catch {
    _ => return ""
  }
}
