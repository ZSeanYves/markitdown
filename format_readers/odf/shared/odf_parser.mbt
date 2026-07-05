///|
const ODF_MIMETYPE_ODT : String = "application/vnd.oasis.opendocument.text"

///|
const ODF_MIMETYPE_ODS : String = "application/vnd.oasis.opendocument.spreadsheet"

///|
const ODF_MIMETYPE_ODP : String = "application/vnd.oasis.opendocument.presentation"

///|
pub fn open_odt_document(bytes : Bytes) -> OdtDocument raise {
  let archive = @dzip.open_zip(bytes)
  let package_info = read_odf_package_info(archive)
  if package_info.document_kind != OdfDocumentKind::Odt {
    raise ParseError("package is not an ODT document")
  }
  let content = parse_odf_content_document(archive, package_info.content_path)
  let metadata = read_odf_metadata(archive, package_info)
  let state : OdtLowerState = {
    blocks: [],
    assets: [],
    content_path: package_info.content_path,
    list_depth: 0,
  }
  match content.root {
    Some(root) => odf_visit_document_root(root, archive, state)
    None => raise ParseError("odt content.xml missing root element")
  }
  { package_info, metadata, blocks: state.blocks, assets: state.assets }
}

///|
pub fn open_ods_document(bytes : Bytes) -> OdsDocument raise {
  let archive = @dzip.open_zip(bytes)
  let package_info = read_odf_package_info(archive)
  if package_info.document_kind != OdfDocumentKind::Ods {
    raise ParseError("package is not an ODS document")
  }
  let content = parse_odf_content_document(archive, package_info.content_path)
  let metadata = read_odf_metadata(archive, package_info)
  let sheets = match content.root {
    Some(root) => odf_extract_spreadsheet_sheets(root)
    None => raise ParseError("ods content.xml missing root element")
  }
  { package_info, metadata, sheets }
}

///|
pub fn open_odp_document(bytes : Bytes) -> OdpDocument raise {
  let archive = @dzip.open_zip(bytes)
  let package_info = read_odf_package_info(archive)
  if package_info.document_kind != OdfDocumentKind::Odp {
    raise ParseError("package is not an ODP document")
  }
  let content = parse_odf_content_document(archive, package_info.content_path)
  let metadata = read_odf_metadata(archive, package_info)
  let extracted = match content.root {
    Some(root) =>
      odf_extract_presentation_slides(root, archive, package_info.content_path)
    None => raise ParseError("odp content.xml missing root element")
  }
  { package_info, metadata, slides: extracted.slides, assets: extracted.assets }
}

///|
pub fn inspect_odt_package(bytes : Bytes) -> OdfPackageInfo raise {
  let archive = @dzip.open_zip(bytes)
  read_odf_package_info(archive)
}

///|
priv struct OdtLowerState {
  blocks : Array[OdtBlock]
  assets : Array[OdtImageRef]
  content_path : String
  mut list_depth : Int
}

///|
priv struct OdpExtractState {
  slides : Array[OdpSlide]
  assets : Array[OdpImageRef]
}

///|
fn read_odf_package_info(archive : @dzip.ZipArchive) -> OdfPackageInfo raise {
  if !@dzip.has_entry(archive, "META-INF/manifest.xml") ||
    !@dzip.has_entry(archive, "content.xml") {
    raise ParseError("odf package missing manifest.xml or content.xml")
  }
  if !@dzip.has_entry(archive, "mimetype") {
    raise ParseError("odf package missing mimetype")
  }
  let mimetype = odf_read_entry_text(archive, "mimetype").trim().to_owned()
  let document_kind = match mimetype {
    ODF_MIMETYPE_ODT => OdfDocumentKind::Odt
    ODF_MIMETYPE_ODS => OdfDocumentKind::Ods
    ODF_MIMETYPE_ODP => OdfDocumentKind::Odp
    _ => raise ParseError("unsupported odf mimetype: " + mimetype)
  }
  {
    document_kind,
    mimetype,
    manifest_seen: true,
    content_path: "content.xml",
    meta_path: if @dzip.has_entry(archive, "meta.xml") {
      Some("meta.xml")
    } else {
      None
    },
    styles_path: if @dzip.has_entry(archive, "styles.xml") {
      Some("styles.xml")
    } else {
      None
    },
  }
}

///|
fn read_odf_metadata(
  archive : @dzip.ZipArchive,
  package_info : OdfPackageInfo,
) -> OdfMetadataSummary {
  match package_info.meta_path {
    Some(path) => {
      let meta_text = try odf_read_entry_text(archive, path) |> Ok catch {
        _ => Err(())
      }
      match meta_text {
        Ok(text) => {
          let meta_doc = try @dxml.parse_xml_document(text) |> Ok catch {
            _ => Err(())
          }
          match meta_doc {
            Ok(doc) => odf_extract_metadata(doc)
            Err(_) =>
              { title: None, subject: None, description: None, language: None }
          }
        }
        Err(_) =>
          { title: None, subject: None, description: None, language: None }
      }
    }
    None => { title: None, subject: None, description: None, language: None }
  }
}

///|
fn parse_odf_content_document(
  archive : @dzip.ZipArchive,
  content_path : String,
) -> @dxml.XmlDocument raise {
  let content_text = odf_read_entry_text(archive, content_path)
  @dxml.parse_xml_document(content_text)
}

///|
fn odf_read_entry_text(
  archive : @dzip.ZipArchive,
  path : String,
) -> String raise {
  let bytes = @dzip.read_entry(archive, path)
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise ParseError("failed to decode utf-8 entry: " + path)
  }
}

///|
fn odf_visit_document_root(
  root : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  state : OdtLowerState,
) -> Unit {
  for child in root.children {
    match child {
      Element(element) =>
        if element.name == "office:body" {
          odf_visit_office_body(element, archive, state)
        }
      _ => ()
    }
  }
}

///|
fn odf_visit_office_body(
  body : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  state : OdtLowerState,
) -> Unit {
  for child in body.children {
    match child {
      Element(element) =>
        if element.name == "office:text" {
          odf_visit_text_body(element, archive, state)
        }
      _ => ()
    }
  }
}

///|
fn odf_visit_text_body(
  node : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  state : OdtLowerState,
) -> Unit {
  for child in node.children {
    match child {
      Element(element) => odf_visit_text_element(element, archive, state)
      _ => ()
    }
  }
}

///|
fn odf_visit_text_element(
  element : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  state : OdtLowerState,
) -> Unit {
  match element.name {
    "text:h" =>
      state.blocks.push(odf_heading_block(element, state.content_path))
    "text:p" => {
      state.blocks.push(odf_paragraph_block(element, state.content_path))
      odf_visit_paragraph_frame_images(element, archive, state)
    }
    "text:list" => odf_visit_list(element, archive, state)
    "table:table" =>
      state.blocks.push(odf_table_block(element, state.content_path))
    "draw:frame" => odf_visit_frame(element, archive, state)
    "text:section" =>
      for child in element.children {
        match child {
          Element(next) => odf_visit_text_element(next, archive, state)
          _ => ()
        }
      }
    _ => {
      let text = odf_collect_text(element).trim().to_owned()
      if text != "" {
        state.blocks.push({
          kind: OdtBlockKind::Raw,
          text,
          level: None,
          list_depth: None,
          rows: [],
          image: None,
          inlines: [
            {
              text,
              href: None,
              note_id: None,
              note_kind: None,
              note_marker: None,
              note_body: None,
            },
          ],
          note: None,
          content_path: state.content_path,
          xml_path: "/" + element.name,
          line_start: Some(element.span.line_start),
          line_end: Some(element.span.line_end),
          attrs: Map([]),
        })
      }
    }
  }
}

///|
fn odf_visit_paragraph_frame_images(
  element : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  state : OdtLowerState,
) -> Unit {
  for child in element.children {
    match child {
      Element(node) =>
        if node.name == "draw:frame" {
          odf_visit_frame(node, archive, state)
        } else if node.name == "text:span" {
          odf_visit_paragraph_frame_images_in_span(node, archive, state)
        }
      _ => ()
    }
  }
}

///|
fn odf_visit_paragraph_frame_images_in_span(
  element : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  state : OdtLowerState,
) -> Unit {
  for child in element.children {
    match child {
      Element(node) =>
        if node.name == "draw:frame" {
          odf_visit_frame(node, archive, state)
        } else if node.name == "text:span" {
          odf_visit_paragraph_frame_images_in_span(node, archive, state)
        }
      _ => ()
    }
  }
}

///|
fn odf_heading_block(
  element : @dxml.XmlElement,
  content_path : String,
) -> OdtBlock {
  let text = odf_collect_text(element).trim().to_owned()
  let level = match odf_attr(element, "text:outline-level") {
    Some(raw) => @string.parse_int(raw.trim().to_owned()) catch { _ => 1 }
    None => 1
  }
  {
    kind: OdtBlockKind::Heading,
    text,
    level: Some(level),
    list_depth: None,
    rows: [],
    image: None,
    inlines: [
      {
        text,
        href: None,
        note_id: None,
        note_kind: None,
        note_marker: None,
        note_body: None,
      },
    ],
    note: None,
    content_path,
    xml_path: "/text:h",
    line_start: Some(element.span.line_start),
    line_end: Some(element.span.line_end),
    attrs: Map([]),
  }
}

///|
fn odf_paragraph_block(
  element : @dxml.XmlElement,
  content_path : String,
) -> OdtBlock {
  let inline_model = odf_collect_odt_inlines(element)
  let text = odf_text_from_inlines(inline_model)
  let normalized = if text.contains("\n") {
    text.trim().to_owned()
  } else {
    text.replace_all(old="\n", new=" ").trim().to_owned()
  }
  let kind = if odf_paragraph_is_code_like(element) {
    OdtBlockKind::Code
  } else {
    OdtBlockKind::Paragraph
  }
  {
    kind,
    text: normalized,
    level: None,
    list_depth: None,
    rows: [],
    image: None,
    inlines: inline_model,
    note: None,
    content_path,
    xml_path: "/text:p",
    line_start: Some(element.span.line_start),
    line_end: Some(element.span.line_end),
    attrs: Map([]),
  }
}

///|
fn odf_visit_list(
  element : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  state : OdtLowerState,
) -> Unit {
  state.list_depth += 1
  for child in element.children {
    match child {
      Element(item) =>
        if item.name == "text:list-item" {
          let text = odf_collect_text(item).trim().to_owned()
          if text != "" {
            state.blocks.push({
              kind: OdtBlockKind::ListItem,
              text,
              level: None,
              list_depth: Some(state.list_depth),
              rows: [],
              image: None,
              inlines: [
                {
                  text,
                  href: None,
                  note_id: None,
                  note_kind: None,
                  note_marker: None,
                  note_body: None,
                },
              ],
              note: None,
              content_path: state.content_path,
              xml_path: "/text:list/text:list-item",
              line_start: Some(item.span.line_start),
              line_end: Some(item.span.line_end),
              attrs: Map([]),
            })
          }
          for nested in item.children {
            match nested {
              Element(next) =>
                if next.name == "text:list" {
                  odf_visit_list(next, archive, state)
                }
              _ => ()
            }
          }
        }
      _ => ()
    }
  }
  state.list_depth -= 1
}

///|
fn odf_table_block(
  element : @dxml.XmlElement,
  content_path : String,
) -> OdtBlock {
  let rows : Array[OdtTableRow] = []
  for child in element.children {
    match child {
      Element(row) =>
        if row.name == "table:table-row" {
          let cells : Array[OdtTableCell] = []
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
    kind: OdtBlockKind::Table,
    text: "table",
    level: None,
    list_depth: None,
    rows,
    image: None,
    inlines: [],
    note: None,
    content_path,
    xml_path: "/table:table",
    line_start: Some(element.span.line_start),
    line_end: Some(element.span.line_end),
    attrs: Map([]),
  }
}

///|
fn odf_visit_frame(
  element : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  state : OdtLowerState,
) -> Unit {
  for child in element.children {
    match child {
      Element(image) =>
        if image.name == "draw:image" {
          match odf_attr(image, "xlink:href") {
            Some(href) => {
              let info = OdtImageRef::{
                href,
                media_type: odf_media_type_for_href(archive, href),
                alt: odf_attr(element, "draw:name"),
                bytes: odf_read_entry_optional(archive, href),
              }
              state.assets.push(info)
              state.blocks.push({
                kind: OdtBlockKind::Image,
                text: "",
                level: None,
                list_depth: None,
                rows: [],
                image: Some(info),
                inlines: [],
                note: None,
                content_path: state.content_path,
                xml_path: "/draw:frame/draw:image",
                line_start: Some(image.span.line_start),
                line_end: Some(image.span.line_end),
                attrs: Map([]),
              })
            }
            None => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn odf_extract_spreadsheet_sheets(root : @dxml.XmlElement) -> Array[OdsSheet] {
  let sheets : Array[OdsSheet] = []
  for child in root.children {
    match child {
      Element(body) =>
        if body.name == "office:body" {
          for body_child in body.children {
            match body_child {
              Element(spreadsheet) =>
                if spreadsheet.name == "office:spreadsheet" {
                  for node in spreadsheet.children {
                    match node {
                      Element(sheet) =>
                        if sheet.name == "table:table" {
                          sheets.push(odf_extract_sheet(sheet))
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
  sheets
}

///|
fn odf_extract_sheet(sheet : @dxml.XmlElement) -> OdsSheet {
  let name = odf_attr(sheet, "table:name").unwrap_or("Sheet")
  let visible = match odf_attr(sheet, "table:display") {
    Some(value) => value.trim().to_lower() != "false"
    None => true
  }
  let rows : Array[OdsRow] = []
  let mut row_index = 0
  for child in sheet.children {
    match child {
      Element(row) =>
        if row.name == "table:table-row" {
          let repeat = odf_repeated_count(row, "table:number-rows-repeated")
          let extracted = odf_extract_sheet_row(row, row_index)
          rows.push(extracted)
          row_index += repeat
        }
      _ => ()
    }
  }
  { name, rows, visible }
}

///|
fn odf_extract_sheet_row(row : @dxml.XmlElement, row_index : Int) -> OdsRow {
  let cells : Array[OdsCell] = []
  let hidden = match odf_attr(row, "table:visibility") {
    Some(value) => value.trim().to_lower() == "collapse"
    None => false
  }
  let repeat_count = odf_repeated_count(row, "table:number-rows-repeated")
  for child in row.children {
    match child {
      Element(cell) =>
        if cell.name == "table:table-cell" ||
          cell.name == "table:covered-table-cell" {
          let repeat = odf_repeated_count(cell, "table:number-columns-repeated")
          let text = odf_collect_text(cell).trim().to_owned()
          let formula = odf_attr(cell, "table:formula")
          let col_span = odf_attr(cell, "table:number-columns-spanned")
            .map(raw => @string.parse_int(raw.trim()) catch { _ => 1 })
            .unwrap_or(1)
          let row_span = odf_attr(cell, "table:number-rows-spanned")
            .map(raw => @string.parse_int(raw.trim()) catch { _ => 1 })
            .unwrap_or(1)
          let next : OdsCell = {
            text,
            formula,
            covered: false,
            col_span,
            row_span,
            repeat_count: repeat,
          }
          let cell_to_store : OdsCell = if cell.name ==
            "table:covered-table-cell" {
            {
              text: "",
              formula: None,
              covered: true,
              col_span: 1,
              row_span: 1,
              repeat_count: repeat,
            }
          } else {
            next
          }
          cells.push(cell_to_store)
        }
      _ => ()
    }
  }
  { cells, row_index, hidden, repeat_count }
}

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
        } else if node.name == "presentation:notes" {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            blocks.push({
              kind: OdpBlockKind::Notes,
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
              kind: OdpBlockKind::Raw,
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
          kind: OdpBlockKind::Heading,
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
                kind: OdpBlockKind::Image,
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
        } else {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            blocks.push({
              kind: OdpBlockKind::Raw,
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
            kind: OdpBlockKind::Heading,
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
              kind: OdpBlockKind::Paragraph,
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
              kind: OdpBlockKind::Raw,
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
              kind: OdpBlockKind::ListItem,
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
    kind: OdpBlockKind::Table,
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

///|
fn odf_repeated_count(element : @dxml.XmlElement, name : String) -> Int {
  match odf_attr(element, name) {
    Some(raw) => @string.parse_int(raw.trim().to_owned()) catch { _ => 1 }
    None => 1
  }
}

///|
fn odf_attr(element : @dxml.XmlElement, name : String) -> String? {
  for attr in element.attributes {
    if attr.name == name {
      return Some(attr.value)
    }
  }
  None
}

///|
fn odf_collect_text(element : @dxml.XmlElement) -> String {
  let out : Array[String] = []
  odf_collect_text_into(element, out)
  out.join("")
}

///|
fn odf_collect_text_into(
  element : @dxml.XmlElement,
  out : Array[String],
) -> Unit {
  for child in element.children {
    match child {
      Text(text) => out.push(text.text)
      CData(text) => out.push(text.text)
      Element(next) =>
        if next.name == "text:line-break" {
          out.push("\n")
        } else if next.name == "text:s" {
          out.push(" ")
        } else if next.name == "text:tab" {
          out.push("\t")
        } else {
          odf_collect_text_into(next, out)
        }
      _ => ()
    }
  }
}

///|
fn odf_collect_odt_inlines(element : @dxml.XmlElement) -> Array[OdtInline] {
  let out : Array[OdtInline] = []
  odf_collect_odt_inlines_into(element, out)
  odf_compact_odt_inlines(out)
}

///|
fn odf_collect_odt_inlines_into(
  element : @dxml.XmlElement,
  out : Array[OdtInline],
) -> Unit {
  for child in element.children {
    match child {
      Text(text) =>
        if text.text != "" {
          out.push(odf_plain_odt_inline(text.text))
        }
      CData(text) =>
        if text.text != "" {
          out.push(odf_plain_odt_inline(text.text))
        }
      Element(next) =>
        if next.name == "text:a" {
          let text = odf_collect_text(next)
          if text != "" {
            out.push({
              text,
              href: odf_attr(next, "xlink:href"),
              note_id: None,
              note_kind: None,
              note_marker: None,
              note_body: None,
            })
          }
        } else if next.name == "office:annotation" {
          match odf_extract_comment_inline(next) {
            Some(comment) => out.push(comment)
            None => ()
          }
        } else if next.name == "text:note" {
          match odf_extract_note(next) {
            Some(note) =>
              out.push({
                text: note.citation,
                href: None,
                note_id: Some(note.id),
                note_kind: Some(note.kind),
                note_marker: Some(note.citation),
                note_body: Some(note.body),
              })
            None => ()
          }
        } else if next.name == "text:line-break" {
          out.push(odf_plain_odt_inline("\n"))
        } else if next.name == "text:s" {
          out.push(odf_plain_odt_inline(" "))
        } else if next.name == "text:tab" {
          out.push(odf_plain_odt_inline("\t"))
        } else {
          odf_collect_odt_inlines_into(next, out)
        }
      _ => ()
    }
  }
}

///|
fn odf_plain_odt_inline(text : String) -> OdtInline {
  {
    text,
    href: None,
    note_id: None,
    note_kind: None,
    note_marker: None,
    note_body: None,
  }
}

///|
fn odf_compact_odt_inlines(inlines : Array[OdtInline]) -> Array[OdtInline] {
  let out : Array[OdtInline] = []
  for inline in inlines {
    if inline.text == "" {
      continue
    }
    if out.length() == 0 {
      out.push(inline)
      continue
    }
    let last = out[out.length() - 1]
    if last.href == inline.href &&
      last.note_id == inline.note_id &&
      last.note_kind == inline.note_kind &&
      last.note_marker == inline.note_marker &&
      last.note_body == inline.note_body {
      out[out.length() - 1] = {
        text: last.text + inline.text,
        href: last.href,
        note_id: last.note_id,
        note_kind: last.note_kind,
        note_marker: last.note_marker,
        note_body: last.note_body,
      }
    } else {
      out.push(inline)
    }
  }
  out
}

///|
fn odf_text_from_inlines(inlines : Array[OdtInline]) -> String {
  let out : Array[String] = []
  for inline in inlines {
    out.push(inline.text)
  }
  out.join("")
}

///|
fn odf_extract_note(element : @dxml.XmlElement) -> OdtNote? {
  let kind = match odf_attr(element, "text:note-class") {
    Some(value) =>
      if value.trim().to_lower() == "endnote" {
        "endnote"
      } else {
        "footnote"
      }
    None => "footnote"
  }
  let id = odf_attr(element, "text:id").unwrap_or(
    kind + "-" + element.span.line_start.to_string(),
  )
  let mut citation = ""
  let mut body = ""
  for child in element.children {
    match child {
      Element(node) =>
        if node.name == "text:note-citation" {
          citation = odf_collect_text(node).trim().to_owned()
        } else if node.name == "text:note-body" {
          body = odf_collect_text(node).trim().to_owned()
        }
      _ => ()
    }
  }
  if body == "" {
    return None
  }
  let marker = if citation == "" {
    if kind == "endnote" {
      "[^e1]"
    } else {
      "[^1]"
    }
  } else if kind == "endnote" {
    "[^e" + citation + "]"
  } else {
    "[^" + citation + "]"
  }
  Some({ id, kind, citation: marker, body, author: None })
}

///|
fn odf_extract_comment_inline(element : @dxml.XmlElement) -> OdtInline? {
  let author = odf_extract_annotation_child_text(element, "dc:creator")
  let date = odf_extract_annotation_child_text(element, "dc:date")
  let body = odf_extract_annotation_body_text(element)
  if body == "" {
    return None
  }
  let id = "comment-" + element.span.line_start.to_string()
  let marker = "[comment " + element.span.line_start.to_string() + "]"
  Some({
    text: marker,
    href: None,
    note_id: Some(id),
    note_kind: Some("comment"),
    note_marker: Some(marker),
    note_body: Some(odf_compose_annotation_body(author, date, body)),
  })
}

///|
fn odf_extract_annotation_child_text(
  element : @dxml.XmlElement,
  name : String,
) -> String? {
  for child in element.children {
    match child {
      Element(node) =>
        if node.name == name {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            return Some(text)
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn odf_compose_annotation_body(
  author : String?,
  date : String?,
  body : String,
) -> String {
  let parts : Array[String] = []
  match author {
    Some(value) => parts.push(value)
    None => ()
  }
  match date {
    Some(value) => parts.push("(" + value + ")")
    None => ()
  }
  parts.push(body)
  parts.join(": ")
}

///|
fn odf_extract_annotation_body_text(element : @dxml.XmlElement) -> String {
  let body_parts : Array[String] = []
  for child in element.children {
    match child {
      Element(node) =>
        if node.name == "text:p" {
          let text = odf_collect_text(node).trim().to_owned()
          if text != "" {
            body_parts.push(text)
          }
        }
      _ => ()
    }
  }
  body_parts.join("\n").trim().to_owned()
}

///|
fn odf_extract_metadata(doc : @dxml.XmlDocument) -> OdfMetadataSummary {
  {
    title: odf_find_first_text(doc, "dc:title"),
    subject: odf_find_first_text(doc, "dc:subject"),
    description: odf_find_first_text(doc, "dc:description"),
    language: odf_find_first_text(doc, "dc:language"),
  }
}

///|
fn odf_find_first_text(doc : @dxml.XmlDocument, name : String) -> String? {
  match doc.root {
    Some(root) => odf_find_first_text_in_element(root, name)
    None => None
  }
}

///|
fn odf_find_first_text_in_element(
  element : @dxml.XmlElement,
  name : String,
) -> String? {
  if element.name == name {
    let text = odf_collect_text(element).trim().to_owned()
    if text != "" {
      return Some(text)
    }
  }
  for child in element.children {
    match child {
      Element(next) =>
        match odf_find_first_text_in_element(next, name) {
          Some(value) => return Some(value)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn odf_media_type_for_href(
  archive : @dzip.ZipArchive,
  href : String,
) -> String? {
  let trimmed = href.trim()
  if trimmed == "" {
    return None
  }
  let ext = match trimmed.split(".").to_array().last() {
    Some(value) => value.trim().to_lower().to_owned()
    None => ""
  }
  match ext {
    "png" => Some("image/png")
    "jpg" => Some("image/jpeg")
    "jpeg" => Some("image/jpeg")
    "gif" => Some("image/gif")
    "svg" => Some("image/svg+xml")
    _ =>
      if @dzip.has_entry(archive, trimmed.to_owned()) {
        Some("application/octet-stream")
      } else {
        None
      }
  }
}

///|
fn odf_read_entry_optional(archive : @dzip.ZipArchive, path : String) -> Bytes? {
  let normalized = path.trim().to_owned()
  if normalized == "" || !@dzip.has_entry(archive, normalized) {
    return None
  }
  try @dzip.read_entry(archive, path.trim().to_owned()) |> Some catch {
    _ => None
  }
}

///|
fn odf_paragraph_is_code_like(element : @dxml.XmlElement) -> Bool {
  match odf_attr(element, "text:style-name") {
    Some(name) => {
      let lower = name.to_lower()
      lower.contains("code") ||
      lower.contains("pre") ||
      lower.contains("source")
    }
    None => false
  }
}
