///|
fn wb_bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn wb_append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn wb_append_u32_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn wb_crc32_update_uint(crc : UInt, value : UInt) -> UInt {
  let mut acc = UInt::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt::land(acc, 1) != 0 {
      acc = UInt::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i += 1
  }
  acc
}

///|
fn wb_crc32_of_string(s : String) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for ch in s.to_array() {
    crc = wb_crc32_update_uint(crc, ch.to_int().reinterpret_as_uint())
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn wb_add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int, Int)],
  name : String,
  data : String,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = wb_bytes_of_string(name)
  let data_bytes = wb_bytes_of_string(data)
  let crc32 = wb_crc32_of_string(data)

  wb_append_u32_le(out, 0x04034b50)
  wb_append_u16_le(out, 20)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, 0)
  wb_append_u32_le(out, crc32)
  wb_append_u32_le(out, data_bytes.length())
  wb_append_u32_le(out, data_bytes.length())
  wb_append_u16_le(out, name_bytes.length())
  wb_append_u16_le(out, 0)
  for b in name_bytes {
    out.push(b)
  }
  for b in data_bytes {
    out.push(b)
  }

  central.push((name, data_bytes.length(), local_offset, crc32))
}

///|
fn wb_build_store_zip(entries : Array[(String, String)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []

  for entry in entries {
    let (name, data) = entry
    wb_add_store_entry(out, central, name, data)
  }

  let cd_offset = out.length()
  for item in central {
    let (name, size, local_offset, crc32) = item
    let name_bytes = wb_bytes_of_string(name)
    wb_append_u32_le(out, 0x02014b50)
    wb_append_u16_le(out, 20)
    wb_append_u16_le(out, 20)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u32_le(out, crc32)
    wb_append_u32_le(out, size)
    wb_append_u32_le(out, size)
    wb_append_u16_le(out, name_bytes.length())
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u32_le(out, 0)
    wb_append_u32_le(out, local_offset)
    for b in name_bytes {
      out.push(b)
    }
  }
  let cd_size = out.length() - cd_offset

  wb_append_u32_le(out, 0x06054b50)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, central.length())
  wb_append_u16_le(out, central.length())
  wb_append_u32_le(out, cd_size)
  wb_append_u32_le(out, cd_offset)
  wb_append_u16_le(out, 0)

  Bytes::from_array(out)
}

///|
fn wb_minimal_container(rootfiles : Array[(String, String?)]) -> String {
  let children : Array[String] = []
  for entry in rootfiles {
    let (path, media_type) = entry
    let media = match media_type {
      Some(v) => " media-type=\"" + v + "\""
      None => ""
    }
    children.push("<rootfile full-path=\"" + path + "\"" + media + "/>")
  }
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\">" +
  "<rootfiles>" +
  children.join("") +
  "</rootfiles>" +
  "</container>"
}

///|
fn wb_minimal_opf(
  manifest_items : Array[(String, String, String, String?)],
  spine_items : Array[(String, String?)],
) -> String {
  let manifest_xml : Array[String] = []
  for entry in manifest_items {
    let (id, href, media_type, properties) = entry
    let props = match properties {
      Some(v) => " properties=\"" + v + "\""
      None => ""
    }
    manifest_xml.push(
      "<item id=\"" +
      id +
      "\" href=\"" +
      href +
      "\" media-type=\"" +
      media_type +
      "\"" +
      props +
      "/>",
    )
  }
  let spine_xml : Array[String] = []
  for entry in spine_items {
    let (idref, linear) = entry
    let linear_attr = match linear {
      Some(v) => " linear=\"" + v + "\""
      None => ""
    }
    spine_xml.push("<itemref idref=\"" + idref + "\"" + linear_attr + "/>")
  }
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<package xmlns=\"http://www.idpf.org/2007/opf\" version=\"3.0\">" +
  "<metadata><dc:title xmlns:dc=\"http://purl.org/dc/elements/1.1/\">Cache</dc:title></metadata>" +
  "<manifest>" +
  manifest_xml.join("") +
  "</manifest>" +
  "<spine>" +
  spine_xml.join("") +
  "</spine>" +
  "</package>"
}

///|
fn wb_open_inline_epub() -> EpubPackage raise {
  open_epub_package(
    wb_build_store_zip([
      ("mimetype", "application/epub+zip"),
      (
        "META-INF/container.xml",
        wb_minimal_container([
          ("OPS/content.opf", Some("application/oebps-package+xml")),
        ]),
      ),
      (
        "OPS/content.opf",
        wb_minimal_opf(
          [
            ("nav", "nav.xhtml", "application/xhtml+xml", Some("nav")),
            ("chapter1", "chapter1.xhtml", "application/xhtml+xml", None),
          ],
          [("chapter1", None)],
        ),
      ),
      (
        "OPS/nav.xhtml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><html xmlns=\"http://www.w3.org/1999/xhtml\"><body><nav><ol><li><a href=\"chapter1.xhtml\">Chapter 1</a></li></ol></nav></body></html>",
      ),
      (
        "OPS/chapter1.xhtml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><html xmlns=\"http://www.w3.org/1999/xhtml\"><body><h1>Chapter 1</h1><p>Hello</p></body></html>",
      ),
    ]),
    "inline.epub",
  )
}

///|
test "epub package private caches record inventory inspect text and zip reuse" {
  let pkg = wb_open_inline_epub() catch {
    e => fail("open inline epub failed: " + e.to_string())
  }

  ignore(inspect_epub_inventory(pkg))
  ignore(inspect_epub_inventory(pkg))
  ignore(inspect_epub_package(pkg))
  ignore(inspect_epub_package(pkg))
  ignore(
    read_part_text(pkg, "OPS/content.opf") catch {
      e => fail("first read_part_text failed: " + e.to_string())
    },
  )
  ignore(
    read_part_text(pkg, "OPS/content.opf") catch {
      e => fail("second read_part_text failed: " + e.to_string())
    },
  )

  assert_eq(pkg.inventory_miss_count.val, 1)
  assert_eq(pkg.inventory_hit_count.val, 2)
  assert_eq(pkg.inspect_miss_count.val, 1)
  assert_eq(pkg.inspect_hit_count.val, 1)
  assert_eq(pkg.text_miss_count.val, 1)
  assert_eq(pkg.text_hit_count.val, 1)
  assert_eq(pkg.text_part_cache.length(), 1)
  assert_true(pkg.inventory_cache.val is Some(_))
  assert_true(pkg.inspect_cache.val is Some(_))
}

///|
test "epub repeated opens keep package-local caches independent" {
  let bytes = wb_build_store_zip([
    ("mimetype", "application/epub+zip"),
    (
      "META-INF/container.xml",
      wb_minimal_container([
        ("CACHE/content.opf", Some("application/oebps-package+xml")),
      ]),
    ),
    (
      "CACHE/content.opf",
      wb_minimal_opf(
        [
          ("nav", "nav.xhtml", "application/xhtml+xml", Some("nav")),
          ("chapter1", "chapter1.xhtml", "application/xhtml+xml", None),
        ],
        [("chapter1", None)],
      ),
    ),
    (
      "CACHE/nav.xhtml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><html xmlns=\"http://www.w3.org/1999/xhtml\"><body><nav><ol><li><a href=\"chapter1.xhtml\">Chapter 1</a></li></ol></nav></body></html>",
    ),
    (
      "CACHE/chapter1.xhtml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><html xmlns=\"http://www.w3.org/1999/xhtml\"><body><h1>Chapter 1</h1><p>Hello</p></body></html>",
    ),
  ])
  let first = open_epub_package(bytes, "inline.epub") catch {
    e => fail("first open_epub_package failed: " + e.to_string())
  }
  ignore(inspect_epub_package(first))
  ignore(
    read_part_text(first, "CACHE/content.opf") catch {
      e => fail("first read_part_text failed: " + e.to_string())
    },
  )
  let second = open_epub_package(bytes, "inline.epub") catch {
    e => fail("second open_epub_package failed: " + e.to_string())
  }
  ignore(inspect_epub_package(second))
  ignore(
    read_part_text(second, "CACHE/content.opf") catch {
      e => fail("second read_part_text failed: " + e.to_string())
    },
  )

  assert_eq(first.inspect_miss_count.val, 1)
  assert_eq(first.inspect_hit_count.val, 0)
  assert_eq(first.text_miss_count.val, 1)
  assert_eq(first.text_hit_count.val, 0)
  assert_eq(second.inspect_miss_count.val, 1)
  assert_eq(second.inspect_hit_count.val, 0)
  assert_eq(second.text_miss_count.val, 1)
  assert_eq(second.text_hit_count.val, 0)
}
