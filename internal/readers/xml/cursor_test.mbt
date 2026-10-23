///|
fn cursor_limits(
  depth~ : Int64 = 32L,
  token~ : Int64 = 4096L,
  attributes~ : Int64 = 32L,
  tokens~ : Int64 = 1024L,
  fragment~ : Int32 = 8,
) -> @xml.XmlCursorLimits {
  @xml.XmlCursorLimits::new(
    @budget.Enforced,
    max_depth=Some(depth),
    max_token_bytes=Some(token),
    max_attributes=Some(attributes),
    max_tokens=Some(tokens),
    text_fragment_bytes=fragment,
  ).unwrap()
}

///|
priv struct CursorSample {
  starts : Array[(@xml.XmlCursorName, Array[@xml.XmlCursorAttribute])]
  ends : Array[@xml.XmlCursorName]
  texts : Array[String]
  cdatas : Array[String]
  text_spans : Array[@xml.XmlCursorSpan]
  cdata_spans : Array[@xml.XmlCursorSpan]
  text_starts : Array[@xml.XmlCursorPosition]
  end_spans : Array[@xml.XmlCursorSpan]
  comments : Array[String]
  instructions : Array[(String, String)]
  doctypes : Array[String]
  stats : @xml.XmlCursorStats
}

///|
fn cursor_sample(
  bytes : Bytes,
  chunk_size : Int32,
  fragment~ : Int32 = 8,
) -> CursorSample raise {
  let cursor = @xml.new_xml_cursor(cursor_limits(fragment~)).unwrap()
  defer cursor.close()
  let starts = []
  let ends = []
  let texts = []
  let cdatas = []
  let text_spans = []
  let cdata_spans = []
  let text_starts = []
  let end_spans = []
  let comments = []
  let instructions = []
  let doctypes = []
  let builder = StringBuilder()
  let mut start : @xml.XmlCursorPosition? = None
  let mut previous_end : @xml.XmlCursorPosition? = None
  let mut offset = 0
  while true {
    match cursor.next().unwrap() {
      NeedInput => {
        let end = (offset + chunk_size).min(bytes.length())
        cursor
        .feed(bytes[offset:end].to_owned(), eof=end == bytes.length())
        .unwrap()
        offset = end
      }
      End => break
      Token(token) =>
        match token {
          StartElement(name, attributes, _, _) =>
            starts.push((name, attributes))
          EndElement(name, span) => {
            ends.push(name)
            end_spans.push(span)
          }
          TextFragment(value) | CDataFragment(value) => {
            assert_true(@utf8.encode(value.text).length() <= fragment)
            if value.first {
              builder.reset()
              start = Some(value.span.start)
              previous_end = None
            }
            if previous_end is Some(expected) {
              assert_true(value.span.start == expected)
            }
            previous_end = Some(value.span.end)
            builder.write_string(value.text)
            if value.last {
              if token is TextFragment(_) {
                texts.push(builder.to_string())
                text_spans.push(value.span)
                text_starts.push(start.unwrap())
              } else {
                cdatas.push(builder.to_string())
                cdata_spans.push(value.span)
              }
              // Store the first/last positions without constructing a read-only
              // foreign record. Public span equality is checked separately below.
              assert_true(start is Some(_))
            }
          }
          Comment(text, _) => comments.push(text)
          ProcessingInstruction(target, body, _) =>
            instructions.push((target, body))
          Doctype(text, _) => doctypes.push(text)
          Declaration(_, _) => ()
        }
    }
  }
  {
    starts,
    ends,
    texts,
    cdatas,
    text_spans,
    cdata_spans,
    text_starts,
    end_spans,
    comments,
    instructions,
    doctypes,
    stats: cursor.stats(),
  }
}

///|
fn cursor_failure(
  bytes : Bytes,
  limits : @xml.XmlCursorLimits,
  chunk_size~ : Int32 = 1,
) -> @xml.XmlCursorError raise {
  let cursor = @xml.new_xml_cursor(limits).unwrap()
  defer cursor.close()
  let mut offset = 0
  while true {
    match cursor.next() {
      Err(error) => return error
      Ok(End) => fail("expected a controlled XML cursor error")
      Ok(NeedInput) => {
        let end = (offset + chunk_size).min(bytes.length())
        match
          cursor.feed(bytes[offset:end].to_owned(), eof=end == bytes.length()) {
          Err(error) => return error
          Ok(_) => ()
        }
        offset = end
      }
      Ok(Token(_)) => ()
    }
  }
  fail("unreachable XML cursor failure helper")
}

///|
test "XML cursor partitions preserve Unicode raw offsets CRLF and single entity decoding" {
  let source = "\u{FEFF}<r>😀\r\né&amp;lt;&#x1F600;</r>"
  let bytes = @utf8.encode(source)
  for chunk_size in [1, 2, 3, 7, 65536] {
    let sample = cursor_sample(bytes, chunk_size)
    assert_eq(sample.texts, ["😀\né&lt;😀"])
    assert_eq(sample.text_spans.length(), 1)
    let span = sample.text_spans[0]
    let start = sample.text_starts[0]
    assert_eq(start.utf8_byte, 6L)
    assert_eq(start.scalar, 4L)
    assert_eq(start.utf16, 4L)
    assert_eq(start.line, 1L)
    assert_eq(start.column, 4L)
    assert_eq(span.end.utf8_byte, bytes.length().to_int64() - 4L)
    assert_eq(span.end.line, 2L)
    assert_eq(sample.stats.input_bytes, bytes.length().to_int64())
    assert_eq(sample.stats.logical_tokens, 3L)
    assert_eq(sample.ends[0].raw, "r")
    assert_eq(sample.end_spans[0].end.utf8_byte, bytes.length().to_int64())
    assert_eq(sample.end_spans[0].end.utf16, source.length().to_int64())
    assert_eq(
      sample.end_spans[0].end.scalar,
      source.to_array().length().to_int64(),
    )
  }
}

///|
test "XML cursor attributes honor quoted greater-than and retain exact source provenance" {
  let bytes = @utf8.encode(
    "<r xmlns=\"urn:r\" a=\"x>y &amp;lt;\" b='😀&#x1F600;'/>",
  )
  for chunk_size in [1, 2, 3, 7, 65536] {
    let sample = cursor_sample(bytes, chunk_size)
    assert_eq(sample.starts.length(), 1)
    let (name, attributes) = sample.starts[0]
    assert_eq(name.namespace_uri, Some("urn:r"))
    assert_eq(attributes[1].value, "x>y &lt;")
    assert_eq(attributes[1].quote, '"')
    assert_eq(attributes[1].span.start.utf8_byte, 17L)
    assert_eq(attributes[1].span.end.utf8_byte, 33L)
    assert_eq(attributes[1].name.namespace_uri, None)
    assert_eq(attributes[2].value, "😀😀")
    assert_eq(attributes[2].quote, '\'')
    assert_true(attributes[0].namespace_declaration)
  }
}

///|
test "XML cursor namespace deltas apply regardless of attribute order and restore after empty elements" {
  let bytes = b"<a:r xmlns:a=\"urn:a\" xmlns=\"urn:d\"><a:x a:q=\"1\" plain=\"v\" xmlns:a=\"urn:b\"/><a:y/><z xmlns=\"\"/></a:r>"
  for chunk_size in [1, 2, 3, 7, 65536] {
    let sample = cursor_sample(bytes, chunk_size)
    assert_eq(sample.starts.map(pair => pair.0.namespace_uri), [
      Some("urn:a"),
      Some("urn:b"),
      Some("urn:a"),
      None,
    ])
    assert_eq(sample.starts[1].1[0].name.namespace_uri, Some("urn:b"))
    assert_eq(sample.starts[1].1[1].name.namespace_uri, None)
    assert_eq(sample.ends[0].namespace_uri, Some("urn:a"))
    assert_eq(sample.stats.max_depth, 2L)
    assert_eq(sample.stats.max_namespace_bindings, 3L)
    let nested = cursor_sample(
      b"<a:r xmlns:a='urn:a'><a:x xmlns:a='urn:b'><a:z/></a:x><a:y/></a:r>", chunk_size,
    )
    assert_eq(nested.starts.map(pair => pair.0.namespace_uri), [
      Some("urn:a"),
      Some("urn:b"),
      Some("urn:b"),
      Some("urn:a"),
    ])
    assert_eq(nested.ends.map(name => name.namespace_uri), [
      Some("urn:b"),
      Some("urn:a"),
    ])
  }
}

///|
test "XML cursor bounded CDATA ignores fake markup and preserves cross-chunk delimiters" {
  let bytes = @utf8.encode(
    "<?xml version='1.0'?><!DOCTYPE r [<!ENTITY x '>'>]><r><!-- <fake/> --><?p x>y?><![CDATA[😀]]x]]]>tail<![CDATA[&amp;\r\n<fake/>]]></r>",
  )
  for chunk_size in [1, 2, 3, 7, 65536] {
    let sample = cursor_sample(bytes, chunk_size, fragment=4)
    assert_eq(sample.starts.length(), 1)
    assert_eq(sample.comments, [" <fake/> "])
    assert_eq(sample.instructions, [("p", "x>y")])
    assert_eq(sample.doctypes, ["r [<!ENTITY x '>'>]"])
    assert_eq(sample.cdatas, ["😀]]x]", "&amp;\n<fake/>"])
    assert_eq(sample.cdata_spans.length(), 2)
    assert_eq(sample.texts, ["tail"])
    assert_eq(sample.stats.logical_tokens, 9L)
  }
}

///|
test "XML cursor rejects malformed EOF encoding QName and expanded attribute collisions" {
  for
    bytes in [
      b"<r>", b"<r><!--x", b"<r><![CDATA[x", b"<r>&amp", b"<r a='x", b"<r/", b"<r></s>",
    ] {
    assert_true(cursor_failure(bytes, cursor_limits()) is Syntax(_, _, _))
  }
  for bytes in [b"<r>\xff</r>", b"<r>\xf0\x9f", b"<r>\xed\xa0\x80</r>"] {
    assert_true(cursor_failure(bytes, cursor_limits()) is InvalidEncoding(_, _))
  }
  for
    bytes in [
      b"<p:r/>", b"<r xmlns:xml='urn:wrong'/>", b"<r xmlns:p=''/>", b"<r xmlns:a='u' xmlns:b='u' a:q='1' b:q='2'/>",
      b"<a:1 xmlns:a='u'/>", b"<r xmlns:1='u'/>",
    ] {
    assert_true(cursor_failure(bytes, cursor_limits()) is Syntax(_, _, _))
  }
  assert_true(
    cursor_failure(b"<r>&#4294967361;</r>", cursor_limits())
    is Syntax(MalformedEntity, _, _),
  )
}

///|
test "XML cursor explicit caps distinguish depth atomic markup attributes and logical tokens" {
  assert_true(
    cursor_failure(b"<r><a/></r>", cursor_limits(depth=1L))
    is Limit(Depth, observed=2L, limit=1L),
  )
  assert_true(
    cursor_failure(b"<r a='v'/>", cursor_limits(token=5L))
    is Limit(TokenBytes, ..),
  )
  assert_true(
    cursor_failure(b"<r a='1' b='2'/>", cursor_limits(attributes=1L))
    is Limit(Attributes, observed=2L, limit=1L),
  )
  assert_true(
    cursor_failure(b"<r>x</r>", cursor_limits(tokens=2L))
    is Limit(Tokens, observed=3L, limit=2L),
  )
  assert_true(
    @xml.XmlCursorLimits::new(
      @budget.Enforced,
      max_depth=None,
      max_token_bytes=None,
      max_attributes=None,
      max_tokens=None,
      text_fragment_bytes=4,
    )
    is Err(InvalidState(_)),
  )
  let measured = @xml.XmlCursorLimits::new(
    @budget.MeasurementOnly,
    max_depth=None,
    max_token_bytes=None,
    max_attributes=None,
    max_tokens=None,
    text_fragment_bytes=4,
  ).unwrap()
  let cursor = @xml.new_xml_cursor(measured).unwrap()
  defer cursor.close()
  cursor.feed(b"<r/>", eof=true).unwrap()
  assert_true(cursor.next() is Ok(Token(StartElement(_, _, true, _))))
  assert_true(cursor.next() is Ok(End))
  assert_eq(cursor.stats().max_markup_bytes, 4L)
  let exact = @xml.new_xml_cursor(
    cursor_limits(depth=1L, token=4L, attributes=0L, tokens=1L),
  ).unwrap()
  defer exact.close()
  exact.feed(b"<r/>", eof=true).unwrap()
  assert_true(exact.next() is Ok(Token(StartElement(_, _, true, _))))
  assert_true(exact.next() is Ok(End))
}

///|
test "XML cursor feed protocol errors are sticky and close is idempotent" {
  let cursor = @xml.new_xml_cursor(cursor_limits()).unwrap()
  assert_true(cursor.next() is Ok(NeedInput))
  cursor.feed(b"<r/>", eof=false).unwrap()
  assert_true(cursor.feed(b"", eof=true) is Err(InvalidState(_)))
  assert_true(cursor.next() is Err(InvalidState(_)))
  cursor.close()
  cursor.close()
  let closed = @xml.new_xml_cursor(cursor_limits()).unwrap()
  closed.close()
  assert_true(closed.next() is Err(InvalidState(_)))
}
