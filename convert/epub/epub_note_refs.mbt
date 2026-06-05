///|
fn namespace_epub_subdoc_notes(
  subdoc : @cor.Document,
  entry_id : String,
) -> @cor.Document {
  if subdoc.note_definitions.val.length() == 0 {
    return subdoc
  }

  let id_map : Map[String, String] = {}
  for note in subdoc.note_definitions.val {
    let old_id = note.note_id.trim().to_owned()
    if old_id != "" {
      id_map[old_id] = entry_id + "-" + old_id
    }
  }
  if id_map.length() == 0 {
    return subdoc
  }

  let out = @cor.new_document()
  for i in 0..<subdoc.blocks.val.length() {
    @cor.push_with_origin(
      out,
      remap_note_refs_in_block(subdoc.blocks.val[i], id_map),
      origin_at(subdoc, i),
    )
  }
  for entry in subdoc.asset_origins.val {
    let (path, origin) = entry
    @cor.set_asset_origin(out, path, origin)
  }
  for note in subdoc.note_definitions.val {
    @cor.push_note_definition(out, namespace_epub_note_definition(note, id_map))
  }
  out
}

///|
fn namespace_epub_note_definition(
  note : @cor.NoteDefinition,
  id_map : Map[String, String],
) -> @cor.NoteDefinition {
  let note_id = id_map.get(note.note_id).unwrap_or(note.note_id)
  {
    ..note,
    note_id,
    blocks: note.blocks.map(fn(block) {
      remap_note_refs_in_block(block, id_map)
    }),
  }
}

///|
fn remap_note_refs_in_block(
  block : @cor.Block,
  id_map : Map[String, String],
) -> @cor.Block {
  match block {
    @cor.Block::RichHeading(level, inlines) =>
      @cor.Block::RichHeading(
        level,
        remap_note_refs_in_inlines(inlines, id_map),
      )
    @cor.Block::RichParagraph(inlines) =>
      @cor.Block::RichParagraph(remap_note_refs_in_inlines(inlines, id_map))
    @cor.Block::RichListItem(ordered, level, inlines) =>
      @cor.Block::RichListItem(
        ordered,
        level,
        remap_note_refs_in_inlines(inlines, id_map),
      )
    @cor.Block::RichBlockQuote(inlines) =>
      @cor.Block::RichBlockQuote(remap_note_refs_in_inlines(inlines, id_map))
    _ => block
  }
}

///|
fn remap_note_refs_in_inlines(
  inlines : Array[@cor.Inline],
  id_map : Map[String, String],
) -> Array[@cor.Inline] {
  inlines.map(fn(inline) {
    match inline {
      @cor.Inline::NoteRef(note) => {
        let note_id = id_map.get(note.note_id).unwrap_or(note.note_id)
        @cor.Inline::NoteRef({
          ..note,
          note_id,
          source_kind: @cor.NoteSourceKind::EpubNoteRef,
        })
      }
      _ => inline
    }
  })
}
