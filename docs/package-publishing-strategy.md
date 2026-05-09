# doc_parse Package Publishing Strategy

This document records the current publishing strategy for the reusable
`doc_parse/*` foundations inside this repository.

## Current Module Strategy

Current delivery unit:

* the publishable module is still `ZSeanYves/markitdown`
* `doc_parse/*` is consumed through importable subpackages such as:
  * `ZSeanYves/markitdown/doc_parse/ooxml`
  * `ZSeanYves/markitdown/doc_parse/epub`
  * `ZSeanYves/markitdown/doc_parse/pdf/api`

Important distinction:

* `moon.pkg` / `moon.pkg.json` defines a package boundary inside a module
* it does not, by itself, make that package a separately published MoonBit
  module

Current recommendation:

* keep `doc_parse/ooxml`, `doc_parse/epub`, `doc_parse/pdf`, and `doc_parse/zip`
  as importable subpackages under the root module for now
* keep simple-format parser candidates such as `doc_parse/csv`,
  `doc_parse/tsv`, `doc_parse/json`, `doc_parse/yaml`, and `doc_parse/text`
  inside the same root module until their internal boundaries and future
  release-policy surfaces stabilize
* keep `doc_parse/xml` in active in-tree hardening until its parser/model
  boundary and future convert integration story stabilize
* keep hardening those packages in-tree with package-level README/API/test
  contracts before considering any independent release story
* keep `convert/*` and `doc_parse/*` co-evolving in one repository while the
  parsing foundations continue to stabilize

## Why Not Split Modules Yet

Independent module release would require more than package hardening.

It would also require:

* a dedicated `moon.mod.json` per released module
* a versioning and changelog policy per released module
* a release cadence independent from the converter layer
* a clear strategy for shared dependencies such as `doc_parse/zip`
* cross-package validation split out from the monorepo-level `moon test` and
  `./samples/check.sh` flow

Today the repository still benefits from keeping:

* `doc_parse/*`
* `convert/*`
* CLI/debug integration
* shared regression corpora

in one release and validation line.

## Future Split Candidates

Possible future modules could include:

* `doc_parse_zip`
* `doc_parse_ooxml`
* `doc_parse_epub`
* `doc_parse_pdf`
* `doc_parse_csv`
* `doc_parse_json`
* `doc_parse_yaml`
* `doc_parse_text`
* `doc_parse_xml`

That split should wait until all of the following are clearer:

* API stability has progressed beyond the current candidate surface
* compatibility surfaces have been narrowed further
* the `zip` dependency strategy is explicit
* release/version policy is explicit
* cross-package tests can be run and published independently

Current dependency note:

* `doc_parse/zip` is the lowest-level shared container candidate in the stack
* any future independent `doc_parse_ooxml` or `doc_parse_epub` module split
  would need an explicit dependency story on top of `doc_parse_zip`
* ZIP is therefore the package whose release-policy shape constrains the rest
  of the container/package parsing split the most

## Nested Module Warning

Do not place a `moon.mod.json` directly under `doc_parse/` inside this
repository during normal development.

Why:

* Moon will treat it as a nested module
* that changes import planning and workspace behavior
* it can interfere with the root-module build and validation story

If you want to experiment with an independently published parsing module:

* use a separate branch plus a quarantined local directory
* or use a separate repository/worktree
* or keep the experiment outside the current root module tree

## Short-Term Recommendation

Short term:

* continue shipping `doc_parse/ooxml`, `doc_parse/epub`, and `doc_parse/pdf`
  as importable subpackages under `ZSeanYves/markitdown`
* continue stabilizing the simple-format parser candidates in-tree before any
  standalone-module split is attempted
* prioritize API/documentation/test stability over module splitting
* revisit independent modules only after the current candidate surfaces and
  compatibility boundaries have narrowed further
