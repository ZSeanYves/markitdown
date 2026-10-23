///|
/// Positions refer to the supplied UTF8 representation, before CRLF folding
/// and entity decoding. All offsets are zero based; lines/columns are one
/// based Unicode scalar positions. A non-BMP scalar advances utf16 by two.
pub struct XmlCursorPosition {
  utf8_byte : Int64
  scalar : Int64
  utf16 : Int64
  line : Int64
  column : Int64
} derive(Eq)

///|
pub extend XmlCursorPosition with Eq::{equal, not_equal}

///|
pub struct XmlCursorSpan {
  start : XmlCursorPosition
  end : XmlCursorPosition
} derive(Eq)

///|
pub extend XmlCursorSpan with Eq::{equal, not_equal}

///|
pub struct XmlCursorName {
  raw : String
  local_name : String
  namespace_uri : String?
} derive(Eq)

///|
pub extend XmlCursorName with Eq::{equal, not_equal}

///|
pub struct XmlCursorAttribute {
  name : XmlCursorName
  value : String
  quote : Char
  span : XmlCursorSpan
  namespace_declaration : Bool
}

///|
/// Text and CDATA runs may contain many fragments, including an empty final
/// fragment. Count a logical node at first=true, not once per emitted fragment.
pub struct XmlCursorText {
  text : String
  first : Bool
  last : Bool
  span : XmlCursorSpan
}

///|
pub(all) enum XmlCursorToken {
  StartElement(XmlCursorName, Array[XmlCursorAttribute], Bool, XmlCursorSpan)
  EndElement(XmlCursorName, XmlCursorSpan)
  TextFragment(XmlCursorText)
  CDataFragment(XmlCursorText)
  Comment(String, XmlCursorSpan)
  ProcessingInstruction(String, String, XmlCursorSpan)
  Declaration(String, XmlCursorSpan)
  Doctype(String, XmlCursorSpan)
}

///|
pub(all) enum XmlCursorStep {
  NeedInput
  Token(XmlCursorToken)
  End
}

///|
pub(all) enum XmlCursorLimit {
  Depth
  TokenBytes
  Attributes
  Tokens
} derive(Eq)

///|
pub extend XmlCursorLimit with Eq::{equal, not_equal}

///|
pub(all) enum XmlCursorError {
  Syntax(XmlErrorKind, String, XmlCursorSpan)
  InvalidEncoding(String, XmlCursorPosition)
  Budget(@budget.BudgetError)
  Limit(XmlCursorLimit, observed~ : Int64, limit~ : Int64)
  InvalidState(String)
}

///|
/// No production defaults: None caps require an explicit MeasurementOnly
/// profile. TokenBytes bounds atomic markup, not a whole logical text node.
pub struct XmlCursorLimits {
  profile : @budget.BudgetProfile
  max_depth : Int64?
  max_token_bytes : Int64?
  max_attributes : Int64?
  max_tokens : Int64?
  text_fragment_bytes : Int32
}

///|
pub fn XmlCursorLimits::new(
  profile : @budget.BudgetProfile,
  max_depth~ : Int64?,
  max_token_bytes~ : Int64?,
  max_attributes~ : Int64?,
  max_tokens~ : Int64?,
  text_fragment_bytes~ : Int32,
) -> Result[XmlCursorLimits, XmlCursorError] {
  if text_fragment_bytes < 4 {
    return Err(InvalidState("text fragment capacity must fit one UTF8 scalar"))
  }
  for cap in [max_depth, max_token_bytes, max_attributes, max_tokens] {
    match cap {
      Some(value) if value < 0L =>
        return Err(InvalidState("negative XML cursor cap"))
      None if profile == @budget.Enforced =>
        return Err(InvalidState("enforced XML cursor requires every cap"))
      _ => ()
    }
  }
  Ok({
    profile,
    max_depth,
    max_token_bytes,
    max_attributes,
    max_tokens,
    text_fragment_bytes,
  })
}

///|
pub struct XmlCursorStats {
  input_bytes : Int64
  logical_tokens : Int64
  max_depth : Int64
  max_attributes : Int64
  max_markup_bytes : Int64
  max_fragment_bytes : Int64
  max_namespace_bindings : Int64
}

///|
priv suberror XmlCursorAbort {
  Stop(XmlCursorError)
}

///|
priv enum XmlCursorMode {
  Data
  Markup
  CommentBody
  CDataBody
  InstructionBody
  DoctypeBody
}

///|
priv struct XmlCursorFrame {
  name : XmlCursorName
  prefixes : Array[String]
  lease : @budget.BudgetLease?
}

///|
/// Pure pull lexer. It owns neither a source nor an asynchronous task. Call
/// close on early stop. Returned token payloads must be accounted by consumers
/// if retained past the next next/feed call; the cursor keeps no token queue.
pub struct XmlCursor {
  priv limits : XmlCursorLimits
  priv budget : @budget.BudgetContext?
  priv mut input : Array[Char]
  priv mut input_index : Int32
  priv mut carry : Bytes
  priv mut input_lease : @budget.BudgetLease?
  priv mut carry_lease : @budget.BudgetLease?
  priv mut need_input : Bool
  priv mut final_input : Bool
  priv mut ended : Bool
  priv mut closed : Bool
  priv mut failure : XmlCursorError?
  priv mut mode : XmlCursorMode
  priv mut position : XmlCursorPosition
  priv mut pending_cr : Bool
  priv mut markup_start : XmlCursorPosition
  priv markup : XmlCursorBuffer
  priv text : XmlCursorBuffer
  priv entity : XmlCursorBuffer
  priv mut entity_start : XmlCursorPosition?
  priv mut fragment_start : XmlCursorPosition
  priv mut text_end : XmlCursorPosition
  priv mut run_started : Bool
  priv mut fragment_first : Bool
  priv mut quote : Char?
  priv mut bracket_depth : Int32
  priv mut cdata_brackets : Int32
  priv stack : Array[XmlCursorFrame]
  priv namespaces : Map[String, Array[String]]
  priv returned_leases : Array[@budget.BudgetLease]
  priv mut root_seen : Bool
  priv mut bindings : Int64
  priv mut input_bytes : Int64
  priv mut tokens : Int64
  priv mut max_depth : Int64
  priv mut max_attributes : Int64
  priv mut max_markup_bytes : Int64
  priv mut max_fragment_bytes : Int64
  priv mut max_bindings : Int64
}
