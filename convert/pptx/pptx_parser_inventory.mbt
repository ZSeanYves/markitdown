///|
priv struct PptxParserInventorySummary {
  parser_succeeded : Bool
  fallback_reason : String?
  presentation : @pptx_sem.PptxPresentation?
  slide_count : Int
  slide_ids : Array[String]
  slide_parts : Array[String]
  hidden_slide_count : Int
  shape_count : Int
  text_shape_count : Int
  table_count : Int
  chart_count : Int
  chart_titles : Array[String]
  chart_source_slides : Array[String]
  media_ref_count : Int
  media_relationship_ids : Array[String]
  media_target_parts : Array[String]
  media_content_types : Array[String]
  notes_count : Int
  comment_count : Int
  comment_author_count : Int
  external_relationship_count : Int
  issue_count : Int
}

///|
fn collect_pptx_parser_inventory_summary(
  pkg : @ox.OoxmlPackage,
) -> PptxParserInventorySummary {
  let parsed = try? @pptx_sem.parse_pptx_presentation_from_package(pkg)
  match parsed {
    Ok(pres) => summarize_pptx_parser_inventory(pres)
    Err(e) => failed_pptx_parser_inventory_summary(e.to_string())
  }
}

///|
fn failed_pptx_parser_inventory_summary(
  reason : String,
) -> PptxParserInventorySummary {
  {
    parser_succeeded: false,
    fallback_reason: Some(compact_pptx_parser_inventory_text(reason, 160)),
    presentation: None,
    slide_count: 0,
    slide_ids: [],
    slide_parts: [],
    hidden_slide_count: 0,
    shape_count: 0,
    text_shape_count: 0,
    table_count: 0,
    chart_count: 0,
    chart_titles: [],
    chart_source_slides: [],
    media_ref_count: 0,
    media_relationship_ids: [],
    media_target_parts: [],
    media_content_types: [],
    notes_count: 0,
    comment_count: 0,
    comment_author_count: 0,
    external_relationship_count: 0,
    issue_count: 0,
  }
}

///|
fn summarize_pptx_parser_inventory(
  pres : @pptx_sem.PptxPresentation,
) -> PptxParserInventorySummary {
  let slide_ids : Array[String] = []
  let slide_parts : Array[String] = []
  let chart_titles : Array[String] = []
  let chart_source_slides : Array[String] = []
  let media_relationship_ids : Array[String] = []
  let media_target_parts : Array[String] = []
  let media_content_types : Array[String] = []

  let shape_count : Ref[Int] = { val: 0 }
  let text_shape_count : Ref[Int] = { val: 0 }
  let table_count : Ref[Int] = { val: 0 }
  let chart_count : Ref[Int] = { val: 0 }
  let hidden_slide_count : Ref[Int] = { val: 0 }
  let notes_count : Ref[Int] = { val: 0 }
  let comment_count : Ref[Int] = { val: 0 }
  let external_relationship_count : Ref[Int] = { val: 0 }

  count_external_relationships(
    pres.relationships,
    external_relationship_count,
  )

  for slide in pres.slides {
    match slide.slide_id {
      Some(id) => pptx_parser_inventory_push_unique(slide_ids, id)
      None => ()
    }
    pptx_parser_inventory_push_unique(slide_parts, slide.part_path)
    if slide.hidden {
      hidden_slide_count.val += 1
    }
    match slide.notes {
      Some(_) => notes_count.val += 1
      None => ()
    }
    comment_count.val += slide.comments.length()
    count_external_relationships(
      slide.relationships,
      external_relationship_count,
    )
    collect_pptx_shape_inventory(
      slide.shape_tree,
      slide.index,
      slide.part_path,
      shape_count,
      text_shape_count,
      table_count,
      chart_count,
      chart_titles,
      chart_source_slides,
    )
    for media in slide.media_refs {
      match media.relationship_id {
        Some(rid) => pptx_parser_inventory_push_unique(media_relationship_ids, rid)
        None => ()
      }
      match media.target_part {
        Some(part) => pptx_parser_inventory_push_unique(media_target_parts, part)
        None => ()
      }
      match media.content_type {
        Some(content_type) =>
          pptx_parser_inventory_push_unique(media_content_types, content_type)
        None => ()
      }
    }
  }

  {
    parser_succeeded: true,
    fallback_reason: None,
    presentation: Some(pres),
    slide_count: pres.slides.length(),
    slide_ids,
    slide_parts,
    hidden_slide_count: hidden_slide_count.val,
    shape_count: shape_count.val,
    text_shape_count: text_shape_count.val,
    table_count: table_count.val,
    chart_count: chart_count.val,
    chart_titles,
    chart_source_slides,
    media_ref_count: pres.media_refs.length(),
    media_relationship_ids,
    media_target_parts,
    media_content_types,
    notes_count: notes_count.val,
    comment_count: comment_count.val,
    comment_author_count: pres.comment_authors.length(),
    external_relationship_count: external_relationship_count.val,
    issue_count: pres.issues.length(),
  }
}

///|
fn collect_pptx_shape_inventory(
  shapes : Array[@pptx_sem.PptxShape],
  slide_index : Int,
  slide_part : String,
  shape_count : Ref[Int],
  text_shape_count : Ref[Int],
  table_count : Ref[Int],
  chart_count : Ref[Int],
  chart_titles : Array[String],
  chart_source_slides : Array[String],
) -> Unit {
  for shape in shapes {
    shape_count.val += 1
    if shape.text_paragraphs.length() > 0 {
      text_shape_count.val += 1
    }
    match shape.table {
      Some(_) => table_count.val += 1
      None => ()
    }
    match shape.chart {
      Some(chart) => {
        chart_count.val += 1
        match chart.title {
          Some(title) =>
            if title.trim() != "" {
              pptx_parser_inventory_push_unique(
                chart_titles,
                compact_pptx_parser_inventory_text(title, 80),
              )
            }
          None => ()
        }
        pptx_parser_inventory_push_unique(
          chart_source_slides,
          slide_index.to_string() + ":" + slide_part,
        )
      }
      None => ()
    }
    collect_pptx_shape_inventory(
      shape.children,
      slide_index,
      slide_part,
      shape_count,
      text_shape_count,
      table_count,
      chart_count,
      chart_titles,
      chart_source_slides,
    )
  }
}

///|
fn count_external_relationships(
  rels : @pptx_sem.PptxRelationshipIndex,
  external_relationship_count : Ref[Int],
) -> Unit {
  for rel in rels.relationships {
    if rel.target_mode == @pptx_sem.PptxTargetMode::External {
      external_relationship_count.val += 1
    }
  }
}

///|
fn render_pptx_parser_inventory_summary_detail(
  summary : PptxParserInventorySummary,
) -> String {
  let parts : Array[String] = [
    "parser_ok=" + summary.parser_succeeded.to_string(),
  ]
  match summary.fallback_reason {
    Some(reason) => parts.push("parser_issue=" + reason)
    None => ()
  }
  parts.push("slides=" + summary.slide_count.to_string())
  append_pptx_inventory_joined(parts, "slide_ids", summary.slide_ids)
  append_pptx_inventory_joined(parts, "slide_parts", summary.slide_parts)
  parts.push("hidden=" + summary.hidden_slide_count.to_string())
  parts.push("shapes=" + summary.shape_count.to_string())
  parts.push("text_shapes=" + summary.text_shape_count.to_string())
  parts.push("tables=" + summary.table_count.to_string())
  parts.push("charts=" + summary.chart_count.to_string())
  append_pptx_inventory_joined(parts, "chart_titles", summary.chart_titles)
  append_pptx_inventory_joined(
    parts,
    "chart_source_slides",
    summary.chart_source_slides,
  )
  parts.push("media_refs=" + summary.media_ref_count.to_string())
  append_pptx_inventory_joined(
    parts,
    "media_rids",
    summary.media_relationship_ids,
  )
  append_pptx_inventory_joined(
    parts,
    "media_targets",
    summary.media_target_parts,
  )
  append_pptx_inventory_joined(
    parts,
    "media_content_types",
    summary.media_content_types,
  )
  parts.push("notes=" + summary.notes_count.to_string())
  parts.push("comments=" + summary.comment_count.to_string())
  parts.push("authors=" + summary.comment_author_count.to_string())
  parts.push(
    "external_relationships=" +
    summary.external_relationship_count.to_string(),
  )
  parts.push("issues=" + summary.issue_count.to_string())
  parts.join(" ")
}

///|
fn append_pptx_inventory_joined(
  parts : Array[String],
  name : String,
  values : Array[String],
) -> Unit {
  if values.length() > 0 {
    parts.push(name + "=" + values.join(","))
  }
}

///|
fn pptx_parser_inventory_push_unique(
  values : Array[String],
  value : String,
) -> Unit {
  let normalized = compact_pptx_parser_inventory_text(value, 120)
  if normalized == "" {
    return
  }
  for existing in values {
    if existing == normalized {
      return
    }
  }
  values.push(normalized)
}

///|
fn compact_pptx_parser_inventory_text(text : String, max_len : Int) -> String {
  let cleaned = text
    .replace(old="\r\n", new=" ")
    .replace(old="\n", new=" ")
    .replace(old="\r", new=" ")
    .replace(old="\t", new=" ")
    .replace(old="|", new="/")
    .trim()
  let chars = cleaned.to_array()
  if chars.length() <= max_len {
    cleaned.to_owned()
  } else {
    let out : Array[Char] = []
    let mut i = 0
    while i < max_len {
      out.push(chars[i])
      i += 1
    }
    String::from_array(out)
  }
}
