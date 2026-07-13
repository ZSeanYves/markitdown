#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "moonbit.h"

typedef struct {
  FILE *file;
  int64_t size;
} markitdown_source_file_t;

static void markitdown_source_file_finalize(void *object) {
  markitdown_source_file_t *source = (markitdown_source_file_t *)object;
  if (source->file != NULL) {
    fclose(source->file);
    source->file = NULL;
  }
}

MOONBIT_FFI_EXPORT
markitdown_source_file_t *markitdown_source_file_open(const char *path) {
  if (path == NULL || path[0] == '\0') {
    return NULL;
  }
  struct stat info;
  if (stat(path, &info) != 0 || !S_ISREG(info.st_mode) || info.st_size < 0) {
    return NULL;
  }
  FILE *file = fopen(path, "rb");
  if (file == NULL) {
    return NULL;
  }
  markitdown_source_file_t *source =
      (markitdown_source_file_t *)moonbit_make_external_object(
          markitdown_source_file_finalize, sizeof(markitdown_source_file_t));
  source->file = file;
  source->size = (int64_t)info.st_size;
  return source;
}

MOONBIT_FFI_EXPORT
int32_t markitdown_source_file_is_null(markitdown_source_file_t *source) {
  return source == NULL;
}

MOONBIT_FFI_EXPORT
int64_t markitdown_source_file_size(markitdown_source_file_t *source) {
  return source == NULL ? -1 : source->size;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t markitdown_source_file_read_at(markitdown_source_file_t *source,
                                               int64_t offset,
                                               int32_t length) {
  if (source == NULL || source->file == NULL || offset < 0 || length <= 0 ||
      offset >= source->size) {
    return moonbit_make_bytes_raw(0);
  }
  int64_t remaining = source->size - offset;
  int32_t requested = remaining < length ? (int32_t)remaining : length;
  if (fseeko(source->file, (off_t)offset, SEEK_SET) != 0) {
    return moonbit_make_bytes_raw(0);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes_raw(requested);
  size_t actual = fread(bytes, 1, (size_t)requested, source->file);
  if (actual == (size_t)requested) {
    return bytes;
  }
  moonbit_bytes_t short_bytes = moonbit_make_bytes_raw((int32_t)actual);
  if (actual > 0) {
    memcpy(short_bytes, bytes, actual);
  }
  moonbit_decref(bytes);
  return short_bytes;
}
