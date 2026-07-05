# Parser

`parser/` defines the unified parser contract. Every format parser must follow this shared boundary before it can join the main product path.

Main responsibilities:

- define the parser capability model
- define parse context
- define `ParseResult`
- provide synchronous and asynchronous registry dispatch

Main files:

- `types.mbt`
- `capabilities.mbt`
- `context.mbt`
- `registry.mbt`
- `constructors.mbt`

Maintenance rules:

- new parsers should register through `ParserRegistry` or `AsyncParserRegistry`
- do not grow extra product side paths that call parsers outside the registry
- parser output should converge on `ParseResult`

Validation:

```bash
moon build
moon test
```
