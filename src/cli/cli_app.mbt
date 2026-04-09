///|
async fn cmd_convert(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
  pdf_mode : String?,
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

  let opts : @conv.ConvertOptions = {
    out_dir: Some(out_root),
    max_heading: Some(max_heading),
    pdf_enhance_mode: pdf_mode,
  }

  let doc_res = @conv.parse_to_ir(input, opts)
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
fn exit_error(msg : String) -> Unit {
  println("error: " + msg)
}
