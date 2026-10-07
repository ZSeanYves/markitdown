#include "moonbit.h"

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct {
  FILE *file;
  char *target_path;
  char *temp_path;
  int32_t error_code;
  int32_t committed;
} markitdown_atomic_writer_t;

static void markitdown_atomic_writer_cleanup(void *pointer) {
  markitdown_atomic_writer_t *writer = (markitdown_atomic_writer_t *)pointer;
  if (writer->file != NULL) {
    (void)fclose(writer->file);
    writer->file = NULL;
  }
  if (!writer->committed && writer->temp_path != NULL) {
    (void)unlink(writer->temp_path);
  }
  free(writer->target_path);
  free(writer->temp_path);
  writer->target_path = NULL;
  writer->temp_path = NULL;
}

MOONBIT_FFI_EXPORT markitdown_atomic_writer_t *markitdown_atomic_writer_open(
  const uint8_t *path,
  int32_t path_length
) {
  markitdown_atomic_writer_t *writer =
    (markitdown_atomic_writer_t *)moonbit_make_external_object(
      markitdown_atomic_writer_cleanup,
      sizeof(markitdown_atomic_writer_t)
    );
  memset(writer, 0, sizeof(*writer));
  if (path == NULL || path_length <= 0) {
    writer->error_code = EINVAL;
    return writer;
  }
  writer->target_path = (char *)malloc((size_t)path_length + 1U);
  writer->temp_path = (char *)malloc((size_t)path_length + 16U);
  if (writer->target_path == NULL || writer->temp_path == NULL) {
    writer->error_code = ENOMEM;
    return writer;
  }
  memcpy(writer->target_path, path, (size_t)path_length);
  writer->target_path[path_length] = '\0';
  (void)snprintf(
    writer->temp_path,
    (size_t)path_length + 16U,
    "%s.tmp.XXXXXX",
    writer->target_path
  );
  int fd = mkstemp(writer->temp_path);
  if (fd < 0) {
    writer->error_code = errno;
    return writer;
  }
  writer->file = fdopen(fd, "wb");
  if (writer->file == NULL) {
    writer->error_code = errno;
    (void)close(fd);
    (void)unlink(writer->temp_path);
  }
  return writer;
}

MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_status(
  markitdown_atomic_writer_t *writer
) {
  return writer == NULL ? EINVAL : writer->error_code;
}

MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_write(
  markitdown_atomic_writer_t *writer,
  const uint8_t *payload,
  int32_t payload_length
) {
  if (writer == NULL || writer->file == NULL || writer->committed) {
    return EINVAL;
  }
  if (payload_length <= 0) {
    return 0;
  }
  if (payload == NULL ||
      fwrite(payload, 1, (size_t)payload_length, writer->file) !=
        (size_t)payload_length) {
    writer->error_code = errno == 0 ? EIO : errno;
    return writer->error_code;
  }
  return 0;
}

MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_commit(
  markitdown_atomic_writer_t *writer
) {
  if (writer == NULL || writer->file == NULL || writer->committed) {
    return EINVAL;
  }
  if (fflush(writer->file) != 0 || fsync(fileno(writer->file)) != 0) {
    writer->error_code = errno == 0 ? EIO : errno;
    return writer->error_code;
  }
  if (fclose(writer->file) != 0) {
    writer->file = NULL;
    writer->error_code = errno == 0 ? EIO : errno;
    return writer->error_code;
  }
  writer->file = NULL;
  if (rename(writer->temp_path, writer->target_path) != 0) {
    writer->error_code = errno;
    return writer->error_code;
  }
  writer->committed = 1;
  return 0;
}

MOONBIT_FFI_EXPORT void markitdown_atomic_writer_abort(
  markitdown_atomic_writer_t *writer
) {
  if (writer == NULL || writer->committed) {
    return;
  }
  if (writer->file != NULL) {
    (void)fclose(writer->file);
    writer->file = NULL;
  }
  if (writer->temp_path != NULL) {
    (void)unlink(writer->temp_path);
  }
}
