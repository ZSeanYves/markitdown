///|
/// Evaluate a function on some inputs.
pub fn PdfFunction::eval(
  self : PdfFunction,
  inputs : Array[Double],
) -> Array[Double] raise BadFunctionEvaluation {
  let clamped_inputs = clampvals(inputs, self.domain)
  let outputs = match self.func {
    PdfFunctionKind::Calculator(ops) =>
      eval_function_calculator(clamped_inputs, ops)
    PdfFunctionKind::Sampled(s) =>
      eval_function_sampled(self, s, clamped_inputs)
    PdfFunctionKind::Interpolation(i) => {
      let interp = fn(
        n : Double,
        c0 : Array[Double],
        c1 : Array[Double],
        v : Double,
      ) -> Array[Double] {
        map2(c0, c1, (a, b) => a + @math.pow(v, n) * (b - a))
      }
      let mapped = clamped_inputs.map(v => interp(i.n, i.c0, i.c1, v))
      flatten(mapped)
    }
    PdfFunctionKind::Stitching(s) =>
      match (clamped_inputs, self.domain) {
        ([i], [d0, d1]) => {
          let points = concat_arrays([d0], concat_arrays(s.bounds, [d1]))
          let mut idx = 0
          let mut subfun : PdfFunction? = None
          while idx + 1 < points.length() {
            let p = points[idx]
            let p2 = points[idx + 1]
            if (i >= p && i < p2) || i == p2 {
              subfun = Some(s.functions[idx])
              break
            }
            idx = idx + 1
          }
          match subfun {
            None => raise BadFunctionEvaluation::Msg("stitching: funs")
            Some(f) => {
              let a = select(idx + 1, points)
              let b = select(idx + 2, points)
              let c = select(idx * 2 + 1, s.stitch_encode)
              let d = select(idx * 2 + 2, s.stitch_encode)
              let encode = (x : Double) => interpolate(x, a, b, c, d)
              f.eval([encode(i)])
            }
          }
        }
        _ => raise BadFunctionEvaluation::Msg("stitching: Bad arity")
      }
  }
  match self.range {
    None => outputs
    Some(range) => clampvals(outputs, range)
  }
}
