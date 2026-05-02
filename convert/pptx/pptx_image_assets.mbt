///|
/// Extract embedded slide images into output assets directory.
///
/// Scope:
/// - export package-embedded image blobs only
/// - assign deterministic relative asset paths
///
/// Non-goal:
/// - no caption inference here (kept in slide-level pairing step)
/// - no remote/image-link fetching
priv struct PptxSlideImage {
  _alt_text : String
  _title : String?
  _path : String
  _object_ref : String?
  _relationship_id : String?
  _source_path : String?
}

///|
priv struct PptxPictureShapeMeta {
  rid : String
  descr : String?
  title : String?
  object_ref : String?
}

///|
fn export_slide_images(
  p : PptxPackage,
  rel_ctx : PptxSlideRelContext,
  slide_xml : Bytes,
  out_dir : String,
  slide_no : Int,
  next_idx : Ref[Int],
) -> Array[PptxSlideImage] raise {
  if out_dir == "" {
    return []
  }

  let assets_dir = out_dir + "/assets"
  if !@fs.path_exists(assets_dir) {
    @fs.create_dir(assets_dir) catch {
      _ => return []
    }
  }

  let image_targets = rels_image_target_map(rel_ctx.rels)
  if image_targets.length() == 0 {
    return []
  }

  let picture_shapes = collect_slide_picture_shape_metas(slide_xml)
  if picture_shapes.length() > 0 {
    return export_picture_shape_images(
      p, out_dir, slide_no, next_idx, image_targets, picture_shapes,
    )
  }

  let rids = collect_slide_image_rids(slide_xml)
  if rids.length() == 0 {
    return []
  }

  export_fallback_slide_images(
    p, out_dir, slide_no, next_idx, image_targets, rids,
  )
}

///|
fn export_picture_shape_images(
  p : PptxPackage,
  out_dir : String,
  slide_no : Int,
  next_idx : Ref[Int],
  image_targets : Map[String, String],
  picture_shapes : Array[PptxPictureShapeMeta],
) -> Array[PptxSlideImage] {
  let out : Array[PptxSlideImage] = []
  let mut img_idx = 0

  for picture in picture_shapes {
    let target = match image_targets.get(picture.rid) {
      None => continue
      Some(t) => t
    }

    let ext = image_ext_from_target(target)
    if ext == "" {
      continue
    }

    let data = @ox.read_part_bytes(p.pkg, target) catch { _ => continue }
    img_idx += 1
    let rel_out = @cor.next_image_asset_rel_path_unique(next_idx, ext, out_dir)
    let dst = out_dir + "/" + rel_out
    @fs.write_bytes_to_file(dst, data) catch {
      _ => continue
    }

    let synthetic_alt = synthetic_slide_image_alt_text(slide_no, img_idx)
    out.push({
      _alt_text: picture.descr.unwrap_or(synthetic_alt),
      _title: picture.title,
      _path: rel_out,
      _object_ref: picture.object_ref,
      _relationship_id: Some(picture.rid),
      _source_path: Some(target),
    })
  }

  out
}

///|
fn export_fallback_slide_images(
  p : PptxPackage,
  out_dir : String,
  slide_no : Int,
  next_idx : Ref[Int],
  image_targets : Map[String, String],
  rids : Array[String],
) -> Array[PptxSlideImage] {
  let out : Array[PptxSlideImage] = []
  let mut img_idx = 0

  for rid in rids {
    let target = match image_targets.get(rid) {
      None => continue
      Some(t) => t
    }

    let ext = image_ext_from_target(target)
    if ext == "" {
      continue
    }

    let data = @ox.read_part_bytes(p.pkg, target) catch { _ => continue }
    img_idx += 1
    let rel_out = @cor.next_image_asset_rel_path_unique(next_idx, ext, out_dir)
    let dst = out_dir + "/" + rel_out
    @fs.write_bytes_to_file(dst, data) catch {
      _ => continue
    }

    out.push({
      _alt_text: synthetic_slide_image_alt_text(slide_no, img_idx),
      _title: None,
      _path: rel_out,
      _object_ref: None,
      _relationship_id: Some(rid),
      _source_path: Some(target),
    })
  }

  out
}

///|
fn synthetic_slide_image_alt_text(slide_no : Int, img_idx : Int) -> String {
  "slide-" + slide_no.to_string() + "-image-" + img_idx.to_string()
}

///|
fn rels_image_target_map(
  rels : Array[@ox.OoxmlRelationship],
) -> Map[String, String] {
  let out : Map[String, String] = Map::new()
  for rel in rels {
    if rel.rel_type.has_suffix("/image") {
      out.set(rel.id, rel.resolved_target)
    }
  }
  out
}

///|
fn collect_slide_picture_shape_metas(
  slide_xml : Bytes,
) -> Array[PptxPictureShapeMeta] raise {
  let out : Array[PptxPictureShapeMeta] = []
  let pictures = collect_slide_objects(slide_xml).picture_shapes
  for picture in pictures {
    match read_picture_shape_meta(picture.xml, picture.object_ref) {
      Some(meta) => out.push(meta)
      None => ()
    }
  }

  out
}

///|
fn read_picture_shape_meta(
  pic_xml : Bytes,
  object_ref : String?,
) -> PptxPictureShapeMeta? raise {
  match read_picture_shape_rid(pic_xml) {
    Some(rid) =>
      if rid.trim() == "" {
        None
      } else {
        ignore(read_picture_shape_cnvpr_attr(pic_xml, "name"))
        Some({
          rid: rid.trim().to_owned(),
          descr: read_picture_shape_cnvpr_attr(pic_xml, "descr"),
          title: read_picture_shape_cnvpr_attr(pic_xml, "title"),
          object_ref,
        })
      }
    None => None
  }
}

///|
fn read_picture_shape_rid(pic_xml : Bytes) -> String? raise {
  read_attr_value_in_first_tag_bytes(pic_xml, "<a:blip", "r:embed")
}

///|
fn read_picture_shape_cnvpr_attr(
  pic_xml : Bytes,
  attr_name : String,
) -> String? raise {
  normalize_optional_pptx_image_attr(
    read_attr_value_in_first_tag_bytes(pic_xml, "<p:cNvPr", attr_name),
  )
}

///|
fn read_attr_value_in_first_tag_bytes(
  block : Bytes,
  tag_prefix : String,
  attr_name : String,
) -> String? raise {
  let start = find_bytes(block, pat(tag_prefix), 0).unwrap_or(-1)
  if start < 0 {
    return None
  }

  let end_ = find_bytes(block, pat(">"), start).unwrap_or(-1)
  if end_ < 0 {
    return None
  }

  let tag = block[start:end_ + 1].to_owned()
  read_attr_value_in_tag_bytes(tag, attr_name)
}

///|
fn normalize_optional_pptx_image_attr(value : String?) -> String? {
  match value {
    Some(raw) => {
      let trimmed = xml_unescape(raw).trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn collect_slide_image_rids(slide_xml : Bytes) -> Array[String] raise {
  let out : Array[String] = []
  let open_blip = pat("<a:blip")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let p0 = find_bytes(slide_xml, open_blip, pos)
    match p0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(slide_xml, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let tag = slide_xml[i0:gt0 + 1].to_owned()
            match read_attr_value_in_tag_bytes(tag, "r:embed") {
              Some(rid) => if rid != "" { out.push(rid) }
              None => ()
            }
            pos = gt0 + 1
          }
        }
      }
    }
  }

  out
}

///|
fn image_ext_from_target(target : String) -> String {
  let b = @cor.basename(target).to_lower()

  if b.has_suffix(".png") {
    return "png"
  }
  if b.has_suffix(".jpg") {
    return "jpg"
  }
  if b.has_suffix(".jpeg") {
    return "jpeg"
  }
  if b.has_suffix(".gif") {
    return "gif"
  }
  if b.has_suffix(".bmp") {
    return "bmp"
  }
  if b.has_suffix(".tif") || b.has_suffix(".tiff") {
    return "tiff"
  }
  if b.has_suffix(".webp") {
    return "webp"
  }

  ""
}
