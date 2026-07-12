///|
fn markup_blocks_of_kind(
  document : TextMarkupDocument,
  kind : TextMarkupBlockKind,
) -> Array[TextMarkupBlock] {
  document.blocks.filter(block => block.kind == kind)
}

///|
test "RST block parser covers compound directives lists tables and quotes" {
  let document = parse_markup_document(
    (
      #|========
      #|Overline heading
      #|========
      #|
      #|first paragraph line
      #|second paragraph line
      #|
      #|:author: Ada
      #|  Lovelace
      #|:status: ready
      #|
      #|Term
      #|  First definition line
      #|
      #|  Second definition line
      #|
      #|- bullet
      #|2. ordered
      #|
      #|+------+------+
      #|| Name | Value|
      #|+------+------+
      #|
      #|.. note:: Inline label
      #|   quoted body
      #|
      #|.. code-block:: moonbit
      #|   :linenos:
      #|
      #|   fn main {}
      #|
      #|.. literalinclude:: sample.mbt
      #|   :lines: 1-2
      #|
      #|.. include:: chapter.rst
      #|
      #|.. custom:: payload
      #|   option
      #|
      #|paragraph::
      #|  literal body
    ),
    TextMarkupFormat::Rst,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Heading).length() >= 1,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Paragraph).length() >=
    1,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Table).length() >= 3,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::ListItem).length() >= 2,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::BlockQuote).length() >=
    1,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Code).length() >= 2,
  )
  assert_true(
    document.blocks.any(block => {
      block.meta.get("include_target") == Some("chapter.rst")
    }),
  )
  assert_true(
    document.blocks.any(block => {
      block.meta.get("include_target") == Some("sample.mbt")
    }),
  )
}

///|
test "RST block parser preserves footnote and citation definitions" {
  let doc = parse_markup_document(
    ".. [1] First footnote\n   continuation\n\n.. [RFC] Citation text\n",
    TextMarkupFormat::Rst,
  )
  let notes = doc.blocks.filter(block => {
    block.kind == TextMarkupBlockKind::NoteDefinition
  })
  assert_eq(notes.length(), 2)
  assert_true(notes[0].meta.get("note_id") == Some("1"))
  assert_true(notes[0].text.contains("continuation"))
}

///|
test "AsciiDoc block parser covers attributes source table admonition and truncation" {
  let document = parse_markup_document(
    (
      #|== Section
      #|:author: Ada
      #|:empty:
      #|
      #|. ordered item
      #|* bullet item
      #|WARNING: inspect this boundary
      #|
      #|include::chapter.adoc[leveloffset=+1]
      #|
      #|[source,moonbit]
      #|----
      #|fn main {}
      #|----
      #|
      #|[quote, Ada]
      #|____
      #|quoted text
      #|____
      #|
      #||===
      #||Name |Value
      #||alpha |one
      #||===
      #|
      #|ifdef::feature[]
      #|....
      #|
      #|```
      #|unterminated code
    ),
    TextMarkupFormat::Asciidoc,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Heading).length() == 1,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Table).length() >= 2,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::ListItem).length() >= 2,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::BlockQuote).length() >=
    1,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Code).length() >= 2,
  )
  assert_true(
    document.blocks.any(block => {
      block.meta.get("include_target") == Some("chapter.adoc")
    }),
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Raw).length() >= 2,
  )
}

///|
test "AsciiDoc unresolved image attributes remain readable source text" {
  let document = parse_markup_document(
    "image::{imagesdir}/preview.png[Preview]",
    TextMarkupFormat::Asciidoc,
  )
  assert_true(
    document.blocks.any(block => block.text.contains("image::{imagesdir}")),
  )
  assert_true(
    !document.blocks.any(block => {
      block.meta.get("semantic_kind") == Some("image")
    }),
  )
}

///|
test "TeX block parser covers environments nested list state and missing terminators" {
  let document = parse_markup_document(
    (
      #|\section{Section}
      #|\begin{itemize}
      #|\item bullet
      #|\begin{enumerate}
      #|\item ordered
      #|\end{enumerate}
      #|\end{itemize}
      #|\begin{tabular}{ll}
      #|Name & Value \\
      #|alpha & one \\
      #|\end{tabular}
      #|\begin{lstlisting}
      #|fn main {}
      #|\end{lstlisting}
      #|\begin{verse}
      #|first line
      #|\end{verse}
      #|\begin{quote}
      #|second line
      #|\end{quote}
      #|\input{chapter}
      #|\begin{unknown}
      #|payload
      #|\end{unknown}
      #|\begin{verbatim}
      #|unterminated
    ),
    TextMarkupFormat::Tex,
  )
  let items = markup_blocks_of_kind(document, TextMarkupBlockKind::ListItem)
  assert_true(items.length() >= 2)
  assert_true(items.any(block => block.ordered))
  assert_true(items.any(block => !block.ordered))
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Table).length() >= 1,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Code).length() >= 2,
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::BlockQuote).length() >=
    2,
  )
  assert_true(
    document.blocks.any(block => {
      block.meta.get("include_target") == Some("chapter")
    }),
  )
  assert_true(
    markup_blocks_of_kind(document, TextMarkupBlockKind::Raw).length() >= 1,
  )
}
