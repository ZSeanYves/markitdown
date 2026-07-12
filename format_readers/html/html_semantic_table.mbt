///|
fn collect_html_semantic_table_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_table_order += 1
  let source_key = "html:table:" + ctx.next_table_order.to_string()
  let sections : Array[String] = []
  let rows : Array[String] = []
  let cells : Array[String] = []
  let table_warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    table_warnings.push(warning)
  }

  let caption = find_html_semantic_direct_child_element(element, "caption")
  let caption_source_key = caption.map(fn(caption_element) {
    html_semantic_caption_source_key(source_key, caption_element)
  })
  let caption_text_preview = caption.map(fn(caption_element) {
    html_semantic_text_preview(caption_element.children).0
  })

  let row_count : Ref[Int] = { val: 0 }
  let cell_count : Ref[Int] = { val: 0 }
  for child in element.children {
    match child {
      HtmlNode::Element(child_element) =>
        if html_semantic_table_section_kind(child_element.tag_name)
          is Some(kind) {
          collect_html_semantic_table_section_fact(
            child_element,
            ctx,
            source_key,
            block_source_key,
            kind,
            depth + 1,
            sections,
            rows,
            cells,
            row_count,
            cell_count,
          )
        } else if child_element.tag_name == "tr" {
          ignore(
            collect_html_semantic_table_row_fact(
              child_element,
              ctx,
              source_key,
              None,
              block_source_key,
              depth + 1,
              rows,
              cells,
              row_count,
              cell_count,
            ),
          )
        } else {
          collect_html_semantic_table_nested_rows(
            child_element,
            ctx,
            source_key,
            None,
            block_source_key,
            depth + 1,
            rows,
            cells,
            row_count,
            cell_count,
          )
        }
      _ => ()
    }
  }

  if row_count.val > HTML_SEMANTIC_TABLE_MAX_ROWS ||
    cell_count.val > HTML_SEMANTIC_TABLE_MAX_CELLS {
    table_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TableSizeLimitExceeded,
        source_key,
        element.tag_name,
        "html semantic table size limit exceeded",
      ),
    )
    ignore(
      push_html_semantic_unsupported_fact(
        ctx,
        HtmlUnsupportedKind::HugeTable,
        HtmlWarningSeverity::Warning,
        Some(source_key),
        element.tag_name,
        ctx.next_table_order,
        depth,
        parent_block_source_key,
        text_preview,
        attributes,
        None,
        element.span,
        "html semantic table size limit exceeded",
      ),
    )
  }
  if row_count.val == 0 || cell_count.val == 0 {
    table_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedTableStructure,
        source_key,
        element.tag_name,
        "html semantic table has no rows or cells",
      ),
    )
  }
  push_html_semantic_warnings(ctx, table_warnings)

  let max_column_count = html_semantic_table_max_column_count(ctx, rows)
  let has_ragged_rows = html_semantic_table_has_ragged_rows(
    ctx, rows, max_column_count,
  )
  let has_span = html_semantic_table_has_span(ctx, cells)
  let has_caption = caption_source_key is Some(_)
  let has_nested_table = html_semantic_table_has_nested_table(
    ctx, block_source_key,
  )
  let has_complex_cell = html_semantic_table_has_complex_cell(ctx, cells)
  let span_cell_count = html_semantic_table_span_cell_count(ctx, cells)
  let ragged_row_count = html_semantic_table_ragged_row_count(
    ctx, rows, max_column_count,
  )
  let nested_table_cell_count = html_semantic_table_nested_cell_count(
    ctx, cells,
  )
  let complex_cell_count = html_semantic_table_complex_cell_count(ctx, cells)
  let image_cell_count = html_semantic_table_image_cell_count(ctx, cells)
  let block_child_cell_count = html_semantic_table_block_child_cell_count(
    ctx, cells,
  )
  let malformed_warning_count = html_semantic_warning_kind_count(
    table_warnings,
    HtmlSemanticWarningKind::MalformedTableStructure,
  )
  let safe_simple_table_candidate = table_warnings.length() == 0 &&
    row_count.val > 0 &&
    cell_count.val > 0 &&
    !has_ragged_rows &&
    !has_span &&
    !has_caption &&
    !has_nested_table &&
    !has_complex_cell

  ctx.tables.push({
    source_key,
    block_source_key,
    tag_name: element.tag_name,
    source_order,
    depth,
    parent_block_source_key,
    caption_source_key,
    caption_text_preview,
    sections,
    rows,
    cells,
    row_count: row_count.val,
    cell_count: cell_count.val,
    max_column_count,
    has_ragged_rows,
    has_span,
    has_caption,
    has_nested_table,
    has_complex_cell,
    span_cell_count,
    ragged_row_count,
    nested_table_cell_count,
    complex_cell_count,
    image_cell_count,
    block_child_cell_count,
    malformed_warning_count,
    safe_simple_table_candidate,
    text_preview,
    attributes,
    span: element.span,
    warnings: table_warnings,
  })
}

///|
fn collect_html_semantic_table_section_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  table_source_key : String,
  block_source_key : String,
  kind : HtmlTableSectionKind,
  depth : Int,
  table_sections : Array[String],
  table_rows : Array[String],
  table_cells : Array[String],
  row_count : Ref[Int],
  cell_count : Ref[Int],
) -> Unit {
  ctx.next_table_section_order += 1
  let source_order = ctx.next_table_section_order
  let source_key = "html:table-section:" + source_order.to_string()
  let local_warnings : Array[HtmlSemanticWarning] = []
  let (attrs, attr_warnings) = html_semantic_attribute_summary(
    element, source_key,
  )
  for warning in attr_warnings {
    local_warnings.push(warning)
  }
  let (text_preview, text_truncated) = html_semantic_text_preview(
    element.children,
  )
  if text_truncated {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TextPreviewTruncated,
        source_key,
        element.tag_name,
        "html semantic table section text preview truncated for <" +
        element.tag_name +
        ">",
      ),
    )
  }

  let row_source_keys : Array[String] = []
  let start_row_count = row_count.val
  for child in element.children {
    match child {
      HtmlNode::Element(child_element) =>
        if child_element.tag_name == "tr" {
          match
            collect_html_semantic_table_row_fact(
              child_element,
              ctx,
              table_source_key,
              Some(source_key),
              block_source_key,
              depth + 1,
              table_rows,
              table_cells,
              row_count,
              cell_count,
            ) {
            Some(row_key) => row_source_keys.push(row_key)
            None => ()
          }
        } else {
          collect_html_semantic_table_nested_rows(
            child_element,
            ctx,
            table_source_key,
            Some(source_key),
            block_source_key,
            depth + 1,
            table_rows,
            table_cells,
            row_count,
            cell_count,
          )
        }
      _ => ()
    }
  }
  if row_source_keys.length() == 0 {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedTableStructure,
        source_key,
        element.tag_name,
        "html semantic table section has no rows",
      ),
    )
  }
  push_html_semantic_warnings(ctx, local_warnings)

  table_sections.push(source_key)
  ctx.table_sections.push({
    source_key,
    table_source_key,
    block_source_key,
    kind,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    row_source_keys,
    row_count: row_count.val - start_row_count,
    text_preview,
    attributes: attrs,
    span: element.span,
    warnings: local_warnings,
  })
}

///|
fn collect_html_semantic_table_nested_rows(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  table_source_key : String,
  section_source_key : String?,
  table_block_source_key : String,
  depth : Int,
  table_rows : Array[String],
  table_cells : Array[String],
  row_count : Ref[Int],
  cell_count : Ref[Int],
) -> Unit {
  if element.tag_name == "table" {
    return
  }
  for child in element.children {
    match child {
      HtmlNode::Element(child_element) =>
        if child_element.tag_name == "tr" {
          ignore(
            collect_html_semantic_table_row_fact(
              child_element,
              ctx,
              table_source_key,
              section_source_key,
              table_block_source_key,
              depth + 1,
              table_rows,
              table_cells,
              row_count,
              cell_count,
            ),
          )
        } else {
          collect_html_semantic_table_nested_rows(
            child_element,
            ctx,
            table_source_key,
            section_source_key,
            table_block_source_key,
            depth + 1,
            table_rows,
            table_cells,
            row_count,
            cell_count,
          )
        }
      _ => ()
    }
  }
}

///|
fn collect_html_semantic_table_row_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  table_source_key : String,
  section_source_key : String?,
  table_block_source_key : String,
  depth : Int,
  table_rows : Array[String],
  table_cells : Array[String],
  row_count : Ref[Int],
  cell_count : Ref[Int],
) -> String? {
  row_count.val += 1
  let row_index = row_count.val - 1
  ctx.next_table_row_order += 1
  let source_order = ctx.next_table_row_order
  let source_key = "html:table-row:" + source_order.to_string()
  let row_block_source_key = html_semantic_descendant_block_key_by_tag_index(
    ctx, table_block_source_key, "tr", row_index,
  ).unwrap_or(table_block_source_key)
  let local_warnings : Array[HtmlSemanticWarning] = []
  let (attrs, attr_warnings) = html_semantic_attribute_summary(
    element, source_key,
  )
  for warning in attr_warnings {
    local_warnings.push(warning)
  }
  let (text_preview, text_truncated) = html_semantic_text_preview(
    element.children,
  )
  if text_truncated {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TextPreviewTruncated,
        source_key,
        element.tag_name,
        "html semantic table row text preview truncated",
      ),
    )
  }

  let cell_source_keys : Array[String] = []
  let mut row_cell_count = 0
  for child in element.children {
    match child {
      HtmlNode::Element(child_element) =>
        match html_semantic_table_cell_kind(child_element.tag_name) {
          Some(kind) => {
            cell_count.val += 1
            let cell_index = row_cell_count
            row_cell_count += 1
            match
              collect_html_semantic_table_cell_fact(
                child_element,
                ctx,
                table_source_key,
                section_source_key,
                source_key,
                row_block_source_key,
                depth + 1,
                row_index,
                cell_index,
                kind,
              ) {
              Some(cell_key) => {
                cell_source_keys.push(cell_key)
                table_cells.push(cell_key)
              }
              None => ()
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  if row_cell_count == 0 {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedTableStructure,
        source_key,
        element.tag_name,
        "html semantic table row has no cells",
      ),
    )
  }
  push_html_semantic_warnings(ctx, local_warnings)

  table_rows.push(source_key)
  let row : HtmlTableRowFact = {
    source_key,
    table_source_key,
    section_source_key,
    block_source_key: row_block_source_key,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    row_index,
    cell_source_keys,
    cell_count: row_cell_count,
    text_preview,
    attributes: attrs,
    span: element.span,
    warnings: local_warnings,
  }
  ctx.table_rows.push(row)
  ctx.table_row_by_source_key.set(source_key, row)
  Some(source_key)
}

///|
fn collect_html_semantic_table_cell_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  table_source_key : String,
  section_source_key : String?,
  row_source_key : String,
  block_source_key : String,
  depth : Int,
  row_index : Int,
  cell_index : Int,
  kind : HtmlTableCellKind,
) -> String? {
  ctx.next_table_cell_order += 1
  let source_order = ctx.next_table_cell_order
  let source_key = "html:table-cell:" + source_order.to_string()
  let cell_block_source_key = html_semantic_table_cell_block_key_by_index(
    ctx, block_source_key, cell_index,
  ).unwrap_or(block_source_key)
  let local_warnings : Array[HtmlSemanticWarning] = []
  let (attrs, attr_warnings) = html_semantic_attribute_summary(
    element, source_key,
  )
  for warning in attr_warnings {
    local_warnings.push(warning)
  }
  let (text_preview, text_truncated) = html_semantic_text_preview(
    element.children,
  )
  if text_truncated {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TextPreviewTruncated,
        source_key,
        element.tag_name,
        "html semantic table cell text preview truncated",
      ),
    )
  }
  push_html_semantic_warnings(ctx, local_warnings)

  let inline_child_keys = html_semantic_inline_keys_for_block(
    ctx, cell_block_source_key,
  )
  let direct_child_block_keys = html_semantic_direct_child_block_keys(
    ctx, cell_block_source_key,
  )
  let colspan = html_semantic_optional_bounded_attr(
    element.attributes,
    "colspan",
  )
  let rowspan = html_semantic_optional_bounded_attr(
    element.attributes,
    "rowspan",
  )
  let colspan_value = parse_html_semantic_positive_int_attr(colspan)
  let rowspan_value = parse_html_semantic_positive_int_attr(rowspan)
  let has_nested_table = html_semantic_block_descendants_contain_kind(
    ctx,
    cell_block_source_key,
    HtmlBlockKind::Table,
  )
  let has_image = html_semantic_block_has_image(ctx, cell_block_source_key)
  let has_list = html_semantic_block_descendants_contain_list(
    ctx, cell_block_source_key,
  )
  let has_blockquote = html_semantic_block_descendants_contain_kind(
    ctx,
    cell_block_source_key,
    HtmlBlockKind::BlockQuote,
  )
  let has_pre = html_semantic_block_descendants_contain_pre(
    ctx, cell_block_source_key,
  )
  let has_figure = html_semantic_block_descendants_contain_kind(
    ctx,
    cell_block_source_key,
    HtmlBlockKind::Figure,
  )
  let has_unsupported_warning = html_semantic_warnings_have_unsupported(
    local_warnings,
  )
  let has_complex_block = direct_child_block_keys.length() != 0 ||
    has_nested_table ||
    has_list ||
    has_blockquote ||
    has_pre ||
    has_figure
  let text_complete = !text_truncated
  let safe_simple_cell_candidate = local_warnings.length() == 0 &&
    text_complete &&
    colspan_value == 1 &&
    rowspan_value == 1 &&
    !has_complex_block &&
    !has_image &&
    !has_unsupported_warning
  let cell : HtmlTableCellFact = {
    source_key,
    table_source_key,
    section_source_key,
    row_source_key,
    block_source_key: cell_block_source_key,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    row_index,
    cell_index,
    kind,
    tag_name: element.tag_name,
    colspan,
    rowspan,
    colspan_value,
    rowspan_value,
    headers: html_semantic_optional_bounded_attr(element.attributes, "headers"),
    scope: html_semantic_optional_bounded_attr(element.attributes, "scope"),
    inline_child_keys,
    direct_child_block_keys,
    text_complete,
    has_complex_block,
    has_nested_table,
    has_image,
    has_list,
    has_blockquote,
    has_pre,
    has_figure,
    has_unsupported_warning,
    safe_simple_cell_candidate,
    text_preview,
    attributes: attrs,
    span: element.span,
    warnings: local_warnings,
  }
  ctx.table_cells.push(cell)
  ctx.table_cell_by_source_key.set(source_key, cell)
  Some(source_key)
}

///|
