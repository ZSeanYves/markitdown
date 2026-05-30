///|
/// CLI output path, metadata sidecar, and document-property helpers.
///
/// These wrappers keep the `cli_support` public surface stable while keeping
/// output glue separate from the normal conversion control flow.
pub fn write_document_output(
  input : String,
  format : String,
  doc : @cor.Document,
  output : String?,
  with_metadata : Bool,
) -> Result[Unit, String] {
  @clicom.write_document_output_with_document_properties(
    input,
    format,
    doc,
    output,
    with_metadata,
    read_document_properties(input, format),
  )
}

///|
pub fn resolve_output_path(input : String, output : String?) -> String? {
  @clicom.resolve_output_path(input, output)
}

///|
pub fn dirname_of_path(path : String) -> String {
  @clicom.dirname_of_path(path)
}

///|
pub fn join_path(dir : String, file : String) -> String {
  @clicom.join_path(dir, file)
}

///|
pub fn input_stem(path : String) -> String {
  @clicom.input_stem(path)
}

///|
pub fn metadata_output_path(markdown_path : String) -> String {
  @clicom.metadata_output_path(markdown_path)
}

///|
pub fn ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  @clicom.ensure_dir_tree(path)
}

///|
pub fn read_document_properties(
  input : String,
  format : String,
) -> @cor.MetadataDocumentProperties? {
  if format == "docx" || format == "pptx" || format == "xlsx" {
    return read_ooxml_document_properties(input)
  }
  if format == "epub" {
    return read_epub_document_properties(input)
  }
  None
}

///|
fn read_ooxml_document_properties(
  input : String,
) -> @cor.MetadataDocumentProperties? {
  let bytes = @fs.read_file_to_bytes(input) catch { _ => return None }
  let pkg = @ox.open_ooxml_package(bytes) catch { _ => return None }
  let core = @ox.read_core_properties(pkg)
  let app = @ox.read_app_properties(pkg)

  Some(
    @cor.metadata_document_properties(
      core.title,
      core.subject,
      core.creator,
      core.description,
      core.keywords,
      core.created,
      core.modified,
      app.application,
      app.pages,
      app.words,
      app.slides,
      app.sheets,
    ),
  )
}

///|
fn read_epub_document_properties(
  input : String,
) -> @cor.MetadataDocumentProperties? {
  let bytes = @fs.read_file_to_bytes(input) catch { _ => return None }
  let pkg = @epubpkg.open_epub_package(bytes, @cor.basename(input)) catch {
    _ => return None
  }
  let meta = pkg.metadata

  let props = @cor.metadata_document_properties(
    meta.title,
    None,
    meta.creator,
    None,
    None,
    meta.date,
    meta.modified,
    Some("EPUB"),
    None,
    None,
    None,
    None,
  )
  Some(
    @cor.metadata_document_properties_with_extras(
      props,
      meta.language,
      meta.identifier,
      meta.publisher,
    ),
  )
}
