///|
fn calculator_to_string_inner(op : Calculator) -> String {
  match op {
    Calculator::If(ops) => "\{calculator_ops_to_string(ops)} if"
    Calculator::IfElse(a, b) =>
      "\{calculator_ops_to_string(a)} \{calculator_ops_to_string(b)} ifelse"
    Calculator::Bool(true) => "true"
    Calculator::Bool(false) => "false"
    Calculator::Float(f) => f.to_string()
    Calculator::Int(i) => i.to_string()
    Calculator::Abs => "abs"
    Calculator::Add => "add"
    Calculator::Atan => "atan"
    Calculator::Ceiling => "ceiling"
    Calculator::Cos => "cos"
    Calculator::Cvi => "cvi"
    Calculator::Cvr => "cvr"
    Calculator::Div => "div"
    Calculator::Exp => "exp"
    Calculator::Floor => "floor"
    Calculator::Idiv => "idiv"
    Calculator::Ln => "ln"
    Calculator::Log => "log"
    Calculator::Mod => "mod"
    Calculator::Mul => "mul"
    Calculator::Neg => "neg"
    Calculator::Round => "round"
    Calculator::Sin => "sin"
    Calculator::Sqrt => "sqrt"
    Calculator::Sub => "sub"
    Calculator::Truncate => "truncate"
    Calculator::And => "and"
    Calculator::Bitshift => "bitshift"
    Calculator::Eq => "eq"
    Calculator::Ge => "ge"
    Calculator::Gt => "gt"
    Calculator::Le => "le"
    Calculator::Lt => "lt"
    Calculator::Ne => "ne"
    Calculator::Not => "not"
    Calculator::Or => "or"
    Calculator::Xor => "xor"
    Calculator::Copy => "copy"
    Calculator::Exch => "exch"
    Calculator::Pop => "pop"
    Calculator::Dup => "dup"
    Calculator::Index => "index"
    Calculator::Roll => "roll"
  }
}

///|
fn calculator_ops_to_string(ops : Array[Calculator]) -> String {
  let parts = ops.map(calculator_to_string_inner)
  "{" + parts.join(" ") + "}"
}

///|
pub fn Calculator::to_string(self : Array[Calculator]) -> String {
  calculator_ops_to_string(self)
}

///|
/// Flatten a function to its PDF representation.
pub fn PdfFunction::to_pdf_object(
  self : PdfFunction,
  pdf : @pdf.Pdf,
) -> PdfObject {
  let domain = PdfObject::Array(
    self.domain.map(x => @pdf.ToPdfNumber::to_pdf_number(x)),
  )
  let range_entry = match self.range {
    None => []
    Some(values) =>
      [
        (
          "/Range",
          PdfObject::Array(values.map(x => @pdf.ToPdfNumber::to_pdf_number(x))),
        ),
      ]
  }
  let base = [
    ("/FunctionType", PdfObject::Integer(funtype_of_function(self))),
    ("/Domain", domain),
  ]
  match self.func {
    PdfFunctionKind::Sampled(s) => {
      let encode_vals = if s.encode.length() == 0 {
        interleave_lists(
          many(0.0, s.size.length()),
          s.size.map(x => (x - 1).to_double()),
        )
      } else {
        s.encode
      }
      let decode_vals = if s.decode.length() == 0 {
        match self.range {
          Some(values) => values
          None => []
        }
      } else {
        s.decode
      }
      let sampled_entries = [
        (
          "/Size",
          PdfObject::Array(s.size.map(x => @pdf.ToPdfNumber::to_pdf_number(x))),
        ),
        ("/BitsPerSample", PdfObject::Integer(s.bps)),
        (
          "/Encode",
          PdfObject::Array(
            encode_vals.map(x => @pdf.ToPdfNumber::to_pdf_number(x)),
          ),
        ),
      ]
      let sampled_entries = if decode_vals.length() > 0 {
        concat_arrays(sampled_entries, [
          (
            "/Decode",
            PdfObject::Array(
              decode_vals.map(x => @pdf.ToPdfNumber::to_pdf_number(x)),
            ),
          ),
        ])
      } else {
        sampled_entries
      }
      let entries = concat_arrays(
        concat_arrays(base, range_entry),
        sampled_entries,
      )
      let entries_with_order = if s.order != 1 {
        concat_arrays(entries, [("/Order", PdfObject::Integer(s.order))])
      } else {
        entries
      }
      let data = sampled_bytes(s.samples, s.bps)
      let entries_with_length = concat_arrays(entries_with_order, [
        ("/Length", PdfObject::Integer(@pdfio.bytes_size(data))),
      ])
      PdfObject::Stream(
        Ref::new(
          (PdfObject::Dictionary(entries_with_length), @pdf.Stream::Got(data)),
        ),
      )
    }
    PdfFunctionKind::Calculator(ops) => {
      let entries = concat_arrays(base, range_entry)
      let data = @pdfio.bytes_of_string(calculator_ops_to_string(ops))
      let entries_with_length = concat_arrays(entries, [
        ("/Length", PdfObject::Integer(@pdfio.bytes_size(data))),
      ])
      PdfObject::Stream(
        Ref::new(
          (PdfObject::Dictionary(entries_with_length), @pdf.Stream::Got(data)),
        ),
      )
    }
    _ => {
      let extras = extra_entries_of_function(pdf, self)
      PdfObject::Dictionary(
        concat_arrays(concat_arrays(base, range_entry), extras),
      )
    }
  }
}
