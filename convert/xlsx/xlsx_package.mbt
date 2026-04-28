// ============================
// Types
// ============================

///|
priv struct SheetInfo {
  name : String
  _rid : String
  target : String
}

///|
priv struct XlsxPackage {
  _path : String
  pkg : @ox.OoxmlPackage
}

///|
fn open_xlsx(path : String) -> XlsxPackage raise @fs.IOError {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise @fs.IOError("read xlsx failed: " + path + " : " + e.to_string())
  }
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise @fs.IOError("open_ooxml_package failed: " + e.to_string())
  }
  { _path: path, pkg }
}

///|
fn XlsxPackage::read_text_optional(
  p : XlsxPackage,
  part_name : String,
) -> String {
  let b = @ox.read_part_bytes(p.pkg, part_name) catch { _ => return "" }
  @cor.utf8_bytes_to_string(b) catch {
    _ => return ""
  }
}

///|
fn XlsxPackage::read_text_required(
  p : XlsxPackage,
  part_name : String,
) -> String raise {
  let b = @ox.read_part_bytes(p.pkg, part_name) catch {
    e => fail("read_part_bytes failed: " + part_name + " : " + e.to_string())
  }
  @cor.utf8_bytes_to_string(b) catch {
    e => fail("utf8 decode failed: " + part_name + " : " + e.to_string())
  }
}

// ============================
// Workbook + rels parsing
// ============================

///|
fn parse_workbook_sheets(
  pkg : @ox.OoxmlPackage,
  wb_xml : String,
) -> Array[SheetInfo] {
  let rels = @ox.read_part_relationships(pkg, "xl/workbook.xml") catch { _ => [] }
  let out : Array[SheetInfo] = []

  let mut pos = 0
  while true {
    let idx = find_sub(wb_xml, "<sheet", pos)
    match idx {
      None => break
      Some(i0) => {
        let j = find_sub(wb_xml, ">", i0)
        match j {
          None => break
          Some(i1) => {
            let tag = wb_xml[i0:i1 + 1].to_string()
            let name = get_attr(tag, "name").unwrap_or("Sheet")
            let rid = get_attr(tag, "r:id").unwrap_or("")
            if rid != "" {
              let target = match @ox.find_relationship_by_id(rels, rid) {
                Some(rel) => rel.resolved_target
                None => ""
              }
              out.push({ name, _rid: rid, target })
            }
            pos = i1 + 1
          }
        }
      }
    }
  }

  out
}

///|
fn normalize_sheet_part_target(target : String) -> String {
  let target0 = target.trim().to_string()
  if target0 == "" {
    return ""
  }

  if target0.has_prefix("/") {
    target0[1:]
  } else {
    target0
  }
}
