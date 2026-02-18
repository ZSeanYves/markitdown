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
fn normalize_cli_args(args : Array[String]) -> Array[String] raise{
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

///|
fn normalize_cli_args_safe(args : Array[String]) -> Array[String] {
  normalize_cli_args(args) catch {
    _ => {
      let out : Array[String] = []
      if args.length() <= 1 {
        return out
      }
      for i in 1..<args.length() {
        out.push(args[i].trim().to_string())
      }
      out
    }
  }
}


///|
fn exit_error(msg : String) -> Unit {
  println("error: " + msg)
}

///|
fn cmd_demo() -> Unit {
  let doc = @cor.new_document()

  @cor.push(doc, @cor.Heading(1, "项目申报书（Demo）"))
  @cor.push(
    doc,
    @cor.Paragraph(
      "这是一个用于验证 core/ir + emitter 的最小 demo。",
    ),
  )
  @cor.push(doc, @cor.Heading(2, "1. 研究内容"))
  @cor.push(
    doc,
    @cor.Paragraph("（1）目标：把 docx/pdf 转为结构化 Markdown。"),
  )

  let rows : Array[Array[String]] = [
    ["模块", "状态", "说明"],
    ["core/ir", "完成", "IR 定义与 push"],
    ["core/emitter", "完成", "Markdown 输出"],
    ["parsers/docx", "TODO", "下一步实现"],
    ["parsers/pdf", "TODO", "下一步实现"],
  ]
  @cor.push(doc, @cor.Table(rows))

  @cor.push(doc, @cor.Image("logo", "assets/logo.png"))

  let md = @cor.emit_markdown(doc)
  println(md)
}

///|
async fn cmd_convert(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
) -> Unit {
  let out_root = match out_dir {
    Some(d) => d
    None => "out"
  }

  // 确保 out_root 存在
  if !@fs.path_exists(out_root) {
    @fs.create_dir(out_root) catch {
      e => {
        exit_error(e.to_string())
        return
      }
    }
  }

  let opts : @pdf.ConvertOptions = {
    out_dir: Some(out_root),
    max_heading: Some(max_heading),
  }

  let doc_res = @pdf.parse_to_ir(input, opts) 
  let doc = match doc_res {
    Ok(d) => d
    Err(e) => {
      exit_error("parse failed: " + e.to_string())
      return
    }
  }

  let md = @cor.emit_markdown(doc)

  match output {
    Some(p) =>
      @fs.write_string_to_file(p, md, encoding="utf8") catch {
        e => exit_error("write output failed: " + e.to_string())
      }
    None => println(md)
  }
}



///|
fn parse_int_or_default(sopt : String?, default : Int) -> Int {
  match sopt {
    None => default
    Some(s0) => {
      let s = @cor.trim_string(s0)
      if s == "" {
        return default
      }

      let chars = s.to_array()
      let len = chars.length()
      let i : Ref[Int] = { val: 0 }

      // 处理符号
      let mut sign = 1
      if i.val < len {
        if chars[i.val] == '-' {
          sign = -1
          i.val += 1
        } else if chars[i.val] == '+' {
          i.val += 1
        }
      }

      if i.val >= len {
        return default
      }

      let mut acc : Int = 0
      let mut has_digit = false

      while i.val < len {
        let c = chars[i.val]
        if c >= '0' && c <= '9' {
          has_digit = true
          let digit = c.to_int() - '0'.to_int()
          // 简单累加（MVP 不做溢出检测）
          acc = acc * 10 + digit
          i.val += 1
        } else {
          // 遇到非数字就停止（例如 "3\n" / "3 "）
          break
        }
      }

      if !has_digit {
        default
      } else {
        acc * sign
      }
    }
  }
}


///|
async fn main {
  let args = @sys.get_cli_args()

  let parser = @clap.Parser::new(
    prog="markitdown-mb",
    description="Convert documents (docx/pdf) to Markdown (MoonBit, markitdown-like)",
    subcmds={
      "demo": @clap.SubCommand::new(
        help="Print a demo Markdown document (tests core/ir + emitter)",
        args={},
      ),
      "convert": @clap.SubCommand::new(
        help="Convert a .docx/.pdf file to Markdown (MVP: parser TODO)",
        args={
          "input": @clap.Arg::positional(help="Path to input file (.docx/.pdf)"),
          "output": @clap.Arg::named(
            short='o',
            nargs=@clap.Nargs::AtMost(1),
            help="Output markdown file (default: stdout)",
          ),
          "out-dir": @clap.Arg::named(
            nargs=@clap.Nargs::AtMost(1),
            help="Output directory for assets (default: ./out)",
          ),
          "max-heading": @clap.Arg::named(
            nargs=@clap.Nargs::AtMost(1),
            help="Max heading level to emit (default: 3)",
          ),
        },
      ),
      "help": @clap.SubCommand::new(help="Display help message"),
    },
  )

  let help_msg = parser.gen_help_message(["markitdown-mb"], {})

  let cli_args : Array[String] = normalize_cli_args_safe(args)
  if cli_args.length() == 0 {
    println(help_msg)
    return
  }

  let value = @clap.SimpleValue::new("markitdown-mb")
  //println("raw args  = \{args}")
  let cli_args : Array[String] = normalize_cli_args_safe(args)
  //println("norm args = \{cli_args}")

  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      println(help_msg)
      return
    }
  }

  match subcmd_help {
    Some(msg) => println(msg)
    None =>
      match value.subcmd {
        Some(sub) => {
          let positional = sub.positional_args
          match sub.name {
            "demo" => cmd_demo()
            "convert" => {
              if positional.length() == 0 {
                exit_error("missing input argument")
                println(help_msg)
                return
              }

              let input = positional[0]

              let output_opt : String? = match sub.args.get("output") {
                Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
                None => None
              }

              let out_dir_opt : String? = match sub.args.get("out-dir") {
                Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
                None => None
              }

              let max_heading_opt : String? = match
                sub.args.get("max-heading") {
                Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
                None => None
              }

              let mh0 = parse_int_or_default(max_heading_opt, 3)
              let max_heading = if mh0 < 1 {
                1
              } else if mh0 > 6 {
                6
              } else {
                mh0
              }
              cmd_convert(input, output_opt, out_dir_opt, max_heading)
            }
            "help" => println(help_msg)
            _ => println(help_msg)
          }
        }
        None => println(help_msg)
      }
  }
}
