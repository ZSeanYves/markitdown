///|
pub(all) suberror BenchCliError {
  InvalidArgument(String)
}

///|
pub impl Show for BenchCliError with fn to_string(self : BenchCliError) -> String {
  match self {
    InvalidArgument(message) => message
  }
}

///|
pub impl Show for BenchCliError with fn output(
  self : BenchCliError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}
