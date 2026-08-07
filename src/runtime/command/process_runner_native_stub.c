#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "moonbit.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern char **environ;

typedef struct {
  int32_t exit_code;
  int32_t signal;
  int32_t spawn_error;
  int32_t wait_error;
  int32_t timed_out;
  int32_t stdout_limited;
  int32_t stderr_limited;
  uint8_t *stdout_data;
  int32_t stdout_len;
  uint8_t *stderr_data;
  int32_t stderr_len;
} markitdown_command_result_t;

static void command_result_finalize(void *object) {
  markitdown_command_result_t *result = (markitdown_command_result_t *)object;
  free(result->stdout_data);
  free(result->stderr_data);
  result->stdout_data = NULL;
  result->stderr_data = NULL;
}

static int64_t command_now_ms(void) {
  struct timespec value;
  if (clock_gettime(CLOCK_MONOTONIC, &value) != 0) {
    return 0;
  }
  return (int64_t)value.tv_sec * 1000LL + value.tv_nsec / 1000000LL;
}

static char **decode_argv(const uint8_t *blob, int32_t length, int32_t count) {
  char **argv = (char **)calloc((size_t)count + 1U, sizeof(char *));
  if (argv == NULL) {
    return NULL;
  }
  int32_t offset = 0;
  for (int32_t item = 0; item < count; item += 1) {
    int32_t start = offset;
    while (offset < length && blob[offset] != 0) {
      offset += 1;
    }
    if (offset >= length) {
      for (int32_t i = 0; i < item; i += 1) free(argv[i]);
      free(argv);
      return NULL;
    }
    int32_t item_len = offset - start;
    argv[item] = (char *)malloc((size_t)item_len + 1U);
    if (argv[item] == NULL) {
      for (int32_t i = 0; i < item; i += 1) free(argv[i]);
      free(argv);
      return NULL;
    }
    memcpy(argv[item], blob + start, (size_t)item_len);
    argv[item][item_len] = '\0';
    offset += 1;
  }
  return argv;
}

static void free_argv(char **argv) {
  if (argv == NULL) return;
  for (int32_t index = 0; argv[index] != NULL; index += 1) free(argv[index]);
  free(argv);
}

static void append_pipe_bytes(int fd, uint8_t **data, int32_t *length,
                              int32_t limit, int32_t *limited, int *open) {
  uint8_t scratch[16384];
  while (*open) {
    ssize_t amount = read(fd, scratch, sizeof(scratch));
    if (amount > 0) {
      int32_t available = limit - *length;
      int32_t copy_len = amount < available ? (int32_t)amount : available;
      if (copy_len > 0) {
        uint8_t *next = (uint8_t *)realloc(*data, (size_t)(*length + copy_len));
        if (next == NULL) {
          *limited = 1;
          close(fd);
          *open = 0;
          return;
        }
        *data = next;
        memcpy(*data + *length, scratch, (size_t)copy_len);
        *length += copy_len;
      }
      if (copy_len < amount) {
        *limited = 1;
        close(fd);
        *open = 0;
        return;
      }
      continue;
    }
    if (amount == 0) {
      close(fd);
      *open = 0;
    } else if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) {
      close(fd);
      *open = 0;
    }
    return;
  }
}

static void terminate_process_group(pid_t pid, int32_t grace_ms) {
  kill(-pid, SIGTERM);
  int64_t deadline = command_now_ms() + grace_ms;
  int status = 0;
  while (command_now_ms() < deadline) {
    pid_t waited = waitpid(pid, &status, WNOHANG);
    if (waited == pid || (waited < 0 && errno == ECHILD)) return;
    struct timespec pause = {0, 10000000L};
    nanosleep(&pause, NULL);
  }
  kill(-pid, SIGKILL);
}

MOONBIT_FFI_EXPORT
markitdown_command_result_t *markitdown_command_run(
    const uint8_t *argv_blob, int32_t argv_blob_len, int32_t argv_count,
    int32_t timeout_ms, int32_t max_stdout_bytes, int32_t max_stderr_bytes,
    int32_t termination_grace_ms) {
  markitdown_command_result_t *result =
      (markitdown_command_result_t *)moonbit_make_external_object(
          command_result_finalize, sizeof(markitdown_command_result_t));
  memset(result, 0, sizeof(*result));
  result->exit_code = -1;
  char **argv = decode_argv(argv_blob, argv_blob_len, argv_count);
  if (argv == NULL || argv_count <= 0) {
    result->spawn_error = EINVAL;
    free_argv(argv);
    return result;
  }
  int stdout_pipe[2];
  int stderr_pipe[2];
  if (pipe(stdout_pipe) != 0) {
    result->spawn_error = errno;
    free_argv(argv);
    return result;
  }
  if (pipe(stderr_pipe) != 0) {
    result->spawn_error = errno;
    close(stdout_pipe[0]);
    close(stdout_pipe[1]);
    free_argv(argv);
    return result;
  }
  fcntl(stdout_pipe[0], F_SETFL, O_NONBLOCK);
  fcntl(stderr_pipe[0], F_SETFL, O_NONBLOCK);
  posix_spawn_file_actions_t actions;
  posix_spawn_file_actions_init(&actions);
  posix_spawn_file_actions_adddup2(&actions, stdout_pipe[1], STDOUT_FILENO);
  posix_spawn_file_actions_adddup2(&actions, stderr_pipe[1], STDERR_FILENO);
  posix_spawn_file_actions_addclose(&actions, stdout_pipe[0]);
  posix_spawn_file_actions_addclose(&actions, stderr_pipe[0]);
  posix_spawn_file_actions_addclose(&actions, stdout_pipe[1]);
  posix_spawn_file_actions_addclose(&actions, stderr_pipe[1]);
  posix_spawnattr_t attributes;
  posix_spawnattr_init(&attributes);
  posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETPGROUP);
  posix_spawnattr_setpgroup(&attributes, 0);
  pid_t pid = 0;
  int spawn_status = posix_spawnp(
      &pid, argv[0], &actions, &attributes, argv, environ);
  posix_spawnattr_destroy(&attributes);
  posix_spawn_file_actions_destroy(&actions);
  free_argv(argv);
  close(stdout_pipe[1]);
  close(stderr_pipe[1]);
  if (spawn_status != 0) {
    close(stdout_pipe[0]);
    close(stderr_pipe[0]);
    result->spawn_error = spawn_status;
    return result;
  }
  int stdout_open = 1;
  int stderr_open = 1;
  int child_status = 0;
  int child_reaped = 0;
  int terminated = 0;
  int64_t deadline = command_now_ms() + timeout_ms;
  while (!child_reaped || stdout_open || stderr_open) {
    append_pipe_bytes(stdout_pipe[0], &result->stdout_data,
                      &result->stdout_len, max_stdout_bytes,
                      &result->stdout_limited, &stdout_open);
    append_pipe_bytes(stderr_pipe[0], &result->stderr_data,
                      &result->stderr_len, max_stderr_bytes,
                      &result->stderr_limited, &stderr_open);
    if (!child_reaped) {
      pid_t waited = waitpid(pid, &child_status, WNOHANG);
      if (waited == pid) {
        child_reaped = 1;
      } else if (waited < 0 && errno != EINTR) {
        result->wait_error = errno;
        child_reaped = 1;
      }
    }
    if (!terminated && !child_reaped &&
        (result->stdout_limited || result->stderr_limited ||
         command_now_ms() >= deadline)) {
      result->timed_out = command_now_ms() >= deadline;
      terminate_process_group(pid, termination_grace_ms);
      terminated = 1;
    }
    if (terminated && !child_reaped) {
      pid_t waited = waitpid(pid, &child_status, 0);
      if (waited == pid) child_reaped = 1;
      else if (waited < 0 && errno != ECHILD) result->wait_error = errno;
      else child_reaped = 1;
    }
    if (!child_reaped || stdout_open || stderr_open) {
      struct pollfd descriptors[2] = {
          {stdout_open ? stdout_pipe[0] : -1, POLLIN | POLLHUP, 0},
          {stderr_open ? stderr_pipe[0] : -1, POLLIN | POLLHUP, 0},
      };
      poll(descriptors, 2, 10);
    }
  }
  if (WIFEXITED(child_status)) result->exit_code = WEXITSTATUS(child_status);
  if (WIFSIGNALED(child_status)) result->signal = WTERMSIG(child_status);
  return result;
}

MOONBIT_FFI_EXPORT int32_t markitdown_command_result_is_null(void *result) {
  return result == NULL;
}
MOONBIT_FFI_EXPORT int32_t markitdown_command_result_spawn_error(markitdown_command_result_t *result) { return result->spawn_error; }
MOONBIT_FFI_EXPORT int32_t markitdown_command_result_wait_error(markitdown_command_result_t *result) { return result->wait_error; }
MOONBIT_FFI_EXPORT int32_t markitdown_command_result_exit_code(markitdown_command_result_t *result) { return result->exit_code; }
MOONBIT_FFI_EXPORT int32_t markitdown_command_result_signal(markitdown_command_result_t *result) { return result->signal; }
MOONBIT_FFI_EXPORT int32_t markitdown_command_result_timed_out(markitdown_command_result_t *result) { return result->timed_out; }
MOONBIT_FFI_EXPORT int32_t markitdown_command_result_stdout_limited(markitdown_command_result_t *result) { return result->stdout_limited; }
MOONBIT_FFI_EXPORT int32_t markitdown_command_result_stderr_limited(markitdown_command_result_t *result) { return result->stderr_limited; }

static moonbit_bytes_t command_result_bytes(const uint8_t *data, int32_t length) {
  moonbit_bytes_t bytes = moonbit_make_bytes_raw(length);
  if (length > 0) memcpy(bytes, data, (size_t)length);
  return bytes;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t markitdown_command_result_stdout(markitdown_command_result_t *result) {
  return command_result_bytes(result->stdout_data, result->stdout_len);
}
MOONBIT_FFI_EXPORT moonbit_bytes_t markitdown_command_result_stderr(markitdown_command_result_t *result) {
  return command_result_bytes(result->stderr_data, result->stderr_len);
}
