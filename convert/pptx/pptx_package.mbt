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

  let _ = @ox.read_part_relationships(p.pkg, "ppt/presentation.xml") catch {
    _ => return list_slide_entries(p)
  }
  let out : Array[String] = []

  for rid in rid_order {
    match @ox.find_relationship_by_id(p.pkg, "ppt/presentation.xml", rid) {
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
) -> PptxSlideRelContext {
  let slide_rels = @ox.read_part_relationships(p.pkg, slide_part) catch {
    _ => return { rels: [], hyperlinks: Map::new() }
  }
  { rels: slide_rels, hyperlinks: hyperlink_map_from_rels(slide_rels) }
}

///|
fn hyperlink_map_from_rels(
  rels : Array[@ox.OoxmlRelationship],
) -> Map[String, String] {
  let out : Map[String, String] = Map::new()
  for rel in rels {
    if rel.rel_type.has_suffix("/hyperlink") &&
      rel.target_mode == @ox.OoxmlTargetMode::External &&
      rel.resolved_target.trim() != "" {
      out.set(rel.id, rel.resolved_target.trim().to_owned())
    }
  }
  out
}
