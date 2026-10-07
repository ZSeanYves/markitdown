# Retired multimodal enhancement architecture

This document records the pre-0.8 OCR, scanned-PDF and audio architecture. It
is retained as a migration record only; it is not a supported product contract.

The 0.8 product removes direct image OCR, scanned-page OCR, audio transcription,
model management and their external installers. Image and audio inputs are
still detected so the API can return `UnsupportedCapability`. Document images
remain assets, PDF geometry remains available for text-layer pages, subtitle
text and timing remain supported, and Office/ODF `accurate` semantics remain.

Use the current [capability matrix](../capabilities-and-limitations.md),
[Native/Wasm upgrade](../native-wasm-upgrade.md), and [FFI inventory](../ffi-inventory.md)
for the supported architecture. Any future multimodal work must be proposed as
an explicitly versioned extension and must not silently re-enter the 0.8 core.
