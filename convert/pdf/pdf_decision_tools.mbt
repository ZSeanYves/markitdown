///|
fn push_reason_if(
  out : Array[String],
  condition : Bool,
  tag : String,
) -> Unit {
  if condition {
    out.push(tag)
  }
}

///|
fn push_reason_if_empty(
  out : Array[String],
  fallback : String,
) -> Unit {
  if out.is_empty() {
    out.push(fallback)
  }
}
