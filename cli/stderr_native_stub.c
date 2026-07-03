#include "moonbit.h"

#include <stdint.h>
#include <stdio.h>

MOONBIT_FFI_EXPORT void markitdown_cli_write_stderr(
  const uint8_t *payload,
  int32_t payload_len
) {
  if (payload == NULL || payload_len <= 0) {
    return;
  }
  (void)fwrite(payload, 1, (size_t)payload_len, stderr);
  (void)fflush(stderr);
}
