///|
pub enum XlsxSheetState {
  Visible
  Hidden
  VeryHidden
} derive(Eq)

///|
pub enum XlsxCellKind {
  SharedString
  InlineString
  Boolean
  StringResult
  Error
  Number
  Blank
} derive(Eq)

///|
pub enum XlsxCellSemanticType {
  String
  Number
  Boolean
  Date
  DateTime
  Time
  Blank
  Error
  FormulaCachedValue
  FormulaMissingCache
} derive(Eq)

///|
pub enum XlsxFormulaPolicy {
  Cached
  EvaluatedMissingCache
  UnsupportedFormula
  FormulaError
} derive(Eq)

///|
pub enum XlsxHyperlinkKind {
  External
  Internal
  Unknown
} derive(Eq)

///|
pub enum XlsxDefinedNameKind {
  NamedRange
  PrintArea
  AutoFilter
  FormulaLike
  Unknown
} derive(Eq)

///|
pub enum XlsxUnsupportedFeatureKind {
  Drawing
  Chart
  Image
  PivotTable
  VbaMacro
  OleObject
  ExternalLink
  ThreadedComment
  SheetProtection
  WorkbookProtection
  Unknown
} derive(Eq)

///|
pub struct XlsxMergedRange {
  range_ref : String
  start_row : Int
  start_col : Int
  end_row : Int
  end_col : Int
}

///|
pub struct XlsxComment {
  reference : String
  row : Int
  column : Int
  author_name : String?
  text : String
}

///|
pub struct XlsxTable {
  table_id : String?
  name : String?
  display_name : String?
  style_name : String?
  auto_filter_ref : String?
  header_row_visible : Bool
  totals_row_visible : Bool
  range_ref : String
  start_row : Int
  start_col : Int
  end_row : Int
  end_col : Int
  header_row_count : Int
  totals_row_count : Int
  column_names : Array[String]
  columns : Array[XlsxTableColumn]
  sheet_name : String
  source_part : String?
  relationship_id : String?
}

///|
pub struct XlsxTableColumn {
  column_id : String?
  name : String?
  totals_row_function : String?
  totals_row_label : String?
}

///|
pub struct XlsxHyperlink {
  reference : String
  start_row : Int
  start_col : Int
  end_row : Int
  end_col : Int
  relationship_id : String?
  target : String?
  location : String?
  tooltip : String?
  display : String?
  kind : XlsxHyperlinkKind
  warning : String?
}

///|
pub struct XlsxDefinedName {
  name : String
  text : String
  sheet_scope : String?
  sheet_scope_index : Int?
  kind : XlsxDefinedNameKind
  target_sheet : String?
  target_range : String?
  hidden : Bool
  source : String
}

///|
pub struct XlsxUnsupportedFeature {
  kind : XlsxUnsupportedFeatureKind
  severity : String
  sheet_name : String?
  relationship_id : String?
  part_target : String?
  source : String
  message : String
}

///|
pub struct XlsxFormulaTrace {
  policy : XlsxFormulaPolicy
  evaluated_value : String?
  unsupported_reason : String?
  error_reason : String?
  referenced_cells : Array[String]?
  referenced_ranges : Array[String]?
}

///|
pub struct XlsxCellModel {
  reference : String
  row : Int
  column : Int
  kind : XlsxCellKind
  display_text : String
  source_value : String?
  formula_text : String?
  semantic_type : XlsxCellSemanticType
  style_index : Int
  num_format_id : Int
  formula_trace : XlsxFormulaTrace?
  hyperlink : XlsxHyperlink?
}

///|
pub struct XlsxSheetModel {
  name : String
  relationship_id : String?
  relationship_type : String?
  part_target : String?
  state : XlsxSheetState
  is_supported_worksheet : Bool
  has_sheet_xml : Bool
  cells : Array[XlsxCellModel]
  merged_ranges : Array[XlsxMergedRange]
  comments : Array[XlsxComment]
  hyperlinks : Array[XlsxHyperlink]
  tables : Array[XlsxTable]
  defined_names : Array[XlsxDefinedName]
  unsupported_features : Array[XlsxUnsupportedFeature]
  hidden_rows : Array[Int]
  table_rows : Array[Array[String]]
  table_row_numbers : Array[Int]
  header_rows : Int
  used_min_row : Int
  used_min_col : Int
  used_max_row : Int
  used_max_col : Int
}

///|
pub struct XlsxWorkbookModel {
  source_name : String
  uses_date_1904 : Bool
  defined_names : Array[XlsxDefinedName]
  unsupported_features : Array[XlsxUnsupportedFeature]
  sheets : Array[XlsxSheetModel]
}
