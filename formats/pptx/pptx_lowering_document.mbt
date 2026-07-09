///|
fn pptx_fill_package_metrics(
  diagnostics : @core.Diagnostics,
  pkg : @ox.OoxmlPackage,
  presentation : @pptxdoc.PptxDocument,
) -> Unit {
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  let validation = @ox.validate_ooxml_package(pkg)
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
  let mut external_relationship_count = 0
  let mut missing_relationship_target_count = 0
  let mut unsupported_relationship_count = 0
  for issue in validation.issues {
    match issue.kind {
      @ox.OoxmlValidationIssueKind::ExternalRelationship =>
        external_relationship_count += 1
      @ox.OoxmlValidationIssueKind::MissingRelationshipTarget =>
        missing_relationship_target_count += 1
      @ox.OoxmlValidationIssueKind::UnsafeRelationshipTarget =>
        unsupported_relationship_count += 1
      _ => ()
    }
  }
  diagnostics.metrics.set(
    "external_relationship_count",
    external_relationship_count.to_string(),
  )
  diagnostics.metrics.set(
    "missing_relationship_target_count",
    missing_relationship_target_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_relationship_count",
    unsupported_relationship_count.to_string(),
  )
  diagnostics.metrics.set(
    "media_asset_count",
    count_pptx_media_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "content_type_count",
    inventory.content_type_entry_count.to_string(),
  )
  let mut total_uncompressed_bytes = 0
  for part in inventory.parts {
    total_uncompressed_bytes += part.size
  }
  diagnostics.metrics.set(
    "total_uncompressed_bytes",
    total_uncompressed_bytes.to_string(),
  )

  let mut path_traversal_count = 0
  for issue in validation.issues {
    let message = issue.message.trim().to_owned().to_lower()
    if message.contains("path traversal") ||
      message.contains("unsafe relationship target") {
      path_traversal_count += 1
    }
  }
  diagnostics.metrics.set(
    "path_traversal_count",
    path_traversal_count.to_string(),
  )

  let mut duplicate_part_count = 0
  let mut prev_part = ""
  let sorted_part_names = inventory.parts.map(part => part.part_name)
  sorted_part_names.sort()
  for part_name in sorted_part_names {
    if part_name == prev_part {
      duplicate_part_count += 1
    }
    prev_part = part_name
  }
  diagnostics.metrics.set(
    "duplicate_part_count",
    duplicate_part_count.to_string(),
  )

  let mut macro_part_count = 0
  let mut ole_object_count = 0
  for part in inventory.parts {
    let content_type = part.content_type.unwrap_or("").to_lower()
    let part_name = part.part_name.to_lower()
    if content_type.contains("macroenabled") || part_name.has_suffix(".bin") {
      macro_part_count += 1
    }
    if content_type.contains("oleobject") || part_name.contains("/embeddings/") {
      ole_object_count += 1
    }
  }
  diagnostics.metrics.set("macro_part_count", macro_part_count.to_string())
  diagnostics.metrics.set("ole_object_count", ole_object_count.to_string())

  let inspect = @pptxdoc.inspect_pptx_document(presentation)
  diagnostics.metrics.set(
    "pptx_slide_count",
    presentation.slides.length().to_string(),
  )
  diagnostics.metrics.set(
    "pptx_layout_count",
    presentation.layouts.length().to_string(),
  )
  diagnostics.metrics.set(
    "pptx_master_count",
    presentation.masters.length().to_string(),
  )
  diagnostics.metrics.set(
    "pptx_theme_count",
    pptx_theme_count(presentation).to_string(),
  )
  diagnostics.metrics.set("pptx_shape_count", inspect.shape_count.to_string())
  diagnostics.metrics.set("pptx_table_count", inspect.table_count.to_string())
  diagnostics.metrics.set("pptx_notes_count", inspect.notes_count.to_string())
  diagnostics.metrics.set(
    "pptx_comment_count",
    inspect.comment_count.to_string(),
  )

  let placeholder_count : Ref[Int] = { val: 0 }
  let resolved_placeholder_count : Ref[Int] = { val: 0 }
  let unresolved_placeholder_count : Ref[Int] = { val: 0 }
  let text_box_count : Ref[Int] = { val: 0 }
  let image_count : Ref[Int] = { val: 0 }
  let external_media_count : Ref[Int] = { val: 0 }
  let mut visible_slide_count = 0
  let mut hidden_slide_count = 0
  for slide in presentation.slides {
    if slide.hidden {
      hidden_slide_count += 1
    } else {
      visible_slide_count += 1
    }
    for obj in slide.objects {
      pptx_accumulate_object_metrics(
        obj, diagnostics, placeholder_count, resolved_placeholder_count, unresolved_placeholder_count,
        text_box_count, image_count, external_media_count,
      )
    }
  }
  diagnostics.metrics.set(
    "pptx_visible_slide_count",
    visible_slide_count.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_hidden_slide_count",
    hidden_slide_count.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_placeholder_count",
    placeholder_count.val.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_resolved_placeholder_count",
    resolved_placeholder_count.val.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_unresolved_placeholder_count",
    unresolved_placeholder_count.val.to_string(),
  )
  diagnostics.metrics.set("pptx_text_box_count", text_box_count.val.to_string())
  diagnostics.metrics.set("pptx_image_count", image_count.val.to_string())
  diagnostics.metrics.set(
    "pptx_external_media_count",
    external_media_count.val.to_string(),
  )
}

///|
fn count_pptx_media_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.has_prefix("ppt/media/") &&
      !part.part_name.has_suffix("/") {
      count += 1
    }
  }
  count
}

///|
fn pptx_accumulate_object_metrics(
  obj : @pptxdoc.PptxObject,
  diagnostics : @core.Diagnostics,
  placeholder_count : Ref[Int],
  resolved_placeholder_count : Ref[Int],
  unresolved_placeholder_count : Ref[Int],
  text_box_count : Ref[Int],
  image_count : Ref[Int],
  external_media_count : Ref[Int],
) -> Unit {
  ignore(diagnostics)
  match obj {
    @pptxdoc.PptxObject::Shape(shape) => {
      match shape.direct_placeholder {
        Some(_) => placeholder_count.val += 1
        None => ()
      }
      match shape.placeholder {
        Some(_) => {
          resolved_placeholder_count.val += 1
          placeholder_count.val += 1
        }
        None =>
          if shape.text_body is Some(_) && shape.direct_placeholder is None {
            text_box_count.val += 1
          } else if shape.direct_placeholder is Some(_) {
            unresolved_placeholder_count.val += 1
          }
      }
    }
    @pptxdoc.PptxObject::Picture(pic) => {
      image_count.val += 1
      match pic.media {
        Some(media) => if media.is_external { external_media_count.val += 1 }
        None => ()
      }
    }
    @pptxdoc.PptxObject::Group(group) =>
      for child in group.children {
        pptx_accumulate_object_metrics(
          child, diagnostics, placeholder_count, resolved_placeholder_count, unresolved_placeholder_count,
          text_box_count, image_count, external_media_count,
        )
      }
    @pptxdoc.PptxObject::Ole(_) =>
      diagnostics.degraded_features.push("pptx_ole_unsupported")
    @pptxdoc.PptxObject::Chart(_) =>
      diagnostics.degraded_features.push("pptx_chart_unsupported")
    @pptxdoc.PptxObject::SmartArt(_) =>
      diagnostics.degraded_features.push("pptx_smartart_unsupported")
    _ => ()
  }
}

///|
fn pptx_theme_count(presentation : @pptxdoc.PptxDocument) -> Int {
  let themes : Array[String] = []
  for slide in presentation.slides {
    match slide.master_ref {
      Some(master) =>
        if !themes.contains(master.part_name) {
          themes.push(master.part_name)
        }
      None => ()
    }
  }
  themes.length()
}
