///|
fn collect_slide_objects(slide_xml : Bytes) -> PptxCollectedSlideObjects raise {
  let root = find_slide_sp_tree_inner(slide_xml)
  match root {
    None =>
      {
        text_shapes: collect_slide_shapes_legacy(slide_xml),
        picture_shapes: collect_slide_picture_shapes_legacy(slide_xml),
        graphic_frames: collect_slide_graphic_frames_legacy(slide_xml),
      }
    Some(inner) => {
      let out_text : Array[SlideShape] = []
      let out_pics : Array[PptxRawPictureShape] = []
      let out_frames : Array[PptxRawGraphicFrame] = []
      let ctx : PptxGroupContext = {
        offset_x: 0,
        offset_y: 0,
        scale_x_num: 1,
        scale_x_den: 1,
        scale_y_num: 1,
        scale_y_den: 1,
        group_ref_prefix: None,
      }
      collect_container_children(inner, ctx, out_text, out_pics, out_frames)
      {
        text_shapes: out_text,
        picture_shapes: out_pics,
        graphic_frames: out_frames,
      }
    }
  }
}

///|
fn find_slide_sp_tree_inner(slide_xml : Bytes) -> Bytes? {
  let open_tree = pat("<p:spTree")
  let close_tree = pat("</p:spTree>")
  let gt_pat = pat(">")
  let p0 = find_bytes(slide_xml, open_tree, 0)
  match p0 {
    None => None
    Some(i0) => {
      let gt = find_bytes(slide_xml, gt_pat, i0)
      match gt {
        None => None
        Some(gt0) => {
          let end0 = find_bytes(slide_xml, close_tree, gt0 + 1)
          match end0 {
            None => None
            Some(end) => Some(slide_xml[gt0 + 1:end].to_owned())
          }
        }
      }
    }
  }
}

///|
fn collect_container_children(
  inner : Bytes,
  ctx : PptxGroupContext,
  out_text : Array[SlideShape],
  out_pics : Array[PptxRawPictureShape],
  out_frames : Array[PptxRawGraphicFrame],
) -> Unit raise {
  let mut pos = 0
  while pos < inner.length() {
    let start0 = find_bytes(inner, pat("<p:"), pos)
    match start0 {
      None => break
      Some(start) => {
        let tag_name = read_open_tag_name(inner, start)
        match tag_name {
          None => break
          Some(name) =>
            match name {
              "p:grpSp" =>
                match slice_full_element(inner, start, name) {
                  Some((block, next_pos)) => {
                    collect_group_children(
                      block, ctx, out_text, out_pics, out_frames,
                    )
                    pos = next_pos
                  }
                  None => break
                }
              "p:sp" =>
                match slice_full_element(inner, start, name) {
                  Some((block, next_pos)) => {
                    match make_text_shape_from_xml(block, ctx, None) {
                      Some(sp) => out_text.push(sp)
                      None => ()
                    }
                    pos = next_pos
                  }
                  None => break
                }
              "p:pic" =>
                match slice_full_element(inner, start, name) {
                  Some((block, next_pos)) => {
                    match make_picture_shape_from_xml(block, ctx, None) {
                      Some(pic) => out_pics.push(pic)
                      None => ()
                    }
                    pos = next_pos
                  }
                  None => break
                }
              "p:graphicFrame" =>
                match slice_full_element(inner, start, name) {
                  Some((block, next_pos)) => {
                    match make_graphic_frame_from_xml(block, ctx, None) {
                      Some(frame) => out_frames.push(frame)
                      None => ()
                    }
                    pos = next_pos
                  }
                  None => break
                }
              _ =>
                match skip_full_element(inner, start, name) {
                  Some(next_pos) => pos = next_pos
                  None => break
                }
            }
        }
      }
    }
  }
}

///|
fn read_open_tag_name(xml : Bytes, start : Int) -> String? raise {
  if start < 0 || start >= xml.length() || xml[start] != '<'.to_int().to_byte() {
    return None
  }
  let mut i = start + 1
  while i < xml.length() {
    let b = xml[i]
    if b == ' '.to_int().to_byte() ||
      b == '>'.to_int().to_byte() ||
      b == '/'.to_int().to_byte() ||
      b == '\n'.to_int().to_byte() ||
      b == '\r'.to_int().to_byte() ||
      b == '\t'.to_int().to_byte() {
      return Some(bytes_slice_to_string(xml, start + 1, i))
    }
    i += 1
  }
  None
}

///|
fn slice_full_element(
  xml : Bytes,
  start : Int,
  tag_name : String,
) -> (Bytes, Int)? raise {
  let gt = find_bytes(xml, pat(">"), start)
  match gt {
    None => None
    Some(gt0) =>
      if gt0 > start && xml[gt0 - 1] == '/'.to_int().to_byte() {
        Some((xml[start:gt0 + 1].to_owned(), gt0 + 1))
      } else {
        let end0 = find_matching_named_element_close(xml, start, tag_name)
        match end0 {
          None => None
          Some(end) => Some((xml[start:end].to_owned(), end))
        }
      }
  }
}

///|
fn skip_full_element(xml : Bytes, start : Int, tag_name : String) -> Int? raise {
  match slice_full_element(xml, start, tag_name) {
    Some((_block, next_pos)) => Some(next_pos)
    None => None
  }
}

///|
fn find_matching_named_element_close(
  xml : Bytes,
  open_start : Int,
  tag_name : String,
) -> Int? raise {
  let gt = find_bytes(xml, pat(">"), open_start)
  match gt {
    None => None
    Some(gt0) => {
      if gt0 > open_start && xml[gt0 - 1] == '/'.to_int().to_byte() {
        return Some(gt0 + 1)
      }
      let close_pat = pat("</" + tag_name + ">")
      let mut depth = 1
      let mut pos = gt0 + 1
      while pos < xml.length() {
        let next_lt = find_bytes(xml, pat("<"), pos)
        match next_lt {
          None => return None
          Some(i0) =>
            if i0 + close_pat.length() <= xml.length() &&
              xml[i0:i0 + close_pat.length()] == close_pat {
              depth -= 1
              if depth == 0 {
                return Some(i0 + close_pat.length())
              }
              pos = i0 + close_pat.length()
            } else if i0 + 1 < xml.length() &&
              xml[i0 + 1] != '/'.to_int().to_byte() &&
              xml[i0 + 1] != '?'.to_int().to_byte() &&
              xml[i0 + 1] != '!'.to_int().to_byte() {
              match read_open_tag_name(xml, i0) {
                Some(name) => {
                  let gt1 = find_bytes(xml, pat(">"), i0)
                  match gt1 {
                    None => return None
                    Some(gt10) => {
                      if name == tag_name &&
                        !(gt10 > i0 && xml[gt10 - 1] == '/'.to_int().to_byte()) {
                        depth += 1
                      }
                      pos = gt10 + 1
                    }
                  }
                }
                None => pos = i0 + 1
              }
            } else {
              pos = i0 + 1
            }
        }
      }
      None
    }
  }
}

///|
fn collect_group_children(
  group_xml : Bytes,
  parent_ctx : PptxGroupContext,
  out_text : Array[SlideShape],
  out_pics : Array[PptxRawPictureShape],
  out_frames : Array[PptxRawGraphicFrame],
) -> Unit raise {
  let group_ref = read_group_object_ref(group_xml)
  let inner = group_inner_content(group_xml)
  match inner {
    None => ()
    Some(group_inner) => {
      let child_ctx = compose_group_context(parent_ctx, group_xml, group_ref)
      collect_container_children(
        group_inner, child_ctx, out_text, out_pics, out_frames,
      )
    }
  }
}

///|
fn group_inner_content(group_xml : Bytes) -> Bytes? raise {
  let gt_pat = pat(">")
  let first_gt = find_bytes(group_xml, gt_pat, 0)
  match first_gt {
    None => None
    Some(first_gt0) => {
      let inner_start = first_gt0 + 1
      let close_pat = pat("</p:grpSp>")
      let inner_end = find_matching_named_element_close(group_xml, 0, "p:grpSp")
      match inner_end {
        None => None
        Some(end) =>
          Some(group_xml[inner_start:end - close_pat.length()].to_owned())
      }
    }
  }
}

///|
fn compose_group_context(
  parent_ctx : PptxGroupContext,
  group_xml : Bytes,
  group_ref : String?,
) -> PptxGroupContext raise {
  let (gx, gy, gcx, gcy) = read_local_transform_bounds(group_xml)
  let (chx, chy, chcx, chcy) = read_group_child_transform(group_xml)

  let scale_x_num = if chcx > 0 { gcx } else { 1 }
  let scale_x_den = if chcx > 0 { chcx } else { 1 }
  let scale_y_num = if chcy > 0 { gcy } else { 1 }
  let scale_y_den = if chcy > 0 { chcy } else { 1 }

  let mapped_x = apply_group_transform_axis(parent_ctx, gx - chx, true)
  let mapped_y = apply_group_transform_axis(parent_ctx, gy - chy, false)

  {
    offset_x: mapped_x,
    offset_y: mapped_y,
    scale_x_num: normalize_scale_num(parent_ctx.scale_x_num * scale_x_num),
    scale_x_den: normalize_scale_den(parent_ctx.scale_x_den * scale_x_den),
    scale_y_num: normalize_scale_num(parent_ctx.scale_y_num * scale_y_num),
    scale_y_den: normalize_scale_den(parent_ctx.scale_y_den * scale_y_den),
    group_ref_prefix: combine_group_ref(parent_ctx.group_ref_prefix, group_ref),
  }
}

///|
fn normalize_scale_num(n : Int) -> Int {
  if n <= 0 {
    1
  } else {
    n
  }
}

///|
fn normalize_scale_den(n : Int) -> Int {
  if n <= 0 {
    1
  } else {
    n
  }
}

///|
fn apply_group_transform_axis(
  ctx : PptxGroupContext,
  local_coord : Int,
  x_axis : Bool,
) -> Int {
  let (num, den, offset) = if x_axis {
    (ctx.scale_x_num, ctx.scale_x_den, ctx.offset_x)
  } else {
    (ctx.scale_y_num, ctx.scale_y_den, ctx.offset_y)
  }
  offset + scale_coord(local_coord, num, den)
}

///|
fn scale_coord(value : Int, num : Int, den : Int) -> Int {
  if den <= 0 {
    value
  } else {
    value * num / den
  }
}

///|
fn read_group_object_ref(group_xml : Bytes) -> String? raise {
  let open_cnvpr = pat("<p:cNvPr")
  let gt_pat = pat(">")
  let p0 = find_bytes(group_xml, open_cnvpr, 0)
  match p0 {
    None => None
    Some(i0) => {
      let gt = find_bytes(group_xml, gt_pat, i0)
      match gt {
        None => None
        Some(gt0) => {
          let tag = group_xml[i0:gt0 + 1].to_owned()
          match read_attr_value_in_tag_bytes(tag, "id") {
            Some(id) =>
              if id.trim() == "" {
                None
              } else {
                Some("group-" + id.trim().to_owned())
              }
            None => None
          }
        }
      }
    }
  }
}

///|
fn combine_group_ref(prefix : String?, cur : String?) -> String? {
  match prefix {
    Some(p) =>
      match cur {
        Some(c) => Some(p + "/" + c)
        None => Some(p)
      }
    None => cur
  }
}

///|
fn read_local_transform_bounds(xml : Bytes) -> (Int, Int, Int, Int) raise {
  read_transform_bounds(xml, "<a:xfrm")
}

///|
fn read_group_child_transform(xml : Bytes) -> (Int, Int, Int, Int) raise {
  let xfrm = find_transform_element(xml, "<a:xfrm")
  match xfrm {
    None => (0, 0, 0, 0)
    Some(xfrm_xml) => {
      let (x, y) = read_transform_pair(xfrm_xml, "<a:chOff")
      let (w, h) = read_transform_pair(xfrm_xml, "<a:chExt")
      (x, y, w, h)
    }
  }
}

///|
fn find_transform_element(xml : Bytes, open_prefix : String) -> Bytes? raise {
  let open_pat = pat(open_prefix)
  let gt_pat = pat(">")
  let p0 = find_bytes(xml, open_pat, 0)
  match p0 {
    None => None
    Some(i0) =>
      match
        find_matching_named_element_close(xml, i0, open_prefix[1:].to_owned()) {
        Some(end_) => Some(xml[i0:end_].to_owned())
        None =>
          match find_bytes(xml, gt_pat, i0) {
            None => None
            Some(gt0) => Some(xml[i0:gt0 + 1].to_owned())
          }
      }
  }
}

///|
fn read_transform_bounds(
  xml : Bytes,
  open_prefix : String,
) -> (Int, Int, Int, Int) raise {
  let xfrm = find_transform_element(xml, open_prefix)
  match xfrm {
    None => (0, 0, 0, 0)
    Some(xfrm_xml) => {
      let (x, y) = read_transform_pair(xfrm_xml, "<a:off")
      let (w, h) = read_transform_pair(xfrm_xml, "<a:ext")
      (x, y, w, h)
    }
  }
}

///|
fn read_transform_pair(xml : Bytes, tag_prefix : String) -> (Int, Int) raise {
  let open_pat = pat(tag_prefix)
  let gt_pat = pat(">")
  let p0 = find_bytes(xml, open_pat, 0)
  match p0 {
    None => (0, 0)
    Some(i0) => {
      let gt = find_bytes(xml, gt_pat, i0)
      match gt {
        None => (0, 0)
        Some(gt0) => {
          let tag = xml[i0:gt0 + 1].to_owned()
          let a0 = read_attr_value_in_tag_bytes(
            tag,
            if tag_prefix == "<a:ext" || tag_prefix == "<a:chExt" {
              "cx"
            } else {
              "x"
            },
          )
          let b0 = read_attr_value_in_tag_bytes(
            tag,
            if tag_prefix == "<a:ext" || tag_prefix == "<a:chExt" {
              "cy"
            } else {
              "y"
            },
          )
          (
            parse_nonneg_int(a0.unwrap_or("0")),
            parse_nonneg_int(b0.unwrap_or("0")),
          )
        }
      }
    }
  }
}

///|
fn make_text_shape_from_xml(
  sp_xml : Bytes,
  ctx : PptxGroupContext,
  object_ref_override : String?,
) -> SlideShape? raise {
  let (lx, ly, lw, lh) = read_local_transform_bounds(sp_xml)
  let object_ref = match object_ref_override {
    Some(v) => Some(v)
    None => read_shape_object_ref(sp_xml, ctx.group_ref_prefix)
  }
  Some({
    xml: sp_xml,
    x: apply_group_transform_axis(ctx, lx, true),
    y: apply_group_transform_axis(ctx, ly, false),
    w: scale_coord(lw, ctx.scale_x_num, ctx.scale_x_den),
    h: scale_coord(lh, ctx.scale_y_num, ctx.scale_y_den),
    is_title: shape_is_title_like(sp_xml),
    is_body: shape_is_body_like(sp_xml),
    object_ref,
  })
}

///|
fn make_picture_shape_from_xml(
  pic_xml : Bytes,
  ctx : PptxGroupContext,
  object_ref_override : String?,
) -> PptxRawPictureShape? raise {
  let object_ref = match object_ref_override {
    Some(v) => Some(v)
    None => read_picture_object_ref(pic_xml, ctx.group_ref_prefix)
  }
  Some({ xml: pic_xml, object_ref })
}

///|
fn make_graphic_frame_from_xml(
  frame_xml : Bytes,
  ctx : PptxGroupContext,
  object_ref_override : String?,
) -> PptxRawGraphicFrame? raise {
  let object_ref = match object_ref_override {
    Some(v) => Some(v)
    None =>
      Some(
        read_graphic_frame_object_ref_with_prefix(
          frame_xml,
          0,
          ctx.group_ref_prefix,
        ),
      )
  }
  Some({ xml: frame_xml, object_ref })
}

///|
fn read_shape_object_ref(sp_xml : Bytes, prefix : String?) -> String? raise {
  read_cnvpr_object_ref(sp_xml, "shape", prefix)
}

///|
fn read_picture_object_ref(pic_xml : Bytes, prefix : String?) -> String? raise {
  read_cnvpr_object_ref(pic_xml, "picture", prefix)
}

///|
fn read_cnvpr_object_ref(
  xml : Bytes,
  kind : String,
  prefix : String?,
) -> String? raise {
  let open_cnvpr = pat("<p:cNvPr")
  let gt_pat = pat(">")
  let p0 = find_bytes(xml, open_cnvpr, 0)
  match p0 {
    None => prefix
    Some(i0) => {
      let gt = find_bytes(xml, gt_pat, i0)
      match gt {
        None => prefix
        Some(gt0) => {
          let tag = xml[i0:gt0 + 1].to_owned()
          let local_ref = match read_attr_value_in_tag_bytes(tag, "id") {
            Some(id) =>
              if id.trim() == "" {
                None
              } else {
                Some(kind + "-" + id.trim().to_owned())
              }
            None => None
          }
          match prefix {
            Some(p) =>
              match local_ref {
                Some(l) => Some(p + "/" + l)
                None => Some(p)
              }
            None => local_ref
          }
        }
      }
    }
  }
}

///|
fn collect_slide_shapes_legacy(xml : Bytes) -> Array[SlideShape] raise {
  let out : Array[SlideShape] = []

  let open_sp = pat("<p:sp")
  let close_sp = pat("</p:sp>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let s0 = find_bytes(xml, open_sp, pos)
    match s0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(xml, gt_pat, i0)
        match gt {
          None => break
          Some(_gt0) => {
            let sp_end = find_bytes(xml, close_sp, i0)
            match sp_end {
              None => break
              Some(sp_end0) => {
                let sp_xml = xml[i0:sp_end0 + close_sp.length()].to_owned()
                match
                  make_text_shape_from_xml(
                    sp_xml,
                    default_group_context(),
                    None,
                  ) {
                  Some(sp) => out.push(sp)
                  None => ()
                }
                pos = sp_end0 + close_sp.length()
              }
            }
          }
        }
      }
    }
  }

  out
}

///|
fn collect_slide_picture_shapes_legacy(
  slide_xml : Bytes,
) -> Array[PptxRawPictureShape] raise {
  let out : Array[PptxRawPictureShape] = []
  let open_pic = pat("<p:pic")
  let close_pic = pat("</p:pic>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let p0 = find_bytes(slide_xml, open_pic, pos)
    match p0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(slide_xml, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let pic_end = find_bytes(slide_xml, close_pic, gt0 + 1)
            match pic_end {
              None => break
              Some(pic_end0) => {
                let pic_xml = slide_xml[i0:pic_end0 + close_pic.length()].to_owned()
                match
                  make_picture_shape_from_xml(
                    pic_xml,
                    default_group_context(),
                    None,
                  ) {
                  Some(meta) => out.push(meta)
                  None => ()
                }
                pos = pic_end0 + close_pic.length()
              }
            }
          }
        }
      }
    }
  }

  out
}

///|
fn collect_slide_graphic_frames_legacy(
  slide_xml : Bytes,
) -> Array[PptxRawGraphicFrame] raise {
  let out : Array[PptxRawGraphicFrame] = []
  let open_frame = pat("<p:graphicFrame")
  let close_frame = pat("</p:graphicFrame>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let p0 = find_bytes(slide_xml, open_frame, pos)
    match p0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(slide_xml, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let end0 = find_bytes(slide_xml, close_frame, gt0 + 1)
            match end0 {
              None => break
              Some(end) => {
                let frame_xml = slide_xml[i0:end + close_frame.length()].to_owned()
                match
                  make_graphic_frame_from_xml(
                    frame_xml,
                    default_group_context(),
                    None,
                  ) {
                  Some(frame) => out.push(frame)
                  None => ()
                }
                pos = end + close_frame.length()
              }
            }
          }
        }
      }
    }
  }

  out
}

///|
fn default_group_context() -> PptxGroupContext {
  {
    offset_x: 0,
    offset_y: 0,
    scale_x_num: 1,
    scale_x_den: 1,
    scale_y_num: 1,
    scale_y_den: 1,
    group_ref_prefix: None,
  }
}
