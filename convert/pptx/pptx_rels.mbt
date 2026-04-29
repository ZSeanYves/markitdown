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
            match read_attr_value_in_tag_bytes(tag.to_owned(), "r:id") {
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
