///|
async test "batch_v1 writes isolated doc roots and summary" {
  let root = test_tmp_root() + "/batch-basic"
  recreate_clean_dir(root)

  let input_dir = root + "/input"
  let output_dir = root + "/out"
  @fs.create_dir(input_dir) catch {
    e => fail("create input dir failed: " + e.to_string())
  }

  write_utf8_text(input_dir + "/a.txt", "alpha\n")
  write_utf8_text(input_dir + "/b.md", "# beta\n")
  write_utf8_text(input_dir + "/c.json", "{\"k\":\"v\"}\n")
  @fs.create_dir(input_dir + "/nested") catch {
    e => fail("create nested dir failed: " + e.to_string())
  }
  write_utf8_text(input_dir + "/nested/ignored.txt", "ignored\n")

  let result = @clisup.run_batch(input_dir, output_dir, false)
  let result = match result {
    Ok(r) => r
    Err(msg) => fail("batch should succeed: " + msg)
  }

  assert_eq(result.total_count, 4)
  assert_eq(result.success_count, 3)
  assert_eq(result.failure_count, 0)
  assert_eq(result.unsupported_count, 0)
  assert_eq(result.skipped_directory_count, 1)
  assert_true(result.had_error == false)

  assert_true(@fs.path_exists(output_dir + "/001-b/b.md"))
  assert_true(@fs.path_exists(output_dir + "/002-a/a.md"))
  assert_true(@fs.path_exists(output_dir + "/003-c/c.md"))
  assert_true(!@fs.path_exists(output_dir + "/002-a/metadata/a.metadata.json"))
  assert_true(@fs.path_exists(output_dir + "/batch-summary.tsv"))

  let summary = read_utf8_text(output_dir + "/batch-summary.tsv")
  assert_contains(
    summary, "index\tinput_path\toutput_md\tformat\tstatus\telapsed_ms\terror",
  )
  assert_contains(
    summary,
    "1\t" + input_dir + "/b.md\t" + output_dir + "/001-b/b.md\tmarkdown\tok\t",
  )
  assert_contains(
    summary,
    "4\t" + input_dir + "/nested\t\t\tskipped_directory\t0\t",
  )
}

///|
async test "batch_v1 supports metadata and stem collisions" {
  let root = test_tmp_root() + "/batch-metadata"
  recreate_clean_dir(root)

  let input_dir = root + "/input"
  let output_dir = root + "/out"
  @fs.create_dir(input_dir) catch {
    e => fail("create input dir failed: " + e.to_string())
  }

  write_utf8_text(input_dir + "/same.txt", "same txt\n")
  write_utf8_text(input_dir + "/same.md", "# same md\n")

  let result = @clisup.run_batch(input_dir, output_dir, true)
  let result = match result {
    Ok(r) => r
    Err(msg) => fail("batch should succeed: " + msg)
  }

  assert_eq(result.total_count, 2)
  assert_eq(result.success_count, 2)
  assert_true(result.had_error == false)

  assert_true(@fs.path_exists(output_dir + "/001-same/same.md"))
  assert_true(
    @fs.path_exists(output_dir + "/001-same/metadata/same.metadata.json"),
  )
  assert_true(@fs.path_exists(output_dir + "/002-same/same.md"))
  assert_true(
    @fs.path_exists(output_dir + "/002-same/metadata/same.metadata.json"),
  )
}

///|
async test "batch_v1 records unsupported files as failures" {
  let root = test_tmp_root() + "/batch-unsupported"
  recreate_clean_dir(root)

  let input_dir = root + "/input"
  let output_dir = root + "/out"
  @fs.create_dir(input_dir) catch {
    e => fail("create input dir failed: " + e.to_string())
  }

  write_utf8_text(input_dir + "/bad.bin", "not supported\n")

  let result = @clisup.run_batch(input_dir, output_dir, false)
  let result = match result {
    Ok(r) => r
    Err(msg) => fail("batch should still write summary: " + msg)
  }

  assert_eq(result.total_count, 1)
  assert_eq(result.success_count, 0)
  assert_eq(result.failure_count, 1)
  assert_eq(result.unsupported_count, 1)
  assert_true(result.had_error)

  let summary = read_utf8_text(output_dir + "/batch-summary.tsv")
  assert_contains(summary, "\tbin\tunsupported\t")
  assert_contains(summary, "Unsupported file type: bin")
}

///|
test "ocr cli parser accepts rebuild stub positional args" {
  let parser = @clisup.new_cli_parser()
  let value = @clap.SimpleValue::new("markitdown-mb")
  let help = parser.parse(value, ["ocr", "page.png", "out.txt"]) catch {
    e => fail("OCR parser should accept positional args: " + e.to_string())
  }
  assert_true(help == None)
  match value.subcmd {
    Some(sub) => {
      assert_eq(sub.name, "ocr")
      assert_true(sub.positional_args == ["page.png", "out.txt"])
    }
    None => fail("expected ocr subcommand")
  }
}

///|
test "ocr cli parser keeps missing optional rebuild args absent" {
  let parser = @clisup.new_cli_parser()
  let value = @clap.SimpleValue::new("markitdown-mb")
  let help = parser.parse(value, ["ocr", "page.png", "out.txt"]) catch {
    e =>
      fail(
        "OCR parser should accept missing optional rebuild args: " +
        e.to_string(),
      )
  }
  assert_true(help == None)
  match value.subcmd {
    Some(sub) => {
      assert_eq(sub.name, "ocr")
      assert_true(sub.positional_args == ["page.png", "out.txt"])
    }
    None => fail("expected ocr subcommand")
  }
}

///|
test "debug layout assist eval parser accepts missing optional split" {
  let parser = @clisup.new_cli_parser()
  let value = @clap.SimpleValue::new("markitdown-mb")
  let help = parser.parse(value, ["debug", "layout-assist-eval"]) catch {
    e =>
      fail(
        "debug layout-assist eval parser should accept missing split: " +
        e.to_string(),
      )
  }
  assert_true(help == None)
  match value.subcmd {
    Some(sub) => {
      assert_eq(sub.name, "debug")
      assert_true(sub.positional_args == ["layout-assist-eval"])
      let split : String? = @clap.SimpleValue::get_option(sub, "split") catch {
        e => fail("split option lookup failed: " + e.to_string())
      }
      assert_true(split == None)
    }
    None => fail("expected debug subcommand")
  }
}

///|
fn test_tmp_root() -> String {
  match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(path) => path + "/cli-test"
    None => ".tmp/cli-test"
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
  ensure_dir_tree(path)
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn read_utf8_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => fail("utf8 decode failed")
  }
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }

  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }

    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }

  ignore(flush(part, current))
}

///|
fn assert_contains(haystack : String, needle : String) -> Unit raise {
  if !haystack.contains(needle) {
    fail("expected text to contain: " + needle + "\nactual:\n" + haystack)
  }
}
