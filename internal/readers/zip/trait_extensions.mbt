///|
pub extend CompressionMethod with Eq::{equal, not_equal}

///|
pub extend CodecError with Show::{to_string, output}

///|
pub extend ZipError with Show::{to_string, output}

///|
pub extend ZipErrorMappingKind with Eq::{equal, not_equal}

///|
pub extend ZipErrorKind with Eq::{equal, not_equal}

///|
pub extend ZipValidationSeverity with Eq::{equal, not_equal}

///|
pub extend ZipValidationIssueKind with Eq::{equal, not_equal}
