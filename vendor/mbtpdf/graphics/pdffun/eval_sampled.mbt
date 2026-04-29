///|
fn interpolate(
  x : Double,
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
) -> Double {
  ymin + (x - xmin) * ((ymax - ymin) / (xmax - xmin))
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn clampvals(
  values : Array[Double],
  domain : Array[Double],
) -> Array[Double] raise BadFunctionEvaluation {
  if domain.length() % 2 == 1 {
    raise BadFunctionEvaluation::Msg("Domain wrong")
  }
  let out = Array::new(capacity=values.length())
  for i in 0..<values.length() {
    let d = i * 2
    if d + 1 >= domain.length() {
      raise BadFunctionEvaluation::Msg("Domain wrong")
    }
    out.push(clamp_double(values[i], domain[d], domain[d + 1]))
  }
  out
}
