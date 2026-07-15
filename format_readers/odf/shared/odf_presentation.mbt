///|
fn odf_extract_presentation_slides(
  root : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  content_path : String,
) -> OdpExtractState {
  let slides : Array[OdpSlide] = []
  let assets : Array[OdpImageRef] = []
  let mut slide_index = 0
  for child in root.children {
    match child {
      Element(body) =>
        if body.name == "office:body" {
          for body_child in body.children {
            match body_child {
              Element(presentation) =>
                if presentation.name == "office:presentation" {
                  for node in presentation.children {
                    match node {
                      Element(page) =>
                        if page.name == "draw:page" {
                          let extracted = odf_extract_slide(
                            page, archive, content_path, slide_index,
                          )
                          slide_index += 1
                          slides.push(extracted.slide)
                          for asset in extracted.assets {
                            assets.push(asset)
                          }
                        }
                      _ => ()
                    }
                  }
                }
              _ => ()
            }
          }
        }
      _ => ()
    }
  }
  { slides, assets }
}

///|
priv struct OdpSlideExtracted {
  slide : OdpSlide
  assets : Array[OdpImageRef]
}

///|
fn odf_extract_slide(
  page : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  content_path : String,
  slide_index : Int,
) -> OdpSlideExtracted {
  let blocks : Array[OdpSlideBlock] = []
  let assets : Array[OdpImageRef] = []
  let page_name = odf_attr(page, "draw:name")
  for child in page.children {
    match child {
      Element(node) =>
        if node.name == "draw:frame" {
          let frame_blocks = odf_extract_slide_frame(
            node, archive, content_path,
          )
          for block in frame_blocks.blocks {
            blocks.push(block)
          }
          for asset in frame_blocks.assets {
            assets.push(asset)
          }
        } else if node.name == "draw:g" {
          odf_extract_slide_group(
            node, archive, content_path, blocks, assets, 1,
          )
        } else if node.name == "presentation:notes" {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            blocks.push({
              kind: Notes,
              text,
              rows: [],
              image: None,
              content_path,
              xml_path: "/presentation:notes",
              line_start: Some(node.span.line_start),
              line_end: Some(node.span.line_end),
              attrs: Map([
                ("notes_kind", "slide_notes"),
                ("slide_local", "true"),
              ]),
            })
          }
        } else {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            blocks.push({
              kind: Raw,
              text,
              rows: [],
              image: None,
              content_path,
              xml_path: "/" + node.name,
              line_start: Some(node.span.line_start),
              line_end: Some(node.span.line_end),
              attrs: Map([("slide_local", "true")]),
            })
          }
        }
      _ => ()
    }
  }
  match page_name {
    Some(name) =>
      if name.trim() != "" {
        blocks.insert(0, {
          kind: Heading,
          text: name,
          rows: [],
          image: None,
          content_path,
          xml_path: "/draw:page",
          line_start: Some(page.span.line_start),
          line_end: Some(page.span.line_end),
          attrs: Map([("slide_local", "true")]),
        })
      }
    None => ()
  }
  { slide: { index: slide_index, name: page_name, blocks }, assets }
}

///|
fn odf_extract_slide_group(
  group : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  content_path : String,
  blocks : Array[OdpSlideBlock],
  assets : Array[OdpImageRef],
  depth : Int,
) -> Unit {
  if depth > 32 {
    let text = odf_collect_text(group).trim().to_owned()
    if text != "" {
      blocks.push({
        kind: Raw,
        text,
        rows: [],
        image: None,
        content_path,
        xml_path: "/draw:g",
        line_start: Some(group.span.line_start),
        line_end: Some(group.span.line_end),
        attrs: Map([
          ("slide_local", "true"),
          ("group_depth", depth.to_string()),
          ("group_depth_limited", "true"),
        ]),
      })
    }
    return
  }
  for child in group.children {
    match child {
      Element(node) =>
        if node.name == "draw:frame" {
          let frame_blocks = odf_extract_slide_frame(
            node, archive, content_path,
          )
          for block in frame_blocks.blocks {
            block.attrs.set("group_depth", depth.to_string())
            blocks.push(block)
          }
          for asset in frame_blocks.assets {
            assets.push(asset)
          }
        } else if node.name == "draw:g" {
          odf_extract_slide_group(
            node,
            archive,
            content_path,
            blocks,
            assets,
            depth + 1,
          )
        } else {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            blocks.push({
              kind: Raw,
              text,
              rows: [],
              image: None,
              content_path,
              xml_path: "/draw:g/" + node.name,
              line_start: Some(node.span.line_start),
              line_end: Some(node.span.line_end),
              attrs: Map([
                ("slide_local", "true"),
                ("group_depth", depth.to_string()),
              ]),
            })
          }
        }
      _ => ()
    }
  }
}

///|
priv struct OdpFrameBlocks {
  blocks : Array[OdpSlideBlock]
  assets : Array[OdpImageRef]
}

///|
fn odf_extract_slide_frame(
  frame : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  content_path : String,
) -> OdpFrameBlocks {
  let blocks : Array[OdpSlideBlock] = []
  let assets : Array[OdpImageRef] = []
  for child in frame.children {
    match child {
      Element(node) =>
        if node.name == "draw:text-box" {
          odf_collect_slide_text_blocks(node, content_path, blocks)
        } else if node.name == "table:table" {
          blocks.push(odf_odp_table_block(node, content_path))
        } else if node.name == "draw:image" {
          match odf_attr(node, "xlink:href") {
            Some(href) => {
              let info = OdpImageRef::{
                href,
                media_type: odf_media_type_for_href(archive, href),
                alt: odf_attr(frame, "draw:name"),
                bytes: odf_read_entry_optional(archive, href),
              }
              assets.push(info)
              blocks.push({
                kind: Image,
                text: "",
                rows: [],
                image: Some(info),
                content_path,
                xml_path: "/draw:frame/draw:image",
                line_start: Some(node.span.line_start),
                line_end: Some(node.span.line_end),
                attrs: Map([
                  ("slide_local", "true"),
                  ("asset_summary_ready", "true"),
                ]),
              })
            }
            None => ()
          }
        } else if node.name == "draw:object" || node.name == "chart:chart" {
          let text = odf_extract_chart_text(node, archive)
          if text != "" {
            blocks.push({
              kind: Raw,
              text,
              rows: [],
              image: None,
              content_path,
              xml_path: "/draw:frame/" + node.name,
              line_start: Some(node.span.line_start),
              line_end: Some(node.span.line_end),
              attrs: Map([
                ("slide_local", "true"),
                ("semantic_kind", "chart_text"),
              ]),
            })
          }
        } else {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            blocks.push({
              kind: Raw,
              text,
              rows: [],
              image: None,
              content_path,
              xml_path: "/" + node.name,
              line_start: Some(node.span.line_start),
              line_end: Some(node.span.line_end),
              attrs: Map([("slide_local", "true")]),
            })
          }
        }
      _ => ()
    }
  }
  { blocks, assets }
}

///|
fn odf_extract_chart_text(
  node : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
) -> String {
  let inline = odf_collect_text(node).trim().to_owned()
  if inline != "" {
    return inline
  }
  let href = match odf_attr(node, "xlink:href") {
    Some(value) => value.trim().to_owned()
    None => return ""
  }
  let normalized = if href.has_prefix("./") {
    href[2:].to_owned()
  } else {
    href
  }
  if normalized == "" ||
    normalized.has_prefix("/") ||
    normalized.contains("..") ||
    normalized.contains("\\") {
    return ""
  }
  let path = if normalized.has_suffix("/") {
    normalized + "content.xml"
  } else {
    normalized + "/content.xml"
  }
  let bytes = match odf_read_entry_optional(archive, path) {
    Some(value) => value
    None => return ""
  }
  let xml = @utf8.decode(bytes, ignore_bom=false) catch { _ => return "" }
  let document = try @dxml.parse_xml_document(xml) |> Ok catch {
    _ => Err(())
  }
  match document {
    Ok(value) =>
      match value.root {
        Some(root) => odf_collect_text(root).trim().to_owned()
        None => ""
      }
    Err(_) => ""
  }
}

///|
fn odf_collect_slide_text_blocks(
  text_box : @dxml.XmlElement,
  content_path : String,
  blocks : Array[OdpSlideBlock],
) -> Unit {
  for child in text_box.children {
    match child {
      Element(node) =>
        if node.name == "text:h" {
          blocks.push({
            kind: Heading,
            text: odf_collect_text(node).trim().to_owned(),
            rows: [],
            image: None,
            content_path,
            xml_path: "/draw:frame/draw:text-box/text:h",
            line_start: Some(node.span.line_start),
            line_end: Some(node.span.line_end),
            attrs: Map([("slide_local", "true")]),
          })
        } else if node.name == "text:p" {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            blocks.push({
              kind: Paragraph,
              text,
              rows: [],
              image: None,
              content_path,
              xml_path: "/draw:frame/draw:text-box/text:p",
              line_start: Some(node.span.line_start),
              line_end: Some(node.span.line_end),
              attrs: Map([("slide_local", "true")]),
            })
          }
        } else if node.name == "text:list" {
          odf_collect_slide_list_items(node, content_path, blocks)
        } else {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            blocks.push({
              kind: Raw,
              text,
              rows: [],
              image: None,
              content_path,
              xml_path: "/" + node.name,
              line_start: Some(node.span.line_start),
              line_end: Some(node.span.line_end),
              attrs: Map([("slide_local", "true")]),
            })
          }
        }
      _ => ()
    }
  }
}

///|
fn odf_collect_slide_list_items(
  list : @dxml.XmlElement,
  content_path : String,
  blocks : Array[OdpSlideBlock],
) -> Unit {
  for child in list.children {
    match child {
      Element(item) =>
        if item.name == "text:list-item" {
          let text = odf_collect_text(item).trim().to_owned()
          if text != "" {
            blocks.push({
              kind: ListItem,
              text,
              rows: [],
              image: None,
              content_path,
              xml_path: "/draw:frame/draw:text-box/text:list/text:list-item",
              line_start: Some(item.span.line_start),
              line_end: Some(item.span.line_end),
              attrs: Map([("slide_local", "true")]),
            })
          }
        }
      _ => ()
    }
  }
}

///|
fn odf_odp_table_block(
  element : @dxml.XmlElement,
  content_path : String,
) -> OdpSlideBlock {
  let rows : Array[OdpTableRow] = []
  for child in element.children {
    match child {
      Element(row) =>
        if row.name == "table:table-row" {
          let cells : Array[OdpTableCell] = []
          for cell_node in row.children {
            match cell_node {
              Element(cell) =>
                if cell.name == "table:table-cell" {
                  cells.push({ text: odf_collect_text(cell).trim().to_owned() })
                }
              _ => ()
            }
          }
          if cells.length() > 0 {
            rows.push({ cells, })
          }
        }
      _ => ()
    }
  }
  {
    kind: Table,
    text: "table",
    rows,
    image: None,
    content_path,
    xml_path: "/draw:frame/table:table",
    line_start: Some(element.span.line_start),
    line_end: Some(element.span.line_end),
    attrs: Map([("slide_local", "true")]),
  }
}
