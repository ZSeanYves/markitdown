///|
const ODF_MIMETYPE_ODT : String = "application/vnd.oasis.opendocument.text"

///|
const ODF_MIMETYPE_ODS : String = "application/vnd.oasis.opendocument.spreadsheet"

///|
const ODF_MIMETYPE_ODP : String = "application/vnd.oasis.opendocument.presentation"

///|
pub fn open_odt_document(bytes : Bytes) -> OdtDocument raise {
  open_odt_archive(@dzip.open_zip(bytes))
}

///|
pub fn open_odt_archive(archive : @dzip.ZipArchive) -> OdtDocument raise {
  let package_info = read_odf_package_info(archive)
  if package_info.document_kind != OdfDocumentKind::Odt {
    raise ParseError("package is not an ODT document")
  }
  let content = parse_odf_content_document(archive, package_info.content_path)
  let metadata = read_odf_metadata(archive, package_info)
  let styles = odf_collect_text_styles(archive, package_info, content)
  let state : OdtLowerState = {
    blocks: [],
    assets: [],
    content_path: package_info.content_path,
    list_depth: 0,
    styles,
  }
  match content.root {
    Some(root) => odf_visit_document_root(root, archive, state)
    None => raise ParseError("odt content.xml missing root element")
  }
  { package_info, metadata, blocks: state.blocks, assets: state.assets }
}

///|
pub fn open_ods_document(bytes : Bytes) -> OdsDocument raise {
  open_ods_archive(@dzip.open_zip(bytes))
}

///|
pub fn open_ods_archive(archive : @dzip.ZipArchive) -> OdsDocument raise {
  let package_info = read_odf_package_info(archive)
  if package_info.document_kind != OdfDocumentKind::Ods {
    raise ParseError("package is not an ODS document")
  }
  let content = parse_odf_content_document(archive, package_info.content_path)
  let metadata = read_odf_metadata(archive, package_info)
  let sheets = match content.root {
    Some(root) => odf_extract_spreadsheet_sheets(root, archive)
    None => raise ParseError("ods content.xml missing root element")
  }
  let assets : Array[OdtImageRef] = []
  for sheet in sheets {
    assets.append(sheet.images[:])
  }
  { package_info, metadata, sheets, assets }
}

///|
pub fn open_odp_document(bytes : Bytes) -> OdpDocument raise {
  open_odp_archive(@dzip.open_zip(bytes))
}

///|
pub fn open_odp_archive(archive : @dzip.ZipArchive) -> OdpDocument raise {
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
  styles : Map[String, OdfTextStyle]
}

///|
priv struct OdfTextStyle {
  display_name : String?
  parent_name : String?
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
      state.blocks.push(
        odf_paragraph_block(element, state.content_path, state.styles),
      )
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
  styles : Map[String, OdfTextStyle],
) -> OdtBlock {
  let inline_model = odf_collect_odt_inlines(element)
  let text = odf_text_from_inlines(inline_model)
  let normalized = if text.contains("\n") {
    text.trim().to_owned()
  } else {
    text.replace_all(old="\n", new=" ").trim().to_owned()
  }
  let inherited_heading_level = odf_paragraph_heading_level(element, styles)
  let kind = if inherited_heading_level is Some(_) {
    OdtBlockKind::Heading
  } else if odf_paragraph_is_code_like(element, styles) {
    OdtBlockKind::Code
  } else {
    OdtBlockKind::Paragraph
  }
  {
    kind,
    text: normalized,
    level: inherited_heading_level,
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
                  let repeat = odf_bounded_repeat_count(
                    cell, "table:number-columns-repeated", 16_384,
                  )
                  let text = odf_collect_text(cell).trim().to_owned()
                  for _ in 0..<repeat {
                    cells.push({ text, })
                  }
                }
              _ => ()
            }
          }
          if cells.length() > 0 {
            let repeat = odf_bounded_repeat_count(
              row, "table:number-rows-repeated", 10_000,
            )
            for _ in 0..<repeat {
              rows.push({ cells: cells.copy() })
            }
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
fn odf_extract_spreadsheet_sheets(
  root : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
) -> Array[OdsSheet] raise {
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
                          sheets.push(odf_extract_sheet(sheet, archive))
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
fn odf_extract_sheet(
  sheet : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
) -> OdsSheet raise {
  let name = odf_attr(sheet, "table:name").unwrap_or("Sheet")
  let visible = match odf_attr(sheet, "table:display") {
    Some(value) => value.trim().to_lower() != "false"
    None => true
  }
  let rows : Array[OdsRow] = []
  let images : Array[OdtImageRef] = []
  odf_collect_sheet_images(sheet, archive, images)
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
  { name, rows, visible, images }
}

///|
fn odf_collect_sheet_images(
  element : @dxml.XmlElement,
  archive : @dzip.ZipArchive,
  images : Array[OdtImageRef],
) -> Unit {
  if element.name == "draw:image" {
    match odf_attr(element, "xlink:href") {
      Some(href) =>
        images.push({
          href,
          media_type: odf_media_type_for_href(archive, href),
          alt: odf_attr(element, "draw:name"),
          bytes: odf_read_entry_optional(archive, href),
        })
      None => ()
    }
  }
  for child in element.children {
    match child {
      Element(next) => odf_collect_sheet_images(next, archive, images)
      _ => ()
    }
  }
}

///|
fn odf_extract_sheet_row(
  row : @dxml.XmlElement,
  row_index : Int,
) -> OdsRow raise {
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
