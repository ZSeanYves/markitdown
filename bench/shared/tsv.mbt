///|
pub fn escape(text : String) -> String {
  text
  .replace(old="\t", new=" ")
  .replace(old="\n", new=" ")
  .replace(old="\r", new=" ")
}

///|
pub fn header(cols : Array[String]) -> String {
  cols.map(fn(col) { escape(col) }).join("\t")
}

///|
pub fn row(cols : Array[String]) -> String {
  cols.map(fn(col) { escape(col) }).join("\t")
}
