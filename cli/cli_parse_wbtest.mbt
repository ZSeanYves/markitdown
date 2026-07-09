///|
test "main cli product policy exposes text, notebook, markup, container, office, pdf, and image formats" {
  assert_true(cli_is_supported_format(@input.DetectedFormat::Txt))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Csv))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Tsv))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Srt))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Vtt))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Json))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Jsonl))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Ndjson))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Ipynb))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Xml))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Yaml))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Toml))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Html))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Eml))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Markdown))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Tex))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Rst))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Asciidoc))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Zip))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Epub))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Odt))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Ods))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Odp))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Docx))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Xlsx))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Pptx))
  assert_true(cli_is_supported_format(@input.DetectedFormat::Pdf))
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Audio(@input.AudioFormat::Mp3),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Audio(@input.AudioFormat::M4a),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Jpg),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Jpeg),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Bmp),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Webp),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Tif),
    ),
  )
  assert_true(
    cli_is_supported_format(
      @input.DetectedFormat::Image(@input.ImageFormat::Tiff),
    ),
  )
  assert_true(!cli_is_supported_format(@input.DetectedFormat::Unknown))
  let supported = [
    "txt", "csv", "tsv", "srt", "vtt", "json", "jsonl", "ndjson", "ipynb", "xml",
    "yaml", "yml", "toml", "html", "htm", "markdown", "md", "eml", "msg", "tex",
    "latex", "rst", "adoc", "asciidoc", "zip", "epub", "docx", "xlsx", "pptx", "pdf",
    "wav", "mp3", "m4a", "png", "jpg", "jpeg", "bmp", "webp", "tif", "tiff",
  ]
  assert_eq(supported.length(), 40)
  assert_eq(supported[0], "txt")
  assert_eq(supported[1], "csv")
  assert_eq(supported[2], "tsv")
  assert_eq(supported[3], "srt")
  assert_eq(supported[4], "vtt")
  assert_eq(supported[5], "json")
  assert_eq(supported[6], "jsonl")
  assert_eq(supported[7], "ndjson")
  assert_eq(supported[8], "ipynb")
  assert_eq(supported[9], "xml")
  assert_eq(supported[10], "yaml")
  assert_eq(supported[11], "yml")
  assert_eq(supported[12], "toml")
  assert_eq(supported[13], "html")
  assert_eq(supported[14], "htm")
  assert_eq(supported[15], "markdown")
  assert_eq(supported[16], "md")
  assert_eq(supported[17], "eml")
  assert_eq(supported[18], "msg")
  assert_eq(supported[19], "tex")
  assert_eq(supported[20], "latex")
  assert_eq(supported[21], "rst")
  assert_eq(supported[22], "adoc")
  assert_eq(supported[23], "asciidoc")
  assert_eq(supported[24], "zip")
  assert_eq(supported[25], "epub")
  assert_eq(supported[26], "docx")
  assert_eq(supported[27], "xlsx")
  assert_eq(supported[28], "pptx")
  assert_eq(supported[29], "pdf")
  assert_eq(supported[30], "wav")
  assert_eq(supported[31], "mp3")
  assert_eq(supported[32], "m4a")
  assert_eq(supported[33], "png")
  assert_eq(supported[34], "jpg")
  assert_eq(supported[35], "jpeg")
  assert_eq(supported[36], "bmp")
  assert_eq(supported[37], "webp")
  assert_eq(supported[38], "tif")
  assert_eq(supported[39], "tiff")
}

///|
test "main cli parses msg as eml alias" {
  match parse_cli_options(["--format", "msg", "mail.msg"]) {
    Ok(opts) =>
      assert_true(opts.explicit_format == Some(@input.DetectedFormat::Eml))
    Err(msg) => fail("expected msg alias to parse: " + msg)
  }

  match parse_cli_options(["mail.msg"]) {
    Ok(opts) => {
      assert_true(cli_requested_format(opts) == @input.DetectedFormat::Eml)
      assert_eq(cli_requested_format_label(opts), "eml")
    }
    Err(msg) => fail("expected implicit msg alias to parse: " + msg)
  }
}

///|
test "main cli accepts known image extensions as supported formats" {
  let root = test_tmp_root() + "/main-cli-image-fail-closed"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let png_path = root + "/tiny.png"
  write_utf8_text(png_path, "not-a-real-image")

  let explicit = parse_explicit_format(Some("png"))
  match explicit {
    Ok(Some(format)) =>
      assert_true(
        format == @input.DetectedFormat::Image(@input.ImageFormat::Png),
      )
    Ok(None) => fail("expected explicit png format to parse")
    Err(msg) => fail("expected explicit png format to stay supported: " + msg)
  }
}

///|
test "main cli parses explicit OCR intent flags" {
  match parse_cli_options(["--ocr", "--ocr-lang", "eng", "tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == Some("eng"))
    }
    Err(msg) => fail("expected OCR flags to parse: " + msg)
  }

  match parse_cli_options(["--no-ocr", "tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Disabled)
      assert_true(opts.ocr_options.language == None)
    }
    Err(msg) => fail("expected --no-ocr to parse: " + msg)
  }

  match parse_cli_options(["tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == None)
    }
    Err(msg) => fail("expected direct image input to default to OCR: " + msg)
  }

  match parse_cli_options(["--ocr-lang", "eng", "tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == Some("eng"))
    }
    Err(msg) => fail("expected direct image input to accept --ocr-lang: " + msg)
  }

  match parse_cli_options(["--audio-lang", "zh", "tiny.wav"]) {
    Ok(opts) => {
      assert_true(opts.audio_options.language == Some("zh"))
      assert_true(opts.ocr_options.language == None)
    }
    Err(msg) => fail("expected audio input to accept --audio-lang: " + msg)
  }
}

///|
test "main cli keeps --debug and rejects retired --json alias" {
  match
    parse_cli_options_from_index(
      ["tiny.txt"],
      0,
      mode=@convert.ConvertMode::Accurate,
    ) {
    Ok(opts) => {
      assert_true(opts.fidelity_mode == @convert.FidelityMode::Accurate)
      assert_true(opts.convert_mode == @convert.ConvertMode::Accurate)
      assert_true(opts.output_mode == @convert.OutputMode::Markdown)
      assert_true(opts.output_format == @convert.OutputFormat::Markdown)
    }
    Err(msg) => fail("expected accurate mode to parse: " + msg)
  }

  match
    parse_cli_options_from_index(
      ["--debug", "tiny.txt"],
      0,
      mode=@convert.ConvertMode::Accurate,
    ) {
    Ok(opts) => {
      assert_true(opts.fidelity_mode == @convert.FidelityMode::Accurate)
      assert_true(opts.convert_mode == @convert.ConvertMode::Accurate)
      assert_true(opts.output_mode == @convert.OutputMode::Debug)
      assert_true(opts.output_format == @convert.OutputFormat::DebugJson)
    }
    Err(msg) => fail("expected accurate --debug to parse: " + msg)
  }

  match
    parse_cli_options_from_index(
      ["--rag", "tiny.txt"],
      0,
      mode=@convert.ConvertMode::Accurate,
    ) {
    Ok(opts) => {
      assert_true(opts.fidelity_mode == @convert.FidelityMode::Accurate)
      assert_true(opts.convert_mode == @convert.ConvertMode::Accurate)
      assert_true(opts.output_mode == @convert.OutputMode::Rag)
      assert_true(opts.output_format == @convert.OutputFormat::RagJson)
    }
    Err(msg) => fail("expected accurate --rag to parse: " + msg)
  }

  match parse_cli_options(["--debug", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.convert_mode == @convert.ConvertMode::Balanced)
      assert_true(!opts.stream_requested)
      assert_true(opts.output_mode == @convert.OutputMode::Debug)
      assert_true(opts.output_format == @convert.OutputFormat::DebugJson)
    }
    Err(msg) => fail("expected --debug to parse: " + msg)
  }

  match parse_cli_options(["--rag", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.convert_mode == @convert.ConvertMode::Balanced)
      assert_true(opts.output_mode == @convert.OutputMode::Rag)
      assert_true(opts.output_format == @convert.OutputFormat::RagJson)
      assert_eq(
        opts.rag_options.chunk_size,
        @rag.default_rag_options().chunk_size,
      )
      assert_eq(
        opts.rag_options.chunk_overlap,
        @rag.default_rag_options().chunk_overlap,
      )
      assert_true(opts.rag_options.preserve_heading_path)
      assert_true(opts.rag_options.preserve_source_ref)
      assert_true(opts.rag_options.split_tables)
      assert_true(opts.rag_options.split_code_blocks)
    }
    Err(msg) => fail("expected --rag to parse: " + msg)
  }

  match parse_cli_options(["--debug", "--rag", "tiny.txt"]) {
    Err(msg) => assert_true(msg.contains("cannot combine --debug and --rag"))
    Ok(_) => fail("expected --debug and --rag to conflict")
  }

  match
    parse_cli_options_from_index(
      ["tiny.txt"],
      0,
      mode=@convert.ConvertMode::Stream,
    ) {
    Ok(opts) => {
      assert_true(opts.stream_requested)
      assert_true(opts.convert_mode == @convert.ConvertMode::Stream)
      assert_true(opts.output_mode == @convert.OutputMode::Markdown)
      assert_true(opts.output_format == @convert.OutputFormat::Markdown)
    }
    Err(msg) => fail("expected stream mode to parse: " + msg)
  }

  match
    parse_cli_options_from_index(
      ["--debug", "tiny.txt"],
      0,
      mode=@convert.ConvertMode::Stream,
    ) {
    Ok(opts) => {
      assert_true(opts.stream_requested)
      assert_true(opts.convert_mode == @convert.ConvertMode::Stream)
      assert_true(opts.output_mode == @convert.OutputMode::Debug)
      assert_true(opts.output_format == @convert.OutputFormat::DebugJson)
    }
    Err(msg) => fail("expected stream --debug to parse: " + msg)
  }

  match
    parse_cli_options_from_index(
      ["--rag", "tiny.txt"],
      0,
      mode=@convert.ConvertMode::Stream,
    ) {
    Ok(opts) => {
      assert_true(opts.stream_requested)
      assert_true(opts.convert_mode == @convert.ConvertMode::Stream)
      assert_true(opts.output_mode == @convert.OutputMode::Rag)
      assert_true(opts.output_format == @convert.OutputFormat::RagJson)
    }
    Err(msg) => fail("expected stream --rag to parse: " + msg)
  }

  match parse_cli_options(["--accurate", "tiny.txt"]) {
    Err(msg) =>
      assert_true(
        msg.contains("`--accurate` was removed; use the `accurate` mode"),
      )
    Ok(_) => fail("expected retired --accurate flag to fail")
  }

  match parse_cli_options(["--stream", "tiny.txt"]) {
    Err(msg) =>
      assert_true(msg.contains("`--stream` was removed; use the `stream` mode"))
    Ok(_) => fail("expected retired --stream flag to fail")
  }

  match parse_cli_options(["--json", "tiny.txt"]) {
    Err(msg) => assert_true(msg.contains("unsupported option: --json"))
    Ok(_) => fail("expected retired --json alias to fail")
  }
}

///|
test "main cli rejects retired PDF-specific options as unsupported" {
  match parse_cli_options(["--pdf-cleanup", "conservative", "tiny.pdf"]) {
    Err(msg) => assert_true(msg.contains("unsupported option: --pdf-cleanup"))
    Ok(_) => fail("expected retired --pdf-cleanup to fail")
  }
  match parse_cli_options(["--pdf-tables", "simple", "tiny.pdf"]) {
    Err(msg) => assert_true(msg.contains("unsupported option: --pdf-tables"))
    Ok(_) => fail("expected retired --pdf-tables to fail")
  }
  match parse_cli_options(["--pdf-ocr", "auto-scanned", "tiny.pdf"]) {
    Err(msg) => assert_true(msg.contains("unsupported option: --pdf-ocr"))
    Ok(_) => fail("expected retired --pdf-ocr to fail")
  }
}

///|
test "main cli rejects conflicting OCR intent flags" {
  match parse_cli_options(["--ocr", "--no-ocr", "tiny.png"]) {
    Err(msg) => assert_true(msg.contains("cannot combine --ocr and --no-ocr"))
    Ok(_) => fail("expected conflicting OCR flags to fail")
  }
}

///|
test "main cli constrains --ocr-lang to OCR-capable routes" {
  match parse_cli_options(["--ocr-lang", "eng", "tiny.png"]) {
    Ok(opts) => {
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.ocr_options.language == Some("eng"))
    }
    Err(msg) => fail("expected direct image --ocr-lang to parse: " + msg)
  }

  match parse_cli_options(["--ocr-lang", "eng", "tiny.txt"]) {
    Err(msg) =>
      assert_true(
        msg.contains(
          "--ocr-lang requires --ocr, direct image input, or the `accurate` PDF layout route",
        ),
      )
    Ok(_) => fail("expected non-image --ocr-lang without --ocr to fail")
  }

  match parse_cli_options(["--ocr-lang", "eng", "--ocr", "tiny.pdf"]) {
    Err(msg) =>
      assert_true(
        msg.contains(
          "PDF OCR is only available through the `accurate` PDF layout route",
        ),
      )
    Ok(_) => fail("expected balanced pdf --ocr to fail closed")
  }

  match
    parse_cli_options_from_index(
      ["tiny.pdf"],
      0,
      mode=@convert.ConvertMode::Accurate,
    ) {
    Ok(opts) => {
      assert_true(opts.fidelity_mode == @convert.FidelityMode::Accurate)
      assert_true(opts.ocr_options.intent == @parser.OcrIntent::Explicit)
      assert_true(opts.input == "tiny.pdf")
    }
    Err(msg) => fail("expected accurate pdf mode to parse: " + msg)
  }

  match parse_cli_options(["--ocr-lang", "eng", "tiny.wav"]) {
    Err(msg) =>
      assert_true(msg.contains("--ocr-lang cannot be used with audio input"))
    Ok(_) => fail("expected audio --ocr-lang to fail")
  }

  match parse_cli_options(["--audio-lang", "eng", "tiny.txt"]) {
    Err(msg) => assert_true(msg.contains("--audio-lang requires audio input"))
    Ok(_) => fail("expected non-audio --audio-lang to fail")
  }

  match
    parse_cli_options(["--audio-lang", "eng", "--ocr-lang", "eng", "tiny.wav"]) {
    Err(msg) =>
      assert_true(msg.contains("cannot combine --ocr-lang and --audio-lang"))
    Ok(_) => fail("expected mixed language flags to fail")
  }
}

///|
test "main cli batch constrains --audio-lang to explicit audio formats" {
  match parse_batch_cli_options(["--audio-lang", "eng", "inputs", "out"], 0) {
    Err(msg) =>
      assert_true(msg.contains("batch --audio-lang requires explicit --format"))
    Ok(_) => fail("expected batch --audio-lang without explicit format to fail")
  }

  match
    parse_batch_cli_options(
      ["--format", "wav", "--audio-lang", "eng", "inputs", "out"],
      0,
    ) {
    Ok((opts, out_dir)) => {
      assert_true(opts.audio_options.language == Some("eng"))
      assert_eq(out_dir, "out")
    }
    Err(msg) =>
      fail("expected batch audio format with --audio-lang to parse: " + msg)
  }
}

///|
test "main cli parses provenance output flag" {
  match parse_cli_options(["--provenance-out", "trace.json", "tiny.txt"]) {
    Ok(opts) => {
      assert_true(opts.provenance_output == Some("trace.json"))
      assert_eq(opts.input, "tiny.txt")
      assert_true(opts.output == None)
    }
    Err(msg) => fail("expected --provenance-out to parse: " + msg)
  }
}

///|
test "main cli batch rejects provenance output flag" {
  match
    parse_batch_cli_options(
      ["--provenance-out", "trace.json", "inputs", "out"],
      0,
    ) {
    Err(msg) =>
      assert_true(msg.contains("batch does not support --provenance-out"))
    Ok(_) => fail("expected batch --provenance-out to fail")
  }
}

///|
test "main cli first user arg helper handles executable-prefixed argv" {
  assert_true(first_user_cli_arg(["cli.exe"]) == None)
  assert_true(first_user_cli_arg(["cli.exe", "help"]) == Some("help"))
  assert_true(first_user_cli_arg(["cli.exe", "balance"]) == Some("balance"))
}

///|
test "main cli can parse options from either implicit or explicit mode position" {
  match parse_cli_options_from_index(["demo.txt"], 0) {
    Ok(opts) => {
      assert_eq(opts.input, "demo.txt")
      assert_true(opts.output == None)
      assert_true(opts.convert_mode == @convert.ConvertMode::Balanced)
    }
    Err(msg) => fail("expected implicit convert argv to parse: " + msg)
  }

  match
    parse_cli_options_from_index(
      ["demo.txt", "out.md"],
      0,
      mode=@convert.ConvertMode::Accurate,
    ) {
    Ok(opts) => {
      assert_eq(opts.input, "demo.txt")
      assert_true(opts.output == Some("out.md"))
      assert_true(opts.convert_mode == @convert.ConvertMode::Accurate)
    }
    Err(msg) => fail("expected explicit accurate mode argv to parse: " + msg)
  }
}

///|
test "main cli rejects removed subcommands with migration guidance" {
  match parse_cli_options(["normal", "demo.txt"]) {
    Err(msg) => assert_true(msg.contains("subcommand `normal` was removed"))
    Ok(_) => fail("expected normal subcommand to fail")
  }

  match parse_cli_options(["convert", "demo.txt"]) {
    Err(msg) => assert_true(msg.contains("subcommand `convert` was removed"))
    Ok(_) => fail("expected convert subcommand to fail")
  }

  match parse_batch_cli_options(["normal", "inputs", "out"], 0) {
    Err(msg) =>
      assert_true(msg.contains("mode `normal` was removed after `batch`"))
    Ok(_) => fail("expected batch normal mode to fail")
  }
}
