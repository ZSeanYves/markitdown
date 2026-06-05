///|
fn[T] assert_is_err(result : Result[T, Error]) -> Unit raise {
  match result {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}
