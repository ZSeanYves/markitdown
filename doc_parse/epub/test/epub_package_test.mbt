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
  @epub.open_epub_package(bytes, @cor.basename(sample)) catch {
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
  let result = try? @epub.open_epub_package(bytes, @cor.basename(sample))
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
  assert_eq(pkg.spine[0].resolved_path, "OEBPS/chapter-02.xhtml")
  assert_eq(pkg.spine[1].resolved_path, "OEBPS/chapter-01.xhtml")
  assert_eq(pkg.spine[0].linear, true)
  assert_eq(pkg.spine[1].linear, true)
}

///|
test "epub package parses metadata basic" {
  let pkg = open_sample_package(
    "samples/metadata/epub/epub_metadata_basic.epub",
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
  assert_eq(pkg.spine[0].resolved_path, "OPS/chapter.xhtml")
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
    "samples/test/epub/epub_missing_container.epub", "missing EPUB part: META-INF/container.xml",
  )
}

///|
test "epub package rejects rootfile parent escape" {
  assert_open_epub_fails(
    "samples/test/epub/epub_rootfile_parent_escape.epub", "container.xml has no usable rootfile",
  )
}

///|
test "epub package rejects manifest href parent escape" {
  assert_open_epub_fails(
    "samples/test/epub/epub_manifest_href_parent_escape.epub", "invalid EPUB path: ../text/chapter.xhtml",
  )
}

///|
test "epub package rejects normalized collisions" {
  assert_open_epub_fails(
    "samples/test/epub/epub_normalized_collision.epub", "normalized path collision",
  )
}

///|
test "epub package rejects encryption xml" {
  assert_open_epub_fails(
    "samples/test/epub/epub_encryption_xml.epub", "DRM/encryption is not supported",
  )
}

///|
test "epub package rejects missing manifest item" {
  assert_open_epub_fails(
    "samples/test/epub/epub_missing_manifest_item.epub", "spine itemref missing manifest item",
  )
}

///|
test "epub package rejects duplicate manifest id" {
  assert_open_epub_fails(
    "samples/test/epub/epub_duplicate_manifest_id.epub", "duplicate manifest id",
  )
}
