name = "ZSeanYves/markitdown"

version = "0.5.2"

import {
  "bikallem/blit@0.2.2",
  "moonbitlang/x@0.4.40",
  "TheWaWaR/clap@0.2.6",
  "moonbitlang/async@0.16.6",
  "bikallem/compress@0.3.4",
  "tonyfettes/unicode@0.3.0",
  "tonyfettes/encoding@0.3.9",
}

readme = "README.mbt.md"

repository = "https://github.com/ZSeanYves/markitdown.git"

license = "Apache-2.0"

keywords = [
  "moonbit",
  "markdown",
  "document-to-markdown",
  "document-conversion",
  "ocr",
  "pdf",
  "docx",
  "xlsx",
  "pptx",
  "epub",
  "rag",
  "content-ingestion",
  "cli",
]

description = "A MoonBit-native document-to-Markdown converter with multi-format parsing, metadata, assets, batch conversion, and validation tooling"

preferred_target = "native"

options(
  exclude: [ "markitdown-quality-lab/**" ],
)
