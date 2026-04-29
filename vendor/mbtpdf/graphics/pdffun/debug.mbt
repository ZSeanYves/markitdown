///|
fn log_line(message : String) -> Unit {
  @pdfe.log(message + "\n")
}

///|
fn print_doubles(values : Array[Double]) -> Unit {
  if values.length() == 0 {
    log_line("")
  } else {
    log_line(values.map(v => v.to_string()).join(" "))
  }
}

///|
fn print_ints(values : Array[Int]) -> Unit {
  if values.length() == 0 {
    log_line("")
  } else {
    log_line(values.map(v => v.to_string()).join(" "))
  }
}

///|
/// Print a function to stdout for debug.
pub fn PdfFunction::print(self : PdfFunction) -> Unit {
  log_line("Domain...")
  print_doubles(self.domain)
  match self.range {
    None => log_line("null range")
    Some(values) => print_doubles(values)
  }
  match self.func {
    PdfFunctionKind::Sampled(s) => {
      log_line("Sampled")
      log_line("size: ")
      print_ints(s.size)
      log_line("order: \{s.order}")
      log_line("encode:")
      print_doubles(s.encode)
      log_line("decode:")
      print_doubles(s.decode)
      log_line("original bits per sample: \{s.bps}")
    }
    PdfFunctionKind::Interpolation(i) => {
      log_line("Interpolation")
      log_line("C0:")
      print_doubles(i.c0)
      log_line("C1:")
      print_doubles(i.c1)
      log_line("n = \{i.n}")
    }
    PdfFunctionKind::Stitching(s) => {
      log_line("Stitching")
      for fun in s.functions {
        fun.print()
      }
      log_line("Bounds:")
      print_doubles(s.bounds)
      log_line("Encode:")
      print_doubles(s.stitch_encode)
    }
    PdfFunctionKind::Calculator(c) => {
      log_line("Calculator:")
      log_line(Calculator::to_string(c))
    }
  }
}
