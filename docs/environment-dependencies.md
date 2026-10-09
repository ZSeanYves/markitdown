# Runtime dependencies

The 0.8 product and its repository validation tools are MoonBit-only. OCR,
audio models, Python comparison environments, shell adapters, and external
converter installers were removed from the supported workflow.

Native and Wasm share detection, routing, readers, the document IR, rendering,
RAG, assets, and source tracking. Native-only code is restricted to the small
FFI boundary recorded in [the FFI inventory](ffi-inventory.md). Wasm remains a
strict subset of the Native capability declaration.

Build the checkout with the MoonBit toolchain, then run the published package
through the MoonX entrypoints in [`tools/regression`](../tools/regression/README.md).
No additional runtime or installer is required.
