///|
priv struct PptxPackage {
  _path : String
  pkg : @ox.OoxmlPackage
}

///|
fn open_pptx(path : String) -> PptxPackage raise @fs.IOError {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise @fs.IOError("read pptx failed: " + path + " : " + e.to_string())
  }

  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise @fs.IOError("open_ooxml_package failed: " + e.to_string())
  }

  { _path: path, pkg }
}

///|
fn PptxPackage::read_text_optional(
  p : PptxPackage,
  part_name : String,
) -> String {
  let b = @ox.read_part_bytes(p.pkg, part_name) catch { _ => return "" }
  @cor.utf8_bytes_to_string(b) catch {
    _ => return ""
  }
}

///|
fn PptxPackage::read_bytes_required(
  p : PptxPackage,
  part_name : String,
) -> Bytes raise {
  @ox.read_part_bytes(p.pkg, part_name) catch {
    e => fail("read_part_bytes failed: " + part_name + " : " + e.to_string())
  }
}

///|
fn list_slide_entries(p : PptxPackage) -> Array[String] {
  let out : Array[String] = []

  for entry in p.pkg.part_index {
    let (name, _) = entry
    if name.has_prefix("ppt/slides/slide") && name.has_suffix(".xml") {
      out.push(name)
    }
  }

  out.sort()
  out
}

///|
fn list_slide_entries_in_presentation_order(
  p : PptxPackage,
) -> Array[String] raise {
  let pres_xml = p.read_text_optional("ppt/presentation.xml")

  if pres_xml == "" {
    return list_slide_entries(p)
  }

  let rid_order = parse_presentation_slide_rids(pres_xml)
  if rid_order.length() == 0 {
    return list_slide_entries(p)
  }

  let rels = @ox.read_part_relationships(p.pkg, "ppt/presentation.xml") catch {
    _ => return list_slide_entries(p)
  }
  let rels_by_id = rels_by_id(rels)

  let out : Array[String] = []

  for rid in rid_order {
    match rels_by_id.get(rid) {
      Some(rel) =>
        if rel.rel_type.has_suffix("/slide") &&
          rel.resolved_target.has_prefix("ppt/slides/slide") &&
          rel.resolved_target.has_suffix(".xml") {
          out.push(rel.resolved_target)
        }
      None => ()
    }
  }

  if out.length() == 0 {
    list_slide_entries(p)
  } else {
    out
  }
}

///|
fn build_slide_rel_context(
  p : PptxPackage,
  slide_part : String,
) -> (String?, String?) {
  let slide_rels = @ox.read_part_relationships(p.pkg, slide_part) catch {
    _ => return (None, None)
  }
  let slide_layout = find_first_rel_target(slide_rels, "/slideLayout")
  match slide_layout {
    None => (None, None)
    Some(layout_part) => {
      let layout_rels = @ox.read_part_relationships(p.pkg, layout_part) catch {
        _ => return (Some(layout_part), None)
      }
      let slide_master = find_first_rel_target(layout_rels, "/slideMaster")
      (Some(layout_part), slide_master)
    }
  }
}

///|
fn rels_by_id(
  rels : Array[@ox.OoxmlRelationship],
) -> Map[String, @ox.OoxmlRelationship] {
  let out : Map[String, @ox.OoxmlRelationship] = {}
  for rel in rels {
    out[rel.id] = rel
  }
  out
}

///|
fn find_first_rel_target(
  rels : Array[@ox.OoxmlRelationship],
  type_suffix : String,
) -> String? {
  for rel in rels {
    if rel.rel_type.has_suffix(type_suffix) {
      return Some(rel.resolved_target)
    }
  }
  None
}
