///|
/// Default error logger, writes the string to stderr (shim).
fn default(message : String) -> Unit {
  @pdfutil.PdfUtil::new().fleprint(message)
}

///|
pub type Logger = (String) -> Unit

///|
/// The current error logger, set to default upon startup.
pub let logger : Ref[Logger] = { val: default }

///|
/// When true, @pdfe.log is suppressed.
pub let quiet : Ref[Bool] = { val: false }

///|
/// Log a string using the current logger.
pub fn log(message : String) -> Unit {
  if !quiet.val {
    (logger.val)(message)
  }
}

///|
/// Debug flag for PDF reading operations.
pub let read_debug : Ref[Bool] = { val: false }

///|
/// Run an action with logging suppressed, restoring the previous state.
pub fn[T] with_silenced_logs(action : () -> T raise) -> T raise {
  let prev = quiet.val
  quiet.val = true
  try {
    let out = action()
    quiet.val = prev
    out
  } catch {
    err => {
      quiet.val = prev
      raise err
    }
  }
}

///|
/// Run an action with a temporary logger, restoring the previous logger.
pub fn[T] with_logger(temp : Logger, action : () -> T raise) -> T raise {
  let prev = logger.val
  logger.val = temp
  try {
    let out = action()
    logger.val = prev
    out
  } catch {
    err => {
      logger.val = prev
      raise err
    }
  }
}
