///|
/// extract all <a:t>...</a:t> text within xml[start:end_]
fn extract_text_runs(xml : Bytes, start : Int, end_ : Int) -> String{
  let open_t = pat("<a:t>")
  let close_t = pat("</a:t>")

  let mut tpos = start
  let mut acc = ""

  while tpos < end_ {
    let t0 = find_bytes(xml, open_t, tpos)
    match t0 {
      None => break
      Some(t0i) => {
        if t0i >= end_ {
          break
        }

        let content_start = t0i + open_t.length()
        let t1 = find_bytes(xml, close_t, content_start)
        match t1 {
          None => break
          Some(t1i) => {
            if t1i > end_ {
              break
            }

            let seg = xml[content_start:t1i].to_bytes()
            let s = @cor.utf8_bytes_to_string(seg) catch { _ => "" }

            acc = acc + s
            tpos = t1i + close_t.length()
          }
        }
      }
    }
  }

  xml_unescape(acc)
}
