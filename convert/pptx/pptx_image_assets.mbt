///|
priv struct PptxSlideImage {
  _alt : String
  _path : String
}

///|
fn export_slide_images(
  p : PptxPackage,
  slide_part : String,
  slide_xml : Bytes,
  out_dir : String,
  slide_no : Int,
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

  let rels = @ox.read_part_relationships(p.pkg, slide_part) catch {
    _ => return []
  }
  let image_targets = rels_image_target_map(rels)
  if image_targets.length() == 0 {
    return []
  }

  let rids = collect_slide_image_rids(slide_xml)
  if rids.length() == 0 {
    return []
  }

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
    let out_name = "pptx_slide_" +
      pad2(slide_no) +
      "_img_" +
      pad2(img_idx) +
      "." +
      ext
    @fs.write_bytes_to_file(assets_dir + "/" + out_name, data) catch {
      _ => continue
    }

    out.push({
      _alt: "slide-" + slide_no.to_string() + "-image-" + img_idx.to_string(),
      _path: "assets/" + out_name,
    })
  }

  out
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
            let tag = slide_xml[i0:gt0 + 1].to_bytes()
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
  if b.has_suffix(".jpg") || b.has_suffix(".jpeg") {
    return "jpg"
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

///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}
