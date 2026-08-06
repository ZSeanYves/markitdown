///|
fn capability(
  format : String,
  canonical_format? : String = format,
  convert_modes? : Array[ConvertMode] = [Balanced],
  status? : CapabilityStatus = Stable,
  external_requirements? : Array[String] = [],
) -> Capability {
  {
    format,
    canonical_format,
    status,
    input_kinds: [Path, Text, Bytes, Reader],
    convert_modes,
    output_modes: [Markdown, Debug, Rag],
    external_requirements,
  }
}

///|
/// Return the format and extension capability manifest for this build.
pub fn capabilities() -> Array[Capability] {
  let stream_formats = [
    "txt", "markdown", "csv", "tsv", "srt", "vtt", "json", "jsonl", "ndjson", "ipynb",
    "xml", "yaml", "html", "eml", "epub", "odt", "ods", "odp", "xlsx",
  ]
  let output = stream_formats.map(format => {
    capability(
      format,
      convert_modes=if ["odt", "ods", "odp", "xlsx"].contains(format) {
        [Balanced, Accurate, Stream]
      } else {
        [Balanced, Stream]
      },
    )
  })
  for format in ["toml", "tex", "rst", "asciidoc", "zip"] {
    output.push(capability(format))
  }
  for format in ["pdf", "docx", "pptx"] {
    output.push(capability(format, convert_modes=[Balanced, Accurate]))
  }
  output.push(
    capability("md", canonical_format="markdown", convert_modes=[
      Balanced,
      Stream,
    ]),
  )
  output.push(
    capability("yml", canonical_format="yaml", convert_modes=[Balanced, Stream]),
  )
  output.push(
    capability("htm", canonical_format="html", convert_modes=[Balanced, Stream]),
  )
  output.push(capability("latex", canonical_format="tex"))
  output.push(capability("adoc", canonical_format="asciidoc"))
  output.push(
    capability(
      "msg",
      canonical_format="eml",
      convert_modes=[Balanced, Stream],
      status=Experimental,
      external_requirements=[
        "RFC822/EML content only; binary Outlook MSG is unsupported",
      ],
    ),
  )
  for format in ["wav", "mp3", "m4a"] {
    output.push(
      capability(format, status=ExternalRuntime, external_requirements=[
        "audio transcription runtime",
      ]),
    )
  }
  for format in ["png", "jpg", "jpeg", "bmp", "webp", "tif", "tiff"] {
    output.push(
      capability(
        format,
        convert_modes=[Balanced, Accurate],
        status=ExternalRuntime,
        external_requirements=["OCR runtime"],
      ),
    )
  }
  output
}
