///|
priv struct PptxChartRenderable {
  order_index : Int
  object_ref : String?
  relationship_id : String?
  title : String?
  blocks : Array[@cor.Block]
}

///|
priv struct PptxSemanticChartSlideData {
  charts : Array[PptxChartRenderable]
  shape_object_orders : Map[String, Int]
}

///|
fn empty_semantic_chart_slide_data() -> PptxSemanticChartSlideData {
  { charts: [], shape_object_orders: Map([]) }
}

///|
fn maybe_parse_semantic_slide_chart_blocks(
  pkg : @ox.OoxmlPackage,
  slide_part : String,
) -> PptxSemanticChartSlideData {
  let rels = @ox.read_part_relationships(pkg, slide_part) catch {
    _ => return empty_semantic_chart_slide_data()
  }
  let mut has_chart_rel = false
  for rel in rels {
    if rel.rel_type.has_suffix("/chart") &&
      rel.resolved_target.trim() != "" &&
      @ox.has_part(pkg, rel.resolved_target) {
      has_chart_rel = true
      break
    }
  }
  if !has_chart_rel {
    return empty_semantic_chart_slide_data()
  }

  let pres = @pptx_sem.parse_pptx_presentation_from_package(pkg) catch {
    _ => return empty_semantic_chart_slide_data()
  }
  for slide in pres.slides {
    if slide.part_path == slide_part {
      let shape_object_orders : Map[String, Int] = Map([])
      let next_order : Ref[Int] = { val: 0 }
      return {
        charts: collect_chart_renderables_from_shapes(
          slide.shape_tree,
          slide.relationship_id,
          shape_object_orders,
          next_order,
        ),
        shape_object_orders,
      }
    }
  }
  empty_semantic_chart_slide_data()
}

///|
fn collect_chart_renderables_from_shapes(
  shapes : Array[@pptx_sem.PptxShape],
  default_relationship_id : String?,
  shape_object_orders : Map[String, Int],
  next_order : Ref[Int],
) -> Array[PptxChartRenderable] {
  let out : Array[PptxChartRenderable] = []
  for shape in shapes {
    let order_index = next_order.val
    next_order.val += 1
    match shape.object_ref {
      Some(object_ref) =>
        if shape_object_orders.get(object_ref) is None {
          shape_object_orders.set(object_ref, order_index)
        }
      None => ()
    }

    match shape.chart {
      Some(chart) =>
        match lower_chart_data_to_blocks(chart) {
          Some(blocks) =>
            out.push({
              order_index,
              object_ref: shape.object_ref,
              relationship_id: match chart.relationship_id {
                Some(v) => Some(v)
                None => default_relationship_id
              },
              title: chart.title,
              blocks,
            })
          None => ()
        }
      None => ()
    }

    for
      child in collect_chart_renderables_from_shapes(
        shape.children,
        default_relationship_id,
        shape_object_orders,
        next_order,
      ) {
      out.push(child)
    }
  }
  out
}

///|
fn chart_has_any_cached_points(chart : @pptx_sem.PptxChartData) -> Bool {
  for series in chart.series {
    if series.categories.length() > 0 || series.values.length() > 0 {
      return true
    }
  }
  false
}

///|
fn shape_order_for_object_ref(
  shape_object_orders : Map[String, Int],
  object_ref : String?,
) -> Int? {
  match object_ref {
    Some(value) => shape_object_orders.get(value)
    None => None
  }
}

///|
fn chart_block_object_ref(block : PptxBlock) -> String? {
  match block {
    PptxBlock::Heading(_, _, object_ref, _) => object_ref
    PptxBlock::Paragraph(_, _, object_ref, _) => object_ref
    PptxBlock::ListItem(_, _, _, _, object_ref, _) => object_ref
  }
}

///|
fn chart_block_shape_order(
  shape_object_orders : Map[String, Int],
  block : PptxBlock,
) -> Int? {
  shape_order_for_object_ref(shape_object_orders, chart_block_object_ref(block))
}

///|
fn emit_pending_chart_renderables(
  doc : @cor.Document,
  charts : Array[PptxChartRenderable],
  next_chart_index : Ref[Int],
  before_order : Int,
  src : String,
  slide_index : Int,
) -> Unit {
  while next_chart_index.val < charts.length() &&
        charts[next_chart_index.val].order_index < before_order {
    push_chart_renderable(doc, charts[next_chart_index.val], src, slide_index)
    next_chart_index.val += 1
  }
}

///|
fn emit_remaining_chart_renderables(
  doc : @cor.Document,
  charts : Array[PptxChartRenderable],
  next_chart_index : Ref[Int],
  src : String,
  slide_index : Int,
) -> Unit {
  while next_chart_index.val < charts.length() {
    push_chart_renderable(doc, charts[next_chart_index.val], src, slide_index)
    next_chart_index.val += 1
  }
}

///|
fn push_chart_renderable(
  doc : @cor.Document,
  chart : PptxChartRenderable,
  src : String,
  slide_index : Int,
) -> Unit {
  match chart.title {
    Some(title) =>
      if title.trim() != "" {
        @cor.push_with_origin(
          doc,
          @cor.Block::Paragraph(title),
          Some({
            source_name: Some(src),
            page: None,
            slide: Some(slide_index),
            sheet: None,
            block_index: Some(doc.blocks.val.length()),
            heading_path: None,
            line_start: None,
            line_end: None,
            row_index: None,
            column_index: None,
            object_ref: chart.object_ref,
            relationship_id: chart.relationship_id,
            key_path: None,
          }),
        )
      }
    None => ()
  }

  for block in chart.blocks {
    @cor.push_with_origin(
      doc,
      block,
      Some({
        source_name: Some(src),
        page: None,
        slide: Some(slide_index),
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: None,
        line_end: None,
        row_index: Some(0),
        column_index: Some(0),
        object_ref: chart.object_ref,
        relationship_id: chart.relationship_id,
        key_path: None,
      }),
    )
  }
}

///|
fn lower_chart_data_to_blocks(
  chart : @pptx_sem.PptxChartData,
) -> Array[@cor.Block]? {
  if chart.series.length() == 0 || !chart_has_any_cached_points(chart) {
    return Some([
      @cor.Block::Paragraph("[Chart data not embedded in chart cache]"),
    ])
  }

  match lower_chart_data_to_table(chart) {
    Some(table) => Some([@cor.Block::RichTable(table)])
    None => Some(render_chart_fallback_blocks(chart))
  }
}

///|
fn lower_chart_data_to_table(
  chart : @pptx_sem.PptxChartData,
) -> @cor.TableData? {
  if chart.series.length() == 0 {
    return None
  }

  let first = chart.series[0]
  if first.categories.length() == 0 || first.values.length() == 0 {
    return None
  }
  if first.categories.length() != first.values.length() {
    return None
  }

  for series in chart.series {
    if series.categories.length() == 0 || series.values.length() == 0 {
      return None
    }
    if series.categories.length() != series.values.length() {
      return None
    }
    if series.categories.length() != first.categories.length() {
      return None
    }
    for i in 0..<first.categories.length() {
      if series.categories[i] != first.categories[i] {
        return None
      }
    }
  }

  let rows : Array[Array[String]] = []
  let header : Array[String] = ["Category"]
  for series in chart.series {
    header.push(series.name)
  }
  rows.push(header)

  for i in 0..<first.categories.length() {
    let row : Array[String] = [first.categories[i]]
    for series in chart.series {
      row.push(series.values[i])
    }
    rows.push(row)
  }

  Some({ rows, header_rows: 1, hints: None })
}

///|
fn render_chart_fallback_blocks(
  chart : @pptx_sem.PptxChartData,
) -> Array[@cor.Block] {
  let blocks : Array[@cor.Block] = [@cor.Block::Paragraph("Chart")]
  for series in chart.series {
    blocks.push(@cor.Block::ListItem(false, 0, "Series: " + series.name))
    let pair_count = if series.categories.length() < series.values.length() {
      series.categories.length()
    } else {
      series.values.length()
    }
    for i in 0..<pair_count {
      blocks.push(
        @cor.Block::ListItem(
          false,
          1,
          series.categories[i] + ": " + series.values[i],
        ),
      )
    }
    if pair_count == 0 && series.values.length() > 0 {
      for value in series.values {
        blocks.push(@cor.Block::ListItem(false, 1, value))
      }
    }
  }
  if blocks.length() == 1 {
    [@cor.Block::Paragraph("[Chart data not embedded in chart cache]")]
  } else {
    blocks
  }
}
