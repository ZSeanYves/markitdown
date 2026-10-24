///|
async test "None JSONL pull scan rejects nonblank content beyond a truncated blank prefix" {
  for suffix in ["0", "\"😀\""] {
    let source = @input.input_from_text_with_format(
      " ".repeat(4) + suffix + "\n",
      "prefix.jsonl",
      Some(Jsonl),
    )
    let context = truncated_blank_context(None, line_chars=4)
    let result = scan_line_json_source("jsonl", source, context)
    assert_true(
      result is Err(RecordLimit(_)),
      msg="overlong nonblank records must be explicit limit errors",
    )
  }
}

///|
async test "None JSONL record pull uses whole-line blank fact before the existing hard line limit" {
  for suffix in ["0", "\"😀\""] {
    let source = @input.input_from_text_with_format(
      " ".repeat(4) + suffix,
      "prefix.jsonl",
      Some(Jsonl),
    )
    let context = truncated_blank_context(None, line_chars=4)
    let reader = open_line_json_reader(source, context).unwrap()
    defer (reader.close)()
    let count = Ref(0)
    let result = next_line_json_record(reader, "jsonl", context, count)
    assert_true(result is Err(_))
    assert_eq(count.val, 0)
    assert_eq(result.unwrap_err(), "jsonl record exceeds max_line_chars")
  }
}

///|
async test "None JSONL pull preserves genuine blanks optional prefixes and row cap" {
  for
    prefix in [" ".repeat(9) + "\n", "\u{001E}\u{FEFF}" + " ".repeat(9) + "\n"] {
    let source = @input.input_from_text_with_format(
      prefix + "0\n",
      "blank.jsonl",
      Some(Jsonl),
    )
    let context = truncated_blank_context(None, line_chars=4)
    let scan = scan_line_json_source("jsonl", source, context).unwrap()
    assert_eq(scan.record_count, 1)
    assert_eq(scan.blank_line_count, 1)
    let reader = open_line_json_reader(source, context).unwrap()
    defer (reader.close)()
    let count = Ref(0)
    assert_true(
      next_line_json_record(reader, "jsonl", context, count).unwrap() is Some(_),
    )
    assert_eq(count.val, 1)
  }
  let source = @input.input_from_text_with_format(
    "0\n" + " ".repeat(4) + "1\n",
    "capped.jsonl",
    Some(Jsonl),
  )
  let context = truncated_blank_context(None, rows=1, line_chars=4)
  let scan = scan_line_json_source("jsonl", source, context).unwrap()
  assert_eq(scan.record_count, 1)
  assert_eq(scan.blank_line_count, 0)
}
