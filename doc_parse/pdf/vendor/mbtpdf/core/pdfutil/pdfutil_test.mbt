///|
test "PdfUtil print shims respect quiet and printer" {
  let util = @pdfutil.PdfUtil::new()
  let prev_quiet = @pdfutil.quiet.val
  let prev_printer = @pdfutil.printer.val
  let lines : Array[String] = []
  @pdfutil.printer.val = s => lines.push(s)
  try {
    @pdfutil.quiet.val = true
    util.flprint("reset")
    util.fleprint("reset")
    assert_eq(lines.length(), 0)
    @pdfutil.quiet.val = false
    util.flprint("a")
    util.flprint("b\nc")
    util.flprint("\n")
    util.fleprint("err\n")
    assert_eq(lines, ["ab", "c", "err"])
    @pdfutil.quiet.val = true
    util.flprint("ignored\n")
    util.fleprint("ignored\n")
    assert_eq(lines, ["ab", "c", "err"])
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

///|
test "PdfUtil::memoize caches computed values" {
  let util = @pdfutil.PdfUtil::new()
  let calls : Ref[Int] = Ref::new(0)
  let memo = util.memoize(fn() {
    calls.val = calls.val + 1
    calls.val
  })
  assert_eq(memo(), 1)
  assert_eq(memo(), 1)
  assert_eq(calls.val, 1)
}
