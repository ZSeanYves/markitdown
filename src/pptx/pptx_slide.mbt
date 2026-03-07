///|
/// scan slide xml, extract each <a:p> as one paragraph
fn extract_slide_paragraphs(xml : Bytes) -> Array[String] raise {
  let out : Array[String] = []

  let open_p = pat("<a:p")
  let close_p = pat("</a:p>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let p0 = find_bytes(xml, open_p, pos)
    match p0 {
      None => break
      Some(i0) => {
        // find '>' end of <a:p ...>
        let gt = find_bytes(xml, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let inner_start = gt0 + 1
            let p_end = find_bytes(xml, close_p, inner_start)
            match p_end {
              None => break
              Some(p_end0) => {
                let line = extract_text_runs(xml, inner_start, p_end0)
                  .trim()
                  .to_string()

                if line != "" {
                  out.push(line)
                }

                pos = p_end0 + close_p.length()
              }
            }
          }
        }
      }
    }
  }

  out
}
