///|
fn cache_test_bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn cache_test_append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn cache_test_append_u32_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn cache_test_crc32_update_uint(crc : UInt, value : UInt) -> UInt {
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
fn cache_test_byte_to_int(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 0 {
    v
  } else {
    v + 256
  }
}

///|
fn cache_test_crc32_of_bytes(bytes : Bytes) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for b in bytes {
    crc = cache_test_crc32_update_uint(
      crc,
      cache_test_byte_to_int(b).reinterpret_as_uint(),
    )
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn cache_test_add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int, Int)],
  name : String,
  data : Bytes,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = cache_test_bytes_of_string(name)
  let data_bytes = data.to_array()
  let crc32 = cache_test_crc32_of_bytes(data)

  cache_test_append_u32_le(out, 0x04034b50)
  cache_test_append_u16_le(out, 20)
  cache_test_append_u16_le(out, 0)
  cache_test_append_u16_le(out, 0)
  cache_test_append_u16_le(out, 0)
  cache_test_append_u16_le(out, 0)
  cache_test_append_u32_le(out, crc32)
  cache_test_append_u32_le(out, data_bytes.length())
  cache_test_append_u32_le(out, data_bytes.length())
  cache_test_append_u16_le(out, name_bytes.length())
  cache_test_append_u16_le(out, 0)
  for b in name_bytes {
    out.push(b)
  }
  for b in data_bytes {
    out.push(b)
  }

  central.push((name, data_bytes.length(), local_offset, crc32))
}

///|
fn cache_test_build_store_zip(entries : Array[(String, Bytes)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []

  for entry in entries {
    let (name, data) = entry
    cache_test_add_store_entry(out, central, name, data)
  }

  let cd_offset = out.length()
  for entry in central {
    let (name, size, local_offset, crc32) = entry
    let name_bytes = cache_test_bytes_of_string(name)
    cache_test_append_u32_le(out, 0x02014b50)
    cache_test_append_u16_le(out, 20)
    cache_test_append_u16_le(out, 20)
    cache_test_append_u16_le(out, 0)
    cache_test_append_u16_le(out, 0)
    cache_test_append_u16_le(out, 0)
    cache_test_append_u16_le(out, 0)
    cache_test_append_u32_le(out, crc32)
    cache_test_append_u32_le(out, size)
    cache_test_append_u32_le(out, size)
    cache_test_append_u16_le(out, name_bytes.length())
    cache_test_append_u16_le(out, 0)
    cache_test_append_u16_le(out, 0)
    cache_test_append_u16_le(out, 0)
    cache_test_append_u16_le(out, 0)
    cache_test_append_u32_le(out, 0)
    cache_test_append_u32_le(out, local_offset)
    for b in name_bytes {
      out.push(b)
    }
  }
  let cd_size = out.length() - cd_offset

  cache_test_append_u32_le(out, 0x06054b50)
  cache_test_append_u16_le(out, 0)
  cache_test_append_u16_le(out, 0)
  cache_test_append_u16_le(out, central.length())
  cache_test_append_u16_le(out, central.length())
  cache_test_append_u32_le(out, cd_size)
  cache_test_append_u32_le(out, cd_offset)
  cache_test_append_u16_le(out, 0)

  Bytes::from_array(out)
}

///|
fn cache_test_minimal_content_types_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Default Extension=\"bin\" ContentType=\"application/octet-stream\"/>" +
  "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>" +
  "</Types>"
}

///|
fn cache_test_minimal_rels_xml(inner : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  inner +
  "</Relationships>"
}

///|
fn cache_test_open_package() -> OoxmlPackage raise {
  let document_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"urn:test\"><w:body><w:p><w:r><w:t>Cäsar</w:t></w:r></w:p></w:body></w:document>"
  open_ooxml_package(
    cache_test_build_store_zip([
      (
        "[Content_Types].xml",
        @utf8.encode(cache_test_minimal_content_types_xml()),
      ),
      ("word/document.xml", @utf8.encode(document_xml)),
      ("word/media/image1.bin", @utf8.encode("BINARY")),
    ]),
  )
}

///|
fn cache_test_open_relationship_package() -> OoxmlPackage raise {
  open_ooxml_package(
    cache_test_build_store_zip([
      (
        "[Content_Types].xml",
        @utf8.encode(cache_test_minimal_content_types_xml()),
      ),
      (
        "_rels/.rels",
        @utf8.encode(
          cache_test_minimal_rels_xml(
            "<Relationship Id=\"rIdRoot\" Type=\"officeDocument\" Target=\"word/document.xml\"/>",
          ),
        ),
      ),
      (
        "word/_rels/document.xml.rels",
        @utf8.encode(
          cache_test_minimal_rels_xml(
            "<Relationship Id=\"rIdLink\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"https://example.com/spec\" TargetMode=\"External\"/>" +
            "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/image1.bin\"/>",
          ),
        ),
      ),
      ("word/document.xml", @utf8.encode("<doc/>")),
      ("word/media/image1.bin", @utf8.encode("BINARY")),
    ]),
  )
}

///|
test "ooxml part cache reuses bytes by normalized package path" {
  let pkg = cache_test_open_package()
  let first = read_part_bytes(pkg, "word/document.xml") catch {
    e => fail("first read_part_bytes failed: " + e.to_string())
  }
  let second = read_part_bytes(pkg, "/word/./document.xml") catch {
    e => fail("second read_part_bytes failed: " + e.to_string())
  }

  assert_eq(first.length(), second.length())
  let stats = inspect_ooxml_part_cache_stats(pkg)
  assert_eq(stats.bytes_miss_count, 1)
  assert_eq(stats.bytes_hit_count, 1)
  assert_eq(stats.bytes_entry_count, 1)
}

///|
test "ooxml part cache reuses decoded text and feeds byte cache" {
  let pkg = cache_test_open_package()
  let first = read_part_text(pkg, "word/document.xml") catch {
    e => fail("first read_part_text failed: " + e.to_string())
  }
  let second = read_part_text(pkg, "/word/./document.xml") catch {
    e => fail("second read_part_text failed: " + e.to_string())
  }
  let bytes = read_part_bytes(pkg, "word/document.xml") catch {
    e => fail("read_part_bytes after text failed: " + e.to_string())
  }

  assert_eq(first, second)
  assert_true(first.contains("Cäsar"))
  assert_true(bytes.length() > 0)
  let stats = inspect_ooxml_part_cache_stats(pkg)
  assert_eq(stats.bytes_miss_count, 1)
  assert_eq(stats.bytes_hit_count, 1)
  assert_eq(stats.text_decode_count, 1)
  assert_eq(stats.text_hit_count, 1)
  assert_eq(stats.text_entry_count, 1)
}

///|
test "ooxml xml part payload reuses decoded text and exposes structure scan" {
  let pkg = cache_test_open_package()
  let first = read_xml_part_payload(pkg, "word/document.xml") catch {
    e => fail("first read_xml_part_payload failed: " + e.to_string())
  }
  let second = read_xml_part_payload(pkg, "/word/./document.xml") catch {
    e => fail("second read_xml_part_payload failed: " + e.to_string())
  }

  assert_eq(first.text, second.text)
  assert_true(first.bytes.length() > 0)
  assert_true(
    first.structure_scan.status == @xml.XmlStructureScanStatus::Success,
  )
  assert_true(first.structure_scan.element_count > 0)
  let stats = inspect_ooxml_part_cache_stats(pkg)
  assert_eq(stats.bytes_miss_count, 1)
  assert_eq(stats.bytes_hit_count, 1)
  assert_eq(stats.text_decode_count, 1)
  assert_eq(stats.text_hit_count, 1)
  assert_eq(stats.text_entry_count, 1)
}

///|
test "ooxml part cache preserves missing part behavior" {
  let pkg = cache_test_open_package()
  let first = try read_part_bytes(pkg, "word/missing.xml") |> Ok catch {
    e => Err(e)
  }
  let second = try read_part_text(pkg, "word/missing.xml") |> Ok catch {
    e => Err(e)
  }

  match first {
    Ok(_) => fail("missing bytes read should fail")
    Err(err) => {
      let info = classify_ooxml_error(err)
      if info.kind != OoxmlErrorKind::MissingPart {
        fail("missing bytes read should classify as MissingPart")
      }
    }
  }
  match second {
    Ok(_) => fail("missing text read should fail")
    Err(err) => {
      let info = classify_ooxml_error(err)
      if info.kind != OoxmlErrorKind::MissingPart {
        fail("missing text read should classify as MissingPart")
      }
    }
  }
  let stats = inspect_ooxml_part_cache_stats(pkg)
  assert_eq(stats.bytes_hit_count, 0)
  assert_eq(stats.text_hit_count, 0)
  assert_eq(stats.bytes_entry_count, 0)
  assert_eq(stats.text_entry_count, 0)
}

///|
test "ooxml relationship cache reuses parsed rels and indexed lookups" {
  let pkg = cache_test_open_relationship_package()
  let first = read_part_relationships(pkg, "word/document.xml") catch {
    e => fail("first read_part_relationships failed: " + e.to_string())
  }
  let second = read_part_relationships(pkg, "/word/./document.xml") catch {
    e => fail("second read_part_relationships failed: " + e.to_string())
  }
  let link = find_relationship_by_id(pkg, "word/document.xml", "rIdLink") catch {
    e => fail("find_relationship_by_id failed: " + e.to_string())
  }
  let image_target = resolve_relationship(pkg, "word/document.xml", "rIdImage") catch {
    e => fail("resolve_relationship failed: " + e.to_string())
  }
  let image_rels = find_relationships_by_type(
    pkg, "word/document.xml", "/image",
  ) catch {
    e => fail("find_relationships_by_type failed: " + e.to_string())
  }

  assert_eq(first.length(), 2)
  assert_eq(second.length(), 2)
  match link {
    Some(rel) => {
      assert_eq(rel.resolved_target, first[0].resolved_target)
      if rel.target_mode != OoxmlTargetMode::External {
        fail("expected external hyperlink target mode to be preserved")
      }
    }
    None => fail("expected rIdLink lookup")
  }
  assert_eq(image_target, "word/media/image1.bin")
  assert_eq(image_rels.length(), 1)
  assert_eq(image_rels[0].id, "rIdImage")

  let stats = inspect_ooxml_relationship_cache_stats(pkg)
  assert_eq(stats.relationships_miss_count, 1)
  assert_true(stats.relationships_hit_count >= 4)
  assert_eq(stats.by_id_hit_count, 2)
  assert_eq(stats.by_id_miss_count, 0)
  assert_eq(stats.by_type_query_count, 1)
  assert_eq(stats.entry_count, 1)
}

///|
test "ooxml relationship cache preserves missing rid behavior" {
  let pkg = cache_test_open_relationship_package()
  let result = try
    resolve_relationship(pkg, "word/document.xml", "rId404") |> Ok
  catch {
    e => Err(e)
  }
  match result {
    Ok(_) => fail("missing relationship id should fail")
    Err(err) => {
      let info = classify_ooxml_error(err)
      if info.kind != OoxmlErrorKind::RelationshipNotFound {
        fail("missing relationship id should classify as RelationshipNotFound")
      }
      match info.rel_id {
        Some(v) => assert_eq(v, "rId404")
        None => fail("expected missing relationship id in error info")
      }
    }
  }
  let stats = inspect_ooxml_relationship_cache_stats(pkg)
  assert_eq(stats.relationships_miss_count, 1)
  assert_eq(stats.by_id_miss_count, 1)
}
