///|
fn resolve_epub_cache_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn open_epub_cache_sample(path : String) -> @epubpkg.EpubPackage raise {
  let sample = resolve_epub_cache_sample_path(path)
  let bytes = @fs.read_file_to_bytes(sample) catch {
    e => fail("read EPUB fixture failed: " + e.to_string())
  }
  @epubpkg.open_epub_package(bytes, @cor.basename(sample)) catch {
    e => fail("open EPUB fixture failed: " + e.to_string())
  }
}

///|
test "epub part cache reuses bytes within one run" {
  let pkg = open_epub_cache_sample(
    "samples/main_process/epub/epub_basic_package.epub",
  )
  let cache = new_epub_part_cache(MAX_SINGLE_ENTRY_BYTES)

  let first = read_epub_part_bytes_cached(cache, pkg, "OPS/chapter.xhtml")
  let second = read_epub_part_bytes_cached(
    cache, pkg, "OPS/chapter.xhtml#section",
  )

  assert_eq(first.length(), second.length())
  assert_eq(cache.byte_read_count.val, 1)
  assert_eq(cache.byte_hit_count.val, 1)
}

///|
test "epub part cache size cap keeps oversized reads uncached" {
  let pkg = open_epub_cache_sample(
    "samples/main_process/epub/epub_basic_package.epub",
  )
  let cache = new_epub_part_cache(0)

  let first = read_epub_part_bytes_cached(cache, pkg, "OPS/chapter.xhtml")
  let second = read_epub_part_bytes_cached(cache, pkg, "OPS/chapter.xhtml")

  assert_eq(first.length(), second.length())
  assert_eq(cache.byte_read_count.val, 2)
  assert_eq(cache.byte_hit_count.val, 0)
}

///|
test "epub part cache reuses decoded text within one run" {
  let pkg = open_epub_cache_sample(
    "samples/main_process/epub/epub_basic_package.epub",
  )
  let cache = new_epub_part_cache(MAX_SINGLE_ENTRY_BYTES)

  let first = read_epub_part_text_cached(cache, pkg, "OPS/chapter.xhtml")
  let second = read_epub_part_text_cached(cache, pkg, "OPS/chapter.xhtml")

  assert_eq(first, second)
  assert_eq(cache.byte_read_count.val, 1)
  assert_eq(cache.text_decode_count.val, 1)
  assert_eq(cache.text_hit_count.val, 1)
}
