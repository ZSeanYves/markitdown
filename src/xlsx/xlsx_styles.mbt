///|
/// minimal XLSX styles support:
/// - parse xl/styles.xml
/// - keep cellXfs style index -> numFmtId
/// - keep custom numFmtId -> formatCode
/// - detect date/time-like numFmt
priv struct XlsxStyles {
  xf_numfmts : Array[Int]
  custom_numfmts : Map[Int, String]
}

///|
fn empty_styles() -> XlsxStyles {
  { xf_numfmts: [], custom_numfmts: Map::new() }
}

///|
/// parse xl/styles.xml:
/// - <numFmts><numFmt numFmtId="..." formatCode="..."/></numFmts>
/// - <cellXfs><xf numFmtId="...">...</xf></cellXfs>
fn parse_styles_xml(styles_xml : String) -> XlsxStyles raise {
  let xf_numfmts : Array[Int] = []
  let custom_numfmts : Map[Int, String] = Map::new()

  // 1) parse custom numFmts
  let numfmts0 = find_sub(styles_xml, "<numFmts", 0)
  match numfmts0 {
    None => ()
    Some(nf0) => {
      let gt0 = find_sub(styles_xml, ">", nf0)
      match gt0 {
        None => ()
        Some(nf1) => {
          let end0 = find_sub(styles_xml, "</numFmts>", nf1 + 1)
          match end0 {
            None => ()
            Some(nf_end) => {
              let inner = styles_xml[nf1 + 1:nf_end].to_string()
              let mut pos = 0
              while true {
                let fmt0 = find_sub(inner, "<numFmt", pos)
                match fmt0 {
                  None => break
                  Some(i0) => {
                    let fmt1 = find_sub(inner, ">", i0)
                    match fmt1 {
                      None => break
                      Some(i1) => {
                        let tag = inner[i0:i1 + 1].to_string()
                        let num_fmt_id = parse_int(
                          get_attr(tag, "numFmtId").unwrap_or(""),
                        )
                        let format_code = get_attr(tag, "formatCode").unwrap_or(
                          "",
                        )
                        if num_fmt_id >= 0 && format_code != "" {
                          custom_numfmts.set(
                            num_fmt_id,
                            xml_unescape(format_code),
                          )
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

  // 2) parse cellXfs
  let cellxfs0 = find_sub(styles_xml, "<cellXfs", 0)
  match cellxfs0 {
    None => ()
    Some(cx0) => {
      let gt0 = find_sub(styles_xml, ">", cx0)
      match gt0 {
        None => ()
        Some(cx1) => {
          let end0 = find_sub(styles_xml, "</cellXfs>", cx1 + 1)
          match end0 {
            None => ()
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

  { xf_numfmts, custom_numfmts }
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
fn custom_numfmt_code(styles : XlsxStyles, num_fmt_id : Int) -> String? {
  styles.custom_numfmts.get(num_fmt_id)
}

///|
fn numfmt_is_builtin_datetime_like(num_fmt_id : Int) -> Bool {
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
fn numfmt_is_date_only_builtin(num_fmt_id : Int) -> Bool {
  num_fmt_id == 14 || num_fmt_id == 15 || num_fmt_id == 16 || num_fmt_id == 17
}

///|
fn numfmt_is_time_only_builtin(num_fmt_id : Int) -> Bool {
  num_fmt_id == 18 ||
  num_fmt_id == 19 ||
  num_fmt_id == 20 ||
  num_fmt_id == 21 ||
  num_fmt_id == 45 ||
  num_fmt_id == 46 ||
  num_fmt_id == 47
}

///|
fn numfmt_is_datetime_builtin(num_fmt_id : Int) -> Bool {
  num_fmt_id == 22
}

///|
/// very lightweight formatCode classifier:
/// - remove quoted literals and escaped chars roughly
/// - if contains y/m/d/h/s tokens, treat as datetime-like
fn numfmt_code_is_datetime_like(code : String) -> Bool {
  let t = normalize_numfmt_code(code)
  let has_date = t.contains("y") || t.contains("m") || t.contains("d")
  let has_time = t.contains("h") || t.contains("s")
  has_date || has_time
}

///|
fn numfmt_code_is_date_only(code : String) -> Bool {
  let t = normalize_numfmt_code(code)
  let has_date = t.contains("y") || t.contains("m") || t.contains("d")
  let has_time = t.contains("h") || t.contains("s")
  has_date && !has_time
}

///|
fn numfmt_code_is_time_only(code : String) -> Bool {
  let t = normalize_numfmt_code(code)
  let has_date = t.contains("y") || t.contains("m") || t.contains("d")
  let has_time = t.contains("h") || t.contains("s")
  !has_date && has_time
}

///|
fn numfmt_code_is_datetime(code : String) -> Bool {
  let t = normalize_numfmt_code(code)
  let has_date = t.contains("y") || t.contains("m") || t.contains("d")
  let has_time = t.contains("h") || t.contains("s")
  has_date && has_time
}

///|
/// rough normalization for Excel formatCode:
/// - lowercase
/// - drop quoted strings
/// - drop escaped chars after '\'
/// - keep core datetime letters
fn normalize_numfmt_code(code : String) -> String {
  let s = code.to_lower()
  let cs = s.to_array()
  let mut i = 0
  let mut out = ""

  while i < cs.length() {
    let c = cs[i]

    if c == '"' {
      i = i + 1
      while i < cs.length() && cs[i] != '"' {
        i = i + 1
      }
      if i < cs.length() {
        i = i + 1
      }
      continue
    }

    if c == '\\' {
      i = i + 2
      continue
    }

    if c == '[' {
      i = i + 1
      while i < cs.length() && cs[i] != ']' {
        i = i + 1
      }
      if i < cs.length() {
        i = i + 1
      }
      continue
    }

    out = out + c.to_string()
    i = i + 1
  }

  out
}
