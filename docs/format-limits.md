# Format Limits and Fallback Policy

This is the working ledger for format capability limits and fallback policy.
It is not a bug list.

The document records unsupported-by-design behavior, deferred advanced
features, and expected fallback behavior. It can later feed the supported
formats matrix or user-facing documentation.

## XML

### Supported baseline

* Safe element trees.
* Attributes.
* Text.
* CDATA as text.
* Namespace prefixes preserved as raw names.
* Predefined entities when supported by the parser.
* Structured lowering for small and simple XML.
* Source-preserving fenced fallback for unsupported, complex, malformed, or
  large XML.

### Unsupported by design

* DTD expansion.
* External entity resolution / XXE.
* External resource fetch.

### Reason

These features carry security and performance risks. XML conversion must not
fetch network resources or read local files from XML entity / system
identifiers.

### Deferred advanced features

* XML schema validation.
* XPath / query language support.
* Namespace semantic resolution.
* Numeric character references, if not yet implemented by the parser.
* Richer mixed-content rendering.
* Repeated-child table inference.

### Default behavior

* Fail closed or use source-preserving fenced fallback.
* No network access.
* No local file reads from XML entity / system identifiers.
* No DTD / entity expansion.

### Quality / real sample status

* Main repo XML tests and samples pass.
* External XML quality rows pass.
* CPython XML and IDPF PLS fixtures are strict metadata-closed.
* Microsoft RSS is runtime guard only pending license review.

## YAML

### Supported baseline

* Conservative block mapping / sequence.
* Scalar strings, bool, and null.
* Quoted strings.
* Comments.
* Conservative single-line flow sequence / mapping.

### Unsupported / deferred

* Full YAML 1.2.
* Block scalars.
* Anchors / aliases.
* Tags.
* Merge keys.
* Complex keys.
* Real multi-document streams.

### Default behavior

* Unsupported features fail closed.
* No implicit schema magic beyond the current parser model.

## CSV / TSV

### Supported baseline

* CSV comma delimiter.
* TSV tab delimiter as input format.
* Quoted fields.
* Escaped quotes.
* CRLF / LF.
* BOM stripping.
* Multiline quoted fields.
* Ragged rows with convert-side table policy.

### Limits

* No streaming parser.
* Full-table memory behavior.
* Header / table policy belongs to `convert/csv`.
* TSV manifest / config / control is not a runtime conversion format policy.
