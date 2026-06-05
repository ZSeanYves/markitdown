///|
/// Bundled product component delegation for formats kept outside the main CLI
/// closure.
///
/// PDF and ZIP stay as explicit bundled components so the user-facing CLI does
/// not pull in the heavier PDF/ZIP runtime closures directly.
async fn delegate_pdf_conversion(
  input : String,
  output : String?,
  with_metadata : Bool,
) -> Result[Unit, String] {
  match
    @clicom.delegate_external_command(
      "bundled PDF support component",
      "pdf",
      "MARKITDOWN_PDF_CLI",
      external_component_args(input, output, with_metadata),
    ) {
    Ok(_) => Ok(())
    Err(msg) =>
      Err(
        "pdf support is unavailable in this product bundle: " +
        msg +
        ". Rebuild pdf alongside cli, or set MARKITDOWN_PDF_CLI for an explicit component path.",
      )
  }
}

///|
async fn delegate_zip_conversion(
  input : String,
  output : String?,
  with_metadata : Bool,
) -> Result[Unit, String] {
  match
    @clicom.delegate_external_command(
      "bundled ZIP support component",
      "zip",
      "MARKITDOWN_ZIP_CLI",
      external_component_args(input, output, with_metadata),
    ) {
    Ok(_) => Ok(())
    Err(msg) =>
      Err(
        "zip support is unavailable in this product bundle: " +
        msg +
        ". Rebuild zip alongside cli, or set MARKITDOWN_ZIP_CLI for an explicit component path.",
      )
  }
}

///|
fn external_component_args(
  input : String,
  output : String?,
  with_metadata : Bool,
) -> Array[String] {
  let args : Array[String] = ["normal"]
  if with_metadata {
    args.push("--with-metadata")
  }
  args.push(input)
  match output {
    Some(out) => args.push(out)
    None => ()
  }
  args
}
