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
  tabs, anchors, aliases, tags, and flow style

Current subset boundary:

* nested mappings/sequences/scalars
* quoted and plain scalars
* conservative comments stripping
* unsupported YAML features fail closed instead of being silently ignored

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
* unsupported YAML features still fail closed as parse errors rather than a
  richer validation-report family

Testing:

* lower-layer tests live in `doc_parse/yaml/tests`
* converter behavior is regression-guarded separately under `convert/yaml/test`

Versioning note:

* future release-policy work may add a richer validation surface, but the
  current candidate scope intentionally centers on the YAML subset parser
