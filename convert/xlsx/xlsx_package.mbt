// ============================
// Types
// ============================

///|
priv struct SheetInfo {
  name : String
  _rid : String
  state : XlsxSheetState
  rel_type : String?
  target : String?
  is_supported_worksheet : Bool
}

///|
fn parse_sheet_state(value : String) -> XlsxSheetState {
  if value == "hidden" {
    XlsxSheetState::Hidden
  } else if value == "veryHidden" {
    XlsxSheetState::VeryHidden
  } else {
    XlsxSheetState::Visible
  }
}

///|
fn is_supported_sheet_relationship(rel_type : String?) -> Bool {
  match rel_type {
    Some(v) => v.has_suffix("/worksheet")
    None => false
  }
}

///|
priv struct XlsxPackage {
  _path : String
  pkg : @ox.OoxmlPackage
}

///|
priv struct XlsxReadTextProfile {
  normalized_part_name : String
  part_index_hit : Bool
  entry_lookup_elapsed_ms : UInt64
  read_entry_elapsed_ms : UInt64
  bytes_to_string_elapsed_ms : UInt64
  byte_len : Int
  text_len : Int
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
  @utf8.decode(b, ignore_bom=true) catch {
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
  @utf8.decode(b, ignore_bom=true) catch {
    _ => fail("utf8 decode failed: " + part_name)
  }
}

///|
fn XlsxPackage::read_text_required_profiled(
  p : XlsxPackage,
  part_name : String,
) -> (String, XlsxReadTextProfile) raise {
  let lookup_started = @env.now()
  let normalized = part_name.trim().to_owned()
  let part_index_hit = p.pkg.part_index.contains(normalized)
  let entry_lookup_elapsed_ms = @env.now() - lookup_started

  let read_entry_started = @env.now()
  let b = @zip.read_entry(p.pkg.archive, normalized) catch {
    @zip.EntryNotFound(path) => fail("read_part_bytes failed: " + path)
    e => fail("read_part_bytes failed: " + normalized + " : " + e.to_string())
  }
  let read_entry_elapsed_ms = @env.now() - read_entry_started

  let decode_started = @env.now()
  let text = @utf8.decode(b, ignore_bom=true) catch {
    _ => fail("utf8 decode failed: " + normalized)
  }
  let bytes_to_string_elapsed_ms = @env.now() - decode_started

  (
    text,
    {
      normalized_part_name: normalized,
      part_index_hit,
      entry_lookup_elapsed_ms,
      read_entry_elapsed_ms,
      bytes_to_string_elapsed_ms,
      byte_len: b.length(),
      text_len: text.length(),
    },
  )
}

// ============================
// Workbook + rels parsing
// ============================

///|
fn parse_workbook_sheets(
  pkg : @ox.OoxmlPackage,
  wb_xml : String,
) -> Array[SheetInfo] raise {
  let _ = @ox.read_part_relationships(pkg, "xl/workbook.xml") catch { _ => [] }
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
            let tag = wb_xml[i0:i1 + 1].to_owned()
            let name = get_attr(tag, "name").unwrap_or("Sheet")
            let rid = get_attr(tag, "r:id").unwrap_or("")
            let state = parse_sheet_state(get_attr(tag, "state").unwrap_or(""))
            if rid != "" {
              let (rel_type, target) = match
                @ox.find_relationship_by_id(pkg, "xl/workbook.xml", rid) {
                Some(rel) => (Some(rel.rel_type), Some(rel.resolved_target))
                None => (None, None)
              }
              out.push({
                name,
                _rid: rid,
                state,
                rel_type,
                target,
                is_supported_worksheet: is_supported_sheet_relationship(
                  rel_type,
                ),
              })
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
  let target0 = target.trim().to_owned()
  if target0 == "" {
    return ""
  }

  if target0.has_prefix("/") {
    target0[1:].to_owned()
  } else {
    target0
  }
}

///|
fn workbook_uses_date_1904(wb_xml : String) -> Bool {
  let idx = find_sub(wb_xml, "<workbookPr", 0)
  match idx {
    None => false
    Some(i0) => {
      let gt0 = find_sub(wb_xml, ">", i0)
      match gt0 {
        None => false
        Some(i1) => {
          let tag = wb_xml[i0:i1 + 1].to_owned()
          let raw = get_attr(tag, "date1904").unwrap_or("")
          raw == "1" || raw == "true"
        }
      }
    }
  }
}
