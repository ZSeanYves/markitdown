#include <errno.h>
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "moonbit.h"

MOONBIT_FFI_EXPORT
moonbit_bytes_t markitdown_decode_cp932(moonbit_bytes_t input, int32_t input_length) {
  if (input == NULL) {
    return moonbit_make_bytes_raw(0);
  }
  if (input_length <= 0) {
    return moonbit_make_bytes_raw(0);
  }
  for (int32_t index = 0; index < input_length; index++) {
    unsigned char value = ((unsigned char *)input)[index];
    if (value <= 0x7f || (value >= 0xa1 && value <= 0xdf)) continue;
    if (!((value >= 0x81 && value <= 0x9f) ||
          (value >= 0xe0 && value <= 0xef)) || index + 1 >= input_length) {
      return moonbit_make_bytes_raw(0);
    }
    unsigned char trail = ((unsigned char *)input)[++index];
    if (!((trail >= 0x40 && trail <= 0x7e) ||
          (trail >= 0x80 && trail <= 0xfc))) {
      return moonbit_make_bytes_raw(0);
    }
  }
  void *library = dlopen("/usr/lib/libiconv.2.dylib", RTLD_LAZY);
  if (library == NULL) {
    library = dlopen("libiconv.so.2", RTLD_LAZY);
  }
  if (library == NULL) {
    library = dlopen("libc.so.6", RTLD_LAZY);
  }
  if (library == NULL) {
    return moonbit_make_bytes_raw(0);
  }
  typedef void *(*open_fn_t)(const char *, const char *);
  typedef size_t (*convert_fn_t)(void *, char **, size_t *, char **, size_t *);
  typedef int (*close_fn_t)(void *);
  open_fn_t open_fn = (open_fn_t)dlsym(library, "iconv_open");
  convert_fn_t convert_fn = (convert_fn_t)dlsym(library, "iconv");
  close_fn_t close_fn = (close_fn_t)dlsym(library, "iconv_close");
  if (open_fn == NULL || convert_fn == NULL || close_fn == NULL) {
    dlclose(library);
    return moonbit_make_bytes_raw(0);
  }
  void *converter = open_fn("UTF-8", "CP932");
  if (converter == (void *)-1) {
    dlclose(library);
    return moonbit_make_bytes_raw(0);
  }
  size_t capacity = (size_t)input_length * 4u + 4u;
  moonbit_bytes_t output = moonbit_make_bytes_raw((int32_t)capacity);
  char *input_cursor = (char *)input;
  char *output_cursor = (char *)output;
  size_t input_left = (size_t)input_length;
  size_t output_left = capacity;
  size_t result = convert_fn(converter, &input_cursor, &input_left,
                             &output_cursor, &output_left);
  close_fn(converter);
  dlclose(library);
  if (result == (size_t)-1 || input_left != 0) {
    moonbit_decref(output);
    return moonbit_make_bytes_raw(0);
  }
  size_t written = capacity - output_left;
  moonbit_bytes_t resized = moonbit_make_bytes_raw((int32_t)written);
  if (written > 0) {
    memcpy(resized, output, written);
  }
  moonbit_decref(output);
  return resized;
}
