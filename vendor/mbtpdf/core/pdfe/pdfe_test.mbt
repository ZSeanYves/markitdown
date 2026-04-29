///|
test "log forwards to logger" {
  let messages : Array[String] = []
  @pdfe.with_logger(fn(message) { messages.push(message) }, fn() {
    @pdfe.log("hello")
    @pdfe.log("world")
    ()
  })
  inspect(messages, content="[\"hello\", \"world\"]")
}

///|
test "quiet suppresses log output" {
  let messages : Array[String] = []
  @pdfe.with_logger(fn(message) { messages.push(message) }, fn() {
    @pdfe.quiet.val = true
    @pdfe.log("hello")
    @pdfe.quiet.val = false
    @pdfe.log("world")
    ()
  })
  inspect(messages, content="[\"world\"]")
}

///|
test "with_silenced_logs restores quiet flag" {
  @pdfe.quiet.val = false
  let messages : Array[String] = []
  @pdfe.with_logger(fn(message) { messages.push(message) }, fn() {
    @pdfe.with_silenced_logs(fn() {
      @pdfe.log("hidden")
      ()
    })
    @pdfe.log("shown")
    ()
  })
  assert_false(@pdfe.quiet.val)
  inspect(messages, content="[\"shown\"]")
}

///|
test "with_logger restores previous logger on error" {
  let outer_messages : Array[String] = []
  let inner_messages : Array[String] = []
  @pdfe.with_logger(fn(message) { outer_messages.push(message) }, fn() {
    let res : Result[Unit, Error] = try? @pdfe.with_logger(
      fn(message) { inner_messages.push(message) },
      fn() {
        @pdfe.log("inner")
        fail("boom")
      },
    )
    assert_true(res is Err(_))
    @pdfe.log("outer")
    ()
  })
  inspect(inner_messages, content="[\"inner\"]")
  inspect(outer_messages, content="[\"outer\"]")
}

///|
test "default logger writes via PdfUtil" {
  let prev_quiet = @pdfutil.quiet.val
  let prev_printer = @pdfutil.printer.val
  let lines : Array[String] = []
  @pdfutil.printer.val = s => lines.push(s)
  try {
    @pdfutil.quiet.val = true
    @pdfutil.PdfUtil::new().fleprint("reset")
    @pdfutil.quiet.val = false
    (@pdfe.logger.val)("hello\n")
    assert_eq(lines, ["hello"])
    @pdfutil.quiet.val = prev_quiet
    @pdfutil.printer.val = prev_printer
  } catch {
    err => {
      @pdfutil.quiet.val = prev_quiet
      @pdfutil.printer.val = prev_printer
      raise err
    }
  }
}
