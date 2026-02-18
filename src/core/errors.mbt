pub(all) suberror Utf8DecodeError{Utf8DecodeError (String)}


///|
pub impl Show for Utf8DecodeError with to_string(self : Utf8DecodeError) -> String {
  match self {
    Utf8DecodeError(msg) => msg
  }
}

///|
pub impl Show for Utf8DecodeError with output(
  self : Utf8DecodeError,
  logger : &Logger,
) -> Unit {
  match self {
    Utf8DecodeError(msg) => logger.write_string(msg)
  }
}
