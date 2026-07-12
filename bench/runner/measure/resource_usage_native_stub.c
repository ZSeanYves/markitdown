#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "moonbit.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#if defined(__APPLE__)
#include <AvailabilityVersions.h>
#endif
#include <spawn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern char **environ;

static int64_t bench_now_us(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0;
  }
  return ((int64_t)ts.tv_sec * 1000000LL) + (ts.tv_nsec / 1000LL);
}

static int64_t normalize_rss_kb(long ru_maxrss) {
#if defined(__APPLE__)
  if (ru_maxrss <= 0) {
    return 0;
  }
  return (int64_t)(ru_maxrss / 1024L);
#else
  return (int64_t)ru_maxrss;
#endif
}

#if defined(__linux__)
static const char *path_basename(const char *path) {
  const char *slash = path != NULL ? strrchr(path, '/') : NULL;
  return slash != NULL ? slash + 1 : path;
}

static bool linux_process_executable_matches(pid_t pid, const char *program) {
  if (program == NULL || program[0] == '\0') {
    return false;
  }
  char path[64];
  int written = snprintf(path, sizeof(path), "/proc/%ld/exe", (long)pid);
  if (written <= 0 || (size_t)written >= sizeof(path)) {
    return false;
  }
  char executable[4096];
  ssize_t length = readlink(path, executable, sizeof(executable) - 1U);
  if (length <= 0) {
    return false;
  }
  executable[length] = '\0';
  const char *actual_name = path_basename(executable);
  const char *expected_name = path_basename(program);
  return actual_name != NULL && expected_name != NULL &&
    strcmp(actual_name, expected_name) == 0;
}

static int64_t linux_process_peak_rss_kb(pid_t pid) {
  char path[64];
  int written = snprintf(path, sizeof(path), "/proc/%ld/status", (long)pid);
  if (written <= 0 || (size_t)written >= sizeof(path)) {
    return 0;
  }
  FILE *status = fopen(path, "r");
  if (status == NULL) {
    return 0;
  }
  char line[256];
  int64_t peak_kb = 0;
  while (fgets(line, sizeof(line), status) != NULL) {
    long value = 0;
    if (sscanf(line, "VmHWM: %ld kB", &value) == 1 && value > 0) {
      peak_kb = (int64_t)value;
      break;
    }
  }
  fclose(status);
  return peak_kb;
}
#endif

static char *copy_c_string(const uint8_t *src, int32_t len) {
  char *out = (char *)malloc((size_t)len + 1U);
  if (out == NULL) {
    return NULL;
  }
  if (len > 0) {
    memcpy(out, src, (size_t)len);
  }
  out[len] = '\0';
  return out;
}

static int32_t c_string_len(const uint8_t *src) {
  if (src == NULL) {
    return 0;
  }
  return (int32_t)strlen((const char *)src);
}

static char **decode_blob_to_argv(const uint8_t *blob, int32_t blob_len, int32_t count) {
  char **argv = (char **)calloc((size_t)count + 1U, sizeof(char *));
  if (argv == NULL) {
    return NULL;
  }
  int32_t index = 0;
  int32_t item = 0;
  while (index < blob_len && item < count) {
    int32_t start = index;
    while (index < blob_len && blob[index] != 0) {
      index += 1;
    }
    argv[item] = copy_c_string(blob + start, index - start);
    if (argv[item] == NULL) {
      for (int32_t i = 0; i < item; i += 1) {
        free(argv[i]);
      }
      free(argv);
      return NULL;
    }
    item += 1;
    index += 1;
  }
  argv[count] = NULL;
  return argv;
}

static void free_argv(char **argv, int32_t count) {
  if (argv == NULL) {
    return;
  }
  for (int32_t i = 0; i < count; i += 1) {
    free(argv[i]);
  }
  free(argv);
}

static int validate_cwd(const char *cwd) {
  if (cwd == NULL || cwd[0] == '\0') {
    return 0;
  }
  struct stat st;
  if (stat(cwd, &st) != 0) {
    return errno != 0 ? errno : ENOENT;
  }
  if (!S_ISDIR(st.st_mode)) {
    return ENOTDIR;
  }
  if (access(cwd, X_OK) != 0) {
    return errno != 0 ? errno : EACCES;
  }
  return 0;
}

static int classify_spawn_exit_code(int spawn_error) {
  if (spawn_error == ENOENT) {
    return 127;
  }
  return 126;
}

static int add_spawn_chdir_action(
  posix_spawn_file_actions_t *file_actions,
  const char *cwd_c_path
) {
  if (cwd_c_path == NULL || cwd_c_path[0] == '\0') {
    return 0;
  }
#if defined(__APPLE__)
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && defined(__MAC_15_0) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
  return posix_spawn_file_actions_addchdir(file_actions, cwd_c_path);
#else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  int rc = posix_spawn_file_actions_addchdir_np(file_actions, cwd_c_path);
#pragma clang diagnostic pop
  return rc;
#endif
#elif defined(__GLIBC__)
  return posix_spawn_file_actions_addchdir_np(file_actions, cwd_c_path);
#else
  return ENOSYS;
#endif
}

static bool argv_has_path_separator(char **argv) {
  if (argv == NULL || argv[0] == NULL) {
    return false;
  }
  return strchr(argv[0], '/') != NULL;
}

MOONBIT_FFI_EXPORT int32_t markitdown_bench_native_measure_command(
  const uint8_t *argv_blob,
  int32_t argv_blob_len,
  int32_t argv_count,
  const uint8_t *env_blob,
  int32_t env_blob_len,
  int32_t env_count,
  const uint8_t *stdout_path,
  const uint8_t *stderr_path,
  const uint8_t *cwd,
  int64_t timeout_ms,
  int32_t *out_exit_code,
  int32_t *out_timed_out,
  int32_t *out_measurement_error,
  int32_t *out_spawn_error,
  int32_t *out_wait_error,
  int32_t *out_signal,
  int64_t *out_wall_us,
  int64_t *out_user_time_us,
  int64_t *out_sys_time_us,
  int64_t *out_peak_rss_kb
) {
  if (argv_blob == NULL || argv_count <= 0) {
    return -1;
  }

  if (out_exit_code != NULL) *out_exit_code = 1;
  if (out_timed_out != NULL) *out_timed_out = 0;
  if (out_measurement_error != NULL) *out_measurement_error = 0;
  if (out_spawn_error != NULL) *out_spawn_error = 0;
  if (out_wait_error != NULL) *out_wait_error = 0;
  if (out_signal != NULL) *out_signal = 0;
  if (out_wall_us != NULL) *out_wall_us = 0;
  if (out_user_time_us != NULL) *out_user_time_us = 0;
  if (out_sys_time_us != NULL) *out_sys_time_us = 0;
  if (out_peak_rss_kb != NULL) *out_peak_rss_kb = 0;

  char **argv = decode_blob_to_argv(argv_blob, argv_blob_len, argv_count);
  if (argv == NULL) {
    if (out_measurement_error != NULL) *out_measurement_error = 1;
    return -2;
  }

  char **envp = NULL;
  if (env_blob != NULL && env_count > 0) {
    envp = decode_blob_to_argv(env_blob, env_blob_len, env_count);
    if (envp == NULL) {
      free_argv(argv, argv_count);
      if (out_measurement_error != NULL) *out_measurement_error = 1;
      return -3;
    }
  }

  char *stdout_c_path = copy_c_string(stdout_path, c_string_len(stdout_path));
  if (stdout_c_path == NULL) {
    free_argv(argv, argv_count);
    free_argv(envp, env_count);
    if (out_measurement_error != NULL) *out_measurement_error = 1;
    return -4;
  }

  char *stderr_c_path = copy_c_string(stderr_path, c_string_len(stderr_path));
  if (stderr_c_path == NULL) {
    free(stdout_c_path);
    free_argv(argv, argv_count);
    free_argv(envp, env_count);
    if (out_measurement_error != NULL) *out_measurement_error = 1;
    return -5;
  }

  char *cwd_c_path = NULL;
  if (cwd != NULL && cwd[0] != 0) {
    cwd_c_path = copy_c_string(cwd, c_string_len(cwd));
    if (cwd_c_path == NULL) {
      free(stdout_c_path);
      free(stderr_c_path);
      free_argv(argv, argv_count);
      free_argv(envp, env_count);
      if (out_measurement_error != NULL) *out_measurement_error = 1;
      return -6;
    }
    int cwd_error = validate_cwd(cwd_c_path);
    if (cwd_error != 0) {
      if (out_exit_code != NULL) *out_exit_code = 125;
      if (out_spawn_error != NULL) *out_spawn_error = -cwd_error;
      free(cwd_c_path);
      free(stdout_c_path);
      free(stderr_c_path);
      free_argv(argv, argv_count);
      free_argv(envp, env_count);
      return 0;
    }
  }

  posix_spawn_file_actions_t file_actions;
  int file_actions_rc = posix_spawn_file_actions_init(&file_actions);
  if (file_actions_rc != 0) {
    free(cwd_c_path);
    free(stdout_c_path);
    free(stderr_c_path);
    free_argv(argv, argv_count);
    free_argv(envp, env_count);
    if (out_measurement_error != NULL) *out_measurement_error = 1;
    if (out_spawn_error != NULL) *out_spawn_error = file_actions_rc;
    return -7;
  }

  int addopen_rc = posix_spawn_file_actions_addopen(
    &file_actions,
    STDOUT_FILENO,
    stdout_c_path,
    O_CREAT | O_TRUNC | O_WRONLY,
    0644
  );
  if (addopen_rc != 0) {
    posix_spawn_file_actions_destroy(&file_actions);
    free(cwd_c_path);
    free(stdout_c_path);
    free(stderr_c_path);
    free_argv(argv, argv_count);
    free_argv(envp, env_count);
    if (out_measurement_error != NULL) *out_measurement_error = 1;
    if (out_spawn_error != NULL) *out_spawn_error = addopen_rc;
    return -8;
  }

  addopen_rc = posix_spawn_file_actions_addopen(
    &file_actions,
    STDERR_FILENO,
    stderr_c_path,
    O_CREAT | O_TRUNC | O_WRONLY,
    0644
  );
  if (addopen_rc != 0) {
    posix_spawn_file_actions_destroy(&file_actions);
    free(cwd_c_path);
    free(stdout_c_path);
    free(stderr_c_path);
    free_argv(argv, argv_count);
    free_argv(envp, env_count);
    if (out_measurement_error != NULL) *out_measurement_error = 1;
    if (out_spawn_error != NULL) *out_spawn_error = addopen_rc;
    return -9;
  }

  {
    int chdir_rc = add_spawn_chdir_action(&file_actions, cwd_c_path);
    if (chdir_rc != 0) {
      posix_spawn_file_actions_destroy(&file_actions);
      free(cwd_c_path);
      free(stdout_c_path);
      free(stderr_c_path);
      free_argv(argv, argv_count);
      free_argv(envp, env_count);
      if (out_measurement_error != NULL) *out_measurement_error = 1;
      if (out_spawn_error != NULL) *out_spawn_error = chdir_rc;
      return -10;
    }
  }

  int64_t started_us = bench_now_us();
  pid_t pid = 0;
  char **effective_env = envp != NULL ? envp : environ;
  int spawn_rc = 0;
  if (argv_has_path_separator(argv)) {
    spawn_rc = posix_spawn(
      &pid,
      argv[0],
      &file_actions,
      NULL,
      argv,
      effective_env
    );
  } else {
    spawn_rc = posix_spawnp(
      &pid,
      argv[0],
      &file_actions,
      NULL,
      argv,
      effective_env
    );
  }
  posix_spawn_file_actions_destroy(&file_actions);
  free(cwd_c_path);
  free(stdout_c_path);
  free(stderr_c_path);
  if (spawn_rc != 0) {
    if (out_exit_code != NULL) *out_exit_code = classify_spawn_exit_code(spawn_rc);
    if (out_spawn_error != NULL) *out_spawn_error = spawn_rc;
    if (out_wall_us != NULL) *out_wall_us = bench_now_us() - started_us;
    free_argv(argv, argv_count);
    free_argv(envp, env_count);
    return 0;
  }

  int status = 0;
  int wait_rc = 0;
  struct rusage usage;
  memset(&usage, 0, sizeof(usage));
  bool did_timeout = false;
#if defined(__linux__)
  int64_t sampled_peak_rss_kb = 0;
  bool linux_executable_observed = false;
#endif

  while (true) {
#if defined(__linux__)
    if (linux_process_executable_matches(pid, argv[0])) {
      if (!linux_executable_observed) {
        linux_executable_observed = true;
        usleep(1000);
      }
      int64_t current_peak_rss_kb = linux_process_peak_rss_kb(pid);
      if (current_peak_rss_kb > sampled_peak_rss_kb) {
        sampled_peak_rss_kb = current_peak_rss_kb;
      }
    }
#endif
    wait_rc = wait4(pid, &status, WNOHANG, &usage);
    if (wait_rc == pid) {
      break;
    }
    if (wait_rc < 0) {
      if (errno == EINTR) {
        continue;
      }
      if (out_measurement_error != NULL) *out_measurement_error = 1;
      if (out_wait_error != NULL) *out_wait_error = errno;
      break;
    }
    if (timeout_ms > 0 && (bench_now_us() - started_us) / 1000LL >= timeout_ms) {
      did_timeout = true;
      kill(pid, SIGKILL);
      while ((wait_rc = wait4(pid, &status, 0, &usage)) < 0 && errno == EINTR) {
      }
      break;
    }
    usleep(1000);
  }

  int64_t ended_us = bench_now_us();
  if (out_wall_us != NULL) *out_wall_us = ended_us - started_us;
  if (out_timed_out != NULL) *out_timed_out = did_timeout ? 1 : 0;
  if (out_user_time_us != NULL) {
    *out_user_time_us =
      ((int64_t)usage.ru_utime.tv_sec * 1000000LL) + usage.ru_utime.tv_usec;
  }
  if (out_sys_time_us != NULL) {
    *out_sys_time_us =
      ((int64_t)usage.ru_stime.tv_sec * 1000000LL) + usage.ru_stime.tv_usec;
  }
  if (out_peak_rss_kb != NULL) {
#if defined(__linux__)
    *out_peak_rss_kb = sampled_peak_rss_kb;
#else
    *out_peak_rss_kb = normalize_rss_kb(usage.ru_maxrss);
#endif
  }

  if (wait_rc < 0 && !did_timeout) {
    if (out_measurement_error != NULL) *out_measurement_error = 1;
    if (out_wait_error != NULL) *out_wait_error = errno;
    if (out_exit_code != NULL) *out_exit_code = 1;
  } else if (WIFEXITED(status)) {
    if (out_exit_code != NULL) *out_exit_code = WEXITSTATUS(status);
  } else if (WIFSIGNALED(status)) {
    if (out_exit_code != NULL) *out_exit_code = 128 + WTERMSIG(status);
    if (out_signal != NULL) *out_signal = WTERMSIG(status);
  } else {
    if (out_exit_code != NULL) *out_exit_code = 1;
  }

  free_argv(argv, argv_count);
  free_argv(envp, env_count);
  return 0;
}
