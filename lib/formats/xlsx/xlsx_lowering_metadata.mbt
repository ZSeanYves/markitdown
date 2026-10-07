///|
fn xlsx_fill_package_metrics(
  diagnostics : @core.Diagnostics,
  pkg : @ox.OoxmlPackage,
) -> Unit {
  let validation = @ox.validate_ooxml_package(pkg)
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  let package_relationship_count = (@ox.read_package_relationships(pkg) catch {
    _ => []
  }).length()
  let part_relationship_count = inventory.relationship_source_parts.fold(
    init=0,
    fn(acc, source_part) {
      acc +
      (@ox.read_part_relationships(pkg, source_part) catch { _ => [] }).length()
    },
  )
  diagnostics.metrics.set("ooxml_part_count", inventory.part_count.to_string())
  diagnostics.metrics.set(
    "relationship_count",
    (package_relationship_count + part_relationship_count).to_string(),
  )
  diagnostics.metrics.set(
    "content_type_count",
    inventory.content_type_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "media_asset_count",
    count_xlsx_media_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "external_relationship_count",
    xlsx_count_validation_kind(validation.issues, ExternalRelationship).to_string(),
  )
  diagnostics.metrics.set(
    "missing_relationship_target_count",
    xlsx_count_validation_kind(validation.issues, MissingRelationshipTarget).to_string(),
  )
  diagnostics.metrics.set("unsupported_relationship_count", "0")
  diagnostics.metrics.set("duplicate_part_count", "0")
  diagnostics.metrics.set(
    "total_uncompressed_bytes",
    xlsx_total_uncompressed_bytes(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "macro_part_count",
    xlsx_count_macro_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "ole_object_count",
    xlsx_count_ole_parts(inventory.parts).to_string(),
  )
}

///|
fn xlsx_count_validation_kind(
  issues : Array[@ox.OoxmlValidationIssue],
  kind : @ox.OoxmlValidationIssueKind,
) -> Int {
  let mut count = 0
  for issue in issues {
    if issue.kind == kind {
      count += 1
    }
  }
  count
}

///|
fn xlsx_total_uncompressed_bytes(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut total = 0
  for part in parts {
    total += part.size
  }
  total
}

///|
fn xlsx_count_macro_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    match part.content_type {
      Some(value) => if value.contains("macroEnabled") { count += 1 }
      None => ()
    }
  }
  count
}

///|
fn xlsx_count_ole_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.contains("/embeddings/") ||
      part.part_name.contains("oleObject") {
      count += 1
    }
  }
  count
}

///|
fn count_xlsx_media_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.has_prefix("xl/media/") && !part.part_name.has_suffix("/") {
      count += 1
    }
  }
  count
}

///|
fn xlsx_sheet_heading_source_ref(
  source_name : String,
  sheet : XlsxSheet,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source_name),
    Some("xlsx"),
    Some(source_name),
    Some(sheet.part_name),
    None,
    Some("xlsx"),
    Some("/worksheet"),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source_name),
    Some("xlsx"),
    Some("/worksheet"),
    Some(sheet.sheet_name),
    None,
    None,
    None,
    Some(sheet.relationship_id),
  )
  let with_sheet = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(office, "part_name", sheet.part_name),
        "sheet_name",
        sheet.sheet_name,
      ),
      "sheet_visibility",
      @shared.xlsx_sheet_visibility_name(sheet.visibility),
    ),
    "relationship_id",
    sheet.relationship_id,
  )
  match sheet.sheet_id {
    Some(value) => @core.source_ref_with_extra(with_sheet, "sheet_id", value)
    None => with_sheet
  }
}

///|
fn xlsx_sheet_table_source_ref(
  source_name : String,
  sheet : XlsxSheet,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source_name),
    Some("xlsx"),
    Some(source_name),
    Some(sheet.part_name),
    None,
    Some("xlsx"),
    Some("/worksheet/sheetData"),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source_name),
    Some("xlsx"),
    Some("/worksheet/sheetData"),
    Some(sheet.sheet_name),
    sheet.dimension_ref,
    None,
    None,
    Some(sheet.relationship_id),
  )
  let mut with_keys = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(office, "part_name", sheet.part_name),
        "sheet_name",
        sheet.sheet_name,
      ),
      "sheet_visibility",
      @shared.xlsx_sheet_visibility_name(sheet.visibility),
    ),
    "relationship_id",
    sheet.relationship_id,
  )
  match sheet.sheet_id {
    Some(value) =>
      with_keys = @core.source_ref_with_extra(with_keys, "sheet_id", value)
    None => ()
  }
  match sheet.dimension_ref {
    Some(value) =>
      with_keys = @core.source_ref_with_extra(with_keys, "cell_range", value)
    None => ()
  }
  if !sheet.is_empty {
    with_keys = @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        with_keys,
        "row_index",
        sheet.min_row.to_string(),
      ),
      "column_index",
      sheet.min_col.to_string(),
    )
  }
  with_keys
}

///|
fn xlsx_append_sheet_comments(
  blocks : Array[@core.CoreBlock],
  source_name : String,
  sheet : XlsxSheet,
) -> Unit {
  if sheet.comments.length() == 0 {
    return
  }
  let heading = @core.make_block(
    Heading,
    "Comments",
    source_ref=@core.source_ref_with_extra(
      xlsx_sheet_table_source_ref(source_name, sheet),
      "section",
      "comments",
    ),
  )
  heading.attrs.set("level", "3")
  blocks.push(heading)
  for comment in sheet.comments {
    let item = @core.make_block(
      ListItem,
      xlsx_comment_item_text(comment),
      source_ref=@core.source_ref_with_extra(
        xlsx_sheet_table_source_ref(source_name, sheet),
        "cell_ref",
        comment.cell_ref,
      ),
    )
    item.attrs.set("ordered", "false")
    item.attrs.set("level", "0")
    blocks.push(item)
  }
}

///|
fn xlsx_sheet_heading_source_ref_view(
  source_name : String,
  sheet : XlsxParsedSheetView,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source_name),
    Some("xlsx"),
    Some(source_name),
    Some(sheet.part_name),
    None,
    Some("xlsx"),
    Some("/worksheet"),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source_name),
    Some("xlsx"),
    Some("/worksheet"),
    Some(sheet.sheet_name),
    None,
    None,
    None,
    Some(sheet.relationship_id),
  )
  let with_sheet = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(office, "part_name", sheet.part_name),
        "sheet_name",
        sheet.sheet_name,
      ),
      "sheet_visibility",
      @shared.xlsx_sheet_visibility_name(sheet.visibility),
    ),
    "relationship_id",
    sheet.relationship_id,
  )
  match sheet.sheet_id {
    Some(value) => @core.source_ref_with_extra(with_sheet, "sheet_id", value)
    None => with_sheet
  }
}

///|
fn xlsx_sheet_table_source_ref_view(
  source_name : String,
  sheet : XlsxParsedSheetView,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source_name),
    Some("xlsx"),
    Some(source_name),
    Some(sheet.part_name),
    None,
    Some("xlsx"),
    Some("/worksheet/sheetData"),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source_name),
    Some("xlsx"),
    Some("/worksheet/sheetData"),
    Some(sheet.sheet_name),
    sheet.dimension_ref,
    None,
    None,
    Some(sheet.relationship_id),
  )
  let mut with_keys = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(office, "part_name", sheet.part_name),
        "sheet_name",
        sheet.sheet_name,
      ),
      "sheet_visibility",
      @shared.xlsx_sheet_visibility_name(sheet.visibility),
    ),
    "relationship_id",
    sheet.relationship_id,
  )
  match sheet.sheet_id {
    Some(value) =>
      with_keys = @core.source_ref_with_extra(with_keys, "sheet_id", value)
    None => ()
  }
  match sheet.dimension_ref {
    Some(value) =>
      with_keys = @core.source_ref_with_extra(with_keys, "cell_range", value)
    None => ()
  }
  if !sheet.is_empty {
    with_keys = @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        with_keys,
        "row_index",
        sheet.min_row.to_string(),
      ),
      "column_index",
      sheet.min_col.to_string(),
    )
  }
  with_keys
}

///|
fn xlsx_append_sheet_comments_view(
  blocks : Array[@core.CoreBlock],
  source_name : String,
  sheet : XlsxParsedSheetView,
) -> Unit {
  if sheet.comments.length() == 0 {
    return
  }
  let heading = @core.make_block(
    Heading,
    "Comments",
    source_ref=@core.source_ref_with_extra(
      xlsx_sheet_table_source_ref_view(source_name, sheet),
      "section",
      "comments",
    ),
  )
  heading.attrs.set("level", "3")
  blocks.push(heading)
  for comment in sheet.comments {
    let item = @core.make_block(
      ListItem,
      xlsx_comment_item_text(comment),
      source_ref=@core.source_ref_with_extra(
        xlsx_sheet_table_source_ref_view(source_name, sheet),
        "cell_ref",
        comment.cell_ref,
      ),
    )
    item.attrs.set("ordered", "false")
    item.attrs.set("level", "0")
    blocks.push(item)
  }
}

///|
