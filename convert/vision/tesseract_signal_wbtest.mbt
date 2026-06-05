///|
test "tesseract signal options default executable stays tesseract" {
  let options = make_tesseract_signal_options()
  assert_eq(options.executable, "tesseract")
  assert_eq(options.lang, "")
  assert_eq(options.psm, "")
  assert_eq(options.oem, "")
}

///|
test "tesseract signal command includes input path output base and tsv arg" {
  let options = make_tesseract_signal_options()
  let plan = build_tesseract_tsv_command(
    "samples/fixtures/ocr/tiny_ocr_sample.png", "/tmp/ocr-output", options,
  )
  assert_eq(plan.executable, "tesseract")
  assert_eq(plan.output_base, "/tmp/ocr-output")
  assert_eq(plan.argv[0], "samples/fixtures/ocr/tiny_ocr_sample.png")
  assert_eq(plan.argv[1], "/tmp/ocr-output")
  assert_eq(plan.argv[2], "tsv")
}

///|
test "tesseract signal command includes lang psm and oem when nonempty" {
  let options = make_tesseract_signal_options(
    executable="custom-tesseract",
    lang="eng+chi_sim",
    psm="6",
    oem="1",
  )
  let plan = build_tesseract_tsv_command(
    "input with spaces.png", "output base with spaces", options,
  )
  assert_eq(plan.executable, "custom-tesseract")
  assert_eq(plan.argv.length(), 9)
  assert_eq(plan.argv[0], "input with spaces.png")
  assert_eq(plan.argv[1], "output base with spaces")
  assert_eq(plan.argv[2], "-l")
  assert_eq(plan.argv[3], "eng+chi_sim")
  assert_eq(plan.argv[4], "--psm")
  assert_eq(plan.argv[5], "6")
  assert_eq(plan.argv[6], "--oem")
  assert_eq(plan.argv[7], "1")
  assert_eq(plan.argv[8], "tsv")
}

///|
test "tesseract signal command omits empty lang psm and oem" {
  let options = make_tesseract_signal_options(
    executable="  ",
    lang="  ",
    psm="",
    oem="",
  )
  let plan = build_tesseract_tsv_command("input.png", "out/base", options)
  assert_eq(plan.executable, "tesseract")
  assert_eq(plan.argv.length(), 3)
  assert_eq(plan.argv[0], "input.png")
  assert_eq(plan.argv[1], "out/base")
  assert_eq(plan.argv[2], "tsv")
}

///|
test "tesseract signal parser composition reuses page parser" {
  let tsv = "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t40\t88\tMoonBit\n" +
    "5\t1\t1\t1\t1\t2\t50\t20\t25\t40\t90\tOCR\n"
  let page = expect_signal_page(parse_tesseract_tsv_signal(tsv, "future-tsv"))
  assert_eq(page.provider, "future-tsv")
  assert_eq(page.source_kind, "tesseract-tsv")
  assert_eq(page.lines.length(), 1)
  assert_eq(page.lines[0].text, "MoonBit OCR")
  assert_eq(page.words.length(), 2)
  assert_eq(page.words[0].text, "MoonBit")
  assert_eq(page.words[1].text, "OCR")
}

///|
async test "tesseract signal runner parses fake executable output" {
  let case_dir = prepare_tesseract_signal_test_dir("runner success with spaces")
  let script_path = case_dir + "/fake tesseract.sh"
  write_fake_tesseract_script(
    script_path,
    "#!/usr/bin/env bash\n" +
    "set -eu\n" +
    "input_path=\"$1\"\n" +
    "output_base=\"$2\"\n" +
    "shift 2\n" +
    "lang=\"\"\n" +
    "psm=\"\"\n" +
    "oem=\"\"\n" +
    "last_arg=\"\"\n" +
    "while [ \"$#\" -gt 0 ]; do\n" +
    "  case \"$1\" in\n" +
    "    -l)\n" +
    "      lang=\"$2\"\n" +
    "      shift 2\n" +
    "      ;;\n" +
    "    --psm)\n" +
    "      psm=\"$2\"\n" +
    "      shift 2\n" +
    "      ;;\n" +
    "    --oem)\n" +
    "      oem=\"$2\"\n" +
    "      shift 2\n" +
    "      ;;\n" +
    "    *)\n" +
    "      last_arg=\"$1\"\n" +
    "      shift\n" +
    "      ;;\n" +
    "  esac\n" +
    "done\n" +
    "mkdir -p \"$(dirname \"$output_base\")\"\n" +
    "cat > \"${output_base}.args\" <<EOF\n" +
    "INPUT=$input_path\n" +
    "OUTPUT_BASE=$output_base\n" +
    "LANG=$lang\n" +
    "PSM=$psm\n" +
    "OEM=$oem\n" +
    "LAST=$last_arg\n" +
    "EOF\n" +
    "cat > \"${output_base}.tsv\" <<'EOF'\n" +
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n" +
    "5\t1\t1\t1\t1\t1\t10\t20\t30\t40\t91\tMoonBit\n" +
    "5\t1\t1\t1\t1\t2\t50\t20\t25\t40\t87\tOCR\n" +
    "EOF\n",
  )
  let input_path = case_dir + "/input with spaces.png"
  let output_base = case_dir + "/nested output/result file"
  let page = expect_signal_runner_page(
    run_tesseract_tsv_signal(
      input_path,
      output_base,
      make_tesseract_signal_options(
        executable=script_path,
        lang="eng+chi_sim",
        psm="6",
        oem="1",
      ),
    ),
  )
  assert_eq(page.provider, "tesseract-tsv")
  assert_eq(page.source_kind, "tesseract-tsv")
  assert_eq(page.lines.length(), 1)
  assert_eq(page.lines[0].text, "MoonBit OCR")
  let args_log = @fs.read_file_to_string(output_base + ".args", encoding="utf8") catch {
    _ => panic()
  }
  assert_true(args_log.contains("INPUT=" + input_path))
  assert_true(args_log.contains("OUTPUT_BASE=" + output_base))
  assert_true(args_log.contains("LANG=eng+chi_sim"))
  assert_true(args_log.contains("PSM=6"))
  assert_true(args_log.contains("OEM=1"))
  assert_true(args_log.contains("LAST=tsv"))
}

///|
async test "tesseract signal runner reports missing tsv output" {
  let case_dir = prepare_tesseract_signal_test_dir("runner missing output")
  let script_path = case_dir + "/fake_missing_output.sh"
  write_fake_tesseract_script(
    script_path,
    "#!/usr/bin/env bash\n" +
    "set -eu\n" +
    "output_base=\"$2\"\n" +
    "mkdir -p \"$(dirname \"$output_base\")\"\n",
  )
  let err = expect_signal_runner_error(
    run_tesseract_tsv_signal(
      case_dir + "/input.png",
      case_dir + "/out/missing",
      make_tesseract_signal_options(executable=script_path),
    ),
  )
  assert_true(err.kind == TesseractSignalErrorKind::MissingTsvOutput)
  assert_true(err.message.contains("expected tesseract TSV output"))
}

///|
async test "tesseract signal runner reports command failure with exit code" {
  let case_dir = prepare_tesseract_signal_test_dir("runner command failed")
  let script_path = case_dir + "/fake_failure.sh"
  write_fake_tesseract_script(
    script_path,
    "#!/usr/bin/env bash\n" + "echo \"simulated failure\" >&2\n" + "exit 7\n",
  )
  let err = expect_signal_runner_error(
    run_tesseract_tsv_signal(
      case_dir + "/input.png",
      case_dir + "/out/failure",
      make_tesseract_signal_options(executable=script_path),
    ),
  )
  assert_true(err.kind == TesseractSignalErrorKind::CommandFailed)
  assert_true(err.message.contains("simulated failure"))
  match err.exit_code {
    Some(code) => assert_eq(code, 7)
    None => panic()
  }
}

///|
async test "tesseract signal runner reports invalid tsv output as parse failure" {
  let case_dir = prepare_tesseract_signal_test_dir("runner invalid tsv")
  let script_path = case_dir + "/fake_invalid_tsv.sh"
  write_fake_tesseract_script(
    script_path,
    "#!/usr/bin/env bash\n" +
    "set -eu\n" +
    "output_base=\"$2\"\n" +
    "mkdir -p \"$(dirname \"$output_base\")\"\n" +
    "cat > \"${output_base}.tsv\" <<'EOF'\n" +
    "level\tpage_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\n" +
    "5\t1\t1\t1\t10\t20\t30\t40\t80\n" +
    "EOF\n",
  )
  let err = expect_signal_runner_error(
    run_tesseract_tsv_signal(
      case_dir + "/input.png",
      case_dir + "/out/invalid",
      make_tesseract_signal_options(executable=script_path),
    ),
  )
  assert_true(err.kind == TesseractSignalErrorKind::TsvParseFailed)
  assert_true(err.message.contains("text"))
}

///|
async test "tesseract signal runner rejects blank output base" {
  let err = expect_signal_runner_error(
    run_tesseract_tsv_signal(
      "input.png",
      "   ",
      make_tesseract_signal_options(executable="fake"),
    ),
  )
  assert_true(err.kind == TesseractSignalErrorKind::InvalidOutputBase)
  assert_true(err.message.contains("must not be blank"))
}

///|
fn expect_signal_page(
  result : Result[OcrPageModel, TesseractTsvParseError],
) -> OcrPageModel {
  match result {
    Ok(page) => page
    Err(_) => panic()
  }
}

///|
fn expect_signal_runner_page(
  result : Result[OcrPageModel, TesseractSignalError],
) -> OcrPageModel {
  match result {
    Ok(page) => page
    Err(_) => panic()
  }
}

///|
fn expect_signal_runner_error(
  result : Result[OcrPageModel, TesseractSignalError],
) -> TesseractSignalError {
  match result {
    Ok(_) => panic()
    Err(err) => err
  }
}

///|
fn prepare_tesseract_signal_test_dir(case_name : String) -> String {
  let root = ".tmp/convert-vision-tesseract-signal/" + case_name
  clear_tesseract_signal_test_dir(root)
  ensure_tesseract_signal_test_dir(root)
  root
}

///|
fn clear_tesseract_signal_test_dir(path : String) -> Unit {
  if !@fs.path_exists(path) {
    return
  }
  let entries = @fs.read_dir(path) catch { _ => panic() }
  for name in entries {
    let child = path + "/" + name
    let is_dir = @fs.is_dir(child) catch { _ => panic() }
    if is_dir {
      clear_tesseract_signal_test_dir(child)
    } else {
      let is_file = @fs.is_file(child) catch { _ => panic() }
      if is_file {
        ignore(@fs.remove_file(child) catch { _ => panic() })
      }
    }
  }
  ignore(@fs.remove_dir(path) catch { _ => panic() })
}

///|
fn ensure_tesseract_signal_test_dir(path : String) -> Unit {
  let current_parts : Array[String] = []
  for raw_part in path.split("/") {
    let part = raw_part.trim().to_owned()
    if part == "" || part == "." {
      continue
    }
    current_parts.push(part)
    let current = current_parts.join("/")
    if !@fs.path_exists(current) {
      ignore(@fs.create_dir(current) catch { _ => panic() })
    }
  }
}

///|
async fn write_fake_tesseract_script(path : String, body : String) -> Unit {
  ignore(
    @fs.write_string_to_file(path, body, encoding="utf8") catch {
      _ => panic()
    },
  )
  let chmod_result = @process.collect_output("/bin/chmod", ["+x", path]) catch {
    _ => panic()
  }
  match chmod_result {
    (0, _stdout, _stderr) => ()
    (_code, _stdout, _stderr) => panic()
  }
}
