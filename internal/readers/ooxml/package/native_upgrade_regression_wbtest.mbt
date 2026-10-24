///|
async fn native_upgrade_ooxml_package(
  part_name : String,
  part_bytes : Bytes,
) -> OoxmlPackage raise OoxmlError {
  let content_types = "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>"
  open_ooxml_package(
    @zip.build_store_zip_bytes([
      ("[Content_Types].xml", @utf8.encode(content_types)),
      (part_name, part_bytes),
    ]),
  )
}

///|
async test "native upgrade OOXML rejects invalid UTF8 instead of byte character fallback" {
  let package_ = native_upgrade_ooxml_package(
    "custom.xml",
    b"<r>" + Bytes::from_array([0xFF]) + b"</r>",
  )
  let read = try read_part_text(package_, "custom.xml") |> Ok catch {
    error => Err(error)
  }
  match read {
    Err(InvalidEncoding(_)) => ()
    _ => fail("an OOXML XML part with invalid UTF8 must return InvalidEncoding")
  }
}

///|
async test "native upgrade OOXML property cursor preserves non BMP text and following tags" {
  let pkg = native_upgrade_ooxml_package(
    "docProps/core.xml",
    @utf8.encode("<root><title>😀</title><creator>A</creator></root>"),
  )
  let value = read_core_properties(pkg)
  assert_eq(value.title, Some("😀"))
  assert_eq(value.creator, Some("A"))
}

///|
async test "native upgrade relationship cursor preserves non BMP values and following rows" {
  let pkg = native_upgrade_ooxml_package(
    "word/_rels/document.xml.rels",
    @utf8.encode(
      "<Relationships><Relationship Id='😀' Type='image' Target='😀.png'/><Relationship Id='next' Type='image' Target='next.png'/></Relationships>",
    ),
  )
  let rows = read_part_relationships(pkg, "word/document.xml")
  assert_eq(rows.map(row => row.id), ["😀", "next"])
  assert_eq(rows[0].resolved_target, "word/😀.png")
}

///|
async test "native upgrade OOXML core properties preserve non BMP metadata" {
  let package_ = native_upgrade_ooxml_package(
    "docProps/core.xml",
    @utf8.encode(
      "<cp:coreProperties xmlns:cp=\"urn:cp\" xmlns:dc=\"urn:dc\">" +
      "<dc:title>😀</dc:title><dc:creator>A</dc:creator></cp:coreProperties>",
    ),
  )
  let properties = read_core_properties(package_)
  assert_eq(properties.title, Some("😀"))
  assert_eq(properties.creator, Some("A"))
}

///|
async test "native upgrade OOXML metadata propagates invalid UTF8 errors" {
  for
    part_name in [
      "docProps/core.xml", "docProps/app.xml", "docProps/custom.xml",
    ] {
    let package_ = native_upgrade_ooxml_package(
      part_name,
      b"<r>" + Bytes::from_array([0xFF]) + b"</r>",
    )
    let read = try
      ({
        match part_name {
          "docProps/core.xml" => ignore(read_core_properties(package_))
          "docProps/app.xml" => ignore(read_app_properties(package_))
          _ => ignore(read_custom_properties(package_))
        }
        true
      })
      |> Ok
    catch {
      error => Err(error)
    }
    match read {
      Err(InvalidEncoding(_)) => ()
      _ => fail("invalid metadata encoding must not become empty properties")
    }
  }
}

///|
async test "native upgrade OOXML absent metadata remains optional" {
  let package_ = native_upgrade_ooxml_package("custom.xml", b"<r/>")
  assert_eq(read_core_properties(package_).title, None)
  assert_eq(read_app_properties(package_).application, None)
  assert_true(read_custom_properties(package_).is_empty())
}

///|
async test "native upgrade OOXML property cursor preserves attribute scalars and part paths" {
  let pkg = native_upgrade_ooxml_package(
    "docProps/custom.xml",
    @utf8.encode(
      "<r><property name='😀'><vt:lpwstr>B</vt:lpwstr></property></r>",
    ),
  )
  let properties = read_custom_properties(pkg)
  assert_eq(properties[0].name, "😀")
  assert_eq(properties[0].value, "B")
  assert_eq(split_dir_file("😀/子.xml"), ("😀", "子.xml"))
  assert_eq(extension_of_part("😀/子.xml"), "xml")
}

///|
async test "native upgrade OOXML custom properties preserve non BMP text and order" {
  let package_ = native_upgrade_ooxml_package(
    "docProps/custom.xml",
    @utf8.encode(
      "<Properties>" +
      "<property name=\"😀\"><vt:lpwstr>😀</vt:lpwstr></property>" +
      "<property name=\"second\"><vt:lpwstr>B</vt:lpwstr></property>" +
      "</Properties>",
    ),
  )
  let properties = read_custom_properties(package_)
  assert_eq(properties.length(), 2)
  assert_eq(properties[0].name, "😀")
  assert_eq(properties[0].value, "😀")
  assert_eq(properties[1].name, "second")
  assert_eq(properties[1].value, "B")
}
