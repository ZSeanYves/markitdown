///|
pub fn register_builtin_parsers(registry : @parser.ParserRegistry) -> Unit {
  @meta.register_builtin_parsers(registry)
}

///|
pub fn builtin_registry() -> @parser.ParserRegistry {
  @meta.builtin_registry()
}

///|
/// Construct the canonical asynchronous registry used by the product path.
/// Synchronous format implementations are adapted once at this boundary;
/// callers never maintain a second conversion executor.
pub fn builtin_unified_registry() -> @parser.UnifiedParserRegistry {
  @parser.unified_registry_from_sync(builtin_registry())
}
