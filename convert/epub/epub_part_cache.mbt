///|
priv struct EpubPartCache {
  bytes_by_path : Map[String, Bytes]
  text_by_path : Map[String, String]
  max_cached_bytes : Int
  byte_read_count : Ref[Int]
  byte_hit_count : Ref[Int]
  text_decode_count : Ref[Int]
  text_hit_count : Ref[Int]
}

///|
fn new_epub_part_cache(max_cached_bytes : Int) -> EpubPartCache {
  {
    bytes_by_path: Map([]),
    text_by_path: Map([]),
    max_cached_bytes,
    byte_read_count: { val: 0 },
    byte_hit_count: { val: 0 },
    text_decode_count: { val: 0 },
    text_hit_count: { val: 0 },
  }
}

///|
fn read_epub_part_bytes_cached(
  cache : EpubPartCache,
  pkg : @epubpkg.EpubPackage,
  part_path : String,
) -> Bytes raise @epubpkg.EpubError {
  let key = match epub_part_cache_key(part_path) {
    Some(path) => path
    None => return @epubpkg.read_part_bytes(pkg, part_path)
  }

  match cache.bytes_by_path.get(key) {
    Some(bytes) => {
      cache.byte_hit_count.val += 1
      bytes
    }
    None => {
      let bytes = @epubpkg.read_part_bytes(pkg, key)
      cache.byte_read_count.val += 1
      if should_cache_epub_part(cache, bytes) {
        cache.bytes_by_path.set(key, bytes)
      }
      bytes
    }
  }
}

///|
fn read_epub_part_text_cached(
  cache : EpubPartCache,
  pkg : @epubpkg.EpubPackage,
  part_path : String,
) -> String raise @epubpkg.EpubError {
  let key = match epub_part_cache_key(part_path) {
    Some(path) => path
    None => return @epubpkg.read_part_text(pkg, part_path)
  }

  match cache.text_by_path.get(key) {
    Some(text) => {
      cache.text_hit_count.val += 1
      text
    }
    None => {
      let bytes = read_epub_part_bytes_cached(cache, pkg, key)
      let text = @utf8.decode(bytes, ignore_bom=false) catch {
        _ => raise @epubpkg.InvalidXml("utf8 decode failed for `" + key + "`")
      }
      cache.text_decode_count.val += 1
      if should_cache_epub_part(cache, bytes) {
        cache.text_by_path.set(key, text)
      }
      text
    }
  }
}

///|
fn should_cache_epub_part(cache : EpubPartCache, bytes : Bytes) -> Bool {
  cache.max_cached_bytes < 0 || bytes.length() <= cache.max_cached_bytes
}

///|
fn epub_part_cache_key(part_path : String) -> String? {
  let raw = strip_epub_part_fragment_and_query(part_path.trim().to_owned())
  if raw == "" || raw.contains("\\") || raw.has_prefix("/") {
    return None
  }
  if raw.length() >= 2 && raw[1] == ':' {
    return None
  }
  if epub_part_has_scheme_like_prefix(raw.to_lower()) {
    return None
  }
  normalize_entry_path(raw)
}

///|
fn strip_epub_part_fragment_and_query(value : String) -> String {
  let mut end = value.length()
  for i in 0..<value.length() {
    if value[i] == '#' || value[i] == '?' {
      end = i
      break
    }
  }
  value[:end].trim().to_owned()
}

///|
fn epub_part_has_scheme_like_prefix(src : String) -> Bool {
  for i in 0..<src.length() {
    match src[i] {
      ':' => return i > 0
      '/' | '?' | '#' => return false
      _ => ()
    }
  }
  false
}
