///|
test "build and read name tree" {
  let pdf = @pdf.Pdf::empty()
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("A", Integer(1)),
    ("B", Integer(2)),
    ("C", Integer(3)),
  ]
  let tree = tree_ctx.build_name_tree(false, entries)
  let read = tree_ctx.read_name_tree(tree)
  assert_eq(read.length(), 3)
  assert_eq(read[0].0, "A")
  assert_eq(read[1].0, "B")
  assert_eq(read[2].0, "C")
}

///|
test "build and read number tree" {
  let pdf = @pdf.Pdf::empty()
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("1", Name(@pdf.PdfName::of_string("/One"))),
    ("3", Name(@pdf.PdfName::of_string("/Three"))),
    ("2", Name(@pdf.PdfName::of_string("/Two"))),
  ]
  let tree = tree_ctx.build_name_tree(true, entries)
  let read = tree_ctx.read_number_tree(tree)
  assert_eq(read.length(), 3)
  assert_eq(read[0].0, "1")
  assert_eq(read[1].0, "2")
  assert_eq(read[2].0, "3")
}

///|
test "build_name_tree handles empty input" {
  let pdf = @pdf.Pdf::empty()
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  let name_tree = tree_ctx.build_name_tree(false, [])
  match pdf.lookup_direct("/Names", name_tree) {
    Some(Array(items)) => assert_eq(items.length(), 0)
    _ => fail("expected empty /Names")
  }
  let num_tree = tree_ctx.build_name_tree(true, [])
  match pdf.lookup_direct("/Nums", num_tree) {
    Some(Array(items)) => assert_eq(items.length(), 0)
    _ => fail("expected empty /Nums")
  }
}

///|
test "build_name_tree uses kids for large inputs" {
  let pdf = @pdf.Pdf::empty()
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  let entries : Array[(String, @pdf.PdfObject)] = Array::makei(11, i => (
    "Key\{i}",
    Integer(i),
  ))
  let tree = tree_ctx.build_name_tree(false, entries)
  match pdf.lookup_direct("/Kids", tree) {
    Some(Array(kids)) => assert_true(kids.length() > 0)
    _ => fail("expected /Kids on large tree")
  }
  let read = tree_ctx.read_name_tree(tree)
  assert_eq(read.length(), 11)
  assert_eq(read[0].0, "Key0")
  let mut found = false
  for pair in read {
    if pair.0 == "Key10" {
      found = true
    }
  }
  assert_true(found)
}

///|
test "read_name_tree skips malformed keys" {
  let pdf = @pdf.Pdf::empty()
  let tree : @pdf.PdfObject = Dictionary([
    (
      "/Names",
      Array([
        Integer(1),
        Name(@pdf.PdfName::of_string("/One")),
        String("B"),
        Name(@pdf.PdfName::of_string("/Two")),
      ]),
    ),
  ])
  let read = @pdfe.with_logger(_ => (), fn() {
    @pdftree.PdfTree::new(pdf).read_name_tree(tree)
  })
  assert_eq(read.length(), 0)
}

///|
test "read_number_tree handles duplicate keys" {
  let pdf = @pdf.Pdf::empty()
  let tree : @pdf.PdfObject = Dictionary([
    (
      "/Nums",
      Array([
        Integer(1),
        Name(@pdf.PdfName::of_string("/One")),
        Integer(1),
        Name(@pdf.PdfName::of_string("/Uno")),
        Integer(2),
        Name(@pdf.PdfName::of_string("/Two")),
      ]),
    ),
  ])
  let read = @pdftree.PdfTree::new(pdf).read_number_tree(tree)
  assert_eq(read.length(), 2)
  let mut found = false
  for pair in read {
    if pair.0 == "1" {
      match (pair.1 : @pdf.PdfObject) {
        Name(name) =>
          if name.equal_string_bytes("/One") || name.equal_string_bytes("/Uno") {
            found = true
          }
        _ => ()
      }
    }
  }
  assert_true(found)
}

///|
test "build_number_tree parses non-integer keys as 0" {
  let pdf = @pdf.Pdf::empty()
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("x", Name(@pdf.PdfName::of_string("/X"))),
    ("2", Name(@pdf.PdfName::of_string("/Two"))),
  ]
  let tree = tree_ctx.build_name_tree(true, entries)
  let read = tree_ctx.read_number_tree(tree)
  assert_eq(read.length(), 2)
  assert_eq(read[0].0, "0")
  assert_eq(read[1].0, "2")
}

///|
test "read_number_tree returns empty on non-integer keys" {
  let pdf = @pdf.Pdf::empty()
  let tree : @pdf.PdfObject = Dictionary([
    (
      "/Nums",
      Array([
        String("x"),
        Name(@pdf.PdfName::of_string("/X")),
        Integer(2),
        Name(@pdf.PdfName::of_string("/Two")),
      ]),
    ),
  ])
  let read = @pdfe.with_logger(_ => (), fn() {
    @pdftree.PdfTree::new(pdf).read_number_tree(tree)
  })
  assert_eq(read.length(), 0)
}

///|
test "merge name trees combines entries" {
  let pdf = @pdf.Pdf::empty()
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  let tree1 = tree_ctx.build_name_tree(false, [
    ("A", Integer(1)),
    ("C", Integer(3)),
  ])
  let tree2 = tree_ctx.build_name_tree(false, [("B", Integer(2))])
  let merged = tree_ctx.merge_name_trees_no_clash([tree1, tree2])
  let read = tree_ctx.read_name_tree(merged)
  assert_eq(read.length(), 3)
  assert_eq(read[0].0, "A")
  assert_eq(read[1].0, "B")
  assert_eq(read[2].0, "C")
}
