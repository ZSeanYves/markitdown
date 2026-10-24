///|
// A small JSON root array is represented by one existing List block/unit.
// Its children already carry their locations. Associate those locations only
// after ordinary chunking, keeping every successful body/ID/asset relation.
fn rag_json_root_list_with_child_sources(
  blocks : Array[@core.CoreBlock],
  document_format : String,
  chunks : Array[@rag.RagChunk],
  options : @rag.RagOptions,
) -> Array[@rag.RagChunk] {
  if !options.preserve_source_ref ||
    document_format != "json" ||
    blocks.length() != 1 {
    return chunks
  }
  let root = blocks[0]
  if root.kind != List ||
    root.children.is_empty() ||
    root.attrs.get("ordered") == Some("true") {
    return chunks
  }
  let parent = match @core.block_source_ref(root) {
    Some(source) if source.format == Some("json") &&
      source.json_pointer == Some("/") => source
    _ => return chunks
  }
  let children : Array[@core.SourceRef] = []
  for child in root.children {
    if child.kind != ListItem || !child.children.is_empty() {
      return chunks
    }
    match @core.block_source_ref(child) {
      Some(source) if source.format == Some("json") &&
        json_root_array_child_pointer(source.json_pointer) =>
        children.push(source)
      _ => return chunks
    }
  }
  let parent_key = rag_json_list_source_identity(parent)
  chunks.map(fn(chunk) {
    if chunk.kind != Text ||
      !chunk.source_refs.any(source => {
        rag_json_list_source_identity(source) == parent_key
      }) {
      return chunk
    }
    let sources = chunk.source_refs.copy()
    let seen : Map[String, Bool] = Map([])
    for source in sources {
      seen.set(rag_json_list_source_identity(source), true)
    }
    for source in children {
      let key = rag_json_list_source_identity(source)
      if !seen.contains(key) {
        seen.set(key, true)
        sources.push(source)
      }
    }
    chunk.with_source_refs(sources)
  })
}

///|
fn json_root_array_child_pointer(pointer : String?) -> Bool {
  match pointer {
    Some(pointer) if pointer.length() > 1 && pointer.has_prefix("/") => {
      for ch in pointer[1:] {
        if ch < '0' || ch > '9' {
          return false
        }
      }
      true
    }
    _ => false
  }
}
