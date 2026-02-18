// TODO： 后序为“—” 等做规范化，先原样返回
// TODO：拓展兼容 "--out=xxx"
///|
fn normalize_cli_args(args : Array[String]) -> Array[String] {
  let out : Array[String] = []
  if args.length() <= 1 {
    return out
  }
  for i in 1..<args.length() {
    out.push(args[i].trim().to_string())
  }
  out
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
fn cmd_convert(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
) -> Unit {
  // 目前 parser 还没做，这里先给可预期的行为
  // 你之后实现 parsers.docx / parsers.pdf 后，
  // 只需要在这里根据后缀 dispatch -> parse -> emit -> write

  println("convert 尚未实现：")
  println("  input = " + input)
  match output {
    Some(o) => println("  output = " + o)
    None => ()
  }
  match out_dir {
    Some(d) => println("  out-dir = " + d)
    None => ()
  }
  println("  max-heading = " + max_heading.to_string())
  println("")
  println(
    "你可以先运行：markitdown-mb demo 来验证 core 是否正常。",
  )
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
fn main {
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

  let cli_args : Array[String] = normalize_cli_args(args)
  if cli_args.length() == 0 {
    println(help_msg)
    return
  }

  let value = @clap.SimpleValue::new("markitdown-mb")
  println("raw args  = \{args}")
  let cli_args : Array[String] = normalize_cli_args(args)
  println("norm args = \{cli_args}")

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
