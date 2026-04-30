///|
async fn cleanup(path : String) -> Unit {
  let _ : Result[Unit, Error] = try? @fs.remove(path)
}

///|
async test "run writes output pdf" {
  let out = "cmd_pdfhello_test.pdf"
  cleanup(out)
  run(out_file=out, quiet=true)
  assert_true(@fs.exists(out))
  cleanup(out)
}
