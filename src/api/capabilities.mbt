///|
fn capability(
  format : String,
  canonical_format? : String = format,
  input_kinds? : Array[InputKind] = [Path, Text, Bytes, Reader],
  convert_modes? : Array[ConvertMode] = [Balanced],
  output_modes? : Array[OutputMode] = [Markdown, Debug, Rag],
  status? : CapabilityStatus = Stable,
  external_requirements? : Array[String] = [],
) -> Capability {
  {
    format,
    canonical_format,
    status,
    input_kinds,
    convert_modes,
    output_modes,
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
    output.push(
      capability(format, input_kinds=[Path, Bytes, Reader], convert_modes=[
        Balanced,
        Accurate,
      ]),
    )
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
  for
    format in [
      "xls", "outlook-msg", "rss", "atom", "wikipedia", "youtube", "bing-serp", "azure-document-intelligence",
    ] {
    output.push(
      capability(
        format,
        input_kinds=[],
        convert_modes=[],
        output_modes=[],
        status=Unsupported,
        external_requirements=["not available in the core 0.8 product"],
      ),
    )
  }
  for
    format in [
      "png", "jpg", "jpeg", "bmp", "webp", "tif", "tiff", "wav", "mp3", "m4a",
    ] {
    output.push(
      capability(
        format,
        input_kinds=[],
        convert_modes=[],
        output_modes=[],
        status=Unsupported,
        external_requirements=[
          "image recognition and audio transcription are outside the text-only core",
        ],
      ),
    )
  }
  output
}

///|
/// Return the capability registry in the same deterministic JSON shape used
/// by the CLI. Keeping serialization here makes the public API manifest the
/// single source for consumers and avoids a second CLI-only format list.
pub fn capabilities_json() -> String {
  let status_name = fn(status : CapabilityStatus) {
    match status {
      Stable => "stable"
      Experimental => "experimental"
      ExternalRuntime => "external_runtime"
      Unsupported => "unsupported"
    }
  }
  let quote_array = fn(values : Array[String]) {
    "[" + values.map(value => @core.json_string(value)).join(",") + "]"
  }
  let rows = capabilities().map(entry => {
    "{" +
    "\"format\":" +
    @core.json_string(entry.format) +
    ",\"canonical_format\":" +
    @core.json_string(entry.canonical_format) +
    ",\"status\":" +
    @core.json_string(status_name(entry.status)) +
    ",\"input_kinds\":" +
    quote_array(entry.input_kinds.map(input_kind_name)) +
    ",\"convert_modes\":" +
    quote_array(entry.convert_modes.map(convert_mode_name)) +
    ",\"output_modes\":" +
    quote_array(entry.output_modes.map(output_mode_name)) +
    ",\"external_requirements\":" +
    quote_array(entry.external_requirements) +
    "}"
  })
  "[" + rows.join(",") + "]"
}

///|
fn input_kind_name(kind : InputKind) -> String {
  match kind {
    Path => "path"
    Text => "text"
    Bytes => "bytes"
    Reader => "reader"
  }
}

///|
fn convert_mode_name(mode : ConvertMode) -> String {
  match mode {
    Balanced => "balance"
    Accurate => "accurate"
    Stream => "stream"
  }
}

///|
fn output_mode_name(mode : OutputMode) -> String {
  match mode {
    Markdown => "markdown"
    Debug => "debug"
    Rag => "rag"
  }
}
