///|
fn find_next_from(chars : Array[Char], start : Int, pat : String) -> Int {
  let p = pat.to_array()
  let plen = p.length()
  let n = chars.length()
  let mut i = start
  while i + plen <= n {
    let mut ok = true
    for k in 0..<plen {
      if chars[i + k] != p[k] {
        ok = false
        break
      }
    }
    if ok {
      return i
    }
    i += 1
  }
  -1
}

///|
fn read_quoted(chars : Array[Char], start : Int) -> String {
  // start 指向引号后第一个字符
  let mut j = start
  let buf : Ref[Array[Char]] = { val: [] }
  while j < chars.length() && chars[j] != '"' {
    buf.val.push(chars[j])
    j += 1
  }
  String::from_array(buf.val)
}

///|
pub fn parse_rels(rels_xml : String) -> Map[String, String] {
  let m : Map[String, String] = Map::new()
  let chars = rels_xml.to_array()
  let len = chars.length()
  let mut i = 0

  while i < len {
    let pos_id = find_next_from(chars, i, "Id=\"")
    if pos_id < 0 {
      break
    }
    let id = read_quoted(chars, pos_id + 4)

    let after_id = pos_id + 4 + id.length() + 1
    let pos_t = find_next_from(chars, after_id, "Target=\"")
    if pos_t < 0 {
      i = after_id
      continue
    }
    let target = read_quoted(chars, pos_t + 8)

    m.set(id, target)
    i = pos_t + 8 + target.length() + 1
  }

  m
}

///|
pub fn rid_to_asset_path(target : String) -> String {
  "assets/" + @cor.basename(target)
}
