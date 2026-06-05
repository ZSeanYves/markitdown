///|
pub(all) suberror Utf8DecodeError {
  Utf8DecodeError(String)
}

///|
pub(all) suberror AppError {
  AppError(String)
}

///|
pub impl Show for Utf8DecodeError with fn to_string(self : Utf8DecodeError) -> String {
  match self {
    Utf8DecodeError(msg) => msg
  }
}

///|
pub impl Show for Utf8DecodeError with fn output(
  self : Utf8DecodeError,
  logger : &Logger,
) -> Unit {
  match self {
    Utf8DecodeError(msg) => logger.write_string(msg)
  }
}

///|
pub impl Show for AppError with fn to_string(self : AppError) -> String {
  match self {
    AppError(msg) => msg
  }
}

///|
pub impl Show for AppError with fn output(self : AppError, logger : &Logger) -> Unit {
  match self {
    AppError(msg) => logger.write_string(msg)
  }
}
