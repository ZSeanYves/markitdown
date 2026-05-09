# pdfreadfs

Filesystem/channel convenience wrappers for `@pdfread`.

`@pdfread` reads from `@pdfio.Input` so it can be used in non-filesystem
contexts (in-memory buffers, custom IO backends, etc.). This package provides
native-only helpers for `@fs.File` and filenames.

