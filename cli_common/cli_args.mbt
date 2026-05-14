///|
/// CLI argument normalization helper.
/// Converts `--key=value` form into `--key value` so downstream clap config can
/// stay simple and consistent across subcommands.
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
pub fn normalize_cli_args(args : Array[String]) -> Array[String] {
  let out : Array[String] = []
  if args.length() <= 1 {
    return out
  }

  for i in 1..<args.length() {
    let a = args[i].trim().to_owned()

    if a.has_prefix("--") {
      let eq = find_first_eq(a)
      match eq {
        Some(pos) => {
          let k = a[:pos].to_owned()
          let v = a[pos + 1:].to_owned()
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
