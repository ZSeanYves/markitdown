///|
pub fn register_builtin_parsers(registry : @parser.ParserRegistry) -> Unit {
  @meta.register_builtin_parsers(registry)
}

///|
pub fn builtin_registry() -> @parser.ParserRegistry {
  @meta.builtin_registry()
}
