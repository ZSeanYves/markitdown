# doc_parse/yaml

Purpose:

* parser/AST/inspect foundation for the current YAML subset used by the
  project
* reusable lower-layer package inside `ZSeanYves/markitdown`
* not a YAML-to-Markdown policy layer

Current status:

* internal foundation hardening
* not yet labeled as a standalone publishable package candidate

Public API:

* `parse_yaml_document`
* `inspect_yaml_document`
* `classify_yaml_error`
* `yaml_value_kind`

Current model:

* `YamlDocument`
* `YamlValue`
* `YamlMember`

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

Testing:

* lower-layer tests live in `doc_parse/yaml/tests`
* converter behavior is regression-guarded separately under `convert/yaml/test`
