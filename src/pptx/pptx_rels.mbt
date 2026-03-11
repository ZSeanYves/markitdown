//|
///|
fn parse_presentation_slide_rids(xml : String) -> Array[String] raise {
  let bs = @utf8.encode(xml)
  let out : Array[String] = []

  let open_pat = pat("<p:sldId")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let s0 = find_bytes(bs, open_pat, pos)
    match s0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(bs, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let tag = bs[i0:gt0 + 1]
            match read_attr_value_in_tag_bytes(tag.to_bytes(), "r:id") {
              Some(rid) => out.push(rid)
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
fn parse_presentation_rels(xml : String) -> Map[String, String] raise {
  let bs = @utf8.encode(xml)
  let out : Map[String, String] = {}

  let rel_pat = pat("<Relationship")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let r0 = find_bytes(bs, rel_pat, pos)
    match r0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(bs, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let tag = bs[i0:gt0 + 1]

            let id = match read_attr_value_in_tag_bytes(tag.to_bytes(), "Id") {
              Some(v) => v
              None => {
                pos = gt0 + 1
                continue
              }
            }

            let target = match
              read_attr_value_in_tag_bytes(tag.to_bytes(), "Target") {
              Some(v) => v
              None => {
                pos = gt0 + 1
                continue
              }
            }

            out[id] = target
            pos = gt0 + 1
          }
        }
      }
    }
  }

  out
}

///|
fn normalize_ppt_target(target : String) -> String {
  if target.has_prefix("ppt/") {
    target
  } else if target.has_prefix("/") {
    target[1:].to_string()
  } else {
    "ppt/" + target
  }
}
