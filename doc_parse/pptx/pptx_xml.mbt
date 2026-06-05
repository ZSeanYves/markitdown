///|
fn pat(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn find_bytes(hay : Bytes, needle : Bytes, start : Int) -> Int? {
  let n = hay.length()
  let m = needle.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start > n - m {
    return None
  }
  let last = n - m
  let mut i = start
  while i <= last {
    let mut ok = true
    let mut j = 0
    while j < m {
      if hay[i + j] != needle[j] {
        ok = false
        break
      }
      j += 1
    }
    if ok {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn bytes_slice_to_string(bs : Bytes, start : Int, end_ : Int) -> String raise {
  let len = end_ - start
  if len <= 0 {
    return ""
  }
  @utf8.decode(bs[start:end_].to_owned(), ignore_bom=false)
}

///|
fn read_attr_value_in_tag_bytes(
  tag : Bytes,
  attr_name : String,
) -> String? raise {
  let p1 = pat(attr_name + "=\"")
  let p2 = pat(attr_name + "='")

  match find_bytes(tag, p1, 0) {
    Some(i0) => {
      let start = i0 + p1.length()
      let mut i = start
      while i < tag.length() {
        if tag[i] == '"'.to_int().to_byte() {
          return Some(bytes_slice_to_string(tag, start, i))
        }
        i += 1
      }
      None
    }
    None =>
      match find_bytes(tag, p2, 0) {
        Some(i0) => {
          let start = i0 + p2.length()
          let mut i = start
          while i < tag.length() {
            if tag[i] == '\''.to_int().to_byte() {
              return Some(bytes_slice_to_string(tag, start, i))
            }
            i += 1
          }
          None
        }
        None => None
      }
  }
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
fn xml_unescape(s : String) -> String {
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
  @cor.decode_numeric_entities(t)
}

///|
fn contains_bytes(hay : Bytes, needle : Bytes) -> Bool {
  match find_bytes(hay, needle, 0) {
    Some(_) => true
    None => false
  }
}

///|
fn parse_nonneg_int(s : String) -> Int {
  let t = s.trim().to_owned()
  if t == "" {
    return 0
  }

  let mut n = 0
  let mut ok = false
  for c in t.to_array() {
    if c >= '0' && c <= '9' {
      n = n * 10 + (c.to_int() - '0'.to_int())
      ok = true
    } else {
      return 0
    }
  }
  if ok {
    n
  } else {
    0
  }
}

///|
fn shape_is_title_like(xml : Bytes) -> Bool {
  contains_bytes(xml, pat("type=\"title\"")) ||
  contains_bytes(xml, pat("type=\"ctrTitle\"")) ||
  contains_bytes(xml, pat("type=\"subTitle\""))
}

///|
fn shape_is_body_like(xml : Bytes) -> Bool {
  contains_bytes(xml, pat("type=\"body\""))
}

///|
fn shape_is_text_box_like(xml : Bytes) -> Bool {
  contains_bytes(xml, pat("txBox=\"1\"")) ||
  contains_bytes(xml, pat("txBox='1'"))
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
fn find_sp_tree_inner(xml : Bytes) -> Bytes? {
  let open_tree = pat("<p:spTree")
  let close_tree = pat("</p:spTree>")
  let gt_pat = pat(">")
  let p0 = find_bytes(xml, open_tree, 0)
  match p0 {
    None => None
    Some(i0) =>
      match find_bytes(xml, gt_pat, i0) {
        None => None
        Some(gt0) =>
          match find_bytes(xml, close_tree, gt0 + 1) {
            None => None
            Some(end) => Some(xml[gt0 + 1:end].to_owned())
          }
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
fn scale_coord(value : Int, num : Int, den : Int) -> Int {
  if den <= 0 {
    value
  } else {
    value * num / den
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
fn read_transform_pair(xml : Bytes, tag_prefix : String) -> (Int, Int) raise {
  let open_pat = pat(tag_prefix)
  let gt_pat = pat(">")
  let p0 = find_bytes(xml, open_pat, 0)
  match p0 {
    None => (0, 0)
    Some(i0) =>
      match find_bytes(xml, gt_pat, i0) {
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
fn read_group_object_ref(group_xml : Bytes) -> String? raise {
  let open_cnvpr = pat("<p:cNvPr")
  let gt_pat = pat(">")
  let p0 = find_bytes(group_xml, open_cnvpr, 0)
  match p0 {
    None => None
    Some(i0) =>
      match find_bytes(group_xml, gt_pat, i0) {
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
fn read_cnvpr_id(xml : Bytes) -> String? raise {
  read_attr_value_in_first_tag_bytes(xml, "<p:cNvPr", "id")
}

///|
fn read_cnvpr_name(xml : Bytes) -> String? raise {
  read_attr_value_in_first_tag_bytes(xml, "<p:cNvPr", "name")
}

///|
fn read_cnvpr_object_ref(
  xml : Bytes,
  kind : String,
  prefix : String?,
) -> String? raise {
  let local_ref = match read_cnvpr_id(xml) {
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
