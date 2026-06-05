///|
/// read paragraph level from <a:pPr ... lvl="N">
/// default to 0 if absent / invalid
fn paragraph_level(xml : Bytes, start : Int, end_ : Int) -> Int raise {
  let ppr_pat = pat("<a:pPr")
  let gt_pat = pat(">")

  let ppr0 = find_bytes(xml, ppr_pat, start)
  match ppr0 {
    None => 0
    Some(i0) => {
      if i0 >= end_ {
        return 0
      }

      let gt = find_bytes(xml, gt_pat, i0)
      match gt {
        None => 0
        Some(gt0) => {
          if gt0 >= end_ {
            return 0
          }

          let tag = xml[i0:gt0 + 1].to_owned()
          match read_attr_value_in_tag_bytes(tag, "lvl") {
            Some(v) => parse_nonneg_int(v)
            None => 0
          }
        }
      }
    }
  }
}

///|
fn paragraph_bullet_kind(xml : Bytes, start : Int, end_ : Int) -> BulletKind? {
  let bu_char = pat("<a:buChar")
  let bu_auto = pat("<a:buAutoNum")
  let bu_blip = pat("<a:buBlip")
  let bu_none = pat("<a:buNone")

  let has_bu_none = match find_bytes(xml, bu_none, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_none {
    return None
  }

  let has_bu_auto = match find_bytes(xml, bu_auto, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_auto {
    return Some(BulletKind::Ordered)
  }

  let has_bu_char = match find_bytes(xml, bu_char, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_char {
    return Some(BulletKind::Unordered)
  }

  let has_bu_blip = match find_bytes(xml, bu_blip, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_blip {
    return Some(BulletKind::Unordered)
  }

  None
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
