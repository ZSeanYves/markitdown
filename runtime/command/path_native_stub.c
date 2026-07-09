#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static bool runtime_is_executable_file(const char *path) {
  if (path == NULL || path[0] == '\0') {
    return false;
  }
  struct stat st;
  if (stat(path, &st) != 0) {
    return false;
  }
  if (!S_ISREG(st.st_mode)) {
    return false;
  }
  return access(path, X_OK) == 0;
}

int markitdown_runtime_is_executable_file(const char *path) {
  return runtime_is_executable_file(path) ? 1 : 0;
}

static char *copy_segment(const char *start, size_t len) {
  char *segment = (char *)malloc(len + 1);
  if (segment == NULL) {
    return NULL;
  }
  if (len > 0) {
    memcpy(segment, start, len);
  }
  segment[len] = '\0';
  return segment;
}

static char *join_path(const char *dir, const char *name) {
  size_t dir_len = strlen(dir);
  size_t name_len = strlen(name);
  bool needs_sep = dir_len > 0 && dir[dir_len - 1] != '/';
  size_t total = dir_len + (needs_sep ? 1 : 0) + name_len;
  char *path = (char *)malloc(total + 1);
  if (path == NULL) {
    return NULL;
  }
  memcpy(path, dir, dir_len);
  size_t cursor = dir_len;
  if (needs_sep) {
    path[cursor++] = '/';
  }
  memcpy(path + cursor, name, name_len);
  path[total] = '\0';
  return path;
}

char *markitdown_runtime_find_in_path(const char *name, const char *path_env) {
  if (name == NULL || name[0] == '\0') {
    return strdup("");
  }
  if (strchr(name, '/') != NULL) {
    return runtime_is_executable_file(name) ? strdup(name) : strdup("");
  }
  const char *path = path_env;
  if (path == NULL || path[0] == '\0') {
    path = getenv("PATH");
  }
  if (path == NULL || path[0] == '\0') {
    return strdup("");
  }
  const char *cursor = path;
  while (true) {
    const char *next = strchr(cursor, ':');
    size_t len = next == NULL ? strlen(cursor) : (size_t)(next - cursor);
    char *dir = len == 0 ? strdup(".") : copy_segment(cursor, len);
    if (dir == NULL) {
      return strdup("");
    }
    char *candidate = join_path(dir, name);
    free(dir);
    if (candidate == NULL) {
      return strdup("");
    }
    if (runtime_is_executable_file(candidate)) {
      return candidate;
    }
    free(candidate);
    if (next == NULL) {
      break;
    }
    cursor = next + 1;
  }
  return strdup("");
}
