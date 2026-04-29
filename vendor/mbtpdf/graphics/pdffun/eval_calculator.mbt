///|
fn value_equal(a : Calculator, b : Calculator) -> Bool {
  match (a, b) {
    (Calculator::Bool(x), Calculator::Bool(y)) => x == y
    (Calculator::Float(x), Calculator::Float(y)) => x == y
    (Calculator::Int(x), Calculator::Int(y)) => x == y
    _ => false
  }
}

///|
fn value_compare(
  a : Calculator,
  b : Calculator,
) -> Int raise BadFunctionEvaluation {
  match (a, b) {
    (Calculator::Bool(x), Calculator::Bool(y)) =>
      if x == y {
        0
      } else if x {
        1
      } else {
        -1
      }
    (Calculator::Float(x), Calculator::Float(y)) =>
      if x < y {
        -1
      } else if x > y {
        1
      } else {
        0
      }
    (Calculator::Int(x), Calculator::Int(y)) =>
      if x < y {
        -1
      } else if x > y {
        1
      } else {
        0
      }
    (Calculator::Bool(_), _) => -1
    (Calculator::Float(_), Calculator::Int(_)) => -1
    (Calculator::Float(_), Calculator::Bool(_)) => 1
    (Calculator::Int(_), _) => 1
    _ => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn pop_value(
  stack : Array[Calculator],
) -> Calculator raise BadFunctionEvaluation {
  match stack.pop() {
    Some(value) => value
    None => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn pop_float(stack : Array[Calculator]) -> Double raise BadFunctionEvaluation {
  match pop_value(stack) {
    Calculator::Float(f) => f
    Calculator::Int(i) => i.to_double()
    _ => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn pop_int(stack : Array[Calculator]) -> Int raise BadFunctionEvaluation {
  match pop_value(stack) {
    Calculator::Int(i) => i
    _ => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn pop_bool(stack : Array[Calculator]) -> Bool raise BadFunctionEvaluation {
  match pop_value(stack) {
    Calculator::Bool(b) => b
    _ => raise BadFunctionEvaluation::Msg("Type error")
  }
}

///|
fn eval_function_calculator(
  clamped_inputs : Array[Double],
  ops : Array[Calculator],
) -> Array[Double] raise BadFunctionEvaluation {
  let stack = Array::new()
  for idx in (clamped_inputs.length() - 1)>=..0 {
    stack.push(Calculator::Float(clamped_inputs[idx]))
  }
  fn eval(
    op : Calculator,
    stack : Array[Calculator],
  ) -> Unit raise BadFunctionEvaluation {
    match op {
      Calculator::If(body) => {
        let cond = pop_bool(stack)
        if cond {
          for inner in body {
            eval(inner, stack)
          }
        }
      }
      Calculator::IfElse(a, b) => {
        let cond = pop_bool(stack)
        let body = if cond { a } else { b }
        for inner in body {
          eval(inner, stack)
        }
      }
      Calculator::Bool(_) | Calculator::Float(_) | Calculator::Int(_) =>
        stack.push(op)
      Calculator::Abs =>
        match pop_value(stack) {
          Calculator::Float(f) => stack.push(Calculator::Float(f.abs()))
          Calculator::Int(i) => stack.push(Calculator::Int(i.abs()))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Add => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(x + y))
          (Calculator::Float(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(x + y))
          (Calculator::Int(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(x.to_double() + y))
          (Calculator::Float(x), Calculator::Int(y)) =>
            stack.push(Calculator::Float(x + y.to_double()))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Atan => {
        let num = pop_float(stack)
        let den = pop_float(stack)
        stack.push(Calculator::Float(@math.atan2(num, den)))
      }
      Calculator::Ceiling =>
        match pop_value(stack) {
          Calculator::Float(f) => stack.push(Calculator::Float(f.ceil()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Cos => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(@math.cos(rad_of_deg(f))))
      }
      Calculator::Cvi =>
        match pop_value(stack) {
          Calculator::Float(f) =>
            stack.push(Calculator::Int(f.floor().to_int()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Cvr =>
        match pop_value(stack) {
          Calculator::Int(i) => stack.push(Calculator::Float(i.to_double()))
          Calculator::Float(f) => stack.push(Calculator::Float(f))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Div => {
        let n = pop_float(stack)
        let d = pop_float(stack)
        stack.push(Calculator::Float(n / d))
      }
      Calculator::Exp => {
        let bse = pop_float(stack)
        let exp = pop_float(stack)
        stack.push(Calculator::Float(@math.pow(bse, exp)))
      }
      Calculator::Floor =>
        match pop_value(stack) {
          Calculator::Float(f) =>
            stack.push(Calculator::Int(f.floor().to_int()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Idiv => {
        let a = pop_int(stack)
        let b = pop_int(stack)
        stack.push(Calculator::Int(a / b))
      }
      Calculator::Ln => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(@math.ln(f)))
      }
      Calculator::Log => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(@math.log10(f)))
      }
      Calculator::Mod => {
        let a = pop_int(stack)
        let b = pop_int(stack)
        stack.push(Calculator::Int(a % b))
      }
      Calculator::Mul => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(x * y))
          (Calculator::Float(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(x * y))
          (Calculator::Int(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(x.to_double() * y))
          (Calculator::Float(x), Calculator::Int(y)) =>
            stack.push(Calculator::Float(x * y.to_double()))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Neg =>
        match pop_value(stack) {
          Calculator::Float(f) => stack.push(Calculator::Float(-f))
          Calculator::Int(i) => stack.push(Calculator::Int(-i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Round =>
        match pop_value(stack) {
          Calculator::Float(f) =>
            stack.push(Calculator::Int(f.round().to_int()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Sin => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(@math.sin(rad_of_deg(f))))
      }
      Calculator::Sqrt => {
        let f = pop_float(stack)
        stack.push(Calculator::Float(f.sqrt()))
      }
      Calculator::Sub => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(y - x))
          (Calculator::Float(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(y - x))
          (Calculator::Int(x), Calculator::Float(y)) =>
            stack.push(Calculator::Float(y - x.to_double()))
          (Calculator::Float(x), Calculator::Int(y)) =>
            stack.push(Calculator::Float(y.to_double() - x))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Truncate =>
        match pop_value(stack) {
          Calculator::Float(f) => stack.push(Calculator::Int(f.to_int()))
          Calculator::Int(i) => stack.push(Calculator::Int(i))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::And => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(Int::land(x, y)))
          (Calculator::Bool(x), Calculator::Bool(y)) =>
            stack.push(Calculator::Bool(x && y))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Bitshift => {
        let i = pop_int(stack)
        let shift = pop_int(stack)
        let result = if i < 0 {
          i << shift
        } else {
          let u = i.reinterpret_as_uint()
          let shifted = u >> (if shift < 0 { -shift } else { shift })
          shifted.reinterpret_as_int()
        }
        stack.push(Calculator::Int(result))
      }
      Calculator::Eq => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_equal(a, b)))
      }
      Calculator::Ge => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_compare(a, b) >= 0))
      }
      Calculator::Gt => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_compare(a, b) > 0))
      }
      Calculator::Le => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_compare(a, b) <= 0))
      }
      Calculator::Lt => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(value_compare(a, b) < 0))
      }
      Calculator::Ne => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(Calculator::Bool(!value_equal(a, b)))
      }
      Calculator::Not =>
        match pop_value(stack) {
          Calculator::Int(i) => stack.push(Calculator::Int(Int::lnot(i)))
          Calculator::Bool(b) => {
            let _ = pop_bool(stack)
            stack.push(Calculator::Bool(!b))
          }
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Or => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(Int::lor(x, y)))
          (Calculator::Bool(x), Calculator::Bool(y)) =>
            stack.push(Calculator::Bool(x || y))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Xor => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        match (a, b) {
          (Calculator::Int(x), Calculator::Int(y)) =>
            stack.push(Calculator::Int(Int::lxor(x, y)))
          (Calculator::Bool(x), Calculator::Bool(y)) =>
            stack.push(Calculator::Bool((x || y) && !(x && y)))
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      }
      Calculator::Copy =>
        match pop_value(stack) {
          Calculator::Int(i) if i >= 0 => {
            let count = i
            let original_len = stack.length()
            let start = original_len - count
            if start < 0 {
              raise BadFunctionEvaluation::Msg("Type error")
            }
            let slice = stack.sub(start~, end=original_len).to_array()
            for value in slice {
              stack.push(value)
            }
          }
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Exch => {
        let a = pop_value(stack)
        let b = pop_value(stack)
        stack.push(a)
        stack.push(b)
      }
      Calculator::Pop => {
        let _ = pop_value(stack)

      }
      Calculator::Dup => {
        let a = pop_value(stack)
        stack.push(a)
        stack.push(a)
      }
      Calculator::Index =>
        match pop_value(stack) {
          Calculator::Int(i) if i >= 0 => {
            let idx = stack.length() - 1 - i
            if idx < 0 || idx >= stack.length() {
              raise BadFunctionEvaluation::Msg("Type error")
            }
            stack.push(stack[idx])
          }
          _ => raise BadFunctionEvaluation::Msg("Type error")
        }
      Calculator::Roll => {
        let j = pop_int(stack)
        let n = pop_int(stack)
        if n < 1 {
          raise BadFunctionEvaluation::Msg("Type error")
        }
        let count = n
        let start = stack.length() - count
        if start < 0 {
          raise BadFunctionEvaluation::Msg("Type error")
        }
        let slice = stack.sub(start~, end=stack.length()).to_array()
        stack.truncate(start)
        let mut rotated = Array::new(capacity=slice.length())
        if j > 0 {
          for k in 0..<slice.length() {
            rotated.push(slice[(k + j) % slice.length()])
          }
        } else if j < 0 {
          let shift = -j
          for k in 0..<slice.length() {
            rotated.push(
              slice[(k + slice.length() - shift % slice.length()) %
              slice.length()],
            )
          }
        } else {
          rotated = slice
        }
        for value in rotated {
          stack.push(value)
        }
      }
    }
  }

  for op in ops {
    eval(op, stack)
  }
  let out = Array::new(capacity=stack.length())
  for i in (stack.length() - 1)>=..0 {
    match stack[i] {
      Calculator::Float(x) => out.push(x)
      Calculator::Int(i) => out.push(i.to_double())
      _ => raise BadFunctionEvaluation::Msg("Type 4-a")
    }
  }
  out
}
