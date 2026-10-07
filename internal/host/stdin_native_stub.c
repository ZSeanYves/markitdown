#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "moonbit.h"

MOONBIT_FFI_EXPORT
moonbit_bytes_t markitdown_cli_read_stdin(int32_t max_bytes) {
  if (max_bytes <= 0) return moonbit_make_bytes_raw(0);
  int32_t capacity = max_bytes < 65536 ? max_bytes : 65536;
  unsigned char *buffer = (unsigned char *)malloc((size_t)capacity);
  if (buffer == NULL) return moonbit_make_bytes_raw(0);
  int32_t length = 0;
  while (length < max_bytes) {
    if (length == capacity) {
      int32_t next = capacity > max_bytes / 2 ? max_bytes : capacity * 2;
      unsigned char *grown = (unsigned char *)realloc(buffer, (size_t)next);
      if (grown == NULL) break;
      buffer = grown;
      capacity = next;
    }
    size_t read = fread(buffer + length, 1, (size_t)(capacity - length), stdin);
    length += (int32_t)read;
    if (read == 0) break;
  }
  moonbit_bytes_t output = moonbit_make_bytes_raw(length);
  if (length > 0) {
    memcpy(output, buffer, (size_t)length);
  }
  free(buffer);
  return output;
}
