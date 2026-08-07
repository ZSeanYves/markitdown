///|
fn html_semantic_table_section_kind(tag_name : String) -> HtmlTableSectionKind? {
  match tag_name {
    "thead" => Some(Head)
    "tbody" => Some(Body)
    "tfoot" => Some(Foot)
    _ => None
  }
}

///|
fn html_semantic_table_cell_kind(tag_name : String) -> HtmlTableCellKind? {
  match tag_name {
    "th" => Some(Header)
    "td" => Some(Data)
    _ => None
  }
}

///|
fn find_html_semantic_direct_child_element(
  element : HtmlElement,
  tag_name : String,
) -> HtmlElement? {
  for child in element.children {
    match child {
      Element(child_element) =>
        if child_element.tag_name == tag_name {
          return Some(child_element)
        }
      _ => ()
    }
  }
  None
}

///|
fn html_semantic_caption_source_key(
  table_source_key : String,
  caption : HtmlElement,
) -> String {
  table_source_key + ":caption:" + caption.span.line_start.to_string()
}

///|
fn html_semantic_inline_keys_for_block(
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
) -> Array[String] {
  match ctx.top_level_inline_keys_by_block_source_key.get(block_source_key) {
    Some(keys) => keys
    None => []
  }
}

///|
fn html_semantic_link_keys_for_block(
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
) -> Array[String] {
  match ctx.link_source_keys_by_block_source_key.get(block_source_key) {
    Some(keys) => keys
    None => []
  }
}

///|
fn html_semantic_image_keys_for_block(
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
) -> Array[String] {
  match ctx.image_source_keys_by_block_source_key.get(block_source_key) {
    Some(keys) => keys
    None => []
  }
}

///|
fn html_semantic_image_keys_for_parent_inline(
  ctx : HtmlSemanticCollectCtx,
  parent_inline_source_key : String,
) -> Array[String] {
  match
    ctx.image_source_keys_by_parent_inline_source_key.get(
      parent_inline_source_key,
    ) {
    Some(keys) => keys
    None => []
  }
}

///|
fn html_semantic_link_key_for_inline(
  ctx : HtmlSemanticCollectCtx,
  inline_source_key : String?,
) -> String? {
  match inline_source_key {
    Some(key) => ctx.link_source_key_by_inline_source_key.get(key)
    None => None
  }
}

///|
fn set_html_semantic_parent_link_source_key(
  ctx : HtmlSemanticCollectCtx,
  parent_inline_source_key : String,
  link_source_key : String,
) -> Unit {
  for
    image_source_key in html_semantic_image_keys_for_parent_inline(
      ctx, parent_inline_source_key,
    ) {
    match ctx.image_index_by_source_key.get(image_source_key) {
      Some(index) => {
        let image = ctx.images[index]
        if image.parent_link_source_key is None {
          ctx.images[index] = {
            source_key: image.source_key,
            inline_source_key: image.inline_source_key,
            parent_block_source_key: image.parent_block_source_key,
            parent_inline_source_key: image.parent_inline_source_key,
            parent_link_source_key: Some(link_source_key),
            src: image.src,
            srcset: image.srcset,
            alt: image.alt,
            title: image.title,
            width: image.width,
            height: image.height,
            loading: image.loading,
            decoding: image.decoding,
            picture_source_keys: image.picture_source_keys,
            alt_complete: image.alt_complete,
            title_complete: image.title_complete,
            kind: image.kind,
            span: image.span,
            warnings: image.warnings,
          }
        }
      }
      None => ()
    }
  }
}

///|
fn html_semantic_block_kind_for_key(
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
) -> HtmlBlockKind? {
  ctx.block_by_source_key.get(block_source_key).map(fn(block) { block.kind })
}

///|
fn html_semantic_parent_list_key(
  ctx : HtmlSemanticCollectCtx,
  parent_block_source_key : String?,
) -> String? {
  match parent_block_source_key {
    Some(key) => ctx.nearest_list_source_key_by_block_source_key.get(key)
    None => None
  }
}

///|
fn html_semantic_parent_item_key(
  ctx : HtmlSemanticCollectCtx,
  parent_block_source_key : String?,
) -> String? {
  match parent_block_source_key {
    Some(key) => ctx.nearest_list_item_source_key_by_block_source_key.get(key)
    None => None
  }
}

///|
fn html_semantic_item_order_in_list(
  items : Array[HtmlListItemFact],
  list_source_key : String?,
) -> Int {
  let mut count = 0
  for item in items {
    if item.list_source_key == list_source_key {
      count += 1
    }
  }
  count
}

///|
fn html_semantic_list_depth(
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
) -> Int {
  match ctx.list_depth_by_block_source_key.get(block_source_key) {
    Some(depth) => depth
    None => 0
  }
}

///|
fn html_semantic_quote_depth(
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
) -> Int {
  match ctx.quote_depth_by_block_source_key.get(block_source_key) {
    Some(depth) => depth
    None => 0
  }
}

///|
fn html_semantic_parent_quote_key(
  ctx : HtmlSemanticCollectCtx,
  parent_block_source_key : String?,
) -> String? {
  match parent_block_source_key {
    Some(parent_key) =>
      ctx.nearest_quote_source_key_by_block_source_key.get(parent_key)
    None => None
  }
}

///|
fn find_html_semantic_child_block_key_by_tag(
  ctx : HtmlSemanticCollectCtx,
  parent_block_source_key : String,
  tag_name : String,
) -> String? {
  for
    child_key in html_semantic_direct_child_block_keys(
      ctx, parent_block_source_key,
    ) {
    match html_semantic_block_for_key(ctx, child_key) {
      Some(block) =>
        if block.tag_name == tag_name {
          return Some(block.source_key)
        }
      None => ()
    }
  }
  None
}

///|
fn html_semantic_block_text_preview_for_key(
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
) -> String? {
  match html_semantic_block_for_key(ctx, block_source_key) {
    Some(block) => Some(block.text_preview)
    None => None
  }
}

///|
fn html_semantic_block_for_key(
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
) -> HtmlBlockFact? {
  ctx.block_by_source_key.get(block_source_key)
}

///|
fn html_semantic_descendant_block_keys(
  ctx : HtmlSemanticCollectCtx,
  ancestor_block_source_key : String,
) -> Array[String] {
  match
    ctx.descendant_block_source_keys_by_ancestor_source_key.get(
      ancestor_block_source_key,
    ) {
    Some(keys) => keys
    None => []
  }
}

///|
fn html_semantic_descendant_block_key_by_tag_index(
  ctx : HtmlSemanticCollectCtx,
  ancestor_block_source_key : String,
  tag_name : String,
  descendant_index : Int,
) -> String? {
  let keys = if tag_name == "tr" {
    match
      ctx.descendant_table_row_block_source_keys_by_table_source_key.get(
        ancestor_block_source_key,
      ) {
      Some(values) => values
      None => []
    }
  } else {
    let matched : Array[String] = []
    for
      key in html_semantic_descendant_block_keys(ctx, ancestor_block_source_key) {
      match html_semantic_block_for_key(ctx, key) {
        Some(block) => if block.tag_name == tag_name { matched.push(key) }
        None => ()
      }
    }
    matched
  }
  if descendant_index >= 0 && descendant_index < keys.length() {
    Some(keys[descendant_index])
  } else {
    None
  }
}

///|
fn html_semantic_table_cell_block_key_by_index(
  ctx : HtmlSemanticCollectCtx,
  row_block_source_key : String,
  cell_index : Int,
) -> String? {
  match
    ctx.direct_table_cell_block_source_keys_by_row_source_key.get(
      row_block_source_key,
    ) {
    Some(keys) =>
      if cell_index >= 0 && cell_index < keys.length() {
        Some(keys[cell_index])
      } else {
        None
      }
    None => None
  }
}

///|
fn html_semantic_direct_child_block_keys(
  ctx : HtmlSemanticCollectCtx,
  parent_block_source_key : String,
) -> Array[String] {
  match
    ctx.child_block_source_keys_by_parent_source_key.get(
      parent_block_source_key,
    ) {
    Some(keys) => keys
    None => []
  }
}

///|
fn parse_html_semantic_positive_int_attr(raw : String?) -> Int {
  match raw {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        return 1
      }
      let chars = trimmed.to_array()
      let mut i = 0
      let mut n = 0
      while i < chars.length() {
        let c = chars[i]
        let k = c.to_int()
        if k < 48 || k > 57 {
          return 1
        }
        n = n * 10 + (k - 48)
        i += 1
      }
      if n <= 0 {
        1
      } else {
        n
      }
    }
    None => 1
  }
}

///|
fn html_semantic_table_max_column_count(
  ctx : HtmlSemanticCollectCtx,
  row_source_keys : Array[String],
) -> Int {
  let mut max_count = 0
  for key in row_source_keys {
    match ctx.table_row_by_source_key.get(key) {
      Some(row) => if row.cell_count > max_count { max_count = row.cell_count }
      None => ()
    }
  }
  max_count
}

///|
fn html_semantic_table_has_ragged_rows(
  ctx : HtmlSemanticCollectCtx,
  row_source_keys : Array[String],
  max_column_count : Int,
) -> Bool {
  if max_column_count == 0 {
    return false
  }
  for key in row_source_keys {
    match ctx.table_row_by_source_key.get(key) {
      Some(row) => if row.cell_count != max_column_count { return true }
      None => ()
    }
  }
  false
}

///|
fn html_semantic_table_has_span(
  ctx : HtmlSemanticCollectCtx,
  cell_source_keys : Array[String],
) -> Bool {
  for key in cell_source_keys {
    match ctx.table_cell_by_source_key.get(key) {
      Some(cell) =>
        if cell.colspan_value > 1 || cell.rowspan_value > 1 {
          return true
        }
      None => ()
    }
  }
  false
}

///|
fn html_semantic_table_has_complex_cell(
  ctx : HtmlSemanticCollectCtx,
  cell_source_keys : Array[String],
) -> Bool {
  for key in cell_source_keys {
    match ctx.table_cell_by_source_key.get(key) {
      Some(cell) => if !cell.safe_simple_cell_candidate { return true }
      None => ()
    }
  }
  false
}

///|
fn html_semantic_table_has_nested_table(
  ctx : HtmlSemanticCollectCtx,
  table_block_source_key : String,
) -> Bool {
  html_semantic_block_descendants_contain_kind(
    ctx,
    table_block_source_key,
    Table,
  )
}

///|
fn html_semantic_table_span_cell_count(
  ctx : HtmlSemanticCollectCtx,
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    match ctx.table_cell_by_source_key.get(key) {
      Some(cell) =>
        if cell.colspan_value > 1 || cell.rowspan_value > 1 {
          count += 1
        }
      None => ()
    }
  }
  count
}

///|
fn html_semantic_table_ragged_row_count(
  ctx : HtmlSemanticCollectCtx,
  row_source_keys : Array[String],
  max_column_count : Int,
) -> Int {
  if max_column_count == 0 {
    return 0
  }
  let mut count = 0
  for key in row_source_keys {
    match ctx.table_row_by_source_key.get(key) {
      Some(row) => if row.cell_count != max_column_count { count += 1 }
      None => ()
    }
  }
  count
}

///|
fn html_semantic_table_nested_cell_count(
  ctx : HtmlSemanticCollectCtx,
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    match ctx.table_cell_by_source_key.get(key) {
      Some(cell) => if cell.has_nested_table { count += 1 }
      None => ()
    }
  }
  count
}

///|
fn html_semantic_table_complex_cell_count(
  ctx : HtmlSemanticCollectCtx,
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    match ctx.table_cell_by_source_key.get(key) {
      Some(cell) => if !cell.safe_simple_cell_candidate { count += 1 }
      None => ()
    }
  }
  count
}

///|
fn html_semantic_table_image_cell_count(
  ctx : HtmlSemanticCollectCtx,
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    match ctx.table_cell_by_source_key.get(key) {
      Some(cell) => if cell.has_image { count += 1 }
      None => ()
    }
  }
  count
}

///|
fn html_semantic_table_block_child_cell_count(
  ctx : HtmlSemanticCollectCtx,
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    match ctx.table_cell_by_source_key.get(key) {
      Some(cell) => if cell.direct_child_block_keys.length() > 0 { count += 1 }
      None => ()
    }
  }
  count
}

///|
fn html_semantic_warning_kind_count(
  warnings : Array[HtmlSemanticWarning],
  kind : HtmlSemanticWarningKind,
) -> Int {
  let mut count = 0
  for warning in warnings {
    if warning.kind == kind {
      count += 1
    }
  }
  count
}

///|
fn html_semantic_block_has_image(
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
) -> Bool {
  html_semantic_image_keys_for_block(ctx, block_source_key).length() > 0
}

///|
fn html_semantic_block_descendants_contain_kind(
  ctx : HtmlSemanticCollectCtx,
  root_source_key : String,
  kind : HtmlBlockKind,
) -> Bool {
  for key in html_semantic_descendant_block_keys(ctx, root_source_key) {
    if html_semantic_block_kind_for_key(ctx, key) == Some(kind) {
      return true
    }
  }
  false
}

///|
fn html_semantic_block_descendants_contain_list(
  ctx : HtmlSemanticCollectCtx,
  root_source_key : String,
) -> Bool {
  for key in html_semantic_descendant_block_keys(ctx, root_source_key) {
    match html_semantic_block_kind_for_key(ctx, key) {
      Some(List(_)) | Some(ListItem) => return true
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_block_descendants_contain_pre(
  ctx : HtmlSemanticCollectCtx,
  root_source_key : String,
) -> Bool {
  for key in html_semantic_descendant_block_keys(ctx, root_source_key) {
    match html_semantic_block_kind_for_key(ctx, key) {
      Some(Pre) | Some(CodeBlock) => return true
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_warnings_have_unsupported(
  warnings : Array[HtmlSemanticWarning],
) -> Bool {
  for warning in warnings {
    match warning.kind {
      UnsupportedElement
      | UnsafeUrl
      | DataUriImage
      | RemoteImage
      | EmptyImageSource => return true
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_parent_block_is_tag(
  ctx : HtmlSemanticCollectCtx,
  parent_block_source_key : String?,
  tag_name : String,
) -> Bool {
  match parent_block_source_key {
    Some(key) =>
      match html_semantic_block_for_key(ctx, key) {
        Some(block) => block.tag_name == tag_name
        None => false
      }
    None => false
  }
}

///|
fn html_semantic_language_hint_from_class(class_value : String) -> String? {
  for token in class_value.split(" ") {
    let trimmed = token.trim().to_owned()
    if trimmed.has_prefix("language-") && trimmed.length() > 9 {
      return Some(trimmed[9:].to_owned())
    }
    if trimmed.has_prefix("lang-") && trimmed.length() > 5 {
      return Some(trimmed[5:].to_owned())
    }
  }
  None
}

///|
fn html_semantic_block_kind(tag_name : String) -> HtmlBlockKind? {
  match tag_name {
    "h1" => Some(Heading(1))
    "h2" => Some(Heading(2))
    "h3" => Some(Heading(3))
    "h4" => Some(Heading(4))
    "h5" => Some(Heading(5))
    "h6" => Some(Heading(6))
    "p" => Some(Paragraph)
    "ul" => Some(List(false))
    "ol" => Some(List(true))
    "li" => Some(ListItem)
    "table" => Some(Table)
    "tr" => Some(TableRow)
    "th" => Some(TableCell(true))
    "td" => Some(TableCell(false))
    "blockquote" => Some(BlockQuote)
    "pre" => Some(Pre)
    "code" => Some(CodeBlock)
    "figure" => Some(Figure)
    "figcaption" => Some(FigCaption)
    "hr" => Some(HorizontalRule)
    _ =>
      if is_html_semantic_unsupported_tag(tag_name) {
        Some(UnsupportedBlock)
      } else if is_html_semantic_container_tag(tag_name) {
        Some(UnknownBlock)
      } else {
        None
      }
  }
}

///|
fn is_html_semantic_container_tag(tag_name : String) -> Bool {
  tag_name == "body" ||
  tag_name == "main" ||
  tag_name == "article" ||
  tag_name == "section" ||
  tag_name == "div" ||
  tag_name == "details" ||
  tag_name == "summary" ||
  tag_name == "header" ||
  tag_name == "footer" ||
  tag_name == "nav" ||
  tag_name == "aside" ||
  tag_name == "thead" ||
  tag_name == "tbody" ||
  tag_name == "tfoot"
}

///|
fn is_html_semantic_unsupported_tag(tag_name : String) -> Bool {
  html_semantic_unsupported_kind_for_tag(tag_name) is Some(_)
}

///|
fn html_semantic_unsupported_kind_for_tag(
  tag_name : String,
) -> HtmlUnsupportedKind? {
  match tag_name {
    "script" | "noscript" => Some(Script)
    "style" => Some(Style)
    "iframe" => Some(Iframe)
    "embed" => Some(Embed)
    "object" => Some(Object)
    "svg" => Some(Svg)
    "math" => Some(Math)
    "template" => Some(Template)
    "form" => Some(Form)
    "input" => Some(Input)
    "select" => Some(Select)
    "textarea" => Some(TextArea)
    "button" => Some(Button)
    "video" => Some(Video)
    "audio" => Some(Audio)
    "source" => Some(Source)
    "canvas" => Some(Canvas)
    _ => None
  }
}

///|
fn html_semantic_unsupported_kind_for_link(
  kind : HtmlLinkKind,
) -> HtmlUnsupportedKind? {
  match kind {
    Data | Unsafe => Some(UnsafeUrl)
    Empty => Some(EmptyUrl)
    _ => None
  }
}

///|
fn html_semantic_unsupported_kind_for_image(
  kind : HtmlImageKind,
) -> HtmlUnsupportedKind? {
  match kind {
    Remote => Some(RemoteImage)
    DataUri => Some(DataImage)
    Unsafe => Some(UnsafeUrl)
    Empty => Some(EmptyUrl)
    _ => None
  }
}

///|
fn html_semantic_unsupported_url_severity(
  kind : HtmlUnsupportedKind,
) -> HtmlWarningSeverity {
  match kind {
    RemoteImage => Info
    EmptyUrl => Info
    DataImage => Warning
    UnsafeUrl => Warning
    _ => Warning
  }
}

///|
fn html_semantic_unsupported_url_message(
  kind : HtmlUnsupportedKind,
  subject : String,
) -> String {
  match kind {
    RemoteImage => "html semantic " + subject + " references remote source"
    DataImage => "html semantic " + subject + " uses data uri source"
    UnsafeUrl => "html semantic " + subject + " has unsafe url"
    EmptyUrl => "html semantic " + subject + " has empty url"
    _ => "html semantic " + subject + " has unsupported url"
  }
}

///|
fn html_semantic_anchor_is_note_ref(element : HtmlElement) -> Bool {
  if html_semantic_attr_token_contains(
      element.attributes,
      "epub:type",
      "noteref",
    ) {
    return true
  }
  if html_semantic_attr_token_contains(
      element.attributes,
      "role",
      "doc-noteref",
    ) {
    return true
  }
  if html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "noteref",
    ) {
    return true
  }
  match html_semantic_attr_value(element.attributes, "href") {
    Some(href) => {
      let lower = href.to_lower()
      lower.has_prefix("#fn") ||
      lower.has_prefix("#footnote") ||
      lower.has_prefix("#endnote")
    }
    None => false
  }
}

///|
fn html_semantic_anchor_is_backref(element : HtmlElement) -> Bool {
  html_semantic_attr_token_contains(element.attributes, "epub:type", "backlink") ||
  html_semantic_attr_token_contains(element.attributes, "role", "doc-backlink") ||
  html_semantic_attr_any_contains(
    element.attributes,
    ["class", "id", "href"],
    "backref",
  )
}

///|
fn html_semantic_fragment_id_from_href(href : String) -> String? {
  let trimmed = href.trim().to_owned()
  if !trimmed.has_prefix("#") || trimmed.length() <= 1 {
    return None
  }
  let value = trimmed[1:].to_owned()
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
fn html_semantic_note_body_kind(element : HtmlElement) -> HtmlNoteKind {
  if html_semantic_attr_token_contains(
      element.attributes,
      "epub:type",
      "footnote",
    ) ||
    html_semantic_attr_token_contains(
      element.attributes,
      "role",
      "doc-footnote",
    ) {
    return Footnote
  }
  if html_semantic_attr_token_contains(
      element.attributes,
      "epub:type",
      "endnote",
    ) ||
    html_semantic_attr_token_contains(element.attributes, "role", "doc-endnote") {
    return EndnoteLike
  }
  if html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "footnote",
    ) ||
    html_semantic_attr_any_contains(element.attributes, ["class", "id"], "fn") {
    return Footnote
  }
  if html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "endnote",
    ) {
    return EndnoteLike
  }
  Unknown
}

///|
fn html_semantic_note_body_id(element : HtmlElement) -> String? {
  match html_semantic_attr_value(element.attributes, "id") {
    Some(value) =>
      if value.trim() == "" {
        None
      } else {
        Some(value.trim().to_owned())
      }
    None =>
      match html_semantic_attr_value(element.attributes, "name") {
        Some(value) =>
          if value.trim() == "" {
            None
          } else {
            Some(value.trim().to_owned())
          }
        None => None
      }
  }
}

///|
fn html_semantic_note_body_id_seen(
  ctx : HtmlSemanticCollectCtx,
  note_id : String,
) -> Bool {
  ctx.note_body_by_id.contains(note_id)
}

///|
fn html_semantic_note_body_for_id(
  ctx : HtmlSemanticCollectCtx,
  note_id : String,
) -> HtmlNoteBodyFact? {
  ctx.note_body_by_id.get(note_id)
}

///|
fn html_semantic_index_block_ancestry(
  ctx : HtmlSemanticCollectCtx,
  source_key : String,
  block_kind : HtmlBlockKind,
  source_order : Int,
  parent_source_key : String?,
) -> Unit {
  let mut list_depth = 0
  let mut quote_depth = 0
  let mut nearest_list_source_key : String? = None
  let mut nearest_list_item_source_key : String? = None
  let mut nearest_quote_source_key : String? = None
  let mut nearest_table_ancestor_source_key : String? = None

  match parent_source_key {
    Some(parent_key) => {
      ctx.parent_source_key_by_block_source_key.set(source_key, parent_key)
      match ctx.list_depth_by_block_source_key.get(parent_key) {
        Some(depth) => list_depth = depth
        None => ()
      }
      match ctx.quote_depth_by_block_source_key.get(parent_key) {
        Some(depth) => quote_depth = depth
        None => ()
      }
      nearest_list_source_key = ctx.nearest_list_source_key_by_block_source_key.get(
        parent_key,
      )
      nearest_list_item_source_key = ctx.nearest_list_item_source_key_by_block_source_key.get(
        parent_key,
      )
      nearest_quote_source_key = ctx.nearest_quote_source_key_by_block_source_key.get(
        parent_key,
      )
      nearest_table_ancestor_source_key = ctx.nearest_table_ancestor_source_key_by_block_source_key.get(
        parent_key,
      )

      let mut current = Some(parent_key)
      while current is Some(ancestor_key) {
        html_semantic_map_push_string(
          ctx.descendant_block_source_keys_by_ancestor_source_key,
          ancestor_key,
          source_key,
        )
        current = ctx.parent_source_key_by_block_source_key.get(ancestor_key)
      }
    }
    None => ()
  }

  match block_kind {
    List(_) => {
      list_depth += 1
      nearest_list_source_key = Some(
        html_semantic_list_source_key(source_order),
      )
    }
    ListItem =>
      nearest_list_item_source_key = Some(
        html_semantic_list_item_source_key(source_order),
      )
    BlockQuote => {
      quote_depth += 1
      nearest_quote_source_key = Some(
        html_semantic_blockquote_source_key(source_order),
      )
    }
    Table => nearest_table_ancestor_source_key = Some(source_key)
    _ => ()
  }

  ctx.list_depth_by_block_source_key.set(source_key, list_depth)
  ctx.quote_depth_by_block_source_key.set(source_key, quote_depth)
  match nearest_list_source_key {
    Some(key) =>
      ctx.nearest_list_source_key_by_block_source_key.set(source_key, key)
    None => ()
  }
  match nearest_list_item_source_key {
    Some(key) =>
      ctx.nearest_list_item_source_key_by_block_source_key.set(source_key, key)
    None => ()
  }
  match nearest_quote_source_key {
    Some(key) =>
      ctx.nearest_quote_source_key_by_block_source_key.set(source_key, key)
    None => ()
  }
  match nearest_table_ancestor_source_key {
    Some(key) =>
      ctx.nearest_table_ancestor_source_key_by_block_source_key.set(
        source_key, key,
      )
    None => ()
  }

  match (parent_source_key, block_kind) {
    (Some(parent_key), TableCell(_)) =>
      html_semantic_map_push_string(
        ctx.direct_table_cell_block_source_keys_by_row_source_key,
        parent_key,
        source_key,
      )
    _ => ()
  }
  match block_kind {
    TableRow =>
      match nearest_table_ancestor_source_key {
        Some(table_key) =>
          html_semantic_map_push_string(
            ctx.descendant_table_row_block_source_keys_by_table_source_key,
            table_key,
            source_key,
          )
        None => ()
      }
    _ => ()
  }
}

///|
fn html_semantic_inline_for_key(
  ctx : HtmlSemanticCollectCtx,
  source_key : String,
) -> HtmlInlineFact? {
  ctx.inline_by_source_key.get(source_key)
}

///|
