# Acceptance Checklist (Proposal -> Repository Evidence)

> Status legend:
> - `[x]` Completed
> - `[~]` Basic capability implemented, still being finalized/polished
> - `[ ]` Future phase

## A. Project Goals Mapping

### A1. Unified IR + Multi-format Conversion

- [x] Supports multiple current format families through one unified IR main pipeline: OOXML (DOCX / PPTX / XLSX), PDF, HTML / HTM, structured data (CSV / TSV / JSON / YAML / YML / XML), textlike input (Markdown / MD / MARKDOWN / TXT), and containers / ebooks (ZIP / EPUB).  
  Evidence: `convert/convert/dispatcher.mbt`, `core/ir.mbt`, `README.mbt.md`

### A2. Structured Output (Markdown)

- [x] A stable Markdown primary output path has been established (conversion can be invoked from normal/ocr/debug).  
  Evidence: `cli/main.mbt`, `cli/cli_app.mbt`, `core/emitter_markdown.mbt`

### A3. Explainability and Engineering Consumption

- [x] `block_origins` / `asset_origins` and sidecar output capabilities are provided.  
  Evidence: `core/ir.mbt`, `core/metadata.mbt`, `samples/test/metadata/*`

### A4. Usability for Service Knowledge Base / RAG Direction

- [~] The foundational form of “structured Markdown + sidecar + assets” is already in place and can support future integration, but fine-grained grounding and complex semantics remain in later phases.  
  Evidence: `core/metadata.mbt`, `docs/metadata-sidecar.md`, `docs/support-and-limits.md`

## B. Deliverables Mapping

### B1. CLI Tool and Usage

- [x] The three subcommands `normal / ocr / debug` are available.  
  Evidence: `cli/main.mbt`
- [x] `--with-metadata` enables sidecar output.  
  Evidence: `cli/main.mbt`, `cli/cli_app.mbt`

### B2. Regression Sample System

- [x] Three complete regression chains have been established: `main_process / metadata / assets`.  
  Evidence: `samples/check.sh`, `samples/check_main_process.sh`, `samples/check_metadata.sh`, `samples/check_assets.sh`
- [x] A compact acceptance demo sample set is provided under `samples/test` (condensed demonstration, not equivalent to the full regression suite).  
  Evidence: `samples/test/*.md`, `samples/test/metadata/*.metadata.json`, `samples/test/assets/*`

### B3. Documentation Delivery

- [x] Support scope and limitations, architecture description, sidecar documentation, and the acceptance checklist have all been provided.  
  Evidence: `docs/support-and-limits.md`, `docs/architecture.md`, `docs/metadata-sidecar.md`, `docs/acceptance-checklist.md`

## C. Technical Route Mapping

### C1. Main Technical Route: Multi-format -> IR -> Markdown

- [x] The main route has been implemented and can be verified through regression.  
  Evidence: `convert/convert/dispatcher.mbt`, `core/ir.mbt`, `core/emitter_markdown.mbt`, `samples/check_main_process.sh`

### C2. Metadata Route: origin / image-context / caption / nearby-caption

- [x] The sidecar already covers basic fields and the asset-oriented perspective.  
  Evidence: `core/metadata.mbt`, `samples/metadata/*`, `samples/test/metadata/*`
- [~] Data completeness under weak semantics and complex layout scenarios is still being finalized.  
  Evidence: `docs/support-and-limits.md`

### C3. Resource Route: Closed Loop for Assets Export and Referencing

- [x] Assets export and Markdown reference validity checks are already in place.  
  Evidence: `samples/check_assets.sh`, `samples/assets/expected/*`

## D. Risks and Boundary Mapping

### D1. PDF

- [x] The normal mainline path already uses native structural recovery (non-OCR default path).  
  Evidence: `README.mbt.md`, `cli/main.mbt`
- [~] Complex multi-column layouts and heavy mixed-layout cases are still being improved.  
  Evidence: `docs/support-and-limits.md`

### D2. OCR

- [x] OCR is available as an independent subcommand path.  
  Evidence: `cli/main.mbt`
- [~] OCR quality is coupled with the external toolchain environment and requires separate environment-level acceptance.  
  Evidence: `README.mbt.md` (external dependencies), `docs/support-and-limits.md`

### D3. Advanced OOXML and Fine-grained Grounding

- [~] Basic structural recovery is already available, but advanced OOXML semantics are not yet fully covered.  
  Evidence: `docs/support-and-limits.md`
- [ ] Fine-grained grounding such as bbox / char-range / source-object-id belongs to a later phase.  
  Evidence: `docs/support-and-limits.md`, `docs/metadata-sidecar.md`

## E. Phase Boundaries

### E1. Current Phase (Recommended for the Acceptance Conclusion)

- [x] Unified IR main pipeline for multiple formats
- [x] Three validation chains are regression-testable
- [x] Engineering-ready sidecar output

### E2. Future Phase

- [ ] Semantic enhancement for complex PDF layouts
- [ ] Further refinement of OCR quality
- [ ] Systematic enhancement of advanced OOXML and fine-grained grounding

## F. Recommended Acceptance Execution Order

1. Run `samples/scripts/check_samples.sh` to verify consistency of the sample inventory.
2. Run `samples/check.sh` for the full release-style validation chain.
3. Run `samples/check_main_process.sh` for isolated main pipeline regression when needed.
4. Run `samples/check_metadata.sh` to independently verify metadata semantic stability.
5. Run `samples/check_assets.sh` to independently verify asset extraction/reference stability.
6. Spot-check `samples/test` as the compact acceptance demonstration sample set.
