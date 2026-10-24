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
  int32_t error_stage;
  int32_t cleanup_close_error;
  int32_t cleanup_remove_error;
  int32_t name_owned;
  int32_t closed;
  int32_t committed;
  int64_t last_write_count;
} markitdown_atomic_writer_t;

/* Operation failure is independent of cleanup failure. Never replace the
 * original phase/errno while attempting cleanup or a disallowed transition. */
static int32_t markitdown_atomic_operation_error(
  markitdown_atomic_writer_t *writer, int32_t stage, int32_t code
) {
  if (writer->error_code == 0) {
    writer->error_code = code == 0 ? EIO : code;
    writer->error_stage = stage;
  }
  return writer->error_code;
}

static int32_t markitdown_atomic_status(markitdown_atomic_writer_t *writer) {
  if (writer == NULL) return EINVAL;
  if (writer->error_code != 0) return writer->error_code;
  if (writer->cleanup_close_error != 0) return writer->cleanup_close_error;
  return writer->cleanup_remove_error;
}

static void markitdown_atomic_abort_owned(markitdown_atomic_writer_t *writer) {
  writer->closed = 1;
  if (writer->file != NULL) {
    FILE *file = writer->file;
    writer->file = NULL; /* fclose consumes the stream even on failure. */
    if (fclose(file) != 0 && writer->cleanup_close_error == 0) {
      writer->cleanup_close_error = errno == 0 ? EIO : errno;
    }
  }
  if (writer->name_owned) {
    if (unlink(writer->temp_path) == 0 || errno == ENOENT) {
      /* Retired names can subsequently belong to somebody else. Neither a
       * repeated abort nor the finalizer may try to unlink them again. */
      writer->name_owned = 0;
    } else if (writer->cleanup_remove_error == 0) {
      writer->cleanup_remove_error = errno == 0 ? EIO : errno;
    }
  }
}

static void markitdown_atomic_writer_cleanup(void *pointer) {
  markitdown_atomic_writer_t *writer = (markitdown_atomic_writer_t *)pointer;
  markitdown_atomic_abort_owned(writer);
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
    markitdown_atomic_operation_error(writer, 1, EINVAL);
    return writer;
  }
  writer->target_path = (char *)malloc((size_t)path_length + 1U);
  if (writer->target_path == NULL) {
    markitdown_atomic_operation_error(writer, 1, ENOMEM);
    return writer;
  }
  memcpy(writer->target_path, path, (size_t)path_length);
  writer->target_path[path_length] = '\0';
  writer->temp_path = (char *)malloc((size_t)path_length + 16U);
  if (writer->temp_path == NULL) {
    markitdown_atomic_operation_error(writer, 1, ENOMEM);
    return writer;
  }
  writer->temp_path[0] = '\0';
  (void)snprintf(
    writer->temp_path,
    (size_t)path_length + 16U,
    "%s.tmp.XXXXXX",
    writer->target_path
  );
  int fd = mkstemp(writer->temp_path);
  if (fd < 0) {
    markitdown_atomic_operation_error(writer, 1, errno);
    return writer;
  }
  writer->name_owned = 1;
  writer->file = fdopen(fd, "wb");
  if (writer->file == NULL) {
    markitdown_atomic_operation_error(writer, 1, errno);
    if (close(fd) != 0) writer->cleanup_close_error = errno == 0 ? EIO : errno;
    markitdown_atomic_abort_owned(writer);
  }
  return writer;
}

MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_status(
  markitdown_atomic_writer_t *writer
) {
  return markitdown_atomic_status(writer);
}

MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_error_stage(markitdown_atomic_writer_t *writer) { return writer->error_stage; }
MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_operation_error(markitdown_atomic_writer_t *writer) { return writer->error_code; }
MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_close_error(markitdown_atomic_writer_t *writer) { return writer->cleanup_close_error; }
MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_remove_error(markitdown_atomic_writer_t *writer) { return writer->cleanup_remove_error; }
MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_cleanup_complete(markitdown_atomic_writer_t *writer) { return writer->file == NULL && !writer->name_owned; }
/* A consumed FILE token is not proof of successful close. In particular,
 * commit's stage5 and abort's close errno both forbid refunding uncertain
 * temporary-storage credit, even when the name was successfully removed. */
MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_reclamation_certain(markitdown_atomic_writer_t *writer) {
  return writer->file == NULL && !writer->name_owned &&
    writer->cleanup_close_error == 0 && writer->error_stage != 5;
}
MOONBIT_FFI_EXPORT int64_t markitdown_atomic_writer_last_write_count(markitdown_atomic_writer_t *writer) { return writer->last_write_count; }
MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_invalid_encoding(markitdown_atomic_writer_t *writer) {
  int32_t previous = markitdown_atomic_status(writer);
  return previous == 0 ? markitdown_atomic_operation_error(writer, 8, EILSEQ) : previous;
}

MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_write(
  markitdown_atomic_writer_t *writer,
  const uint8_t *payload,
  int32_t payload_length
) {
  if (writer == NULL) return EINVAL;
  if (markitdown_atomic_status(writer) != 0) return markitdown_atomic_status(writer);
  if (writer->file == NULL || writer->closed || writer->committed) {
    return markitdown_atomic_operation_error(writer, 7, EINVAL);
  }
  writer->last_write_count = 0;
  if (payload_length == 0) {
    return 0;
  }
  if (payload == NULL || payload_length < 0) {
    return markitdown_atomic_operation_error(writer, 2, EINVAL);
  }
  errno = 0;
  writer->last_write_count = (int64_t)fwrite(payload, 1, (size_t)payload_length, writer->file);
  if (writer->last_write_count != payload_length) {
    return markitdown_atomic_operation_error(writer, 2, errno);
  }
  return 0;
}

MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_commit(
  markitdown_atomic_writer_t *writer
) {
  if (writer == NULL) return EINVAL;
  if (markitdown_atomic_status(writer) != 0) return markitdown_atomic_status(writer);
  if (writer->file == NULL || writer->closed || writer->committed) {
    return markitdown_atomic_operation_error(writer, 7, EINVAL);
  }
  if (fflush(writer->file) != 0) return markitdown_atomic_operation_error(writer, 3, errno);
  if (fsync(fileno(writer->file)) != 0) return markitdown_atomic_operation_error(writer, 4, errno);
  FILE *file = writer->file;
  writer->file = NULL;
  writer->closed = 1;
  if (fclose(file) != 0) return markitdown_atomic_operation_error(writer, 5, errno);
  if (rename(writer->temp_path, writer->target_path) != 0) {
    return markitdown_atomic_operation_error(writer, 6, errno);
  }
  writer->name_owned = 0;
  writer->committed = 1;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t markitdown_atomic_writer_abort(
  markitdown_atomic_writer_t *writer
) {
  if (writer == NULL) return EINVAL;
  markitdown_atomic_abort_owned(writer);
  return markitdown_atomic_status(writer);
}
