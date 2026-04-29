///|
fn calc_fun(ops : Array[Calculator]) -> PdfFunction {
  { func: PdfFunctionKind::Calculator(ops), domain: [0.0, 1.0], range: None }
}

///|
fn eval_calc_inputs(
  ops : Array[Calculator],
  inputs : Array[Double],
) -> Array[Double] raise BadFunctionEvaluation {
  calc_fun(ops).eval(inputs)
}

///|
fn assert_calc_err(ops : Array[Calculator]) -> Unit raise {
  let res : Result[Array[Double], Error] = try? calc_fun(ops).eval([0.0])
  assert_true(res is Err(_))
}

///|
test "parse_function sampled order" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
    ("/Range", Array([Real(0.0), Real(1.0)])),
    ("/Size", Array([Integer(1)])),
    ("/BitsPerSample", Integer(8)),
    ("/Order", Integer(3)),
    ("/Length", Integer(1)),
  ])
  let data = @pdfio.bytes_of_list([0x80])
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let parsed = PdfFunction::parse(pdf, stream)
  match parsed.func {
    PdfFunctionKind::Sampled(s) => assert_eq(s.order, 3)
    _ => fail("expected sampled function")
  }
}

///|
test "parse_function defaults c0 c1" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(2)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
    ("/N", Real(1.0)),
  ])
  let parsed = PdfFunction::parse(pdf, dict)
  match parsed.func {
    PdfFunctionKind::Interpolation(i) => {
      assert_eq(i.c0.length(), 1)
      assert_eq(i.c1.length(), 1)
      assert_eq(i.c0[0], 0.0)
      assert_eq(i.c1[0], 1.0)
    }
    _ => fail("expected interpolation function")
  }
}

///|
test "parse_function rejects bad bits per sample" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
    ("/Range", Array([Real(0.0), Real(1.0)])),
    ("/Size", Array([Integer(1)])),
    ("/BitsPerSample", Name(@pdf.PdfName::of_string("/Bad"))),
  ])
  let res : Result[PdfFunction, Error] = try? PdfFunction::parse(pdf, dict)
  assert_true(res is Err(_))
}

///|
test "calculator bool output errors" {
  let ops = [Calculator::Float(1.0), Calculator::Float(1.0), Calculator::Eq]
  let res : Result[Array[Double], Error] = try? calc_fun(ops).eval([0.0])
  assert_true(res is Err(_))
}

///|
test "calculator compares bools" {
  let ops = [
    Calculator::Pop,
    Calculator::Bool(true),
    Calculator::Bool(true),
    Calculator::Ge,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ]
  let out = eval_calc_inputs(ops, [0.0])
  assert_eq(out.length(), 1)
  assert_eq(out[0], 1.0)
}

///|
test "calculator conversions and rounding" {
  let ops = [
    Calculator::Pop,
    Calculator::Int(2),
    Calculator::Cvi,
    Calculator::Cvr,
    Calculator::Float(1.5),
    Calculator::Cvr,
    Calculator::Neg,
    Calculator::Int(3),
    Calculator::Round,
    Calculator::Truncate,
    Calculator::Floor,
  ]
  let out = eval_calc_inputs(ops, [0.0])
  assert_true(out.length() >= 2)
}

///|
test "calculator mul and sub mixed types" {
  let ops = [
    Calculator::Pop,
    Calculator::Float(2.0),
    Calculator::Int(3),
    Calculator::Mul,
    Calculator::Int(1),
    Calculator::Sub,
  ]
  let out = eval_calc_inputs(ops, [0.0])
  assert_eq(out.length(), 1)
  assert_eq(out[0], 5.0)
}

///|
test "calculator mul and sub float int" {
  let ops = [
    Calculator::Pop,
    Calculator::Int(4),
    Calculator::Float(1.5),
    Calculator::Mul,
    Calculator::Int(2),
    Calculator::Float(1.0),
    Calculator::Sub,
    Calculator::Sub,
  ]
  let out = eval_calc_inputs(ops, [0.0])
  assert_true(out.length() >= 1)
}

///|
test "calculator bitshift with negative values" {
  let ops = [
    Calculator::Pop,
    Calculator::Int(1),
    Calculator::Int(-4),
    Calculator::Bitshift,
  ]
  let out = eval_calc_inputs(ops, [0.0])
  assert_eq(out.length(), 1)
}

///|
test "calculator roll handles negative and zero shift" {
  let ops_negative = [
    Calculator::Pop,
    Calculator::Int(10),
    Calculator::Int(20),
    Calculator::Int(30),
    Calculator::Int(3),
    Calculator::Int(-1),
    Calculator::Roll,
  ]
  let out = eval_calc_inputs(ops_negative, [0.0])
  assert_eq(out.length(), 3)
  let ops_zero = [
    Calculator::Pop,
    Calculator::Int(1),
    Calculator::Int(2),
    Calculator::Int(3),
    Calculator::Int(3),
    Calculator::Int(0),
    Calculator::Roll,
  ]
  let out_zero = eval_calc_inputs(ops_zero, [0.0])
  assert_eq(out_zero.length(), 3)
}

///|
test "calculator type errors" {
  let cases : Array[Array[Calculator]] = [
    [Calculator::Pop, Calculator::Bool(true), Calculator::Abs],
    [
      Calculator::Pop,
      Calculator::Bool(true),
      Calculator::Int(1),
      Calculator::Add,
    ],
    [Calculator::Pop, Calculator::Bool(true), Calculator::Ceiling],
    [Calculator::Pop, Calculator::Bool(true), Calculator::Cvi],
    [Calculator::Pop, Calculator::Bool(true), Calculator::Cvr],
    [Calculator::Pop, Calculator::Bool(true), Calculator::Floor],
    [
      Calculator::Pop,
      Calculator::Bool(true),
      Calculator::Int(1),
      Calculator::Mul,
    ],
    [Calculator::Pop, Calculator::Bool(true), Calculator::Neg],
    [Calculator::Pop, Calculator::Bool(true), Calculator::Round],
    [
      Calculator::Pop,
      Calculator::Bool(true),
      Calculator::Int(1),
      Calculator::Sub,
    ],
    [Calculator::Pop, Calculator::Bool(true), Calculator::Truncate],
    [
      Calculator::Pop,
      Calculator::Bool(true),
      Calculator::Int(1),
      Calculator::And,
    ],
    [Calculator::Pop, Calculator::Float(1.0), Calculator::Not],
    [
      Calculator::Pop,
      Calculator::Bool(true),
      Calculator::Int(1),
      Calculator::Or,
    ],
    [
      Calculator::Pop,
      Calculator::Bool(true),
      Calculator::Int(1),
      Calculator::Xor,
    ],
    [Calculator::Pop, Calculator::Float(1.0), Calculator::Copy],
    [Calculator::Pop, Calculator::Float(1.0), Calculator::Index],
    [
      Calculator::Pop,
      Calculator::Int(10),
      Calculator::Int(2),
      Calculator::Int(1),
      Calculator::Roll,
    ],
  ]
  for ops in cases {
    assert_calc_err(ops)
  }
}

///|
test "stitching bad arity and NaN input" {
  let f1 : PdfFunction = {
    func: PdfFunctionKind::Interpolation({ c0: [0.0], c1: [1.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let fun : PdfFunction = {
    func: PdfFunctionKind::Stitching({
      functions: [f1],
      bounds: [],
      stitch_encode: [0.0, 1.0],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let res_bad : Result[Array[Double], Error] = try? fun.eval([0.1, 0.2])
  assert_true(res_bad is Err(_))
  let res_nan : Result[Array[Double], Error] = try? fun.eval([0.0 / 0.0])
  assert_true(res_nan is Err(_))
}

///|
test "pdfobject_of_function handles zero bps" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Sampled({
      size: [1],
      order: 1,
      encode: [0.0, 0.0],
      decode: [0.0, 1.0],
      bps: 0,
      samples: [],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    Stream(r) =>
      match (r.val.1 : @pdf.Stream) {
        Got(bytes) => assert_eq(@pdfio.bytes_size(bytes), 0)
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
}
