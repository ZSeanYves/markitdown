///|
fn yaml_logical_test_account(cap : Int64) -> @budget.Budget {
  @budget.Budget::new(
    @budget.BudgetLimits::new(
      Enforced,
      inflate_bytes=Some(1048576L),
      parse_work=Some(cap),
      output_utf8_bytes=Some(1048576L),
      source_metadata_bytes=Some(1048576L),
      rag_metadata_bytes=Some(1048576L),
      read_traffic_bytes=Some(1048576L),
      cache_bytes=Some(1048576L),
      working_bytes=Some(1048576L),
      temporary_bytes=Some(1048576L),
      ir_bytes=Some(1048576L),
    ).unwrap(),
  )
}

///|
async test "YAML shared alias graph admits logical work before structure expansion" {
  let text = "a: &a [x, x]\nb: &b [*a, *a]\nc: &c [*b, *b]\nroot: *c\n"
  let account = yaml_logical_test_account(20L)
  let owner = @input.begin_input_session(
    @input.input_from_text(text),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let prepared = prepare_yaml_document_from_source(owner.source)
  assert_true(prepared is Err(_))
  assert_true(
    @input.input_source_failure(owner.source)
    is Some(
      BudgetFailure(
        LimitExceeded(Cumulative(ParseWork), used=19L, requested=7L, limit=20L)
      )
    ),
  )
}

///|
async test "YAML logical admission accepts its exact expanded-node work bound" {
  let account = yaml_logical_test_account(41L)
  let owner = @input.begin_input_session(
    @input.input_from_text(
      "a: &a [x, x]\nb: &b [*a, *a]\nc: &c [*b, *b]\nroot: *c\n",
    ),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let result = prepare_yaml_document_from_source(owner.source).unwrap()
  assert_true(result.document is Some(_))
  assert_eq(result.inspect.unwrap().node_count, 41)
  assert_eq(account.snapshot().cumulative.parse_work, 41L)
  assert_true(account.failure() is None)
}

///|
async test "YAML merge admissions cover copied members before override and retain precedence" {
  let account = yaml_logical_test_account(11L)
  let owner = @input.begin_input_session(
    @input.input_from_text(
      "a: &a {x: one, y: two}\nb:\n  <<: *a\n  x: override\n",
    ),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let prepared = prepare_yaml_document_from_source(owner.source).unwrap()
  assert_eq(account.snapshot().cumulative.parse_work, 11L)
  let root = prepared.document.unwrap().document.root.unwrap()
  match root {
    Mapping(members) =>
      match members[1].value {
        Mapping(values) => {
          assert_eq(values.map(value => value.key), ["y", "x"])
          assert_true(values[1].value is String("override"))
        }
        _ => fail("expected merged mapping")
      }
    _ => fail("expected mapping root")
  }
}

///|
async test "YAML logical failure stays typed and stops every subsequent source read" {
  let bytes = b"a: &a [x, x]\nb: &b [*a, *a]\nc: &c [*b, *b]\nroot: *c\n"
  let calls = Ref(0)
  let source = @input.input_from_reader(
    @input.make_input_reader(
      fn(offset, length) {
        calls.val += 1
        let start = offset.to_int()
        Ok(bytes[start:(start + length).min(bytes.length())].to_owned())
      },
      size=bytes.length().to_int64(),
    ),
  )
  let account = yaml_logical_test_account(20L)
  let owner = @input.begin_input_session(source, budget=account)
  defer @input.end_input_session(owner)
  assert_true(prepare_yaml_document_from_source(owner.source) is Err(_))
  let first = account.failure()
  let reads = calls.val
  let work = account.snapshot().cumulative.parse_work
  assert_true(prepare_yaml_document_from_source(owner.source) is Err(_))
  assert_true(account.failure() == first)
  assert_eq(account.snapshot().cumulative.parse_work, work)
  assert_eq(calls.val, reads)
}

///|
test "YAML logical footprint overflow rejects a compact shared graph before expansion" {
  let text = StringBuilder()
  text.write_string("n0: &n0 [x, x]\n")
  for level in 1..<64 {
    let current = level.to_string()
    let previous = (level - 1).to_string()
    text.write_string(
      "n" +
      current +
      ": &n" +
      current +
      " [*n" +
      previous +
      ", *n" +
      previous +
      "]\n",
    )
  }
  let parsed = try parse_yaml_document(text.to_string()) |> Ok catch {
    error => Err(error.to_string())
  }
  assert_true(
    parsed is Err(message) &&
    message.contains("logical expansion arithmetic overflow"),
  )
}

///|
async test "YAML documents have local anchors and a shared cumulative logical work account" {
  let document = "a: &a [x, x]\nb: &b [*a, *a]\nc: &c [*b, *b]\nroot: *c\n"
  for cap in [60L, 82L] {
    let account = yaml_logical_test_account(cap)
    let owner = @input.begin_input_session(
      @input.input_from_text("---\n" + document + "---\n" + document),
      budget=account,
    )
    defer @input.end_input_session(owner)
    let result = prepare_yaml_document_from_source(owner.source)
    if cap == 60L {
      assert_true(result is Err(_))
      assert_true(
        account.failure()
        is Some(
          LimitExceeded(
            Cumulative(ParseWork),
            used=60L,
            requested=7L,
            limit=60L
          )
        ),
      )
    } else {
      assert_true(result is Ok(_))
      assert_eq(account.snapshot().cumulative.parse_work, 82L)
    }
  }
}

///|
async test "YAML alias replay never replays historical discarded merge work" {
  for fanout in [2, 4] {
    let text = StringBuilder()
    text.write_string("n0: &n0 {x: small}\n")
    for level in 1..<64 {
      let name = level.to_string()
      let previous = (level - 1).to_string()
      text.write_string("n" + name + ": &n" + name + " {<<: [")
      for item in 0..<fanout {
        if item > 0 {
          text.write_string(", ")
        }
        text.write_string("*n" + previous)
      }
      text.write_string("], x: small}\n")
    }
    let expected_work = 3L + 63L * (3L + 3L * fanout.to_int64())
    let account = yaml_logical_test_account(expected_work)
    let owner = @input.begin_input_session(
      @input.input_from_text(text.to_string()),
      budget=account,
    )
    defer @input.end_input_session(owner)
    let prepared = match prepare_yaml_document_from_source(owner.source) {
      Ok(value) => value
      Err(error) => fail("small retained merge graph was rejected: " + error)
    }
    assert_eq(account.snapshot().cumulative.parse_work, expected_work)
    assert_eq(prepared.inspect.unwrap().node_count, 129)
    match prepared.document.unwrap().document.root.unwrap() {
      Mapping(members) => {
        assert_eq(members.length(), 64)
        for index in 0..<members.length() {
          assert_eq(members[index].key, "n" + index.to_string())
          match members[index].value {
            Mapping(values) => {
              assert_eq(values.length(), 1)
              assert_eq(values[0].key, "x")
              assert_true(values[0].value is String("small"))
            }
            _ => fail("expected a retained mapping")
          }
        }
      }
      _ => fail("expected mapping root")
    }
  }
}
