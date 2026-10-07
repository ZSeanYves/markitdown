#include <stdio.h>
#include <stdint.h>
#include <unistd.h>

#ifndef MOONBIT_FFI_EXPORT
#define MOONBIT_FFI_EXPORT __attribute__((visibility("default")))
#endif

MOONBIT_FFI_EXPORT void markitdown_bench_write_stderr(
    const uint8_t *payload,
    int32_t payload_len) {
  if (payload == NULL || payload_len <= 0) {
    return;
  }
  (void)fwrite(payload, 1, (size_t)payload_len, stderr);
  (void)fflush(stderr);
}

MOONBIT_FFI_EXPORT int32_t markitdown_bench_stderr_isatty(void) {
  return isatty(STDERR_FILENO) ? 1 : 0;
}
