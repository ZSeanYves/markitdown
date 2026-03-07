///|
/// list ppt/slides/slide*.xml
fn list_slide_entries(z : @cor.ZipReader) -> Array[String] {
  let all = @cor.ZipReader::list_entries(z)
  let out : Array[String] = []
  for name in all {
    if name.has_prefix("ppt/slides/slide") && name.has_suffix(".xml") {
      out.push(name)
    }
  }
  // 简单字典序排序会让 slide10 排在 slide2 前；MVP 先这样也行
  out.sort()
  out
}

///|
async fn read_zip_bytes(z : @cor.ZipReader, name : String) -> Bytes {
  @cor.ZipReader::read_entry_bytes(z, name) catch {
    e =>
      raise @cor.AppError(
        "pptx: read zip entry failed: " + name + ": " + e.to_string(),
      )
  }
}
