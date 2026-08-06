///|
/// Return the stable machine error identifier.
pub fn ConvertError::code(self : ConvertError) -> ErrorCode {
  match self {
    DetectionFailed(_) => DetectionFailed
    ParseFailed(_) => ParseFailed
    RenderFailed(_) => RenderFailed
    ResourceLimitExceeded(_) => ResourceLimitExceeded
    InvalidOption(_) => InvalidOption
  }
}

///|
/// Return a versioned string code suitable for logs and serialized APIs.
pub fn ErrorCode::stable_name(self : ErrorCode) -> String {
  match self {
    DetectionFailed => "MID-1001"
    ParseFailed => "MID-2001"
    RenderFailed => "MID-3001"
    ResourceLimitExceeded => "MID-4001"
    InvalidOption => "MID-0002"
  }
}

///|
/// Return the process exit status assigned to this error class.
pub fn ConvertError::exit_code(self : ConvertError) -> Int {
  match self.code() {
    InvalidOption => 2
    DetectionFailed => 3
    ParseFailed => 4
    ResourceLimitExceeded => 5
    RenderFailed => 6
  }
}

///|
/// Return a human-readable error without discarding its machine code.
pub fn ConvertError::message(self : ConvertError) -> String {
  match self {
    DetectionFailed(message) => "detect failed: " + message
    ParseFailed(message) => "parse failed: " + message
    RenderFailed(message) => "render failed: " + message
    ResourceLimitExceeded(kind~, observed~, limit~) =>
      "resource limit exceeded: " +
      kind +
      "; observed=" +
      observed.to_string() +
      "; limit=" +
      limit.to_string()
    InvalidOption(message) => "invalid option: " + message
  }
}

///|
pub impl Show for ConvertError with fn to_string(self : ConvertError) -> String {
  self.code().stable_name() + ": " + self.message()
}

///|
pub impl Show for ConvertError with fn output(
  self : ConvertError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn convert_error_from_legacy(error : @convert.ConvertError) -> ConvertError {
  match error {
    DetectFailed(message) => DetectionFailed(message)
    ParseFailed(message) => ParseFailed(message)
    RenderFailed(message) => RenderFailed(message)
    ResourceLimitExceeded(kind~, observed~, limit~) =>
      ResourceLimitExceeded(kind~, observed~, limit~)
  }
}
