///|
fn pairs_of_list_eval(
  values : Array[Double],
) -> Array[(Double, Double)] raise BadFunctionEvaluation {
  if values.length() % 2 == 1 {
    raise BadFunctionEvaluation::Msg("Bad list length")
  }
  let out = Array::new(capacity=values.length() / 2)
  for i = 0; i + 1 < values.length(); i = i + 2 {
    out.push((values[i], values[i + 1]))
  }
  out
}

///|
fn split_pairs(
  values : Array[(Double, Double)],
) -> (Array[Double], Array[Double]) {
  let left = Array::new(capacity=values.length())
  let right = Array::new(capacity=values.length())
  for pair in values {
    left.push(pair.0)
    right.push(pair.1)
  }
  (left, right)
}

///|
fn many(value : Double, count : Int) -> Array[Double] {
  Array::make(count, value)
}

///|
fn min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn interleave_lists(a : Array[Double], b : Array[Double]) -> Array[Double] {
  let out = Array::new(capacity=a.length() + b.length())
  let len = min(a.length(), b.length())
  for i in 0..<len {
    out.push(a[i])
    out.push(b[i])
  }
  out
}

///|
fn product(values : Array[Int]) -> Int {
  let mut total = 1
  for value in values {
    total = total * value
  }
  total
}

///|
fn[A, B, C] map2(a : Array[A], b : Array[B], f : (A, B) -> C) -> Array[C] {
  let len = min(a.length(), b.length())
  let out = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(a[i], b[i]))
  }
  out
}

///|
fn[A, B, C, D] map3(
  a : Array[A],
  b : Array[B],
  c : Array[C],
  f : (A, B, C) -> D,
) -> Array[D] {
  let len = min(min(a.length(), b.length()), c.length())
  let out = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(a[i], b[i], c[i]))
  }
  out
}

///|
fn[A, B, C, D, E, F] map5(
  a : Array[A],
  b : Array[B],
  c : Array[C],
  d : Array[D],
  e : Array[E],
  f : (A, B, C, D, E) -> F,
) -> Array[F] {
  let len = min(
    min(min(a.length(), b.length()), c.length()),
    min(d.length(), e.length()),
  )
  let out = Array::new(capacity=len)
  for i in 0..<len {
    out.push(f(a[i], b[i], c[i], d[i], e[i]))
  }
  out
}

///|
fn[T] flatten(lists : Array[Array[T]]) -> Array[T] {
  let mut total = 0
  for list in lists {
    total = total + list.length()
  }
  let out = Array::new(capacity=total)
  for list in lists {
    out.append(list[:])
  }
  out
}

///|
fn[T] select(index : Int, items : Array[T]) -> T raise BadFunctionEvaluation {
  if index <= 0 || index > items.length() {
    raise BadFunctionEvaluation::Msg("select")
  }
  items[index - 1]
}

///|
fn rad_of_deg(deg : Double) -> Double {
  deg * @math.PI / 180.0
}

///|
fn eval_function_sampled(
  f : PdfFunction,
  s : Sampled,
  clamped_inputs : Array[Double],
) -> Array[Double] raise BadFunctionEvaluation {
  let range = match f.range {
    Some(r) => r
    None => raise BadFunctionEvaluation::Msg("No Range")
  }
  let (d, d2) = split_pairs(pairs_of_list_eval(f.domain))
  let (e, e2) = split_pairs(pairs_of_list_eval(s.encode))
  let (dec, dec2) = split_pairs(pairs_of_list_eval(s.decode))
  let (r, r2) = split_pairs(pairs_of_list_eval(range))
  let encoded_inputs = map5(clamped_inputs, d, d2, e, e2, interpolate)
  let clamped_encoded = map2(encoded_inputs, s.size, (i, size) => clamp_double(
    i,
    0.0,
    size.to_double() - 1.0,
  ))
  let vals_to_read = range.length() / 2
  let read_table = (inputs : Array[Int]) => {
    if inputs.length() != s.size.length() {
      raise BadFunctionEvaluation::Msg("Incompatible /Size with inputs")
    }
    let multipliers = Array::new(capacity=inputs.length())
    multipliers.push(1)
    let mut multiplier = 1
    for idx in 1..<inputs.length() {
      multiplier = multiplier * s.size[idx - 1]
      multipliers.push(multiplier)
    }
    let mut pos = 0
    for i in 0..<inputs.length() {
      pos = pos + inputs[i] * multipliers[i]
    }
    pos = pos * vals_to_read
    let out = Array::new(capacity=vals_to_read)
    for j in 0..<vals_to_read {
      out.push(s.samples[pos + j])
    }
    out
  }
  let ceilings = clamped_encoded.map(value => value.ceil().to_int())
  let floors = clamped_encoded.map(value => value.floor().to_int())
  let ceiling_results = read_table(ceilings)
  let floor_results = read_table(floors)
  let outputs = Array::new(capacity=ceiling_results.length())
  for i in 0..<ceiling_results.length() {
    let value = ceiling_results[i].to_double() / 2.0 +
      floor_results[i].to_double() / 2.0
    outputs.push(value)
  }
  let outputs_decoded = map5(
    outputs,
    many(0.0, outputs.length()),
    many(@math.pow(2.0, s.bps.to_double()) - 1.0, outputs.length()),
    dec,
    dec2,
    interpolate,
  )
  map3(outputs_decoded, r, r2, (x, rmin, rmax) => clamp_double(x, rmin, rmax))
}

///|
fn[T] concat_arrays(a : Array[T], b : Array[T]) -> Array[T] {
  let out = Array::new(capacity=a.length() + b.length())
  out.append(a[:])
  out.append(b[:])
  out
}
