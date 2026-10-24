#include <fcntl.h>
#include <stdint.h>
#include <sys/stat.h>
#include <unistd.h>

#include "moonbit.h"

/* Only the safe descriptor acquisition is native. Content reads are scheduled
 * by moonbitlang/async/fs, not performed synchronously in a callback. */
typedef struct { int fd; } markitdown_source_file_t;

static void markitdown_source_file_finalize(void *object) {
  markitdown_source_file_t *source = object;
  if (source->fd >= 0) {
    close(source->fd);
    source->fd = -1;
  }
}

MOONBIT_FFI_EXPORT
markitdown_source_file_t *markitdown_source_file_open(const char *path) {
  if (path == NULL || path[0] == '\0') return NULL;
  int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
  if (fd < 0) return NULL;
  struct stat info;
  if (fstat(fd, &info) != 0 || !S_ISREG(info.st_mode) || info.st_size < 0) {
    close(fd);
    return NULL;
  }
  markitdown_source_file_t *source = moonbit_make_external_object(
      markitdown_source_file_finalize, sizeof(markitdown_source_file_t));
  source->fd = fd;
  return source;
}

MOONBIT_FFI_EXPORT
int32_t markitdown_source_file_is_null(markitdown_source_file_t *source) {
  return source == NULL;
}

MOONBIT_FFI_EXPORT
int32_t markitdown_source_file_fd(markitdown_source_file_t *source) {
  return source == NULL ? -1 : source->fd;
}

MOONBIT_FFI_EXPORT
void markitdown_source_file_close(markitdown_source_file_t *source) {
  if (source != NULL) markitdown_source_file_finalize(source);
}
