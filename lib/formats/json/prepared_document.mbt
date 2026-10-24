///|
/// Preparation already validates and decodes these events. Build the existing
/// source model in event order so duplicate/empty keys and number spellings
/// survive without another lexical pass. Pointers are source facts, not keys.
priv struct JsonPreparedDocumentCursor {
  events : Array[JsonStreamEvent]
  mut position : Int32
}

///|
fn json_document_from_prepared_stream(
  stream : JsonStreamDocument,
) -> JsonDocument raise {
  let cursor = { events: stream.events, position: 0, }
  let root = cursor.read_value()
  guard cursor.position == cursor.events.length() else {
    raise ParseError("invalid prepared JSON event tail")
  }
  { root, }
}

///|
fn JsonPreparedDocumentCursor::read_event(
  self : JsonPreparedDocumentCursor,
) -> JsonStreamEvent raise {
  guard self.position < self.events.length() else {
    raise ParseError("incomplete prepared JSON events")
  }
  let event = self.events[self.position]
  self.position += 1
  event
}

///|
fn json_prepared_event_text(event : JsonStreamEvent) -> String raise {
  match event.text {
    Some(text) => text
    None => raise ParseError("missing prepared JSON event text")
  }
}

///|
fn JsonPreparedDocumentCursor::read_value(
  self : JsonPreparedDocumentCursor,
) -> JsonValue raise {
  let event = self.read_event()
  match event.kind {
    ObjectStart => {
      let members : Array[JsonMember] = []
      while true {
        let next = self.read_event()
        match next.kind {
          ObjectEnd => break
          Key => {
            let key = json_prepared_event_text(next)
            let value = self.read_value()
            members.push({ key, value, })
          }
          _ => raise ParseError("invalid prepared JSON object event")
        }
      }
      Object(members)
    }
    ArrayStart => {
      let items : Array[JsonValue] = []
      while true {
        guard self.position < self.events.length() else {
          raise ParseError("incomplete prepared JSON array events")
        }
        if self.events[self.position].kind == ArrayEnd {
          self.position += 1
          break
        }
        items.push(self.read_value())
      }
      Array(items)
    }
    StringValue => String(json_prepared_event_text(event))
    NumberValue => Number(json_prepared_event_text(event))
    BoolValue =>
      match json_prepared_event_text(event) {
        "true" => Bool(true)
        "false" => Bool(false)
        _ => raise ParseError("invalid prepared JSON boolean event")
      }
    NullValue => Null
    Key | ObjectEnd | ArrayEnd =>
      raise ParseError("unexpected prepared JSON value event")
  }
}
