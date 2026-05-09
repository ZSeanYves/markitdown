#include <stdint.h>
#include <time.h>

int64_t markitdown_doc_parse_bench_now_us(void) {
#if defined(CLOCK_MONOTONIC)
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0) {
    return (int64_t)ts.tv_sec * 1000000LL + (int64_t)(ts.tv_nsec / 1000LL);
  }
#endif
  return 0;
}
