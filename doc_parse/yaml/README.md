# doc_parse/yaml

Purpose:

* parser/AST/inspect foundation for the current YAML subset used by the
  project
* reusable lower-layer package inside `ZSeanYves/markitdown`
* not a YAML-to-Markdown policy layer

Current status:

* YAML-subset parser foundation candidate
* stable as an in-tree subset parser/AST/error/inspect surface
* not a standalone MoonBit module split yet

Stable candidate API:

* `parse_yaml_document`
* `inspect_yaml_document`
* `classify_yaml_error`
* `yaml_value_kind`

Current public API:

* `parse_yaml_document`
* `profile_yaml_document`
* `inspect_yaml_document`
* `classify_yaml_error`
* `yaml_value_kind`

Benchmark-oriented helper surface:

* `profile_yaml_document` exists for internal hotspot attribution and
  benchmark tooling
* it is not part of the main stable candidate API contract
* it does not change the YAML subset model or `convert/yaml` behavior

Minimal examples:

```moonbit
let doc = @yaml.parse_yaml_document("name: alice\nitems:\n  - one\n  - two\n")
let report = @yaml.inspect_yaml_document(doc)

println("root=" + report.root_kind.unwrap_or("none"))
println("depth=" + report.max_depth.to_string())
```

```moonbit
let _ = @yaml.parse_yaml_document("---\na: 1\n---\nb: 2\n") catch {
  err => {
    let info = @yaml.classify_yaml_error(err)
    println(info.kind.to_string())
    println(info.detail)
    @yaml.parse_yaml_document("fallback: true\n")
  }
}
```

Build on top:

* subset-safe YAML validators and custom AST lowering code can sit on this
  package without inheriting `convert/yaml` table/list policy

Debug / inspect API:

* `inspect_yaml_document`

Current model:

* `YamlDocument`
* `YamlValue`
* `YamlMember`

Compatibility surface:

* `YamlDocument`
* `YamlValue`
* `YamlMember`
* `YamlErrorInfo`
* exact subset behavior is part of the documented compatibility boundary

Internal exposed surface:

* indentation walkers, scalar parsing helpers, and comment stripping remain
  internal implementation details

Current inspect surface:

* `is_empty`
* `node_count`
* `mapping_count`
* `sequence_count`
* `scalar_count`
* `max_depth`
* `root_kind`

Current error surface:

* `YamlError`
* `YamlErrorInfo`
* classifier kinds for indentation/trailing-content issues and currently
  unsupported subset boundaries such as block scalars, multi-document markers,
  tabs, anchors, aliases, tags, and full flow-style semantics beyond the
  conservative single-line subset

Current subset boundary:

* nested mappings/sequences/scalars
* quoted and plain scalars
* conservative single-line flow sequences and mappings (`[...]` / `{...}`)
  without full YAML flow semantics
* conservative comments stripping
* optional single-document start/end markers (`---` / `...`)
* unsupported YAML features fail closed instead of being silently ignored

Marker compatibility note:

* a single-document YAML file may start with `---`
* a single-document YAML file may end with `...`
* real multi-document streams remain unsupported

Non-goals:

* full YAML spec support
* YAML-to-table/list/code-block policy
* IR or Markdown rendering

Relationship to `convert/yaml`:

* `doc_parse/yaml` owns parsing / AST / inspect
* `convert/yaml` owns conservative lowering into tables, list items, code
  blocks, and paragraphs

Known limits:

* current package intentionally supports a subset only
* file I/O and converter-side UTF-8 compatibility policy remain in
  `convert/yaml`
* block scalars, anchors, aliases, tags, real multi-document streams, and other
  unsupported YAML features still fail closed as parse errors rather than a
  richer validation-report family

Performance note:

* this subset parser targets predictable tree-building rather than streaming or
  permissive YAML import breadth
* benchmark numbers should separate lower-layer parse cost from later
  converter-side shaping

Testing:

* lower-layer tests live in `doc_parse/yaml/tests`
* converter behavior is regression-guarded separately under `convert/yaml/test`

Versioning note:

* future release-policy work may add a richer validation surface, but the
  current candidate scope intentionally centers on the YAML subset parser
