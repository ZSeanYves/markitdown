///|
async fn pptx_custom_review_package(body : Bytes) -> @ox.OoxmlPackage {
  @ox.open_ooxml_package(
    @dzip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      ("docProps/custom.xml", body),
    ]),
  )
}

///|
async fn pptx_custom_review_observe(
  body : String,
) -> (Array[(String, String, String?)], Array[String]) {
  let pkg = pptx_custom_review_package(
    @utf8.encode("<Properties>" + body + "</Properties>"),
  )
  let ctx = new_pptx_source_parse_context(pkg)
  let values = parse_custom_properties(ctx)
  (
    values.map(value => (value.name, value.value, value.value_type)),
    ctx.warnings.map(warning => warning.message),
  )
}

///|
async fn pptx_review_compare_shared_value(body : String) -> Unit {
  let pkg = pptx_custom_review_package(
    @utf8.encode("<Properties>" + body + "</Properties>"),
  )
  let expected = @ox.read_custom_properties(pkg).map(value => {
    (value.name, value.value, value.value_type.map(kind => "vt:" + kind))
  })
  let ctx = new_pptx_source_parse_context(pkg)
  let actual = parse_custom_properties(ctx).map(value => {
    (value.name, value.value, value.value_type)
  })
  assert_eq(actual, expected)
}

///|
async test "PPTX custom candidate quote controls agree with package projection" {
  pptx_review_compare_shared_value(
    "<property note='a>b' name='quote'><vt:lpwstr note='a>b'>good</vt:lpwstr></property>",
  )
}

///|
async test "PPTX custom candidate comments cannot invent property or VT values" {
  pptx_review_compare_shared_value(
    "<!-- <property name='fake'><vt:i4>fake</vt:i4></property> -->" +
    "<property name='actual'><!-- <vt:i4>fake</vt:i4> --><vt:i4>7</vt:i4></property>",
  )
}

///|
async test "PPTX custom candidate shares once decoded character content" {
  pptx_review_compare_shared_value(
    "<property name='A&amp;quot;B'><vt:lpwstr>&amp;lt; &#65; &#x1F600;<![CDATA[<raw>&amp;]]>A<b>B</b>C</vt:lpwstr></property>",
  )
}

///|
async test "PPTX custom candidate vector retains complete structural value" {
  pptx_review_compare_shared_value(
    "<property name='vector'><vt:vector baseType='lpwstr' size='2'><vt:lpwstr>A</vt:lpwstr><vt:lpwstr>B</vt:lpwstr></vt:vector></property>",
  )
}

///|
async test "PPTX custom candidate public source rejects invalid UTF8 after complete selected property" {
  let pkg = pptx_custom_review_package(
    b"<Properties><property name='one'><vt:i4>1</vt:i4></property></Properties>\xff",
  )
  let rejected = try {
    ignore(parse_pptx_source(pkg))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(@dzip.archive_hard_failure(pkg.archive) is Some(_))
}

///|
async test "PPTX custom 255 256 257 258 candidates preserve type order and one warning" {
  for count in [255, 256, 257, 258] {
    let mut body = ""
    for index in 0..<count {
      body += "<property name='n" +
        index.to_string() +
        "'><vt:i4>" +
        index.to_string() +
        "</vt:i4></property>"
    }
    let (values, warnings) = pptx_custom_review_observe(body)
    assert_eq(values.length(), count.min(256))
    assert_eq(
      warnings,
      if count > 256 {
        ["pptx custom document property budget exceeded"]
      } else {
        []
      },
    )
    assert_eq(values[0], ("n0", "0", Some("vt:i4")))
    assert_eq(values.last().unwrap().0, "n" + (count.min(256) - 1).to_string())
  }
}

///|
async test "PPTX custom slots precede name empty and selfclosing filters while comments are excluded" {
  for
    prefix in [
      "<property><vt:i4>1</vt:i4></property>", "<property name='n'><vt:lpwstr> </vt:lpwstr></property>",
      "<property name='n'/>", "<property><property name='nested'><vt:i4>1</vt:i4></property></property>",
    ] {
    let mut body = ""
    for _ in 0..<256 {
      body += prefix
    }
    body += "<property name='tail'><vt:i4>2</vt:i4></property>"
    let (values, warnings) = pptx_custom_review_observe(body)
    assert_eq(values.length(), 0)
    assert_eq(warnings, ["pptx custom document property budget exceeded"])
  }
  let mut body = ""
  for _ in 0..<256 {
    body += "<!-- <property name='fake'><vt:i4>1</vt:i4></property> -->"
  }
  body += "<property name='tail'><vt:i4>2</vt:i4></property>"
  assert_eq(
    pptx_custom_review_observe(body),
    ([("tail", "2", Some("vt:i4"))], []),
  )
}

///|
async test "PPTX custom duplicates nested type selection and scalar omissions keep legacy contracts" {
  assert_eq(
    pptx_custom_review_observe(
      "<property name='dup'><vt:i4> 007 </vt:i4><vt:bool>true</vt:bool></property>" +
      "<property name='dup'><vt:bool>false</vt:bool></property>" +
      "<property name='empty'></property><property name='paired'><vt:i4> </vt:i4></property>" +
      "<property name='self'><vt:i4/></property><property name='skip'/>" +
      "<property name='outer'><property name='inner'><vt:i4>2</vt:i4></property></property>" +
      "<property name='alternate'><v:i4 xmlns:v='http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes'>3</v:i4></property>" +
      "<property name='foreign'><other:i4>bad</other:i4><vt:i4 xmlns:vt='urn:foreign'>4</vt:i4></property>",
    ),
    (
      [
        ("dup", "007", Some("vt:i4")),
        ("dup", "false", Some("vt:bool")),
        ("outer", "2", Some("vt:i4")),
        ("foreign", "4", Some("vt:i4")),
      ],
      [],
    ),
  )
}

///|
async test "PPTX custom empty structural values retain wrapper while empty scalars stay omitted" {
  assert_eq(
    pptx_custom_review_observe(
      "<property name='empty'><vt:empty/></property>" +
      "<property name='vector'><vt:vector baseType='lpwstr' size='0'/></property>" +
      "<property name='paired'><vt:vector baseType='lpwstr' size='0'></vt:vector></property>",
    ),
    (
      [
        (
          "vector",
          "<vt:vector baseType=\"lpwstr\" size=\"0\"/>",
          Some("vt:vector"),
        ),
        (
          "paired",
          "<vt:vector baseType=\"lpwstr\" size=\"0\"></vt:vector>",
          Some("vt:vector"),
        ),
      ],
      [],
    ),
  )
}

///|
async test "PPTX custom incomplete extra candidate does not invent a limit warning" {
  let mut prefix = ""
  for _ in 0..<256 {
    prefix += "<property name='n'><vt:i4>1</vt:i4></property>"
  }
  for complete in [false, true] {
    let body = prefix +
      (if complete {
        "<property name='extra'></property><broken></wrong>"
      } else {
        "<property name='extra'><vt:i4>2"
      })
    let (values, warnings) = pptx_custom_review_observe(body)
    assert_eq(values.length(), 256)
    assert_eq(warnings.length(), if complete { 1 } else { 0 })
  }
  // A recoverable grammar error preserves completed prior fields, and does
  // not invent a second scanner to discover fields after invalid syntax.
  assert_eq(
    pptx_custom_review_observe(
      "<property name='prior'><vt:i4>1</vt:i4></property>" +
      "<broken></wrong><property name='later'><vt:i4>2</vt:i4></property>",
    ),
    ([("prior", "1", Some("vt:i4"))], []),
  )
}

///|
async test "PPTX custom missing part stays empty and alternate relationship does not change location" {
  let pkg = @ox.open_ooxml_package(
    @dzip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      (
        "_rels/.rels", b"<Relationships><Relationship Id='custom' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties' Target='metadata/custom.xml'/></Relationships>",
      ),
      (
        "metadata/custom.xml", b"<Properties><property name='rel-only'><vt:i4>7</vt:i4></property></Properties>",
      ),
    ]),
  )
  assert_eq(@ox.read_package_relationships(pkg).length(), 1)
  assert_eq(parse_pptx_source(pkg).metadata.custom_properties.length(), 0)
}
