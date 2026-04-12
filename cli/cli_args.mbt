///|
/// 返回第一个 '=' 的位置（按字节扫描），找不到返回 None
fn find_first_eq(s : String) -> Int? {
  let bs = @utf8.encode(s)
  let n = bs.length()
  let mut i = 0
  while i < n {
    if bs[i] == 61 { // '='
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// TODO： 后序为“—” 等做规范化，先原样返回
/// 支持：--out=xxx / --output=xxx / --max-heading=3 这类写法（转成 ["--out", "xxx"]）
fn normalize_cli_args(args : Array[String]) -> Array[String] {
  let out : Array[String] = []
  if args.length() <= 1 {
    return out
  }

  for i in 1..<args.length() {
    let a = args[i].trim().to_string()

    if a.has_prefix("--") {
      let eq = find_first_eq(a)
      match eq {
        Some(pos) => {
          // --key=value  ->  ["--key", "value"]
          let k = a[:pos].to_string()
          let v = a[pos + 1:].to_string()
          out.push(k)
          out.push(v)
          continue
        }
        None => ()
      }
    }

    out.push(a)
  }

  out
}
