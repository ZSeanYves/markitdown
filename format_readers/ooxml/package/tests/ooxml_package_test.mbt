///|
fn bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn append_u32_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn crc32_of_string(s : String) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for ch in s.to_array() {
    crc = crc32_update_uint(crc, ch.to_int().reinterpret_as_uint())
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn crc32_update_uint(crc : UInt, value : UInt) -> UInt {
  let mut acc = UInt::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt::land(acc, 1) != 0 {
      acc = UInt::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i = i + 1
  }
  acc
}

///|
fn add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int, Int)],
  name : String,
  data : String,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = bytes_of_string(name)
  let data_bytes = bytes_of_string(data)
  let crc32 = crc32_of_string(data)

  append_u32_le(out, 0x04034b50)
  append_u16_le(out, 20)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u32_le(out, crc32)
  append_u32_le(out, data_bytes.length())
  append_u32_le(out, data_bytes.length())
  append_u16_le(out, name_bytes.length())
  append_u16_le(out, 0)
  for b in name_bytes {
    out.push(b)
  }
  for b in data_bytes {
    out.push(b)
  }

  central.push((name, data_bytes.length(), local_offset, crc32))
}

///|
fn build_store_zip(entries : Array[(String, String)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []

  for entry in entries {
    let (name, data) = entry
    add_store_entry(out, central, name, data)
  }

  let cd_offset = out.length()
  for entry in central {
    let (name, size, local_offset, crc32) = entry
    let name_bytes = bytes_of_string(name)
    append_u32_le(out, 0x02014b50)
    append_u16_le(out, 20)
    append_u16_le(out, 20)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, crc32)
    append_u32_le(out, size)
    append_u32_le(out, size)
    append_u16_le(out, name_bytes.length())
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, 0)
    append_u32_le(out, local_offset)
    for b in name_bytes {
      out.push(b)
    }
  }
  let cd_size = out.length() - cd_offset

  append_u32_le(out, 0x06054b50)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, central.length())
  append_u16_le(out, central.length())
  append_u32_le(out, cd_size)
  append_u32_le(out, cd_offset)
  append_u16_le(out, 0)

  Bytes::from_array(out)
}

///|
fn minimal_content_types_xml(overrides : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
  "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
  overrides +
  "</Types>"
}

///|
fn minimal_rels_xml(inner : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  inner +
  "</Relationships>"
}

///|
fn expect_error_info(
  result : Result[Unit, @ox.OoxmlError],
  kind : @ox.OoxmlErrorKind,
) -> @oxi.OoxmlErrorInfo raise {
  match result {
    Ok(_) => fail("expected OOXML error")
    Err(err) => {
      let info = @oxi.classify_ooxml_error(err)
      if info.kind != kind {
        fail("unexpected OOXML error kind: err=" + err.to_string())
      }
      info
    }
  }
}

///|
fn[T] ok_or_err_unit(
  result : Result[T, @ox.OoxmlError],
) -> Result[Unit, @ox.OoxmlError] {
  match result {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
test "ooxml package opens generated docx and resolves core relationships" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/image1.png\"/>",
      ),
    ),
    ("word/media/image1.png", "png-bytes"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }

  assert_true(@ox.has_part(pkg, "word/document.xml"))

  let root_rels = @ox.read_package_relationships(pkg) catch {
    e => fail("read_package_relationships failed: " + e.to_string())
  }
  assert_eq(root_rels.length(), 1)

  let root_rel = @ox.find_relationship_by_id(pkg, "", "rIdMain") catch {
    e => fail("find_relationship_by_id failed: " + e.to_string())
  }
  match root_rel {
    Some(rel) => assert_eq(rel.resolved_target, "word/document.xml")
    None => fail("expected root relationship")
  }

  let doc_rels = @ox.read_part_relationships(pkg, "word/document.xml") catch {
    e => fail("read_part_relationships failed: " + e.to_string())
  }
  assert_eq(doc_rels.length(), 1)
  assert_eq(doc_rels[0].resolved_target, "word/media/image1.png")

  let found = @ox.find_relationship_by_id(pkg, "word/document.xml", "rIdImage") catch {
    e => fail("find_relationship_by_id failed: " + e.to_string())
  }
  match found {
    Some(rel) => assert_eq(rel.target, "media/image1.png")
    None => fail("expected part relationship")
  }
}

///|
test "ooxml package malformed content types is classified" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
      "<Default ContentType=\"application/xml\"/>" +
      "</Types>",
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let result = ok_or_err_unit(
    try @ox.open_ooxml_package(bytes) |> Ok catch {
      e => Err(e)
    },
  )
  let info = expect_error_info(
    result,
    @ox.OoxmlErrorKind::MalformedContentTypes,
  )
  match info.part_name {
    Some(path) => assert_eq(path, "[Content_Types].xml")
    None => fail("expected content types part name")
  }
  if !info.detail.contains("missing attribute: Extension") {
    fail("expected malformed content types detail")
  }
}

///|
test "ooxml package rejects unsafe relationship target path" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"image\" Target=\"../media/../../evil.bin\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])

  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let result = ok_or_err_unit(
    try @ox.read_part_relationships(pkg, "word/document.xml") |> Ok catch {
      e => Err(e)
    },
  )
  let info = expect_error_info(
    result,
    @ox.OoxmlErrorKind::UnsafeRelationshipTarget,
  )
  if !info.detail.contains("rels_part=\"word/_rels/document.xml.rels\"") {
    fail("unsafe relationship target should preserve rels part context")
  }
  match info.target {
    Some(target) =>
      if !target.contains("../media/../../evil.bin") {
        fail("unsafe relationship target should retain traversal target detail")
      }
    None => fail("unsafe relationship target should classify target")
  }
}

///|
test "ooxml package inventory skips directory entries" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    ("word/", ""),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  assert_eq(inventory.part_count, 1)
  assert_eq(inventory.parts[0].part_name, "word/document.xml")
}
