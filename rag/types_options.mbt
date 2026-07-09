///|
/// Chunking options used by the RAG JSON render path.
///
/// These options affect both chunk boundaries and how much structural or
/// provenance context each chunk retains.
pub struct RagOptions {
  chunk_size : Int
  chunk_overlap : Int
  preserve_heading_path : Bool
  preserve_source_ref : Bool
  split_tables : Bool
  split_code_blocks : Bool
}

///|
/// Public chunk kinds emitted by the RAG render path.
pub(all) enum ChunkKind {
  Text
  Table
  Code
  ImageCaption
  Metadata
  Raw
} derive(Eq)

///|
/// Construct one public RAG chunk value.
pub fn make_rag_chunk(
  id : String,
  kind : ChunkKind,
  text : String,
  heading_path : Array[String],
  source_refs : Array[@core.SourceRef],
  asset_refs : Array[String],
  metadata : Map[String, @core.JsonValue],
) -> RagChunk {
  { id, kind, text, heading_path, source_refs, asset_refs, metadata }
}

///|
/// One retrieval-oriented chunk emitted by the RAG renderer.
///
/// `heading_path`, `source_refs`, and `asset_refs` let downstream indexing
/// systems preserve navigation context and provenance alongside the text body.
pub struct RagChunk {
  id : String
  kind : ChunkKind
  text : String
  heading_path : Array[String]
  source_refs : Array[@core.SourceRef]
  asset_refs : Array[String]
  metadata : Map[String, @core.JsonValue]
}

///|
/// Return the default chunking policy used by product RAG output.
pub fn default_rag_options() -> RagOptions {
  {
    chunk_size: 1200,
    chunk_overlap: 150,
    preserve_heading_path: true,
    preserve_source_ref: true,
    split_tables: true,
    split_code_blocks: true,
  }
}

///|
/// Construct explicit RAG options, applying normalization to invalid size or
/// overlap values.
pub fn make_rag_options(
  chunk_size : Int,
  chunk_overlap : Int,
  preserve_heading_path : Bool,
  preserve_source_ref : Bool,
  split_tables : Bool,
  split_code_blocks : Bool,
) -> RagOptions {
  {
    chunk_size: rag_chunk_size_or_default(chunk_size),
    chunk_overlap: rag_chunk_overlap_or_default(chunk_overlap),
    preserve_heading_path,
    preserve_source_ref,
    split_tables,
    split_code_blocks,
  }
}

///|
fn rag_chunk_size_or_default(value : Int) -> Int {
  if value <= 0 {
    default_rag_options().chunk_size
  } else {
    value
  }
}

///|
fn rag_chunk_overlap_or_default(value : Int) -> Int {
  if value < 0 {
    default_rag_options().chunk_overlap
  } else {
    value
  }
}

///|
/// Normalize chunk size/overlap while preserving the remaining options.
pub fn normalize_rag_options(options : RagOptions) -> RagOptions {
  {
    chunk_size: rag_chunk_size_or_default(options.chunk_size),
    chunk_overlap: rag_chunk_overlap_or_default(options.chunk_overlap),
    preserve_heading_path: options.preserve_heading_path,
    preserve_source_ref: options.preserve_source_ref,
    split_tables: options.split_tables,
    split_code_blocks: options.split_code_blocks,
  }
}

///|
/// Return the stable string name for a chunk kind.
pub fn chunk_kind_name(kind : ChunkKind) -> String {
  match kind {
    ChunkKind::Text => "text"
    ChunkKind::Table => "table"
    ChunkKind::Code => "code"
    ChunkKind::ImageCaption => "image_caption"
    ChunkKind::Metadata => "metadata"
    ChunkKind::Raw => "raw"
  }
}

///|
