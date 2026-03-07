// ============================
// Types
// ============================

///|
pub struct SheetInfo {
  name : String
  rid : String
  target : String
}

// ============================
// ZIP -> UTF8 string
// ============================

///|
async fn read_zip_utf8(z : @cor.ZipReader, name : String) -> String {
  //println(".. xlsx: reading " + name)
  let bs = @cor.ZipReader::read_entry_bytes(z, name) catch {
    e =>
      raise @cor.AppError(
        "xlsx: read zip entry failed: " + name + ": " + e.to_string(),
      )
  }
  @cor.utf8_bytes_to_string(bs) catch {
    e =>
      raise @cor.AppError(
        "xlsx: invalid utf8 in " + name + ": " + e.to_string(),
      )
  }
}

// ============================
// Workbook + rels parsing
// ============================

///|
fn parse_workbook_sheets(
  wb_xml : String,
  rels_xml : String,
) -> Array[SheetInfo] raise {
  let rel_map = parse_rels_id_to_target(rels_xml)
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
              let target = rel_map.get(rid).unwrap_or("")
              out.push({ name, rid, target })
            }
            pos = i1 + 1
          }
        }
      }
    }
  }

  out
}
// ============================
// Utilities
// ============================
// <Relationship Id="rId1" Target="worksheets/sheet1.xml" .../>

///|
fn parse_rels_id_to_target(rels_xml : String) -> Map[String, String] raise {
  let m : Map[String, String] = Map::new()
  let mut pos = 0

  while true {
    let idx = find_sub(rels_xml, "<Relationship", pos)
    match idx {
      None => break
      Some(i0) => {
        let j = find_sub(rels_xml, ">", i0)
        match j {
          None => break
          Some(i1) => {
            let tag = rels_xml[i0:i1 + 1].to_string()
            let id = get_attr(tag, "Id").unwrap_or("")
            let target = get_attr(tag, "Target").unwrap_or("")
            if id != "" && target != "" {
              m.set(id, target)
            }
            pos = i1 + 1
          }
        }
      }
    }
  }

  m
}
