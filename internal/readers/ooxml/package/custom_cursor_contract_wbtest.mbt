///|
async fn custom_contract_fixture(xml : String) -> OoxmlPackage raise OoxmlError {
  open_ooxml_package(
    @zip.build_store_zip_bytes([
      ("[Content_Types].xml", b"<Types/>"),
      ("docProps/custom.xml", @utf8.encode(xml)),
    ]),
  )
}

///|
async fn custom_contract_values(
  body : String,
) -> Array[(String, String, String?)] raise OoxmlError {
  let pkg = custom_contract_fixture("<Properties>" + body + "</Properties>")
  read_custom_properties(pkg).map(property => {
    (property.name, property.value, property.value_type)
  })
}

///|
async test "custom properties preserve duplicate order missing names empty and first vt contracts" {
  let observed = custom_contract_values(
    "<property name='dup'><vt:i4> 007 </vt:i4><vt:bool>true</vt:bool></property>" +
    "<property name='dup'><vt:bool>false</vt:bool></property>" +
    "<property><vt:lpwstr>skip</vt:lpwstr></property>" +
    "<property name=' \t '><vt:lpwstr>skip</vt:lpwstr></property>" +
    "<property name='empty'></property>" +
    "<property name='paired'><vt:lpwstr></vt:lpwstr></property>" +
    "<property name='self'><vt:lpwstr/></property>" +
    "<property name='wrapped'><wrapper><vt:lpwstr>one</vt:lpwstr></wrapper></property>",
  )
  assert_eq(observed, [
    ("dup", "007", Some("i4")),
    ("dup", "false", Some("bool")),
    ("empty", "", None),
    ("paired", "", Some("lpwstr")),
    ("self", "", Some("lpwstr")),
    ("wrapped", "one", Some("lpwstr")),
  ])
}

///|
async test "custom structural values retain wrapper attributes child boundaries and binary lexical content" {
  let vector = "<vt:lpwstr>One</vt:lpwstr><vt:lpwstr>Two</vt:lpwstr>"
  let array = "<vt:i4>0</vt:i4><vt:i4>1</vt:i4>"
  let nested = "<vt:variant><vt:i4>7</vt:i4></vt:variant>"
  assert_eq(
    custom_contract_values(
      "<property name='vector'><vt:vector baseType='lpwstr' size='2'>" +
      vector +
      "</vt:vector></property>" +
      "<property name='array'><vt:array baseType='i4' lBounds='0' uBounds='1'>" +
      array +
      "</vt:array></property>" +
      "<property name='nested'><vt:vector baseType='variant' size='1'>" +
      nested +
      "</vt:vector></property>" +
      "<property name='blob'><vt:blob>AAAAAA==</vt:blob></property>" +
      "<property name='versioned'><vt:vstream version='{00000000-0000-0000-0000-000000000000}'>AAAAAA==</vt:vstream></property>",
    ),
    [
      (
        "vector",
        "<vt:vector baseType=\"lpwstr\" size=\"2\">" + vector + "</vt:vector>",
        Some("vector"),
      ),
      (
        "array",
        "<vt:array baseType=\"i4\" lBounds=\"0\" uBounds=\"1\">" +
        array +
        "</vt:array>",
        Some("array"),
      ),
      (
        "nested",
        "<vt:vector baseType=\"variant\" size=\"1\">" + nested + "</vt:vector>",
        Some("vector"),
      ),
      ("blob", "AAAAAA==", Some("blob")),
      (
        "versioned",
        "<vt:vstream version=\"{00000000-0000-0000-0000-000000000000}\">AAAAAA==</vt:vstream>",
        Some("vstream"),
      ),
    ],
  )
}

///|
async test "custom properties character data and names decode XML entities once" {
  assert_eq(
    custom_contract_values(
      "<property name='A&amp;lt;B'><vt:lpwstr>&amp;lt; &#x1F600; &#65;</vt:lpwstr></property>",
    ),
    [("A&lt;B", "&lt; 😀 A", Some("lpwstr"))],
  )
}

///|
async test "custom property quote and fake comments do not change the selected property" {
  assert_eq(
    custom_contract_values(
      "<!-- <property name='fake'><vt:lpwstr>fake</vt:lpwstr></property> -->" +
      "<property note='a>b' name='real'><vt:lpwstr>value</vt:lpwstr></property>",
    ),
    [("real", "value", Some("lpwstr"))],
  )
}

///|
async test "custom first vt takes its own content instead of an earlier foreign local name" {
  assert_eq(
    custom_contract_values(
      "<property name='picked'><other:i4>wrong</other:i4><vt:i4>7</vt:i4></property>",
    ),
    [("picked", "7", Some("i4"))],
  )
}

///|
async test "custom CDATA contributes literal characters rather than markup delimiters" {
  assert_eq(
    custom_contract_values(
      "<property name='cdata'><vt:lpwstr>x<![CDATA[A &amp; <b>]]>y</vt:lpwstr></property>",
    ),
    [("cdata", "xA &amp; <b>y", Some("lpwstr"))],
  )
}

///|
async test "custom cursor caches projected properties without keeping complete part bytes and text" {
  let pkg = custom_contract_fixture(
    "<Properties><property name='one'><vt:lpwstr>value</vt:lpwstr></property></Properties>",
  )
  assert_eq(read_custom_properties(pkg).length(), 1)
  assert_false(pkg.part_cache.bytes_by_part.contains("docProps/custom.xml"))
  assert_false(pkg.part_cache.text_by_part.contains("docProps/custom.xml"))
}
