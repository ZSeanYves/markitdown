///|
fn to_pptx_target_mode(mode : @ox.OoxmlTargetMode) -> PptxTargetMode {
  match mode {
    @ox.OoxmlTargetMode::Internal => PptxTargetMode::Internal
    @ox.OoxmlTargetMode::External => PptxTargetMode::External
  }
}

///|
fn to_pptx_relationship(rel : @ox.OoxmlRelationship) -> PptxRelationship {
  {
    id: rel.id,
    rel_type: rel.rel_type,
    target: rel.target,
    target_mode: to_pptx_target_mode(rel.target_mode),
    resolved_target: rel.resolved_target,
  }
}

///|
fn find_pptx_relationship_by_id(
  rels : PptxRelationshipIndex,
  rel_id : String,
) -> PptxRelationship? {
  for rel in rels.relationships {
    if rel.id == rel_id {
      return Some(rel)
    }
  }
  None
}

///|
fn read_pptx_relationship_index(
  pkg : @ox.OoxmlPackage,
  source_part : String,
) -> PptxRelationshipIndex {
  let rels = @ox.read_part_relationships(pkg, source_part) catch {
    _ => return empty_pptx_relationship_index()
  }
  let out : Array[PptxRelationship] = []
  let mut notes_part : String? = None
  let mut notes_relationship_id : String? = None
  for rel in rels {
    let parsed = to_pptx_relationship(rel)
    if parsed.rel_type.has_suffix("/notesSlide") &&
      parsed.resolved_target.has_prefix("ppt/notesSlides/") &&
      parsed.resolved_target.has_suffix(".xml") {
      notes_part = Some(parsed.resolved_target)
      notes_relationship_id = Some(parsed.id)
    }
    out.push(parsed)
  }
  { relationships: out, notes_part, notes_relationship_id }
}

///|
fn parse_presentation_slide_entries(
  xml : String,
) -> Array[PptxSlideEntry] raise {
  let bs = @utf8.encode(xml)
  let out : Array[PptxSlideEntry] = []

  let open_pat = pat("<p:sldId")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let s0 = find_bytes(bs, open_pat, pos)
    match s0 {
      None => break
      Some(i0) =>
        match find_bytes(bs, gt_pat, i0) {
          None => break
          Some(gt0) => {
            let tag = bs[i0:gt0 + 1]
            match read_attr_value_in_tag_bytes(tag.to_owned(), "r:id") {
              Some(rid) => {
                let hidden = match
                  read_attr_value_in_tag_bytes(tag.to_owned(), "show") {
                  Some(v) => v == "0" || v.to_lower() == "false"
                  None => false
                }
                out.push({
                  slide_id: read_attr_value_in_tag_bytes(tag.to_owned(), "id"),
                  part_name: "",
                  rel_id: Some(rid),
                  hidden,
                })
              }
              None => ()
            }
            pos = gt0 + 1
          }
        }
    }
  }

  out
}

///|
fn list_slide_part_names(pkg : @ox.OoxmlPackage) -> Array[String] {
  let out : Array[String] = []
  for part in @ox.list_parts(pkg) {
    if part.has_prefix("ppt/slides/slide") && part.has_suffix(".xml") {
      out.push(part)
    }
  }
  out.sort()
  out
}
