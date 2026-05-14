///|
async test "ocr cli unsupported provider path returns clear error" {
  let root = test_tmp_root() + "/ocr-provider-missing"
  recreate_clean_dir(root)
  let image = root + "/page.png"
  write_utf8_text(image, "fake image")

  let result = run_ocr_cli(image, None, Some("missing-provider"), None, false) catch {
    e => fail("run_ocr_cli raised: " + e.to_string())
  }
  match result {
    Ok(_) => fail("expected missing OCR provider to fail")
    Err(msg) => assert_contains(msg, "unknown OCR provider")
  }
}

///|
async test "ocr cli unsupported input extension returns stable error" {
  let root = test_tmp_root() + "/ocr-unsupported-input"
  recreate_clean_dir(root)
  let input = root + "/page.bin"
  write_utf8_text(input, "fake non-image")

  let result = run_ocr_cli(
    input,
    None,
    Some("tesseract-cli"),
    Some("eng"),
    false,
  ) catch {
    e => fail("run_ocr_cli raised: " + e.to_string())
  }
  match result {
    Ok(_) => fail("expected unsupported OCR input to fail")
    Err(msg) => {
      assert_contains(
        msg,
        "OCR input type is unsupported for provider mode: " + input,
      )
      assert_contains(
        msg, "supported image inputs: png/jpg/jpeg/tif/tiff/bmp/webp; PDF stays on explicit PDF OCR path",
      )
    }
  }
}

///|
async test "ocr cli image input stays on explicit provider path" {
  let root = test_tmp_root() + "/ocr-image-explicit"
  recreate_clean_dir(root)
  let image = root + "/page.png"
  write_utf8_text(image, "fake image")

  let result = run_ocr_cli(image, None, Some("noop"), None, false) catch {
    e => fail("run_ocr_cli raised: " + e.to_string())
  }
  match result {
    Ok(_) => fail("expected noop OCR provider image path to fail closed")
    Err(msg) =>
      assert_contains(msg, "noop OCR provider does not perform recognition")
  }
}

///|
async test "ocr cli pdf input keeps explicit pdf path for tesseract" {
  let pdf = batch_resolve_sample("samples/main_process/pdf/text_simple.pdf")

  let result = run_ocr_cli(pdf, None, Some("tesseract-cli"), Some("eng"), false) catch {
    e => fail("run_ocr_cli raised: " + e.to_string())
  }
  match result {
    Ok(_) => ()
    Err(msg) =>
      fail(
        "expected tesseract PDF OCR path to preserve explicit PDF OCR mode: " +
        msg,
      )
  }
}

///|
fn test_tmp_root() -> String {
  match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(path) => path + "/cli-ocr-test"
    None => ".tmp/cli-ocr-test"
  }
}

///|
fn batch_resolve_sample(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  ignore(try? remove_dir_recursive(path))
  @clisup.ensure_dir_tree(path)
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn assert_contains(haystack : String, needle : String) -> Unit raise {
  if !haystack.contains(needle) {
    fail("expected text to contain: " + needle + "\nactual:\n" + haystack)
  }
}
