// ============================
// sharedStrings.xml parsing
// ============================
//
// Common:
// <si><t>hello</t></si>
// Rich text:
// <si><r><t>he</t></r><r><t>llo</t></r></si>
// MVP: concat all <t> contents inside <si>

///|
fn parse_shared_strings(ss_xml : String) -> Array[String] {
  let out : Array[String] = []
  let mut pos = 0

  while true {
    let si0 = find_sub(ss_xml, "<si", pos)
    match si0 {
      None => break
      Some(si_start) => {
        let si_end0 = find_sub(ss_xml, "</si>", si_start)
        match si_end0 {
          None => break
          Some(si_end) => {
            let chunk = ss_xml[si_start:si_end].to_string()

            let mut tpos = 0
            let mut acc = ""
            while true {
              let t0 = find_sub(chunk, "<t", tpos)
              match t0 {
                None => break
                Some(t_start) => {
                  let ttag_end = find_sub(chunk, ">", t_start)
                  match ttag_end {
                    None => break
                    Some(t_end_tag) => {
                      let content_start = t_end_tag + 1
                      let t1 = find_sub(chunk, "</t>", content_start)
                      match t1 {
                        None => break
                        Some(t_end) => {
                          let content = chunk[content_start:t_end].to_string()
                          acc = acc + content
                          tpos = t_end + 4
                        }
                      }
                    }
                  }
                }
              }
            }

            out.push(xml_unescape(acc))
            pos = si_end + 5
          }
        }
      }
    }
  }

  out
}
