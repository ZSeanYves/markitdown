///|
/// minimal XLSX styles support:
/// - parse xl/styles.xml
/// - keep cellXfs style index -> numFmtId
/// - detect date/time-like numFmtId
priv struct XlsxStyles {
  xf_numfmts : Array[Int]
}

///|
fn empty_styles() -> XlsxStyles {
  { xf_numfmts: [] }
}

///|
/// parse xl/styles.xml:
/// only keep <cellXfs><xf numFmtId="...">...</xf></cellXfs>
fn parse_styles_xml(styles_xml : String) -> XlsxStyles raise {
  let xf_numfmts : Array[Int] = []

  let cellxfs0 = find_sub(styles_xml, "<cellXfs", 0)
  match cellxfs0 {
    None => return empty_styles()
    Some(cx0) => {
      let gt0 = find_sub(styles_xml, ">", cx0)
      match gt0 {
        None => return empty_styles()
        Some(cx1) => {
          let end0 = find_sub(styles_xml, "</cellXfs>", cx1 + 1)
          match end0 {
            None => return empty_styles()
            Some(cx_end) => {
              let inner = styles_xml[cx1 + 1:cx_end].to_string()

              let mut pos = 0
              while true {
                let xf0 = find_sub(inner, "<xf", pos)
                match xf0 {
                  None => break
                  Some(i0) => {
                    let xf1 = find_sub(inner, ">", i0)
                    match xf1 {
                      None => break
                      Some(i1) => {
                        let tag = inner[i0:i1 + 1].to_string()
                        let num_fmt_id = parse_int(
                          get_attr(tag, "numFmtId").unwrap_or(""),
                        )
                        if num_fmt_id >= 0 {
                          xf_numfmts.push(num_fmt_id)
                        } else {
                          xf_numfmts.push(-1)
                        }
                        pos = i1 + 1
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  { xf_numfmts, }
}

///|
fn style_index_numfmt(styles : XlsxStyles, style_idx : Int) -> Int {
  if style_idx < 0 || style_idx >= styles.xf_numfmts.length() {
    -1
  } else {
    styles.xf_numfmts[style_idx]
  }
}

///|
fn numfmt_is_datetime_like(num_fmt_id : Int) -> Bool {
  num_fmt_id == 14 ||
  num_fmt_id == 15 ||
  num_fmt_id == 16 ||
  num_fmt_id == 17 ||
  num_fmt_id == 18 ||
  num_fmt_id == 19 ||
  num_fmt_id == 20 ||
  num_fmt_id == 21 ||
  num_fmt_id == 22 ||
  num_fmt_id == 45 ||
  num_fmt_id == 46 ||
  num_fmt_id == 47
}

///|
fn numfmt_is_date_only(num_fmt_id : Int) -> Bool {
  num_fmt_id == 14 || num_fmt_id == 15 || num_fmt_id == 16 || num_fmt_id == 17
}

///|
fn numfmt_is_time_only(num_fmt_id : Int) -> Bool {
  num_fmt_id == 18 ||
  num_fmt_id == 19 ||
  num_fmt_id == 20 ||
  num_fmt_id == 21 ||
  num_fmt_id == 45 ||
  num_fmt_id == 46 ||
  num_fmt_id == 47
}

///|
fn numfmt_is_datetime(num_fmt_id : Int) -> Bool {
  num_fmt_id == 22
}
