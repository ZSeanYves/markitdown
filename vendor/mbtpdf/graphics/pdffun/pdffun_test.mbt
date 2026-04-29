///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
fn eval_calc(ops : Array[Calculator]) -> Array[Double] raise {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Calculator(ops),
    domain: [],
    range: None,
  }
  PdfFunction::eval(fun, [])
}

///|
test "eval calculator function" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(4)),
    ("/Domain", Array([Real(0.0), Real(10.0)])),
  ])
  let data = @pdfio.bytes_of_string("{ dup mul }")
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let fun = PdfFunction::parse(pdf, stream_obj)
  let output = PdfFunction::eval(fun, [2.0])
  assert_eq(output.length(), 1)
  assert_close(output[0], 4.0)
}

///|
test "eval interpolation function" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Interpolation({ c0: [0.0], c1: [1.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let output = PdfFunction::eval(fun, [0.25])
  assert_eq(output.length(), 1)
  assert_close(output[0], 0.25)
}

///|
test "serialize sampled function" {
  let fun : PdfFunction = {
    func: Sampled({
      size: [2],
      order: 1,
      encode: [0.0, 1.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    Stream(_) => ()
    _ => fail("expected sampled function to be a stream")
  }
  let parsed = PdfFunction::parse(pdf, obj)
  let output = PdfFunction::eval(parsed, [1.0])
  assert_eq(output.length(), 1)
  assert_close(output[0], 1.0)
}

///|
test "serialize calculator function" {
  let fun : PdfFunction = {
    func: Calculator([Dup, Mul]),
    domain: [0.0, 10.0],
    range: Some([0.0, 100.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    Stream(_) => ()
    _ => fail("expected calculator function to be a stream")
  }
  let parsed = PdfFunction::parse(pdf, obj)
  let output = PdfFunction::eval(parsed, [3.0])
  assert_eq(output.length(), 1)
  assert_close(output[0], 9.0)
}

///|
test "parse sampled function stream" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
    ("/Range", Array([Real(0.0), Real(1.0)])),
    ("/Size", Array([Integer(2)])),
    ("/BitsPerSample", Integer(8)),
  ])
  let data = @pdfio.bytes_of_list([0, 255])
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let fun = PdfFunction::parse(pdf, stream)
  match (fun.func : PdfFunctionKind) {
    Sampled(sample) => {
      assert_eq(sample.size.length(), 1)
      assert_eq(sample.samples.length(), 2)
      assert_eq(sample.samples[0], 0)
      assert_eq(sample.samples[1], 255)
    }
    _ => fail("expected sampled function")
  }
}

///|
test "serialize interpolation function" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Interpolation({ c0: [0.0], c1: [2.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 2.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  let parsed = PdfFunction::parse(pdf, obj)
  let output = PdfFunction::eval(parsed, [0.5])
  assert_eq(output.length(), 1)
  assert_close(output[0], 1.0)
}

///|
test "serialize stitching function" {
  let f1 : PdfFunction = {
    func: PdfFunctionKind::Interpolation({ c0: [0.0], c1: [1.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let f2 : PdfFunction = {
    func: PdfFunctionKind::Interpolation({ c0: [1.0], c1: [2.0], n: 1.0 }),
    domain: [0.0, 1.0],
    range: Some([1.0, 2.0]),
  }
  let fun : PdfFunction = {
    func: PdfFunctionKind::Stitching({
      functions: [f1, f2],
      bounds: [0.5],
      stitch_encode: [0.0, 1.0, 0.0, 1.0],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 2.0]),
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  let parsed = PdfFunction::parse(pdf, obj)
  let out1 = PdfFunction::eval(parsed, [0.25])
  let out2 = PdfFunction::eval(parsed, [0.75])
  assert_eq(out1.length(), 1)
  assert_eq(out2.length(), 1)
  assert_close(out1[0], 0.5)
  assert_close(out2[0], 1.5)
}

///|
test "serialize calculator covers opcode strings" {
  let ops : Array[Calculator] = [
    Cvi,
    Cvr,
    Div,
    Exp,
    Floor,
    Idiv,
    Ln,
    Log,
    Mod,
    Truncate,
    And,
    Bitshift,
    Eq,
    Ge,
    Gt,
    Le,
    Lt,
    Ne,
    Not,
    Or,
    Xor,
    Copy,
    Exch,
    Pop,
    Dup,
    Index,
    Roll,
  ]
  let fun : PdfFunction = {
    func: Calculator(ops),
    domain: [0.0, 1.0],
    range: None,
  }
  let pdf = @pdf.Pdf::empty()
  let obj = fun.to_pdf_object(pdf)
  match (obj : @pdf.PdfObject) {
    Stream(r) =>
      match r.val.1 {
        @pdf.Stream::Got(bytes) => {
          let text = @pdfio.string_of_bytes(bytes)
          assert_true(text.contains("cvi"))
          assert_true(text.contains("bitshift"))
          assert_true(text.contains("roll"))
        }
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream object")
  }
}

///|
test "eval stitching function" {
  let pdf = @pdf.Pdf::empty()
  let f1 : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(2)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
    ("/C0", Array([Real(0.0)])),
    ("/C1", Array([Real(1.0)])),
    ("/N", Real(1.0)),
  ])
  let f2 : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(2)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
    ("/C0", Array([Real(1.0)])),
    ("/C1", Array([Real(2.0)])),
    ("/N", Real(1.0)),
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(3)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
    ("/Functions", Array([f1, f2])),
    ("/Bounds", Array([Real(0.5)])),
    ("/Encode", Array([Real(0.0), Real(1.0), Real(0.0), Real(1.0)])),
  ])
  let fun = PdfFunction::parse(pdf, dict)
  let out1 = PdfFunction::eval(fun, [0.25])
  let out2 = PdfFunction::eval(fun, [0.75])
  assert_eq(out1.length(), 1)
  assert_eq(out2.length(), 1)
  assert_close(out1[0], 0.5)
  assert_close(out2[0], 1.5)
}

///|
test "PdfFunction::print covers kinds and array sizes" {
  let prev_logger = @pdfe.logger.val
  @pdfe.logger.val = _ => ()
  defer {
    @pdfe.logger.val = prev_logger
  }
  let empty_doubles : Array[Double] = []
  let some_doubles : Array[Double] = [0.0, 1.0]
  let empty_ints : Array[Int] = []
  let some_ints : Array[Int] = [1, 2]
  let sampled_empty : PdfFunction = {
    func: PdfFunctionKind::Sampled({
      size: empty_ints,
      order: 1,
      encode: empty_doubles,
      decode: empty_doubles,
      bps: 8,
      samples: empty_ints,
    }),
    domain: empty_doubles,
    range: None,
  }
  let sampled_full : PdfFunction = {
    func: PdfFunctionKind::Sampled({
      size: some_ints,
      order: 1,
      encode: some_doubles,
      decode: some_doubles,
      bps: 8,
      samples: some_ints,
    }),
    domain: some_doubles,
    range: Some(some_doubles),
  }
  let interpolation : PdfFunction = {
    func: PdfFunctionKind::Interpolation({
      c0: empty_doubles,
      c1: empty_doubles,
      n: 1.0,
    }),
    domain: empty_doubles,
    range: None,
  }
  let stitching : PdfFunction = {
    func: PdfFunctionKind::Stitching({
      functions: [interpolation],
      bounds: empty_doubles,
      stitch_encode: empty_doubles,
    }),
    domain: empty_doubles,
    range: None,
  }
  let calculator : PdfFunction = {
    func: PdfFunctionKind::Calculator([
      Calculator::Bool(true),
      Calculator::Bool(false),
      Calculator::Add,
      Calculator::Atan,
      Calculator::Ceiling,
      Calculator::Cos,
      Calculator::If([Calculator::Int(1)]),
      Calculator::IfElse([Calculator::Int(0)], [Calculator::Int(1)]),
      Calculator::Neg,
      Calculator::Index,
      Calculator::Round,
      Calculator::Sin,
      Calculator::Sqrt,
      Calculator::Sub,
      Calculator::Roll,
    ]),
    domain: empty_doubles,
    range: None,
  }
  sampled_empty.print()
  sampled_full.print()
  interpolation.print()
  stitching.print()
  calculator.print()
}

///|
test "parse calculator keywords from stream" {
  let prev_logger = @pdfe.logger.val
  @pdfe.logger.val = _ => ()
  defer {
    @pdfe.logger.val = prev_logger
  }
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(4)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
  ])
  let data = @pdfio.bytes_of_string(
    "{ true 1.5 add 2 round 3 1 roll 2 atan 30 sin ceiling sqrt cos sub 2 abs 1 neg 0 index { 1 } if { 0 } { 1 } ifelse }",
  )
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let fun = PdfFunction::parse(pdf, stream)
  match (fun.func : PdfFunctionKind) {
    Calculator(ops) => {
      assert_true(ops.length() >= 10)
      match (ops[0] : Calculator) {
        Bool(true) => ()
        _ => fail("expected boolean literal")
      }
      match (ops[1] : Calculator) {
        Float(f) => assert_close(f, 1.5)
        _ => fail("expected float literal")
      }
      match (ops[2] : Calculator) {
        Add => ()
        _ => fail("expected add operator")
      }
      match (ops[3] : Calculator) {
        Int(2) => ()
        _ => fail("expected int literal")
      }
      match (ops[4] : Calculator) {
        Round => ()
        _ => fail("expected round operator")
      }
      match (ops[5] : Calculator) {
        Int(3) => ()
        _ => fail("expected int literal")
      }
      match (ops[6] : Calculator) {
        Int(1) => ()
        _ => fail("expected int literal")
      }
      match (ops[7] : Calculator) {
        Roll => ()
        _ => fail("expected roll operator")
      }
    }
    _ => fail("expected calculator function")
  }
  fun.print()
}

///|
test "parse calculator rejects multi-token group" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(4)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
  ])
  let data = @pdfio.bytes_of_string("{ 0 { 1 2 } }")
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let res : Result[PdfFunction, Error] = try? PdfFunction::parse(pdf, stream)
  assert_true(res is Err(_))
}

///|
test "calculator arithmetic ops" {
  let add = eval_calc([Calculator::Int(2), Calculator::Int(3), Calculator::Add])
  assert_eq(add.length(), 1)
  assert_close(add[0], 5.0)
  let sub = eval_calc([Calculator::Int(10), Calculator::Int(3), Calculator::Sub])
  assert_close(sub[0], 7.0)
  let mul = eval_calc([Calculator::Int(4), Calculator::Int(5), Calculator::Mul])
  assert_close(mul[0], 20.0)
  let div = eval_calc([Calculator::Int(8), Calculator::Int(2), Calculator::Div])
  assert_close(div[0], 0.25)
  let exp = eval_calc([Calculator::Int(3), Calculator::Int(2), Calculator::Exp])
  assert_close(exp[0], 8.0)
  let idiv = eval_calc([
    Calculator::Int(3),
    Calculator::Int(10),
    Calculator::Idiv,
  ])
  assert_close(idiv[0], 3.0)
  let mod = eval_calc([Calculator::Int(3), Calculator::Int(10), Calculator::Mod])
  assert_close(mod[0], 1.0)
}

///|
test "calculator rounding and conversion ops" {
  let abs = eval_calc([Calculator::Float(-1.4), Calculator::Abs])
  assert_close(abs[0], 1.4)
  let neg = eval_calc([Calculator::Int(5), Calculator::Neg])
  assert_close(neg[0], -5.0)
  let ceil = eval_calc([Calculator::Float(1.1), Calculator::Ceiling])
  assert_close(ceil[0], 2.0)
  let floor = eval_calc([Calculator::Float(1.9), Calculator::Floor])
  assert_close(floor[0], 1.0)
  let round = eval_calc([Calculator::Float(1.6), Calculator::Round])
  assert_close(round[0], 2.0)
  let trunc = eval_calc([Calculator::Float(1.9), Calculator::Truncate])
  assert_close(trunc[0], 1.0)
  let cvi = eval_calc([Calculator::Float(2.9), Calculator::Cvi])
  assert_close(cvi[0], 2.0)
  let cvr = eval_calc([Calculator::Int(5), Calculator::Cvr])
  assert_close(cvr[0], 5.0)
}

///|
test "calculator trig and log ops" {
  let sin = eval_calc([Calculator::Float(90.0), Calculator::Sin])
  assert_close(sin[0], 1.0)
  let cos = eval_calc([Calculator::Float(0.0), Calculator::Cos])
  assert_close(cos[0], 1.0)
  let atan = eval_calc([
    Calculator::Int(1),
    Calculator::Int(0),
    Calculator::Atan,
  ])
  assert_close(atan[0], 0.0)
  let ln = eval_calc([Calculator::Float(1.0), Calculator::Ln])
  assert_close(ln[0], 0.0)
  let log = eval_calc([Calculator::Float(1.0), Calculator::Log])
  assert_close(log[0], 0.0)
  let sqrt = eval_calc([Calculator::Int(9), Calculator::Sqrt])
  assert_close(sqrt[0], 3.0)
}

///|
test "calculator stack ops" {
  let dup = eval_calc([Calculator::Int(3), Calculator::Dup])
  assert_eq(dup.length(), 2)
  assert_close(dup[0], 3.0)
  assert_close(dup[1], 3.0)
  let exch = eval_calc([
    Calculator::Int(1),
    Calculator::Int(2),
    Calculator::Exch,
  ])
  assert_eq(exch.length(), 2)
  assert_close(exch[0], 1.0)
  assert_close(exch[1], 2.0)
  let pop = eval_calc([Calculator::Int(1), Calculator::Int(2), Calculator::Pop])
  assert_eq(pop.length(), 1)
  assert_close(pop[0], 1.0)
  let copy = eval_calc([
    Calculator::Int(1),
    Calculator::Int(2),
    Calculator::Int(3),
    Calculator::Int(2),
    Calculator::Copy,
  ])
  assert_eq(copy.length(), 5)
  assert_close(copy[0], 3.0)
  assert_close(copy[1], 2.0)
  assert_close(copy[2], 3.0)
  assert_close(copy[3], 2.0)
  assert_close(copy[4], 1.0)
  let index = eval_calc([
    Calculator::Int(7),
    Calculator::Int(8),
    Calculator::Int(9),
    Calculator::Int(1),
    Calculator::Index,
  ])
  assert_eq(index.length(), 4)
  assert_close(index[0], 8.0)
  assert_close(index[1], 9.0)
  assert_close(index[2], 8.0)
  assert_close(index[3], 7.0)
  let roll = eval_calc([
    Calculator::Int(1),
    Calculator::Int(2),
    Calculator::Int(3),
    Calculator::Int(3),
    Calculator::Int(1),
    Calculator::Roll,
  ])
  assert_eq(roll.length(), 3)
  assert_close(roll[0], 1.0)
  assert_close(roll[1], 3.0)
  assert_close(roll[2], 2.0)
}

///|
test "calculator boolean and comparison ops" {
  let and_int = eval_calc([
    Calculator::Int(6),
    Calculator::Int(3),
    Calculator::And,
  ])
  assert_close(and_int[0], 2.0)
  let or_int = eval_calc([
    Calculator::Int(2),
    Calculator::Int(1),
    Calculator::Or,
  ])
  assert_close(or_int[0], 3.0)
  let xor_int = eval_calc([
    Calculator::Int(6),
    Calculator::Int(3),
    Calculator::Xor,
  ])
  assert_close(xor_int[0], 5.0)
  let not_int = eval_calc([Calculator::Int(0), Calculator::Not])
  assert_close(not_int[0], -1.0)
  let bitshift = eval_calc([
    Calculator::Int(1),
    Calculator::Int(2),
    Calculator::Bitshift,
  ])
  assert_close(bitshift[0], 1.0)
  let bitshift_neg = eval_calc([
    Calculator::Int(-1),
    Calculator::Int(4),
    Calculator::Bitshift,
  ])
  assert_close(bitshift_neg[0], 2.0)
  let and_bool = eval_calc([
    Calculator::Bool(true),
    Calculator::Bool(false),
    Calculator::And,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(and_bool[0], 0.0)
  let or_bool = eval_calc([
    Calculator::Bool(false),
    Calculator::Bool(true),
    Calculator::Or,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(or_bool[0], 1.0)
  let xor_bool = eval_calc([
    Calculator::Bool(true),
    Calculator::Bool(true),
    Calculator::Xor,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(xor_bool[0], 0.0)
  let not_bool = eval_calc([
    Calculator::Bool(false),
    Calculator::Bool(true),
    Calculator::Not,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(not_bool[0], 0.0)
  let eq_true = eval_calc([
    Calculator::Int(2),
    Calculator::Int(2),
    Calculator::Eq,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(eq_true[0], 1.0)
  let eq_false = eval_calc([
    Calculator::Int(1),
    Calculator::Float(1.0),
    Calculator::Eq,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(eq_false[0], 0.0)
  let gt = eval_calc([
    Calculator::Int(1),
    Calculator::Int(2),
    Calculator::Gt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(gt[0], 1.0)
  let ge = eval_calc([
    Calculator::Int(2),
    Calculator::Int(2),
    Calculator::Ge,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(ge[0], 1.0)
  let lt = eval_calc([
    Calculator::Int(3),
    Calculator::Int(2),
    Calculator::Lt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(lt[0], 1.0)
  let le = eval_calc([
    Calculator::Int(2),
    Calculator::Int(2),
    Calculator::Le,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(le[0], 1.0)
  let ne = eval_calc([
    Calculator::Int(1),
    Calculator::Int(2),
    Calculator::Ne,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(ne[0], 1.0)
  let gt_cross = eval_calc([
    Calculator::Int(2),
    Calculator::Float(1.0),
    Calculator::Gt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(gt_cross[0], 0.0)
}

///|
test "calculator if and ifelse parse" {
  let pdf = @pdf.Pdf::empty()
  let dict_if : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(4)),
    ("/Domain", Array([])),
  ])
  let data_if = @pdfio.bytes_of_string("{ true { 5 } if }")
  let if_stream : @pdf.PdfObject = Stream(
    Ref::new((dict_if, @pdf.Stream::Got(data_if))),
  )
  let fun_if = PdfFunction::parse(pdf, if_stream)
  let out_if = PdfFunction::eval(fun_if, [])
  assert_eq(out_if.length(), 1)
  assert_close(out_if[0], 5.0)
  let dict_ifelse : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(4)),
    ("/Domain", Array([])),
  ])
  let data_ifelse = @pdfio.bytes_of_string("{ false { 1 } { 2 } ifelse }")
  let ifelse_stream : @pdf.PdfObject = Stream(
    Ref::new((dict_ifelse, @pdf.Stream::Got(data_ifelse))),
  )
  let fun_ifelse = PdfFunction::parse(pdf, ifelse_stream)
  let out_ifelse = PdfFunction::eval(fun_ifelse, [])
  assert_eq(out_ifelse.length(), 1)
  assert_close(out_ifelse[0], 2.0)
}

///|
test "calculator errors on bad stack usage" {
  let bad_copy : Result[Array[Double], Error] = try? eval_calc([
    Calculator::Int(1),
    Calculator::Int(2),
    Calculator::Int(3),
    Calculator::Int(5),
    Calculator::Copy,
  ])
  assert_true(bad_copy is Err(_))
  let bad_index : Result[Array[Double], Error] = try? eval_calc([
    Calculator::Int(1),
    Calculator::Int(1),
    Calculator::Index,
  ])
  assert_true(bad_index is Err(_))
  let bad_roll : Result[Array[Double], Error] = try? eval_calc([
    Calculator::Int(0),
    Calculator::Int(1),
    Calculator::Roll,
  ])
  assert_true(bad_roll is Err(_))
}

///|
test "eval_function clamps range and rejects bad domain" {
  let clamped_fun : PdfFunction = {
    func: PdfFunctionKind::Calculator([Calculator::Int(2)]),
    domain: [],
    range: Some([0.0, 1.0]),
  }
  let clamped = PdfFunction::eval(clamped_fun, [])
  assert_eq(clamped.length(), 1)
  assert_close(clamped[0], 1.0)
  let bad_domain : PdfFunction = {
    func: PdfFunctionKind::Calculator([Calculator::Int(1)]),
    domain: [0.0],
    range: None,
  }
  let bad_domain_result : Result[Array[Double], Error] = try? PdfFunction::eval(
    bad_domain,
    [0.0],
  )
  assert_true(bad_domain_result is Err(_))
}

///|
test "parse function rejects bad inputs" {
  let prev_logger = @pdfe.logger.val
  @pdfe.logger.val = _ => ()
  defer {
    @pdfe.logger.val = prev_logger
  }
  let pdf = @pdf.Pdf::empty()
  let bad_type : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(9)),
    ("/Domain", Array([])),
  ])
  let bad_type_result : Result[PdfFunction, Error] = try? PdfFunction::parse(
    pdf, bad_type,
  )
  assert_true(bad_type_result is Err(_))
  let bad_calc_dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(4)),
    ("/Domain", Array([])),
  ])
  let bad_calc_data = @pdfio.bytes_of_string("{ nope }")
  let bad_calc_stream : @pdf.PdfObject = Stream(
    Ref::new((bad_calc_dict, @pdf.Stream::Got(bad_calc_data))),
  )
  let bad_calc_result : Result[PdfFunction, Error] = try? PdfFunction::parse(
    pdf, bad_calc_stream,
  )
  assert_true(bad_calc_result is Err(_))
  let sampled_dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", Array([Real(0.0), Real(1.0)])),
    ("/Size", Array([Integer(2)])),
    ("/BitsPerSample", Integer(1)),
  ])
  let sampled_data = @pdfio.bytes_of_list([0, 1])
  let sampled_stream : @pdf.PdfObject = Stream(
    Ref::new((sampled_dict, @pdf.Stream::Got(sampled_data))),
  )
  let sampled_result : Result[PdfFunction, Error] = try? PdfFunction::parse(
    pdf, sampled_stream,
  )
  assert_true(sampled_result is Err(_))
}

///|
test "PdfFunction::print covers extra calculator strings" {
  let prev_logger = @pdfe.logger.val
  @pdfe.logger.val = _ => ()
  defer {
    @pdfe.logger.val = prev_logger
  }
  let fun : PdfFunction = {
    func: PdfFunctionKind::Calculator([
      Calculator::Cvi,
      Calculator::Cvr,
      Calculator::Div,
      Calculator::Exp,
      Calculator::Floor,
      Calculator::Idiv,
      Calculator::Ln,
      Calculator::Log,
      Calculator::Mod,
      Calculator::Mul,
      Calculator::Truncate,
      Calculator::And,
      Calculator::Bitshift,
      Calculator::Eq,
      Calculator::Ge,
      Calculator::Gt,
      Calculator::Le,
      Calculator::Lt,
      Calculator::Ne,
      Calculator::Not,
      Calculator::Or,
      Calculator::Xor,
      Calculator::Copy,
      Calculator::Exch,
      Calculator::Pop,
      Calculator::Dup,
    ]),
    domain: [],
    range: None,
  }
  fun.print()
}

///|
test "parse calculator keywords covers remaining ops" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(4)),
    ("/Domain", Array([])),
  ])
  let data = @pdfio.bytes_of_string(
    "{ cvi cvr div exp floor idiv ln log mod mul truncate and bitshift eq ge gt le lt ne not or xor copy exch pop dup index roll }",
  )
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let fun = PdfFunction::parse(pdf, stream)
  match (fun.func : PdfFunctionKind) {
    Calculator(ops) => assert_true(ops.length() > 0)
    _ => fail("expected calculator function")
  }
}

///|
test "sampled function covers size multiplication" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Sampled({
      size: [2, 2],
      order: 1,
      encode: [0.0, 1.0, 0.0, 1.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255, 255, 0],
    }),
    domain: [0.0, 1.0, 0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  let out = PdfFunction::eval(fun, [0.5, 0.5])
  assert_eq(out.length(), 1)
}

///|
test "sampled function errors on incompatible size" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Sampled({
      size: [2, 2],
      order: 1,
      encode: [0.0, 1.0, 0.0, 1.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255, 255, 0],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.5]))
}

///|
test "sampled function errors on missing range" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Sampled({
      size: [2],
      order: 1,
      encode: [0.0, 1.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255],
    }),
    domain: [0.0, 1.0],
    range: None,
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.5]))
}

///|
test "sampled function errors on bad encode length" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Sampled({
      size: [2],
      order: 1,
      encode: [0.0, 1.0, 2.0],
      decode: [0.0, 1.0],
      bps: 8,
      samples: [0, 255],
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.5]))
}

///|
test "eval_function rejects bad domain length" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Calculator([Calculator::Int(1)]),
    domain: [0.0, 1.0],
    range: None,
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.5, 0.5]))
}

///|
test "clamp_double clamps to min" {
  let fun : PdfFunction = {
    func: PdfFunctionKind::Calculator([Calculator::Int(-1)]),
    domain: [],
    range: Some([0.0, 1.0]),
  }
  let out = PdfFunction::eval(fun, [])
  assert_close(out[0], 0.0)
}

///|
test "calculator type error cases" {
  assert_is_err(try? eval_calc([Calculator::Add]))
  assert_is_err(
    try? eval_calc([Calculator::Int(1), Calculator::If([Calculator::Int(1)])]),
  )
  assert_is_err(try? eval_calc([Calculator::Bool(true), Calculator::Sin]))
  assert_is_err(
    try? eval_calc([
      Calculator::Float(1.0),
      Calculator::Int(2),
      Calculator::Idiv,
    ]),
  )
}

///|
test "calculator abs/add branches and ceiling int" {
  let abs_int = eval_calc([Calculator::Int(-3), Calculator::Abs])
  assert_close(abs_int[0], 3.0)
  let add_ff = eval_calc([
    Calculator::Float(1.0),
    Calculator::Float(2.0),
    Calculator::Add,
  ])
  assert_close(add_ff[0], 3.0)
  let add_if = eval_calc([
    Calculator::Int(1),
    Calculator::Float(2.0),
    Calculator::Add,
  ])
  assert_close(add_if[0], 3.0)
  let add_fi = eval_calc([
    Calculator::Float(1.0),
    Calculator::Int(2),
    Calculator::Add,
  ])
  assert_close(add_fi[0], 3.0)
  let ceil_int = eval_calc([Calculator::Int(3), Calculator::Ceiling])
  assert_close(ceil_int[0], 3.0)
}

///|
test "calculator comparisons over bool and floats" {
  let bool_eq = eval_calc([
    Calculator::Bool(true),
    Calculator::Bool(true),
    Calculator::Eq,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(bool_eq[0], 1.0)
  let bool_gt = eval_calc([
    Calculator::Bool(false),
    Calculator::Bool(true),
    Calculator::Gt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(bool_gt[0], 1.0)
  let bool_lt = eval_calc([
    Calculator::Bool(true),
    Calculator::Bool(false),
    Calculator::Lt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(bool_lt[0], 1.0)
  let float_lt = eval_calc([
    Calculator::Float(2.0),
    Calculator::Float(1.0),
    Calculator::Lt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(float_lt[0], 1.0)
  let float_gt = eval_calc([
    Calculator::Float(1.0),
    Calculator::Float(2.0),
    Calculator::Gt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(float_gt[0], 1.0)
  let float_eq = eval_calc([
    Calculator::Float(1.0),
    Calculator::Float(1.0),
    Calculator::Ge,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(float_eq[0], 1.0)
}

///|
test "calculator comparisons across types" {
  let bool_int = eval_calc([
    Calculator::Int(1),
    Calculator::Bool(false),
    Calculator::Lt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(bool_int[0], 1.0)
  let float_int = eval_calc([
    Calculator::Int(2),
    Calculator::Float(1.0),
    Calculator::Lt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(float_int[0], 1.0)
  let float_bool = eval_calc([
    Calculator::Bool(false),
    Calculator::Float(1.0),
    Calculator::Gt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(float_bool[0], 1.0)
  let int_bool = eval_calc([
    Calculator::Bool(false),
    Calculator::Int(1),
    Calculator::Gt,
    Calculator::IfElse([Calculator::Int(1)], [Calculator::Int(0)]),
  ])
  assert_close(int_bool[0], 1.0)
}

///|
test "parse_function hits error branches" {
  let pdf = @pdf.Pdf::empty()
  let bad_domain : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(2)),
    ("/Domain", Integer(1)),
    ("/N", Real(1.0)),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_domain))
  let bad_size : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", Array([])),
    ("/Size", Array([Real(2.0)])),
    ("/BitsPerSample", Integer(8)),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_size))
  let bad_size_type : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", Array([])),
    ("/Size", Integer(1)),
    ("/BitsPerSample", Integer(8)),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_size_type))
  let bad_bps : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", Array([])),
    ("/Size", Array([Integer(2)])),
    ("/BitsPerSample", Name(@pdf.PdfName::of_string("/Bad"))),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_bps))
  let to_get = @pdf.ToGet::new(@pdfio.Input::of_string("x"), 0, 1)
  let sample_dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(0)),
    ("/Domain", Array([])),
    ("/Size", Array([Integer(1)])),
    ("/BitsPerSample", Integer(8)),
    ("/Decode", Array([Real(0.0)])),
  ])
  let sample_stream : @pdf.PdfObject = Stream(
    Ref::new((sample_dict, @pdf.Stream::ToGet(to_get))),
  )
  assert_is_err(try? PdfFunction::parse(pdf, sample_stream))
  let calc_dict : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(4)),
    ("/Domain", Array([])),
  ])
  let calc_stream : @pdf.PdfObject = Stream(
    Ref::new((calc_dict, @pdf.Stream::ToGet(to_get))),
  )
  assert_is_err(try? PdfFunction::parse(pdf, calc_stream))
  let bad_functions : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(3)),
    ("/Domain", Array([])),
    ("/Functions", Integer(1)),
    ("/Bounds", Array([])),
    ("/Encode", Array([])),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_functions))
  let bad_bounds : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(3)),
    ("/Domain", Array([])),
    ("/Functions", Array([])),
    ("/Bounds", Integer(1)),
    ("/Encode", Array([])),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_bounds))
  let bad_encode : @pdf.PdfObject = Dictionary([
    ("/FunctionType", Integer(3)),
    ("/Domain", Array([])),
    ("/Functions", Array([])),
    ("/Bounds", Array([])),
    ("/Encode", Integer(1)),
  ])
  assert_is_err(try? PdfFunction::parse(pdf, bad_encode))
}

///|
test "stitching eval errors on encode length" {
  let f : PdfFunction = {
    func: PdfFunctionKind::Calculator([Calculator::Int(1)]),
    domain: [0.0, 1.0],
    range: None,
  }
  let fun : PdfFunction = {
    func: PdfFunctionKind::Stitching({
      functions: [f],
      bounds: [0.5],
      stitch_encode: [],
    }),
    domain: [0.0, 1.0],
    range: None,
  }
  assert_is_err(try? PdfFunction::eval(fun, [0.25]))
}
