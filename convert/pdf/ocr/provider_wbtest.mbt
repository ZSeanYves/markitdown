///|
test "ocr provider noop info is stable" {
  let info = noop_ocr_provider_info()
  assert_eq(info.name, "noop")
  assert_true(info.kind == OcrProviderKind::Noop)
  assert_true(info.available)
  assert_true(!info.probed)
}

///|
test "ocr provider descriptors include known external candidates" {
  let infos = list_known_ocr_providers()
  let names : Array[String] = []
  for info in infos {
    names.push(info.name)
  }
  assert_true(array_contains_string(names, "tesseract-cli"))
  assert_true(array_contains_string(names, "ocrmypdf-cli"))
  assert_true(array_contains_string(names, "paddleocr"))
}

///|
test "ocr provider result structs remain constructible for future providers" {
  let page : OcrPageResult = {
    page_index: 0,
    text: "sample",
    confidence: Some(0.9),
    language: Some("en"),
    warnings: [],
  }
  let doc : OcrDocumentResult = {
    provider: noop_ocr_provider_info(),
    pages: [page],
    warnings: [],
  }
  assert_eq(doc.pages.length(), 1)
  assert_eq(doc.pages[0].text, "sample")
}

///|
test "ocr provider list stays lazy by default" {
  let infos = list_known_ocr_providers()
  for info in infos {
    if info.name == "noop" {
      continue
    }
    assert_true(!info.probed)
    assert_true(!info.available)
    assert_true(info.unavailable_reason != None)
  }
}

///|
test "ocr provider noop recognize returns not implemented" {
  let result = recognize_pdf_with_ocr_provider(
    "noop",
    "sample.pdf",
    default_ocr_options(),
  )
  match result {
    Ok(_) => fail("expected noop OCR provider to fail closed")
    Err(err) => assert_true(err.kind == OcrProviderErrorKind::NotImplemented)
  }
}

///|
async test "ocr provider unknown page recognize returns expected error" {
  let result = recognize_page_with_ocr_provider(
    "missing-provider",
    0,
    "page.png",
    default_ocr_options(),
  )
  match result {
    Ok(_) => fail("expected unknown provider to fail")
    Err(err) => assert_true(err.kind == OcrProviderErrorKind::UnknownProvider)
  }
}

///|
test "ocr provider tesseract language normalization is conservative" {
  assert_eq(normalized_ocr_languages([]), "eng")
  assert_eq(normalized_ocr_languages(["eng", "chi_sim"]), "eng+chi_sim")
  assert_eq(normalized_ocr_languages(["  eng  ", "", "chi-sim"]), "eng+chi-sim")
}

///|
test "ocr provider tesseract args avoid shell concatenation" {
  let args = build_tesseract_page_args("sample page.png", "eng+chi_sim")
  assert_eq(args.length(), 4)
  assert_eq(args[0], "sample page.png")
  assert_eq(args[1], "stdout")
  assert_eq(args[2], "-l")
  assert_eq(args[3], "eng+chi_sim")
}

///|
async test "ocr provider tesseract fake command can return page text" {
  let base = test_tmp_root()
  ensure_test_dir(base)
  let root = base + "/ocr-provider"
  recreate_clean_dir(root)
  let script = root + "/fake_tesseract.sh"
  let image = root + "/page.png"
  let captured = root + "/captured.txt"
  @fs.write_string_to_file(
    script,
    "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"" +
    captured +
    "\"\nif [ \"$1\" = \"--version\" ]; then\n  echo 'tesseract 5.0.0'\n  exit 0\nfi\necho 'Fake OCR text'\necho 'warning from fake tesseract' 1>&2\n",
    encoding="utf8",
  ) catch {
    _ => fail("failed to write fake tesseract script")
  }
  @fs.write_string_to_file(image, "fake image", encoding="utf8") catch {
    _ => fail("failed to write fake image")
  }
  let chmod = @proc.collect_output("chmod", ["+x", script]) catch {
    _ => fail("failed to chmod fake tesseract script")
  }
  let (chmod_status, _, _) = chmod
  if chmod_status != 0 {
    fail("chmod failed for fake tesseract script")
  }

  let result = run_tesseract_page_command(
    script,
    build_tesseract_page_args(image, "eng+chi_sim"),
    7,
    "eng+chi_sim",
  )
  match result {
    Ok(page) => {
      assert_eq(page.page_index, 7)
      assert_eq(page.text, "Fake OCR text\n")
      match page.language {
        Some(lang) => assert_eq(lang, "eng+chi_sim")
        None => fail("expected OCR language to be present")
      }
      assert_eq(page.warnings.length(), 1)
      assert_eq(page.warnings[0], "warning from fake tesseract")
    }
    Err(err) => fail("expected fake tesseract to succeed: " + err.message)
  }

  let captured_args = @fs.read_file_to_string(captured, encoding="utf8") catch {
    _ => fail("failed to read captured tesseract args")
  }
  assert_true(captured_args.contains(image))
  assert_true(captured_args.contains("stdout"))
  assert_true(captured_args.contains("-l"))
  assert_true(captured_args.contains("eng+chi_sim"))
}

///|
test "ocr provider tesseract pdf recognize remains not implemented" {
  let result = recognize_pdf_with_ocr_provider(
    "tesseract-cli",
    "sample.pdf",
    default_ocr_options(),
  )
  match result {
    Ok(_) => fail("expected tesseract pdf OCR to remain unimplemented")
    Err(err) => assert_true(err.kind == OcrProviderErrorKind::NotImplemented)
  }
}

///|
async test "ocr provider explicit noop probe is local and stable" {
  let probed = probe_known_ocr_provider("noop")
  match probed {
    Some(info) => {
      assert_true(info.probed)
      assert_true(info.available)
      assert_eq(info.name, "noop")
    }
    None => fail("expected noop provider probe result")
  }
}

///|
async test "ocr provider tesseract probe remains skip safe" {
  let probed = probe_known_ocr_provider("tesseract-cli")
  match probed {
    Some(info) => {
      assert_eq(info.name, "tesseract-cli")
      assert_true(info.probed)
      if info.available {
        assert_true(info.version != None)
      } else {
        assert_true(info.unavailable_reason != None)
      }
    }
    None => fail("expected tesseract probe result")
  }
}

///|
fn array_contains_string(xs : Array[String], needle : String) -> Bool {
  for x in xs {
    if x == needle {
      return true
    }
  }
  false
}

///|
fn test_tmp_root() -> String {
  match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) =>
      if dir.trim() == "" {
        ".tmp/ocr-provider-test"
      } else {
        dir + "/ocr-provider-test"
      }
    None => ".tmp/ocr-provider-test"
  }
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
  ensure_test_dir(path)
}

///|
fn ensure_test_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path) catch {
      e => fail("failed to create test dir: " + path + ": " + e.to_string())
    }
  }
}
