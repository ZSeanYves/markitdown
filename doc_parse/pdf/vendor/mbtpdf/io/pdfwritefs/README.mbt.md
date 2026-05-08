# pdfwritefs

Filesystem/channel convenience wrappers for `@pdfwrite`.

`@pdfwrite` writes to `@pdfio.Output` so it can be used in non-filesystem
contexts (in-memory buffers, custom IO backends, etc.). This package provides
native-only helpers for `@fs.File` and filenames.

