///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn open_sample_package(path : String) -> @epub.EpubPackage raise {
  let sample = resolve_sample_path(path)
  let bytes = @fs.read_file_to_bytes(sample) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @epub.open_epub_package(bytes, sample_basename(sample)) catch {
    e => fail("open_epub_package failed: " + e.to_string())
  }
}

///|
fn assert_open_epub_fails(
  path : String,
  expected_substr : String,
) -> Unit raise {
  let sample = resolve_sample_path(path)
  let bytes = @fs.read_file_to_bytes(sample) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  let result = try
    @epub.open_epub_package(bytes, sample_basename(sample)) |> Ok
  catch {
    e => Err(e)
  }
  match result {
    Ok(_) => fail("expected epub package parse to fail: " + path)
    Err(e) =>
      if !e.to_string().contains(expected_substr) {
        fail(
          "expected error containing `" +
          expected_substr +
          "`, got: " +
          e.to_string(),
        )
      }
  }
}

///|
fn assert_epub_error_kind(
  path : String,
  expected_kind : @epub.EpubErrorKind,
) -> Unit raise {
  let sample = resolve_sample_path(path)
  let bytes = @fs.read_file_to_bytes(sample) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  let result = try
    @epub.open_epub_package(bytes, sample_basename(sample)) |> Ok
  catch {
    e => Err(e)
  }
  match result {
    Ok(_) => fail("expected EPUB open failure for: " + path)
    Err(err) => {
      let info = @epub.classify_epub_error(err)
      if info.kind != expected_kind {
        fail("unexpected epub error kind")
      }
    }
  }
}

///|
fn bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn sample_basename(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let parts = normalized.split("/").to_array()
  parts.last().unwrap_or(normalized).to_owned()
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
fn open_inline_epub(
  entries : Array[(String, String)],
  name? : String = "inline.epub",
) -> @epub.EpubPackage raise {
  @epub.open_epub_package(build_store_zip(entries), name) catch {
    e => fail("open inline epub failed: " + e.to_string())
  }
}

///|
fn minimal_container(rootfiles : Array[(String, String?)]) -> String {
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
fn minimal_opf(
  manifest_items : Array[(String, String, String, String?)],
  spine_items : Array[(String, String?)],
  toc? : String? = None,
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
  let toc_attr = match toc {
    Some(v) => " toc=\"" + v + "\""
    None => ""
  }
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<package xmlns=\"http://www.idpf.org/2007/opf\" version=\"3.0\">" +
  "<metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>Inline EPUB</dc:title></metadata>" +
  "<manifest>" +
  manifest_xml.join("") +
  "</manifest>" +
  "<spine" +
  toc_attr +
  ">" +
  spine_xml.join("") +
  "</spine>" +
  "</package>"
}

///|
test "epub package parses basic spine in OPF order" {
  let pkg = open_sample_package(
    "samples/main_process/epub/epub_basic_spine.epub",
  )
  assert_eq(pkg.rootfile_path, "OEBPS/content.opf")
  assert_eq(pkg.opf_dir, "OEBPS")
  if pkg.mimetype != Some("application/epub+zip") {
    fail("expected EPUB mimetype to be application/epub+zip")
  }
  assert_eq(pkg.spine.length(), 2)
  if pkg.spine[0].resolved_path != Some("OEBPS/chapter-02.xhtml") {
    fail("expected first EPUB spine path to preserve OPF order")
  }
  if pkg.spine[1].resolved_path != Some("OEBPS/chapter-01.xhtml") {
    fail("expected second EPUB spine path to preserve OPF order")
  }
  assert_eq(pkg.spine[0].linear, true)
  assert_eq(pkg.spine[1].linear, true)

  let rootfiles = @epub.list_epub_rootfiles(pkg)
  assert_eq(rootfiles.length(), 1)
  assert_eq(rootfiles[0].full_path, "OEBPS/content.opf")
  if rootfiles[0].normalized_path != Some("OEBPS/content.opf") {
    fail("expected normalized rootfile path")
  }
  assert_eq(rootfiles[0].exists, true)
  assert_eq(rootfiles[0].usable, true)
  assert_eq(rootfiles[0].is_primary, true)

  let primary = @epub.get_epub_primary_rootfile(pkg)
  assert_eq(primary.full_path, "OEBPS/content.opf")

  let manifest = @epub.list_epub_manifest_items(pkg)
  assert_eq(manifest.length(), 3)
  assert_eq(manifest[0].id, "chap1")
  assert_eq(manifest[1].id, "chap2")
  assert_eq(manifest[2].id, "pic")

  match @epub.find_epub_manifest_item(pkg, "chap1") {
    Some(item) => assert_eq(item.resolved_path, "OEBPS/chapter-01.xhtml")
    None => fail("expected manifest item chap1")
  }

  let spine = @epub.list_epub_spine_items(pkg)
  assert_eq(spine.length(), 2)
  let reading_order = @epub.list_epub_spine_reading_order(pkg)
  assert_eq(reading_order.length(), 2)
  assert_eq(reading_order[0], "OEBPS/chapter-02.xhtml")
  assert_eq(reading_order[1], "OEBPS/chapter-01.xhtml")

  let inventory = @epub.inspect_epub_inventory(pkg)
  assert_eq(inventory.part_count, pkg.entries.length())
  assert_eq(inventory.rootfile_count, 1)
  assert_eq(inventory.manifest_count, 3)
  assert_eq(inventory.spine_count, 2)
  assert_eq(inventory.spine_linear_count, 2)
  assert_eq(inventory.primary_rootfile_path, "OEBPS/content.opf")
  assert_eq(inventory.parts.length(), pkg.entries.length())
  assert_eq(inventory.rootfiles.length(), 1)
}

///|
test "epub package parses metadata basic" {
  let pkg = open_sample_package(
    "samples/main_process/epub/metadata/epub_metadata_basic.epub",
  )
  if pkg.metadata.title != Some("EPUB Metadata Sample") {
    fail("expected EPUB title from OPF metadata")
  }
  if pkg.metadata.creator != Some("Example Author") {
    fail("expected EPUB creator from OPF metadata")
  }
  if pkg.metadata.date != Some("2024-01-15") {
    fail("expected EPUB date from OPF metadata")
  }
  if pkg.metadata.modified != Some("2024-01-16T09:30:00Z") {
    fail("expected EPUB modified timestamp from OPF metadata")
  }
  assert_eq(pkg.spine.length(), 1)
  if pkg.spine[0].resolved_path != Some("OPS/chapter.xhtml") {
    fail("expected EPUB chapter path from spine manifest item")
  }
}

///|
test "epub package parses linear no spine flag" {
  let pkg = open_sample_package(
    "samples/main_process/epub/epub_linear_no_current_behavior.epub",
  )
  assert_eq(pkg.spine.length(), 2)
  assert_eq(pkg.spine[0].linear, true)
  assert_eq(pkg.spine[1].linear, false)
}

///|
test "epub package rejects missing container" {
  assert_open_epub_fails(
    "samples/fixtures/epub/epub_missing_container.epub", "missing EPUB part: META-INF/container.xml",
  )
  assert_epub_error_kind(
    "samples/fixtures/epub/epub_missing_container.epub",
    @epub.EpubErrorKind::MissingContainer,
  )
}

///|
test "epub package rejects rootfile parent escape" {
  assert_open_epub_fails(
    "samples/fixtures/epub/epub_rootfile_parent_escape.epub", "container.xml has no usable rootfile",
  )
  assert_epub_error_kind(
    "samples/fixtures/epub/epub_rootfile_parent_escape.epub",
    @epub.EpubErrorKind::MissingRootfile,
  )
}

///|
test "epub package rejects manifest href parent escape" {
  assert_open_epub_fails(
    "samples/fixtures/epub/epub_manifest_href_parent_escape.epub", "invalid EPUB path: ../text/chapter.xhtml",
  )
  assert_epub_error_kind(
    "samples/fixtures/epub/epub_manifest_href_parent_escape.epub",
    @epub.EpubErrorKind::UnsafeHref,
  )
}

///|
test "epub package rejects normalized collisions" {
  assert_open_epub_fails(
    "samples/fixtures/epub/epub_normalized_collision.epub", "normalized path collision",
  )
  assert_epub_error_kind(
    "samples/fixtures/epub/epub_normalized_collision.epub",
    @epub.EpubErrorKind::InvalidPackage,
  )
}

///|
test "epub package rejects encryption xml" {
  assert_open_epub_fails(
    "samples/fixtures/epub/epub_encryption_xml.epub", "DRM/encryption is not supported",
  )
  assert_epub_error_kind(
    "samples/fixtures/epub/epub_encryption_xml.epub",
    @epub.EpubErrorKind::UnsupportedFeature,
  )
}

///|
test "epub package keeps missing manifest spine item" {
  let pkg = open_sample_package(
    "samples/fixtures/epub/epub_missing_manifest_item.epub",
  )
  assert_eq(pkg.spine.length(), 1)
  let missing = pkg.spine[0]
  assert_eq(missing.idref, "missing")
  assert_eq(missing.spine_index, 0)
  match missing.manifest_item {
    Some(_) =>
      fail(
        "expected missing manifest spine item to preserve None manifest_item",
      )
    None => ()
  }
  match missing.resolved_path {
    Some(_) =>
      fail(
        "expected missing manifest spine item to preserve None resolved_path",
      )
    None => ()
  }
  let inspect = @epub.inspect_epub_package(pkg)
  assert_eq(inspect.spine_items.length(), 1)
  assert_eq(inspect.spine_items[0].idref, "missing")
  assert_eq(inspect.spine_items[0].spine_index, 0)
  assert_eq(inspect.spine_items[0].href, "")
  assert_eq(inspect.spine_items[0].action, "warn")

  let issues = @epub.collect_epub_validation_issues(pkg)
  assert_eq(issues.length(), 3)
  if issues[0].kind != @epub.EpubValidationIssueKind::MissingManifestItem {
    fail("expected missing manifest issue first")
  }
  if issues[1].kind != @epub.EpubValidationIssueKind::MissingSpineTarget {
    fail("expected missing spine target issue second")
  }
  if issues[2].kind != @epub.EpubValidationIssueKind::MissingNavigationDocument {
    fail("expected missing navigation issue third")
  }

  let report = @epub.validate_epub_package(pkg)
  assert_eq(report.issue_count, 3)
  assert_eq(report.error_count, 2)
  assert_eq(report.warning_count, 1)
}

///|
test "epub package rejects duplicate manifest id" {
  assert_open_epub_fails(
    "samples/fixtures/epub/epub_duplicate_manifest_id.epub", "duplicate manifest id",
  )
}

///|
test "epub package detects nav cover and richer metadata" {
  let nav_pkg = open_sample_package(
    "samples/main_process/epub/epub_nav_toc.epub",
  )
  match nav_pkg.nav_item {
    Some(item) => {
      assert_eq(item.resolved_path, "OPS/nav.xhtml")
      if !item.properties.contains("nav") {
        fail("expected nav item properties to include nav")
      }
    }
    None => fail("expected nav item")
  }
  match @epub.find_epub_nav_item(nav_pkg) {
    Some(item) => assert_eq(item.resolved_path, "OPS/nav.xhtml")
    None => fail("expected EPUB3 nav item")
  }
  match @epub.find_epub_ncx_item(nav_pkg) {
    Some(_) => fail("did not expect NCX item for EPUB3 nav package")
    None => ()
  }
  assert_eq(nav_pkg.nav_points.length(), 2)
  assert_eq(nav_pkg.nav_points[0].label, "Section One")
  assert_eq(nav_pkg.nav_points[0].href, "chapter.xhtml#section-1")

  let cover_pkg = open_sample_package(
    "samples/main_process/epub/epub_cover_image.epub",
  )
  match cover_pkg.cover_item {
    Some(item) => {
      assert_eq(item.resolved_path, "OPS/images/cover.jpg")
      if !item.properties.contains("cover-image") {
        fail("expected cover item properties to include cover-image")
      }
    }
    None => fail("expected cover item")
  }
  let cover_candidates = @epub.find_epub_cover_candidates(cover_pkg)
  assert_eq(cover_candidates.length(), 1)
  if cover_candidates[0].source !=
    @epub.EpubCoverCandidateSource::ManifestProperty {
    fail("expected manifest-property cover candidate")
  }
  assert_eq(cover_candidates[0].selected, true)

  let inspect = @epub.inspect_epub_package(nav_pkg)
  if inspect.nav_path != Some("OPS/nav.xhtml") {
    fail("expected inspect nav path")
  }
  if inspect.nav_document_path != Some("OPS/nav.xhtml") {
    fail("expected inspect EPUB3 nav document path")
  }
  if inspect.ncx_path != None {
    fail("did not expect NCX path for EPUB3 nav sample")
  }
  if inspect.cover_path != None {
    fail("expected nav sample cover path to stay empty")
  }
  assert_eq(inspect.spine_items.length(), 1)
  assert_eq(inspect.spine_items[0].action, "convert")
  assert_eq(inspect.primary_rootfile.full_path, "OPS/package.opf")
  assert_eq(inspect.rootfiles.length(), 1)
  if inspect.inventory.nav_document_path != Some("OPS/nav.xhtml") {
    fail("expected inventory nav document path")
  }
}

///|
test "epub package detects guide cover image fallback" {
  let pkg = open_sample_package(
    "samples/fixtures/epub/epub_guide_cover_image.epub",
  )
  match pkg.cover_item {
    Some(item) => {
      assert_eq(item.resolved_path, "OPS/images/cover.jpg")
      if pkg.guide_cover_path != Some("OPS/images/cover.jpg") {
        fail("expected guide cover path to preserve image href")
      }
    }
    None => fail("expected guide cover image fallback to produce cover item")
  }

  let inspect = @epub.inspect_epub_package(pkg)
  if inspect.cover_path != Some("OPS/images/cover.jpg") {
    fail("expected inspect cover path from guide cover image")
  }
  if inspect.guide_cover_path != Some("OPS/images/cover.jpg") {
    fail("expected inspect guide cover path")
  }
  let candidates = @epub.find_epub_cover_candidates(pkg)
  assert_eq(candidates.length(), 1)
  if candidates[0].source != @epub.EpubCoverCandidateSource::GuideReference {
    fail("expected guide cover candidate source")
  }
  assert_eq(candidates[0].is_image, true)
}

///|
test "epub package cover priority keeps manifest cover image over guide" {
  let pkg = open_sample_package(
    "samples/fixtures/epub/epub_guide_cover_priority.epub",
  )
  match pkg.cover_item {
    Some(item) =>
      if item.resolved_path != "OPS/images/main-cover.png" {
        fail("expected manifest cover-image property to outrank guide cover")
      }
    None => fail("expected primary cover item")
  }
  if pkg.guide_cover_path != Some("OPS/images/guide-cover.png") {
    fail("expected guide cover path to remain inspectable")
  }
  let candidates = @epub.find_epub_cover_candidates(pkg)
  assert_eq(candidates.length(), 2)
  assert_eq(candidates[0].selected, true)
}

///|
test "epub package keeps guide cover page without forcing cover image" {
  let pkg = open_sample_package(
    "samples/fixtures/epub/epub_guide_cover_page.epub",
  )
  match pkg.cover_item {
    Some(_) => fail("guide cover page should not be promoted to cover image")
    None => ()
  }
  if pkg.guide_cover_path != Some("OPS/cover.xhtml") {
    fail("expected guide cover page path to remain available")
  }

  let inspect = @epub.inspect_epub_package(pkg)
  if inspect.cover_path != None {
    fail("guide cover page should not populate inspect cover image path")
  }
  if inspect.guide_cover_path != Some("OPS/cover.xhtml") {
    fail("expected inspect guide cover page path")
  }
}

///|
test "epub package rejects unsafe guide cover href" {
  assert_open_epub_fails(
    "samples/fixtures/epub/epub_guide_cover_unsafe.epub", "invalid EPUB path: ../cover.png",
  )
  assert_epub_error_kind(
    "samples/fixtures/epub/epub_guide_cover_unsafe.epub",
    @epub.EpubErrorKind::UnsafeHref,
  )
}

///|
test "epub package discovers ncx nav points from spine toc" {
  let pkg = open_sample_package("samples/fixtures/epub/epub_ncx_basic.epub")
  match pkg.nav_item {
    Some(item) => {
      assert_eq(item.resolved_path, "OPS/toc.ncx")
      match item.media_type {
        Some(v) =>
          if v != "application/x-dtbncx+xml" {
            fail("expected NCX media type")
          }
        None => fail("expected NCX media type")
      }
    }
    None => fail("expected ncx nav item")
  }
  assert_eq(pkg.nav_points.length(), 1)
  assert_eq(pkg.nav_points[0].label, "Chapter One")
  assert_eq(pkg.nav_points[0].href, "chapter.xhtml#s1")
  assert_eq(pkg.nav_points[0].depth, 0)
  if pkg.nav_points[0].source_path != Some("OPS/toc.ncx") {
    fail("expected NCX source path on nav point")
  }
  match @epub.find_epub_nav_item(pkg) {
    Some(_) => fail("did not expect EPUB3 nav item in NCX-only package")
    None => ()
  }
  match @epub.find_epub_ncx_item(pkg) {
    Some(item) => assert_eq(item.resolved_path, "OPS/toc.ncx")
    None => fail("expected NCX item")
  }
  let nav_text = @epub.read_nav_document(pkg)
  if nav_text == None {
    fail("expected NCX nav document to be readable")
  }
}

///|
test "epub package keeps current ncx nested boundary stable" {
  let pkg = open_sample_package("samples/fixtures/epub/epub_ncx_nested.epub")
  assert_eq(pkg.nav_points.length(), 1)
  assert_eq(pkg.nav_points[0].label, "Part One")
  assert_eq(pkg.nav_points[0].depth, 0)
}

///|
test "epub package prefers epub3 nav over ncx" {
  let pkg = open_sample_package(
    "samples/fixtures/epub/epub_ncx_nav_priority.epub",
  )
  match pkg.nav_item {
    Some(item) => {
      assert_eq(item.resolved_path, "OPS/nav.xhtml")
      if !item.properties.contains("nav") {
        fail("expected EPUB3 nav to outrank NCX fallback")
      }
    }
    None => fail("expected nav item")
  }
  assert_eq(pkg.nav_points.length(), 1)
  assert_eq(pkg.nav_points[0].label, "EPUB3 Section")
  if pkg.nav_points[0].source_path != None {
    fail("epub3 nav points should keep current source_path behavior")
  }
}

///|
test "epub package skips unsafe ncx href and keeps safe points" {
  let pkg = open_sample_package(
    "samples/fixtures/epub/epub_ncx_unsafe_href.epub",
  )
  assert_eq(pkg.nav_points.length(), 1)
  assert_eq(pkg.nav_points[0].label, "Good")
  assert_eq(pkg.nav_points[0].href, "chapter.xhtml")
}

///|
test "epub package inventory preserves deterministic manifest and part ordering" {
  let pkg = open_sample_package(
    "samples/main_process/epub/epub_basic_package.epub",
  )
  let inventory = @epub.inspect_epub_inventory(pkg)
  assert_eq(inventory.parts.length(), inventory.part_count)
  assert_eq(inventory.parts[0].path, "META-INF/container.xml")
  assert_eq(inventory.parts[inventory.parts.length() - 1].path, "mimetype")

  let manifest = @epub.list_epub_manifest_items(pkg)
  assert_eq(manifest.length(), inventory.manifest_count)
  for i in 1..<manifest.length() {
    if manifest[i - 1].id[:].lexical_compare(manifest[i].id[:]) > 0 {
      fail(
        "expected manifest order to remain deterministic from OPF scan order",
      )
    }
  }
}

///|
test "epub package metadata entries expose non-empty fields only" {
  let pkg = open_sample_package(
    "samples/main_process/epub/metadata/epub_metadata_basic.epub",
  )
  let entries = @epub.list_epub_metadata(pkg)
  if entries.length() < 4 {
    fail("expected multiple metadata entries")
  }
  assert_eq(entries[0].name, "title")
  assert_eq(entries[0].value, "EPUB Metadata Sample")
}

///|
test "epub package selects first usable rootfile deterministically" {
  let pkg = open_inline_epub([
    ("mimetype", "application/epub+zip"),
    (
      "META-INF/container.xml",
      minimal_container([
        ("OPS/missing.opf", Some("application/oebps-package+xml")),
        ("OPS/content.opf", Some("application/oebps-package+xml")),
        ("OPS/alt.opf", Some("application/oebps-package+xml")),
      ]),
    ),
    (
      "OPS/content.opf",
      minimal_opf([("c1", "chapter.xhtml", "application/xhtml+xml", None)], [
        ("c1", None),
      ]),
    ),
    (
      "OPS/chapter.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body>ok</body></html>",
    ),
    (
      "OPS/alt.opf",
      minimal_opf([("c2", "chapter2.xhtml", "application/xhtml+xml", None)], [
        ("c2", None),
      ]),
    ),
    (
      "OPS/chapter2.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body>alt</body></html>",
    ),
  ])

  assert_eq(pkg.rootfile_path, "OPS/content.opf")
  let rootfiles = @epub.list_epub_rootfiles(pkg)
  assert_eq(rootfiles.length(), 3)
  assert_eq(rootfiles[0].full_path, "OPS/missing.opf")
  assert_eq(rootfiles[0].usable, false)
  assert_eq(rootfiles[1].full_path, "OPS/content.opf")
  assert_eq(rootfiles[1].is_primary, true)

  let report = @epub.validate_epub_package(pkg)
  if report.issues[0].kind !=
    @epub.EpubValidationIssueKind::MissingNavigationDocument {
    fail("expected missing navigation issue first")
  }
  if report.issues[1].kind != @epub.EpubValidationIssueKind::MultipleRootfiles {
    fail("expected multiple rootfiles issue second")
  }
}

///|
test "epub package validation reports duplicate spine idref deterministically" {
  let pkg = open_inline_epub([
    ("mimetype", "application/epub+zip"),
    (
      "META-INF/container.xml",
      minimal_container([
        ("OPS/content.opf", Some("application/oebps-package+xml")),
      ]),
    ),
    (
      "OPS/content.opf",
      minimal_opf(
        [
          ("c1", "chapter.xhtml", "application/xhtml+xml", None),
          ("nav", "nav.xhtml", "application/xhtml+xml", Some("nav")),
        ],
        [("c1", None), ("c1", None)],
      ),
    ),
    (
      "OPS/chapter.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body>dup</body></html>",
    ),
    (
      "OPS/nav.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><nav epub:type=\"toc\"><a href=\"chapter.xhtml\">One</a></nav></body></html>",
    ),
  ])

  let issues = @epub.collect_epub_validation_issues(pkg)
  assert_eq(issues.length(), 1)
  if issues[0].kind != @epub.EpubValidationIssueKind::DuplicateSpineIdref {
    fail("expected duplicate spine idref issue")
  }
  if issues[0].spine_idref != Some("c1") {
    fail("expected duplicate spine idref payload")
  }
}

///|
test "epub package missing nav and ncx is validation warning not fatal" {
  let pkg = open_inline_epub([
    ("mimetype", "application/epub+zip"),
    (
      "META-INF/container.xml",
      minimal_container([
        ("OPS/content.opf", Some("application/oebps-package+xml")),
      ]),
    ),
    (
      "OPS/content.opf",
      minimal_opf([("c1", "chapter.xhtml", "application/xhtml+xml", None)], [
        ("c1", None),
      ]),
    ),
    (
      "OPS/chapter.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body>plain</body></html>",
    ),
  ])

  match pkg.nav_item {
    Some(_) => fail("expected missing nav item")
    None => ()
  }
  let issues = @epub.collect_epub_validation_issues(pkg)
  assert_eq(issues.length(), 1)
  if issues[0].kind != @epub.EpubValidationIssueKind::MissingNavigationDocument {
    fail("expected missing navigation issue")
  }
}

///|
test "epub package nav outranks missing ncx without validation noise" {
  let pkg = open_inline_epub([
    ("mimetype", "application/epub+zip"),
    (
      "META-INF/container.xml",
      minimal_container([
        ("OPS/content.opf", Some("application/oebps-package+xml")),
      ]),
    ),
    (
      "OPS/content.opf",
      minimal_opf(
        [
          ("c1", "chapter.xhtml", "application/xhtml+xml", None),
          ("nav", "nav.xhtml", "application/xhtml+xml", Some("nav")),
        ],
        [("c1", None)],
      ),
    ),
    (
      "OPS/chapter.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body>plain</body></html>",
    ),
    (
      "OPS/nav.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><nav epub:type=\"toc\"><a href=\"chapter.xhtml\">One</a></nav></body></html>",
    ),
  ])

  let issues = @epub.collect_epub_validation_issues(pkg)
  assert_eq(issues.length(), 0)
}

///|
test "epub package validation warns on unsupported spine item" {
  let pkg = open_sample_package(
    "samples/fixtures/epub/epub_unsupported_spine_media.epub",
  )
  let issues = @epub.collect_epub_validation_issues(pkg)
  assert_eq(issues.length(), 2)
  if issues[0].kind != @epub.EpubValidationIssueKind::MissingNavigationDocument {
    fail("expected missing navigation issue first")
  }
  if issues[1].kind != @epub.EpubValidationIssueKind::UnsupportedSpineItem {
    fail("expected unsupported spine item issue second")
  }
  if issues[1].severity != @epub.EpubValidationSeverity::Warning {
    fail("expected unsupported spine item warning")
  }

  let report = @epub.validate_epub_package(pkg)
  assert_eq(report.issue_count, 2)
  assert_eq(report.error_count, 0)
  assert_eq(report.warning_count, 2)
}

///|
test "epub package keeps remote-resource handling above lower-layer package open" {
  let pkg = open_sample_package("samples/fixtures/epub/epub_remote_image.epub")
  assert_eq(pkg.entries.length(), 4)
  assert_eq(@epub.has_part(pkg, "OPS/content.opf"), true)
  assert_eq(@epub.has_part(pkg, "https://example.com/cover.jpg"), false)
  let inventory = @epub.inspect_epub_inventory(pkg)
  assert_eq(inventory.part_count, 4)
}

///|
test "epub package xml helpers ignore doctype and custom entity declarations without loading externals" {
  let pkg = open_inline_epub([
    ("mimetype", "application/epub+zip"),
    (
      "META-INF/container.xml",
      "<!DOCTYPE container SYSTEM \"http://example.com/container.dtd\">" +
      minimal_container([
        ("OPS/content.opf", Some("application/oebps-package+xml")),
      ]),
    ),
    (
      "OPS/content.opf",
      "<!DOCTYPE package [" +
      "<!ENTITY ext SYSTEM \"http://example.com/evil.ent\">" +
      "]>" +
      minimal_opf([("c1", "chapter.xhtml", "application/xhtml+xml", None)], [
        ("c1", None),
      ]),
    ),
    (
      "OPS/chapter.xhtml",
      "<!DOCTYPE html [" +
      "<!ENTITY ext SYSTEM \"http://example.com/chapter.ent\">" +
      "]>" +
      "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><h1>Safe</h1><p>&ext;</p></body></html>",
    ),
  ])

  assert_eq(pkg.rootfile_path, "OPS/content.opf")
  assert_eq(pkg.spine.length(), 1)
  if pkg.spine[0].resolved_path != Some("OPS/chapter.xhtml") {
    fail("expected chapter path to survive doctype prelude")
  }
  let chapter_text = @epub.read_part_text(pkg, "OPS/chapter.xhtml")
  if !chapter_text.contains("<!DOCTYPE html") {
    fail("expected chapter doctype to remain raw text, not executed")
  }
  if !chapter_text.contains("&ext;") {
    fail("expected custom entity reference to remain undecoded")
  }
}

///|
test "epub package keeps remote manifest resources without aborting open" {
  let pkg = open_inline_epub([
    ("mimetype", "application/epub+zip"),
    (
      "META-INF/container.xml",
      minimal_container([
        ("OPS/content.opf", Some("application/oebps-package+xml")),
      ]),
    ),
    (
      "OPS/content.opf",
      minimal_opf(
        [
          ("chap", "chapter.xhtml", "application/xhtml+xml", None),
          ("audio", "https://example.com/media/theme.mp3", "audio/mpeg", None),
        ],
        [("chap", None)],
      ),
    ),
    (
      "OPS/chapter.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body>Remote manifest sidecar should not block package open.</body></html>",
    ),
  ])

  assert_eq(pkg.manifest.length(), 2)
  match @epub.find_epub_manifest_item(pkg, "audio") {
    Some(item) =>
      assert_eq(item.resolved_path, "https://example.com/media/theme.mp3")
    None => fail("expected remote manifest item")
  }
  let reading_order = @epub.list_epub_spine_reading_order(pkg)
  assert_eq(reading_order.length(), 1)
  assert_eq(reading_order[0], "OPS/chapter.xhtml")
  assert_eq(@epub.has_part(pkg, "https://example.com/media/theme.mp3"), false)
}

///|
test "epub package ignores commented-out manifest items" {
  let pkg = open_inline_epub([
    ("mimetype", "application/epub+zip"),
    (
      "META-INF/container.xml",
      minimal_container([
        ("OPS/content.opf", Some("application/oebps-package+xml")),
      ]),
    ),
    (
      "OPS/content.opf",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<package xmlns=\"http://www.idpf.org/2007/opf\" version=\"3.0\">" +
      "<metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>Inline EPUB</dc:title></metadata>" +
      "<manifest>" +
      "<!-- <item id=\"chap\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\" properties=\"scripted\"/> -->" +
      "<item id=\"chap\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/>" +
      "<item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/>" +
      "</manifest>" +
      "<spine><itemref idref=\"chap\"/></spine>" +
      "</package>",
    ),
    (
      "OPS/chapter.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body>Commented manifest item should stay ignored.</body></html>",
    ),
    (
      "OPS/nav.xhtml", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><nav epub:type=\"toc\"><a href=\"chapter.xhtml\">One</a></nav></body></html>",
    ),
  ])

  assert_eq(pkg.manifest.length(), 2)
  let reading_order = @epub.list_epub_spine_reading_order(pkg)
  assert_eq(reading_order.length(), 1)
  assert_eq(reading_order[0], "OPS/chapter.xhtml")
  match @epub.find_epub_manifest_item(pkg, "chap") {
    Some(item) => assert_eq(item.resolved_path, "OPS/chapter.xhtml")
    None => fail("expected chapter manifest item")
  }
}

///|
test "epub package duplicate manifest id classifier stays additive" {
  let sample = resolve_sample_path(
    "samples/fixtures/epub/epub_duplicate_manifest_id.epub",
  )
  let bytes = @fs.read_file_to_bytes(sample) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  let result = try
    @epub.open_epub_package(bytes, sample_basename(sample)) |> Ok
  catch {
    e => Err(e)
  }
  match result {
    Ok(_) => fail("expected duplicate manifest package to fail")
    Err(err) => {
      let info = @epub.classify_epub_error(err)
      if info.kind != @epub.EpubErrorKind::DuplicateManifestId {
        fail("expected duplicate manifest classifier")
      }
      if info.manifest_id != Some("dup") {
        fail("expected duplicate manifest id payload")
      }
    }
  }
}
