#include "moonbit.h"

#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void *MdXmlParser;
typedef char XML_Char;

typedef MdXmlParser (*MdXmlParserCreateFn)(const XML_Char *);
typedef int (*MdXmlParseFn)(MdXmlParser, const char *, int, int);
typedef void (*MdXmlSetUserDataFn)(MdXmlParser, void *);
typedef void (*MdXmlSetElementHandlerFn)(
  MdXmlParser,
  void (*)(void *, const XML_Char *, const XML_Char **),
  void (*)(void *, const XML_Char *)
);
typedef void (*MdXmlSetCharacterDataHandlerFn)(
  MdXmlParser,
  void (*)(void *, const XML_Char *, int)
);
typedef void (*MdXmlSetProcessingInstructionHandlerFn)(
  MdXmlParser,
  void (*)(void *, const XML_Char *, const XML_Char *)
);
typedef void (*MdXmlSetCommentHandlerFn)(
  MdXmlParser,
  void (*)(void *, const XML_Char *)
);
typedef void (*MdXmlSetCdataSectionHandlerFn)(
  MdXmlParser,
  void (*)(void *),
  void (*)(void *)
);
typedef void (*MdXmlSetDefaultHandlerFn)(
  MdXmlParser,
  void (*)(void *, const XML_Char *, int)
);
typedef int (*MdXmlGetErrorCodeFn)(MdXmlParser);
typedef void (*MdXmlParserFreeFn)(MdXmlParser);

typedef struct {
  void *handle;
  MdXmlParserCreateFn XML_ParserCreate;
  MdXmlParseFn XML_Parse;
  MdXmlSetUserDataFn XML_SetUserData;
  MdXmlSetElementHandlerFn XML_SetElementHandler;
  MdXmlSetCharacterDataHandlerFn XML_SetCharacterDataHandler;
  MdXmlSetProcessingInstructionHandlerFn XML_SetProcessingInstructionHandler;
  MdXmlSetCommentHandlerFn XML_SetCommentHandler;
  MdXmlSetCdataSectionHandlerFn XML_SetCdataSectionHandler;
  MdXmlSetDefaultHandlerFn XML_SetDefaultHandler;
  MdXmlGetErrorCodeFn XML_GetErrorCode;
  MdXmlParserFreeFn XML_ParserFree;
  int ready;
} MdXmlApi;

typedef struct {
  uint32_t offset;
  uint32_t len;
} MdStringRef;

typedef struct {
  int node_count;
  int element_count;
  int attribute_count;
  int text_node_count;
  int comment_count;
  int cdata_count;
  int processing_instruction_count;
  int max_depth;
  int has_doctype;
  int has_unsupported_doctype;
  int has_complex_mixed_content;
  int has_markdown_fence_text;
  int has_default_namespace;
  int in_cdata;
  int depth;
  int *child_element_seen;
  size_t child_frame_cap;
  int *text_before_child_seen;
  size_t text_frame_cap;
  size_t frame_count;
} MdStructureCollector;

typedef struct {
  MdStringRef name;
  MdStringRef sheet_id;
  MdStringRef relationship_id;
  MdStringRef state;
} MdWorkbookSheetRecord;

typedef struct {
  int row_index;
  int column_index;
  MdStringRef cell_ref;
  MdStringRef cell_type;
  MdStringRef style_id;
  MdStringRef raw_value;
  MdStringRef inline_text;
  MdStringRef formula_text;
  MdStringRef formula_kind;
} MdWorksheetCellRecord;

typedef struct {
  uint8_t *data;
  size_t len;
  size_t cap;
} MdByteBuffer;

typedef struct {
  char *data;
  size_t len;
  size_t cap;
} MdCharBuffer;

typedef struct {
  MdStringRef dimension_ref;
  uint32_t hidden_count;
  uint32_t merge_count;
} MdWorksheetHeader;

typedef struct {
  MdCharBuffer strings;
  MdWorkbookSheetRecord *records;
  size_t count;
  size_t cap;
  int uses_date_1904;
} MdWorkbookCollector;

typedef struct {
  MdCharBuffer strings;
  MdStringRef *records;
  size_t count;
  size_t cap;
  int in_si;
  int in_t;
  MdCharBuffer current;
} MdSharedStringsCollector;

typedef struct {
  MdCharBuffer strings;
  int *hidden_rows;
  size_t hidden_count;
  size_t hidden_cap;
  MdStringRef *merged_ranges;
  size_t merge_count;
  size_t merge_cap;
  MdWorksheetCellRecord *cells;
  size_t cell_count;
  size_t cell_cap;
  MdStringRef dimension_ref;
  int in_value;
  int in_formula;
  int in_inline_text;
  int in_text_node;
  MdWorksheetCellRecord current_cell;
  MdCharBuffer current_value;
  MdCharBuffer current_formula;
  MdCharBuffer current_inline;
} MdWorksheetCollector;

typedef struct {
  MdXmlParser parser;
  MdWorksheetCollector collector;
  int status;
  int error_code;
  int limits_enabled;
  int max_rows;
  int max_cols;
  int max_cells;
  int min_row;
  int min_col;
  int max_row_bound;
  int max_col_bound;
  int bounds_ready;
  int within_sheet_data;
  int clip_rows_triggered;
  int clip_cols_triggered;
  int clip_cells_triggered;
} MdWorksheetScanner;

static MdXmlApi g_xml_api = {0};

static moonbit_bytes_t md_empty_bytes(void) {
  return moonbit_make_bytes_raw(0);
}

static moonbit_bytes_t md_bytes_from_buffer(const uint8_t *src, int32_t len) {
  if (len <= 0) {
    return md_empty_bytes();
  }
  moonbit_bytes_t out = moonbit_make_bytes_raw(len);
  memcpy(out, src, (size_t)len);
  return out;
}

static void md_xml_set_status(
  int32_t *out_status,
  int32_t *out_error_code,
  int32_t status,
  int32_t error_code
) {
  if (out_status != NULL) *out_status = status;
  if (out_error_code != NULL) *out_error_code = error_code;
}

static int md_try_open_expat(void) {
  if (g_xml_api.ready) {
    return 1;
  }
  const char *candidates[] = {
    "libexpat.dylib",
    "/usr/lib/libexpat.dylib",
    "/opt/homebrew/lib/libexpat.dylib",
    "/usr/local/lib/libexpat.dylib",
    "/Users/winter/miniconda3/lib/libexpat.dylib",
    NULL
  };
  for (int i = 0; candidates[i] != NULL; i += 1) {
    void *handle = dlopen(candidates[i], RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
      continue;
    }
    g_xml_api.handle = handle;
    g_xml_api.XML_ParserCreate =
      (MdXmlParserCreateFn)dlsym(handle, "XML_ParserCreate");
    g_xml_api.XML_Parse =
      (MdXmlParseFn)dlsym(handle, "XML_Parse");
    g_xml_api.XML_SetUserData =
      (MdXmlSetUserDataFn)dlsym(handle, "XML_SetUserData");
    g_xml_api.XML_SetElementHandler =
      (MdXmlSetElementHandlerFn)dlsym(handle, "XML_SetElementHandler");
    g_xml_api.XML_SetCharacterDataHandler =
      (MdXmlSetCharacterDataHandlerFn)dlsym(handle, "XML_SetCharacterDataHandler");
    g_xml_api.XML_SetProcessingInstructionHandler =
      (MdXmlSetProcessingInstructionHandlerFn)dlsym(handle, "XML_SetProcessingInstructionHandler");
    g_xml_api.XML_SetCommentHandler =
      (MdXmlSetCommentHandlerFn)dlsym(handle, "XML_SetCommentHandler");
    g_xml_api.XML_SetCdataSectionHandler =
      (MdXmlSetCdataSectionHandlerFn)dlsym(handle, "XML_SetCdataSectionHandler");
    g_xml_api.XML_SetDefaultHandler =
      (MdXmlSetDefaultHandlerFn)dlsym(handle, "XML_SetDefaultHandler");
    g_xml_api.XML_GetErrorCode =
      (MdXmlGetErrorCodeFn)dlsym(handle, "XML_GetErrorCode");
    g_xml_api.XML_ParserFree =
      (MdXmlParserFreeFn)dlsym(handle, "XML_ParserFree");
    if (
      g_xml_api.XML_ParserCreate != NULL &&
      g_xml_api.XML_Parse != NULL &&
      g_xml_api.XML_SetUserData != NULL &&
      g_xml_api.XML_SetElementHandler != NULL &&
      g_xml_api.XML_SetCharacterDataHandler != NULL &&
      g_xml_api.XML_SetProcessingInstructionHandler != NULL &&
      g_xml_api.XML_SetCommentHandler != NULL &&
      g_xml_api.XML_SetCdataSectionHandler != NULL &&
      g_xml_api.XML_SetDefaultHandler != NULL &&
      g_xml_api.XML_GetErrorCode != NULL &&
      g_xml_api.XML_ParserFree != NULL
    ) {
      g_xml_api.ready = 1;
      return 1;
    }
    dlclose(handle);
    memset(&g_xml_api, 0, sizeof(g_xml_api));
  }
  return 0;
}

static int md_reserve_bytes(uint8_t **buffer, size_t *cap, size_t want) {
  if (want <= *cap) {
    return 1;
  }
  size_t next = *cap == 0U ? 256U : *cap;
  while (want > next) {
    next *= 2U;
  }
  uint8_t *grown = (uint8_t *)realloc(*buffer, next);
  if (grown == NULL) {
    return 0;
  }
  *buffer = grown;
  *cap = next;
  return 1;
}

static int md_append_bytes(uint8_t **buffer, size_t *len, size_t *cap, const void *src, size_t add) {
  size_t want = *len + add;
  if (!md_reserve_bytes(buffer, cap, want)) {
    return 0;
  }
  if (add > 0U) {
    memcpy(*buffer + *len, src, add);
  }
  *len = want;
  return 1;
}

static int md_append_u32_le(uint8_t **buffer, size_t *len, size_t *cap, uint32_t value) {
  uint8_t bytes[4];
  bytes[0] = (uint8_t)(value & 0xFFU);
  bytes[1] = (uint8_t)((value >> 8) & 0xFFU);
  bytes[2] = (uint8_t)((value >> 16) & 0xFFU);
  bytes[3] = (uint8_t)((value >> 24) & 0xFFU);
  return md_append_bytes(buffer, len, cap, bytes, 4U);
}

static int md_char_buffer_append(MdCharBuffer *buffer, const char *src, size_t len) {
  size_t want = buffer->len + len;
  if (want + 1U > buffer->cap) {
    size_t next = buffer->cap == 0U ? 256U : buffer->cap;
    while (want + 1U > next) {
      next *= 2U;
    }
    char *grown = (char *)realloc(buffer->data, next);
    if (grown == NULL) {
      return 0;
    }
    buffer->data = grown;
    buffer->cap = next;
  }
  if (len > 0U) {
    memcpy(buffer->data + buffer->len, src, len);
  }
  buffer->len = want;
  buffer->data[buffer->len] = '\0';
  return 1;
}

static void md_char_buffer_clear(MdCharBuffer *buffer) {
  buffer->len = 0U;
  if (buffer->data != NULL) {
    buffer->data[0] = '\0';
  }
}

static MdStringRef md_string_ref_from_text(MdCharBuffer *table, const char *text) {
  MdStringRef ref;
  ref.offset = (uint32_t)table->len;
  ref.len = text == NULL ? 0U : (uint32_t)strlen(text);
  if (ref.len > 0U) {
    md_char_buffer_append(table, text, ref.len);
  }
  return ref;
}

static MdStringRef md_string_ref_from_buffer(MdCharBuffer *table, MdCharBuffer *value) {
  MdStringRef ref;
  ref.offset = (uint32_t)table->len;
  ref.len = (uint32_t)value->len;
  if (value->len > 0U) {
    md_char_buffer_append(table, value->data, value->len);
  }
  return ref;
}

static const char *md_find_attr(const XML_Char **attrs, const char *name) {
  if (attrs == NULL) {
    return NULL;
  }
  for (int i = 0; attrs[i] != NULL && attrs[i + 1] != NULL; i += 2) {
    if (strcmp(attrs[i], name) == 0) {
      return attrs[i + 1];
    }
  }
  return NULL;
}

static int md_contains_markdown_fence_len(const char *text, size_t len) {
  if (text == NULL || len < 3U) {
    return 0;
  }
  for (size_t i = 0; i + 2U < len; i += 1) {
    if (text[i] == '`' && text[i + 1] == '`' && text[i + 2] == '`') {
      return 1;
    }
  }
  return 0;
}

static int md_contains_markdown_fence(const char *text) {
  if (text == NULL) {
    return 0;
  }
  return md_contains_markdown_fence_len(text, strlen(text));
}

static int md_reserve_ints(int **buffer, size_t *cap, size_t want) {
  if (want <= *cap) {
    return 1;
  }
  size_t next = *cap == 0U ? 16U : *cap;
  while (want > next) {
    next *= 2U;
  }
  int *grown = (int *)realloc(*buffer, next * sizeof(int));
  if (grown == NULL) {
    return 0;
  }
  *buffer = grown;
  *cap = next;
  return 1;
}

static int md_structure_push_frame(MdStructureCollector *collector) {
  size_t want = collector->frame_count + 1U;
  if (
    !md_reserve_ints(
      &collector->child_element_seen,
      &collector->child_frame_cap,
      want
    ) ||
    !md_reserve_ints(
      &collector->text_before_child_seen,
      &collector->text_frame_cap,
      want
    )
  ) {
    return 0;
  }
  collector->child_element_seen[collector->frame_count] = 0;
  collector->text_before_child_seen[collector->frame_count] = 0;
  collector->frame_count = want;
  return 1;
}

static void md_structure_pop_frame(MdStructureCollector *collector) {
  if (collector->frame_count == 0U) {
    return;
  }
  size_t idx = collector->frame_count - 1U;
  int has_child = collector->child_element_seen[idx];
  int has_text_before_child = collector->text_before_child_seen[idx];
  collector->frame_count = idx;
  if (collector->depth > 0) {
    collector->depth -= 1;
  }
  if (has_child && has_text_before_child) {
    collector->has_complex_mixed_content = 1;
  }
}

static void md_structure_record_text(MdStructureCollector *collector, const char *text, int len, int is_cdata) {
  if (collector == NULL || text == NULL || len <= 0) {
    return;
  }
  int has_non_whitespace = 0;
  for (int i = 0; i < len; i += 1) {
    unsigned char ch = (unsigned char)text[i];
    if (!(ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t')) {
      has_non_whitespace = 1;
      break;
    }
  }
  if (!has_non_whitespace) {
    return;
  }
  if (is_cdata) {
    collector->cdata_count += 1;
  } else {
    collector->text_node_count += 1;
  }
  collector->node_count += 1;
  if (collector->frame_count > 0U) {
    size_t idx = collector->frame_count - 1U;
    if (!collector->child_element_seen[idx]) {
      collector->text_before_child_seen[idx] = 1;
    }
  }
  if (md_contains_markdown_fence_len(text, (size_t)len)) {
    collector->has_markdown_fence_text = 1;
  }
}

static void md_structure_start(void *user_data, const XML_Char *name, const XML_Char **attrs) {
  MdStructureCollector *collector = (MdStructureCollector *)user_data;
  if (collector == NULL || name == NULL) {
    return;
  }
  collector->element_count += 1;
  collector->node_count += 1;
  if (collector->frame_count > 0U) {
    collector->child_element_seen[collector->frame_count - 1U] = 1;
  }
  collector->depth += 1;
  if (collector->depth > collector->max_depth) {
    collector->max_depth = collector->depth;
  }
  if (!md_structure_push_frame(collector)) {
    return;
  }
  for (int i = 0; attrs != NULL && attrs[i] != NULL && attrs[i + 1] != NULL; i += 2) {
    const char *attr_name = attrs[i];
    const char *attr_value = attrs[i + 1];
    collector->attribute_count += 1;
    collector->node_count += 1;
    if (strcmp(attr_name, "xmlns") == 0) {
      collector->has_default_namespace = 1;
    }
    if (md_contains_markdown_fence(attr_value)) {
      collector->has_markdown_fence_text = 1;
    }
  }
}

static void md_structure_end(void *user_data, const XML_Char *name) {
  MdStructureCollector *collector = (MdStructureCollector *)user_data;
  (void)name;
  if (collector == NULL) {
    return;
  }
  md_structure_pop_frame(collector);
}

static void md_structure_chars(void *user_data, const XML_Char *text, int len) {
  MdStructureCollector *collector = (MdStructureCollector *)user_data;
  md_structure_record_text(collector, text, len, collector != NULL ? collector->in_cdata : 0);
}

static void md_structure_processing_instruction(void *user_data, const XML_Char *target, const XML_Char *data) {
  MdStructureCollector *collector = (MdStructureCollector *)user_data;
  if (collector == NULL) {
    return;
  }
  collector->processing_instruction_count += 1;
  collector->node_count += 1;
  if (md_contains_markdown_fence(target) || md_contains_markdown_fence(data)) {
    collector->has_markdown_fence_text = 1;
  }
}

static void md_structure_comment(void *user_data, const XML_Char *data) {
  MdStructureCollector *collector = (MdStructureCollector *)user_data;
  if (collector == NULL || data == NULL) {
    return;
  }
  collector->comment_count += 1;
  collector->node_count += 1;
  if (md_contains_markdown_fence(data)) {
    collector->has_markdown_fence_text = 1;
  }
}

static void md_structure_start_cdata(void *user_data) {
  MdStructureCollector *collector = (MdStructureCollector *)user_data;
  if (collector != NULL) {
    collector->in_cdata = 1;
  }
}

static void md_structure_end_cdata(void *user_data) {
  MdStructureCollector *collector = (MdStructureCollector *)user_data;
  if (collector != NULL) {
    collector->in_cdata = 0;
  }
}

static void md_structure_default(void *user_data, const XML_Char *text, int len) {
  MdStructureCollector *collector = (MdStructureCollector *)user_data;
  if (collector == NULL || text == NULL || len <= 0) {
    return;
  }
  if (len >= 9 && strncmp(text, "<!DOCTYPE", 9) == 0) {
    collector->has_doctype = 1;
    collector->has_unsupported_doctype = 1;
    collector->node_count += 1;
    if (md_contains_markdown_fence_len(text, (size_t)len)) {
      collector->has_markdown_fence_text = 1;
    }
  }
}

static void md_free_structure_collector(MdStructureCollector *collector) {
  if (collector == NULL) {
    return;
  }
  free(collector->child_element_seen);
  free(collector->text_before_child_seen);
}

static moonbit_bytes_t md_emit_structure_blob(MdStructureCollector *collector) {
  uint8_t *out = NULL;
  size_t len = 0U;
  size_t cap = 0U;
  uint32_t flags = 0U;
  if (collector->has_doctype) flags |= 1U;
  if (collector->has_unsupported_doctype) flags |= 2U;
  if (collector->has_complex_mixed_content) flags |= 4U;
  if (collector->has_markdown_fence_text) flags |= 8U;
  if (collector->has_default_namespace) flags |= 16U;
  if (
    !md_append_u32_le(&out, &len, &cap, 0x4d584d4cU) ||
    !md_append_u32_le(&out, &len, &cap, 1U) ||
    !md_append_u32_le(&out, &len, &cap, 4U) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->node_count) ||
    !md_append_u32_le(&out, &len, &cap, flags) ||
    !md_append_u32_le(&out, &len, &cap, 28U) ||
    !md_append_u32_le(&out, &len, &cap, 56U) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->element_count) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->attribute_count) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->text_node_count) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->comment_count) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->cdata_count) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->processing_instruction_count) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->max_depth)
  ) {
    free(out);
    return md_empty_bytes();
  }
  moonbit_bytes_t blob = md_bytes_from_buffer(out, (int32_t)len);
  free(out);
  return blob;
}

static int md_col_from_ref(const char *ref, int *out_row, int *out_col) {
  if (ref == NULL || ref[0] == '\0') {
    return 0;
  }
  int col = 0;
  int i = 0;
  while (ref[i] >= 'A' && ref[i] <= 'Z') {
    col = col * 26 + (ref[i] - 'A' + 1);
    i += 1;
  }
  if (col <= 0) {
    return 0;
  }
  int row = 0;
  while (ref[i] >= '0' && ref[i] <= '9') {
    row = row * 10 + (ref[i] - '0');
    i += 1;
  }
  if (row <= 0) {
    return 0;
  }
  *out_row = row;
  *out_col = col;
  return 1;
}

static int md_parse_dimension_bounds(
  const char *ref,
  int *out_min_row,
  int *out_min_col,
  int *out_max_row,
  int *out_max_col
) {
  if (ref == NULL || ref[0] == '\0') {
    return 0;
  }
  const char *colon = strchr(ref, ':');
  if (colon == NULL) {
    int row = 0;
    int col = 0;
    if (!md_col_from_ref(ref, &row, &col)) {
      return 0;
    }
    *out_min_row = row;
    *out_min_col = col;
    *out_max_row = row;
    *out_max_col = col;
    return 1;
  }
  size_t left_len = (size_t)(colon - ref);
  size_t right_len = strlen(colon + 1);
  if (left_len == 0U || right_len == 0U || left_len >= 64U || right_len >= 64U) {
    return 0;
  }
  char left[64];
  char right[64];
  memcpy(left, ref, left_len);
  left[left_len] = '\0';
  memcpy(right, colon + 1, right_len);
  right[right_len] = '\0';
  if (!md_col_from_ref(left, out_min_row, out_min_col)) {
    return 0;
  }
  if (!md_col_from_ref(right, out_max_row, out_max_col)) {
    return 0;
  }
  return 1;
}

static void md_prepare_worksheet_bounds(MdWorksheetScanner *scanner, const char *dimension_ref) {
  if (scanner == NULL || !scanner->limits_enabled || scanner->bounds_ready) {
    return;
  }
  int min_row = 1;
  int min_col = 1;
  int max_row = 0;
  int max_col = 0;
  if (!md_parse_dimension_bounds(dimension_ref, &min_row, &min_col, &max_row, &max_col)) {
    return;
  }
  scanner->min_row = min_row;
  scanner->min_col = min_col;
  scanner->max_row_bound = max_row;
  scanner->max_col_bound = max_col;
  if (scanner->max_rows > 0 && scanner->max_row_bound - scanner->min_row + 1 > scanner->max_rows) {
    scanner->max_row_bound = scanner->min_row + scanner->max_rows - 1;
    scanner->clip_rows_triggered = 1;
  }
  if (scanner->max_cols > 0 && scanner->max_col_bound - scanner->min_col + 1 > scanner->max_cols) {
    scanner->max_col_bound = scanner->min_col + scanner->max_cols - 1;
    scanner->clip_cols_triggered = 1;
  }
  if (
    scanner->max_cells > 0 &&
    scanner->max_col_bound >= scanner->min_col &&
    scanner->max_row_bound >= scanner->min_row
  ) {
    int width = scanner->max_col_bound - scanner->min_col + 1;
    if (width > 0) {
      int max_rows_by_cells = scanner->max_cells / width;
      if (max_rows_by_cells <= 0) {
        max_rows_by_cells = 1;
      }
      if (scanner->max_row_bound - scanner->min_row + 1 > max_rows_by_cells) {
        scanner->max_row_bound = scanner->min_row + max_rows_by_cells - 1;
        scanner->clip_cells_triggered = 1;
      }
    }
  }
  scanner->bounds_ready = 1;
}

static int md_row_outside_bounds(MdWorksheetScanner *scanner, int row_index) {
  if (scanner == NULL || !scanner->limits_enabled || !scanner->bounds_ready || row_index <= 0) {
    return 0;
  }
  return row_index < scanner->min_row || row_index > scanner->max_row_bound;
}

static int md_cell_outside_bounds(MdWorksheetScanner *scanner, int row_index, int col_index) {
  if (scanner == NULL || !scanner->limits_enabled || !scanner->bounds_ready) {
    return 0;
  }
  if (row_index <= 0 || col_index <= 0) {
    return 1;
  }
  return row_index < scanner->min_row ||
    row_index > scanner->max_row_bound ||
    col_index < scanner->min_col ||
    col_index > scanner->max_col_bound;
}

static void md_workbook_start(void *user_data, const XML_Char *name, const XML_Char **attrs) {
  MdWorkbookCollector *collector = (MdWorkbookCollector *)user_data;
  if (strcmp(name, "workbookPr") == 0) {
    const char *date1904 = md_find_attr(attrs, "date1904");
    if (date1904 != NULL &&
        (strcmp(date1904, "1") == 0 ||
         strcmp(date1904, "true") == 0 ||
         strcmp(date1904, "TRUE") == 0)) {
      collector->uses_date_1904 = 1;
    }
    return;
  }
  if (strcmp(name, "sheet") == 0) {
    if (collector->count == collector->cap) {
      size_t next = collector->cap == 0U ? 8U : collector->cap * 2U;
      MdWorkbookSheetRecord *grown = (MdWorkbookSheetRecord *)realloc(
        collector->records,
        next * sizeof(MdWorkbookSheetRecord)
      );
      if (grown == NULL) {
        return;
      }
      collector->records = grown;
      collector->cap = next;
    }
    MdWorkbookSheetRecord record;
    record.name = md_string_ref_from_text(
      &collector->strings,
      md_find_attr(attrs, "name")
    );
    record.sheet_id = md_string_ref_from_text(
      &collector->strings,
      md_find_attr(attrs, "sheetId")
    );
    record.relationship_id = md_string_ref_from_text(
      &collector->strings,
      md_find_attr(attrs, "r:id")
    );
    record.state = md_string_ref_from_text(
      &collector->strings,
      md_find_attr(attrs, "state")
    );
    collector->records[collector->count++] = record;
  }
}

static void md_shared_strings_start(void *user_data, const XML_Char *name, const XML_Char **attrs) {
  MdSharedStringsCollector *collector = (MdSharedStringsCollector *)user_data;
  (void)attrs;
  if (strcmp(name, "si") == 0) {
    collector->in_si = 1;
    md_char_buffer_clear(&collector->current);
    return;
  }
  if (collector->in_si && strcmp(name, "t") == 0) {
    collector->in_t = 1;
  }
}

static void md_shared_strings_end(void *user_data, const XML_Char *name) {
  MdSharedStringsCollector *collector = (MdSharedStringsCollector *)user_data;
  if (strcmp(name, "t") == 0) {
    collector->in_t = 0;
    return;
  }
  if (strcmp(name, "si") == 0) {
    if (collector->count == collector->cap) {
      size_t next = collector->cap == 0U ? 16U : collector->cap * 2U;
      MdStringRef *grown = (MdStringRef *)realloc(
        collector->records,
        next * sizeof(MdStringRef)
      );
      if (grown == NULL) {
        return;
      }
      collector->records = grown;
      collector->cap = next;
    }
    collector->records[collector->count++] = md_string_ref_from_buffer(
      &collector->strings,
      &collector->current
    );
    collector->in_si = 0;
    md_char_buffer_clear(&collector->current);
  }
}

static void md_shared_strings_chars(void *user_data, const XML_Char *text, int len) {
  MdSharedStringsCollector *collector = (MdSharedStringsCollector *)user_data;
  if (!collector->in_si || !collector->in_t || len <= 0) {
    return;
  }
  md_char_buffer_append(&collector->current, text, (size_t)len);
}

static void md_worksheet_start(void *user_data, const XML_Char *name, const XML_Char **attrs) {
  MdWorksheetScanner *scanner = (MdWorksheetScanner *)user_data;
  MdWorksheetCollector *collector = &scanner->collector;
  if (strcmp(name, "dimension") == 0) {
    const char *dimension_ref = md_find_attr(attrs, "ref");
    md_prepare_worksheet_bounds(scanner, dimension_ref);
    collector->dimension_ref = md_string_ref_from_text(
      &collector->strings,
      dimension_ref
    );
    return;
  }
  if (strcmp(name, "sheetData") == 0) {
    scanner->within_sheet_data = 1;
    return;
  }
  if (strcmp(name, "row") == 0) {
    const char *row_attr = md_find_attr(attrs, "r");
    int row_index = row_attr == NULL ? 0 : atoi(row_attr);
    if (scanner->limits_enabled && scanner->bounds_ready && md_row_outside_bounds(scanner, row_index)) {
      return;
    }
    const char *hidden_attr = md_find_attr(attrs, "hidden");
    if (hidden_attr != NULL && strcmp(hidden_attr, "1") == 0 && row_attr != NULL) {
      if (collector->hidden_count == collector->hidden_cap) {
        size_t next = collector->hidden_cap == 0U ? 16U : collector->hidden_cap * 2U;
        int *grown = (int *)realloc(collector->hidden_rows, next * sizeof(int));
        if (grown == NULL) {
          return;
        }
        collector->hidden_rows = grown;
        collector->hidden_cap = next;
      }
      collector->hidden_rows[collector->hidden_count++] = atoi(row_attr);
    }
    return;
  }
  if (strcmp(name, "mergeCell") == 0) {
    if (collector->merge_count == collector->merge_cap) {
      size_t next = collector->merge_cap == 0U ? 8U : collector->merge_cap * 2U;
      MdStringRef *grown = (MdStringRef *)realloc(
        collector->merged_ranges,
        next * sizeof(MdStringRef)
      );
      if (grown == NULL) {
        return;
      }
      collector->merged_ranges = grown;
      collector->merge_cap = next;
    }
    collector->merged_ranges[collector->merge_count++] = md_string_ref_from_text(
      &collector->strings,
      md_find_attr(attrs, "ref")
    );
    return;
  }
  if (strcmp(name, "c") == 0) {
    memset(&collector->current_cell, 0, sizeof(collector->current_cell));
    collector->current_cell.cell_ref = md_string_ref_from_text(
      &collector->strings,
      md_find_attr(attrs, "r")
    );
    collector->current_cell.cell_type = md_string_ref_from_text(
      &collector->strings,
      md_find_attr(attrs, "t")
    );
    collector->current_cell.style_id = md_string_ref_from_text(
      &collector->strings,
      md_find_attr(attrs, "s")
    );
    const char *cell_ref = md_find_attr(attrs, "r");
    int row = 0;
    int col = 0;
    if (cell_ref != NULL && md_col_from_ref(cell_ref, &row, &col)) {
      collector->current_cell.row_index = row;
      collector->current_cell.column_index = col;
    }
    if (scanner->limits_enabled && scanner->bounds_ready && md_cell_outside_bounds(scanner, row, col)) {
      collector->current_cell.row_index = 0;
      collector->current_cell.column_index = 0;
    }
    md_char_buffer_clear(&collector->current_value);
    md_char_buffer_clear(&collector->current_formula);
    md_char_buffer_clear(&collector->current_inline);
    return;
  }
  if (strcmp(name, "v") == 0) {
    collector->in_value = 1;
    return;
  }
  if (strcmp(name, "f") == 0) {
    collector->in_formula = 1;
    collector->current_cell.formula_kind = md_string_ref_from_text(
      &collector->strings,
      md_find_attr(attrs, "t")
    );
    return;
  }
  if (strcmp(name, "is") == 0) {
    collector->in_inline_text = 1;
    return;
  }
  if ((collector->in_inline_text || collector->in_formula) && strcmp(name, "t") == 0) {
    collector->in_text_node = 1;
  }
}

static void md_worksheet_end(void *user_data, const XML_Char *name) {
  MdWorksheetScanner *scanner = (MdWorksheetScanner *)user_data;
  MdWorksheetCollector *collector = &scanner->collector;
  if (strcmp(name, "v") == 0) {
    collector->in_value = 0;
    return;
  }
  if (strcmp(name, "f") == 0) {
    collector->in_formula = 0;
    return;
  }
  if (strcmp(name, "is") == 0) {
    collector->in_inline_text = 0;
    return;
  }
  if (strcmp(name, "t") == 0) {
    collector->in_text_node = 0;
    return;
  }
  if (strcmp(name, "sheetData") == 0) {
    scanner->within_sheet_data = 0;
    return;
  }
  if (strcmp(name, "c") == 0) {
    if (collector->current_cell.row_index <= 0 || collector->current_cell.column_index <= 0) {
      return;
    }
    if (collector->cell_count == collector->cell_cap) {
      size_t next = collector->cell_cap == 0U ? 64U : collector->cell_cap * 2U;
      MdWorksheetCellRecord *grown = (MdWorksheetCellRecord *)realloc(
        collector->cells,
        next * sizeof(MdWorksheetCellRecord)
      );
      if (grown == NULL) {
        return;
      }
      collector->cells = grown;
      collector->cell_cap = next;
    }
    collector->current_cell.raw_value = md_string_ref_from_buffer(
      &collector->strings,
      &collector->current_value
    );
    collector->current_cell.inline_text = md_string_ref_from_buffer(
      &collector->strings,
      &collector->current_inline
    );
    collector->current_cell.formula_text = md_string_ref_from_buffer(
      &collector->strings,
      &collector->current_formula
    );
    collector->cells[collector->cell_count++] = collector->current_cell;
  }
}

static void md_worksheet_chars(void *user_data, const XML_Char *text, int len) {
  MdWorksheetScanner *scanner = (MdWorksheetScanner *)user_data;
  MdWorksheetCollector *collector = &scanner->collector;
  if (len <= 0) {
    return;
  }
  if (collector->in_value) {
    md_char_buffer_append(&collector->current_value, text, (size_t)len);
  }
  if (collector->in_formula && !collector->in_text_node) {
    md_char_buffer_append(&collector->current_formula, text, (size_t)len);
  }
  if (collector->in_inline_text && collector->in_text_node) {
    md_char_buffer_append(&collector->current_inline, text, (size_t)len);
  }
}

static moonbit_bytes_t md_emit_workbook_blob(MdWorkbookCollector *collector) {
  uint8_t *out = NULL;
  size_t len = 0U;
  size_t cap = 0U;
  if (
    !md_append_u32_le(&out, &len, &cap, 0x4d584d4cU) ||
    !md_append_u32_le(&out, &len, &cap, 1U) ||
    !md_append_u32_le(&out, &len, &cap, 1U) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->count) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)(collector->uses_date_1904 ? 1U : 0U)) ||
    !md_append_u32_le(&out, &len, &cap, 28U) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)(28U + collector->count * 32U))
  ) {
    free(out);
    return md_empty_bytes();
  }
  for (size_t i = 0; i < collector->count; i += 1) {
    MdWorkbookSheetRecord *record = &collector->records[i];
    if (
      !md_append_u32_le(&out, &len, &cap, record->name.offset) ||
      !md_append_u32_le(&out, &len, &cap, record->name.len) ||
      !md_append_u32_le(&out, &len, &cap, record->sheet_id.offset) ||
      !md_append_u32_le(&out, &len, &cap, record->sheet_id.len) ||
      !md_append_u32_le(&out, &len, &cap, record->relationship_id.offset) ||
      !md_append_u32_le(&out, &len, &cap, record->relationship_id.len) ||
      !md_append_u32_le(&out, &len, &cap, record->state.offset) ||
      !md_append_u32_le(&out, &len, &cap, record->state.len)
    ) {
      free(out);
      return md_empty_bytes();
    }
  }
  md_append_bytes(&out, &len, &cap, collector->strings.data, collector->strings.len);
  moonbit_bytes_t blob = md_bytes_from_buffer(out, (int32_t)len);
  free(out);
  return blob;
}

static moonbit_bytes_t md_emit_shared_strings_blob(MdSharedStringsCollector *collector) {
  uint8_t *out = NULL;
  size_t len = 0U;
  size_t cap = 0U;
  if (
    !md_append_u32_le(&out, &len, &cap, 0x4d584d4cU) ||
    !md_append_u32_le(&out, &len, &cap, 1U) ||
    !md_append_u32_le(&out, &len, &cap, 2U) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->count) ||
    !md_append_u32_le(&out, &len, &cap, 0U) ||
    !md_append_u32_le(&out, &len, &cap, 28U) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)(28U + collector->count * 8U))
  ) {
    free(out);
    return md_empty_bytes();
  }
  for (size_t i = 0; i < collector->count; i += 1) {
    if (
      !md_append_u32_le(&out, &len, &cap, collector->records[i].offset) ||
      !md_append_u32_le(&out, &len, &cap, collector->records[i].len)
    ) {
      free(out);
      return md_empty_bytes();
    }
  }
  md_append_bytes(&out, &len, &cap, collector->strings.data, collector->strings.len);
  moonbit_bytes_t blob = md_bytes_from_buffer(out, (int32_t)len);
  free(out);
  return blob;
}

static moonbit_bytes_t md_emit_worksheet_blob(MdWorksheetCollector *collector) {
  uint8_t *out = NULL;
  size_t len = 0U;
  size_t cap = 0U;
  uint32_t payload_offset = 28U;
  uint32_t string_offset = payload_offset + 12U +
    (uint32_t)(collector->hidden_count * 4U) +
    (uint32_t)(collector->merge_count * 8U) +
    (uint32_t)(collector->cell_count * 64U);
  if (
    !md_append_u32_le(&out, &len, &cap, 0x4d584d4cU) ||
    !md_append_u32_le(&out, &len, &cap, 1U) ||
    !md_append_u32_le(&out, &len, &cap, 3U) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->cell_count) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->hidden_count) ||
    !md_append_u32_le(&out, &len, &cap, payload_offset) ||
    !md_append_u32_le(&out, &len, &cap, string_offset)
  ) {
    free(out);
    return md_empty_bytes();
  }
  if (
    !md_append_u32_le(&out, &len, &cap, collector->dimension_ref.offset) ||
    !md_append_u32_le(&out, &len, &cap, collector->dimension_ref.len) ||
    !md_append_u32_le(&out, &len, &cap, (uint32_t)collector->merge_count)
  ) {
    free(out);
    return md_empty_bytes();
  }
  for (size_t i = 0; i < collector->hidden_count; i += 1) {
    if (!md_append_u32_le(&out, &len, &cap, (uint32_t)collector->hidden_rows[i])) {
      free(out);
      return md_empty_bytes();
    }
  }
  for (size_t i = 0; i < collector->merge_count; i += 1) {
    if (
      !md_append_u32_le(&out, &len, &cap, collector->merged_ranges[i].offset) ||
      !md_append_u32_le(&out, &len, &cap, collector->merged_ranges[i].len)
    ) {
      free(out);
      return md_empty_bytes();
    }
  }
  for (size_t i = 0; i < collector->cell_count; i += 1) {
    MdWorksheetCellRecord *cell = &collector->cells[i];
    if (
      !md_append_u32_le(&out, &len, &cap, (uint32_t)cell->row_index) ||
      !md_append_u32_le(&out, &len, &cap, (uint32_t)cell->column_index) ||
      !md_append_u32_le(&out, &len, &cap, cell->cell_ref.offset) ||
      !md_append_u32_le(&out, &len, &cap, cell->cell_ref.len) ||
      !md_append_u32_le(&out, &len, &cap, cell->cell_type.offset) ||
      !md_append_u32_le(&out, &len, &cap, cell->cell_type.len) ||
      !md_append_u32_le(&out, &len, &cap, cell->style_id.offset) ||
      !md_append_u32_le(&out, &len, &cap, cell->style_id.len) ||
      !md_append_u32_le(&out, &len, &cap, cell->raw_value.offset) ||
      !md_append_u32_le(&out, &len, &cap, cell->raw_value.len) ||
      !md_append_u32_le(&out, &len, &cap, cell->inline_text.offset) ||
      !md_append_u32_le(&out, &len, &cap, cell->inline_text.len) ||
      !md_append_u32_le(&out, &len, &cap, cell->formula_text.offset) ||
      !md_append_u32_le(&out, &len, &cap, cell->formula_text.len) ||
      !md_append_u32_le(&out, &len, &cap, cell->formula_kind.offset) ||
      !md_append_u32_le(&out, &len, &cap, cell->formula_kind.len)
    ) {
      free(out);
      return md_empty_bytes();
    }
  }
  md_append_bytes(&out, &len, &cap, collector->strings.data, collector->strings.len);
  moonbit_bytes_t blob = md_bytes_from_buffer(out, (int32_t)len);
  free(out);
  return blob;
}

static void md_free_worksheet_collector(MdWorksheetCollector *collector) {
  if (collector == NULL) {
    return;
  }
  free(collector->hidden_rows);
  free(collector->merged_ranges);
  free(collector->cells);
  free(collector->strings.data);
  free(collector->current_value.data);
  free(collector->current_formula.data);
  free(collector->current_inline.data);
}

static MdWorksheetScanner *md_new_worksheet_scanner(
  int limits_enabled,
  int max_rows,
  int max_cols,
  int max_cells,
  int32_t *out_status,
  int32_t *out_error_code
) {
  md_xml_set_status(out_status, out_error_code, 1, 0);
  if (!md_try_open_expat()) {
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return NULL;
  }
  MdXmlParser parser = g_xml_api.XML_ParserCreate(NULL);
  if (parser == NULL) {
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return NULL;
  }
  MdWorksheetScanner *scanner = (MdWorksheetScanner *)calloc(1U, sizeof(MdWorksheetScanner));
  if (scanner == NULL) {
    g_xml_api.XML_ParserFree(parser);
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return NULL;
  }
  scanner->parser = parser;
  scanner->status = 0;
  scanner->error_code = 0;
  scanner->limits_enabled = limits_enabled != 0;
  scanner->max_rows = max_rows;
  scanner->max_cols = max_cols;
  scanner->max_cells = max_cells;
  g_xml_api.XML_SetUserData(parser, scanner);
  g_xml_api.XML_SetElementHandler(parser, md_worksheet_start, md_worksheet_end);
  g_xml_api.XML_SetCharacterDataHandler(parser, md_worksheet_chars);
  md_xml_set_status(out_status, out_error_code, 0, 0);
  return scanner;
}

static int md_feed_worksheet_scanner(
  MdWorksheetScanner *scanner,
  const char *xml_blob,
  int32_t xml_len,
  int is_final,
  int32_t *out_status,
  int32_t *out_error_code
) {
  if (scanner == NULL || scanner->parser == NULL || xml_len < 0) {
    md_xml_set_status(out_status, out_error_code, 2, 1);
    return 0;
  }
  if (!g_xml_api.XML_Parse(scanner->parser, xml_blob, (int)xml_len, is_final)) {
    scanner->status = 2;
    scanner->error_code = (int32_t)g_xml_api.XML_GetErrorCode(scanner->parser);
    md_xml_set_status(out_status, out_error_code, scanner->status, scanner->error_code);
    return 0;
  }
  scanner->status = 0;
  scanner->error_code = 0;
  md_xml_set_status(out_status, out_error_code, 0, 0);
  return 1;
}

static moonbit_bytes_t md_finish_worksheet_scanner(
  MdWorksheetScanner *scanner,
  int32_t *out_status,
  int32_t *out_error_code
) {
  if (scanner == NULL) {
    md_xml_set_status(out_status, out_error_code, 2, 1);
    return md_empty_bytes();
  }
  if (scanner->status != 0) {
    md_xml_set_status(out_status, out_error_code, scanner->status, scanner->error_code);
    return md_empty_bytes();
  }
  md_xml_set_status(out_status, out_error_code, 0, 0);
  return md_emit_worksheet_blob(&scanner->collector);
}

static void md_free_worksheet_scanner(MdWorksheetScanner *scanner) {
  if (scanner == NULL) {
    return;
  }
  if (scanner->parser != NULL) {
    g_xml_api.XML_ParserFree(scanner->parser);
  }
  md_free_worksheet_collector(&scanner->collector);
  free(scanner);
}

moonbit_bytes_t markitdown_xml_native_xlsx_scan_workbook_blob(
  moonbit_bytes_t xml_blob,
  int32_t xml_len,
  int32_t *out_status,
  int32_t *out_error_code
) {
  md_xml_set_status(out_status, out_error_code, 1, 0);
  if (xml_blob == NULL || xml_len < 0) {
    return md_empty_bytes();
  }
  if (!md_try_open_expat()) {
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return md_empty_bytes();
  }
  MdXmlParser parser = g_xml_api.XML_ParserCreate(NULL);
  if (parser == NULL) {
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return md_empty_bytes();
  }
  MdWorkbookCollector collector;
  memset(&collector, 0, sizeof(collector));
  g_xml_api.XML_SetUserData(parser, &collector);
  g_xml_api.XML_SetElementHandler(parser, md_workbook_start, NULL);
  if (!g_xml_api.XML_Parse(parser, (const char *)xml_blob, (int)xml_len, 1)) {
    md_xml_set_status(out_status, out_error_code, 2, (int32_t)g_xml_api.XML_GetErrorCode(parser));
    g_xml_api.XML_ParserFree(parser);
    free(collector.records);
    free(collector.strings.data);
    return md_empty_bytes();
  }
  g_xml_api.XML_ParserFree(parser);
  md_xml_set_status(out_status, out_error_code, 0, 0);
  moonbit_bytes_t out = md_emit_workbook_blob(&collector);
  free(collector.records);
  free(collector.strings.data);
  return out;
}

moonbit_bytes_t markitdown_xml_native_scan_structure_blob(
  moonbit_bytes_t xml_blob,
  int32_t xml_len,
  int32_t *out_status,
  int32_t *out_error_code
) {
  md_xml_set_status(out_status, out_error_code, 1, 0);
  if (xml_blob == NULL || xml_len < 0) {
    return md_empty_bytes();
  }
  if (!md_try_open_expat()) {
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return md_empty_bytes();
  }
  MdXmlParser parser = g_xml_api.XML_ParserCreate(NULL);
  if (parser == NULL) {
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return md_empty_bytes();
  }
  MdStructureCollector collector;
  memset(&collector, 0, sizeof(collector));
  g_xml_api.XML_SetUserData(parser, &collector);
  g_xml_api.XML_SetElementHandler(parser, md_structure_start, md_structure_end);
  g_xml_api.XML_SetCharacterDataHandler(parser, md_structure_chars);
  g_xml_api.XML_SetProcessingInstructionHandler(parser, md_structure_processing_instruction);
  g_xml_api.XML_SetCommentHandler(parser, md_structure_comment);
  g_xml_api.XML_SetCdataSectionHandler(parser, md_structure_start_cdata, md_structure_end_cdata);
  g_xml_api.XML_SetDefaultHandler(parser, md_structure_default);
  if (!g_xml_api.XML_Parse(parser, (const char *)xml_blob, (int)xml_len, 1)) {
    md_xml_set_status(out_status, out_error_code, 2, (int32_t)g_xml_api.XML_GetErrorCode(parser));
    g_xml_api.XML_ParserFree(parser);
    md_free_structure_collector(&collector);
    return md_empty_bytes();
  }
  g_xml_api.XML_ParserFree(parser);
  md_xml_set_status(out_status, out_error_code, 0, 0);
  moonbit_bytes_t out = md_emit_structure_blob(&collector);
  md_free_structure_collector(&collector);
  return out;
}

moonbit_bytes_t markitdown_xml_native_xlsx_scan_shared_strings_blob(
  moonbit_bytes_t xml_blob,
  int32_t xml_len,
  int32_t *out_status,
  int32_t *out_error_code
) {
  md_xml_set_status(out_status, out_error_code, 1, 0);
  if (xml_blob == NULL || xml_len < 0) {
    return md_empty_bytes();
  }
  if (!md_try_open_expat()) {
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return md_empty_bytes();
  }
  MdXmlParser parser = g_xml_api.XML_ParserCreate(NULL);
  if (parser == NULL) {
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return md_empty_bytes();
  }
  MdSharedStringsCollector collector;
  memset(&collector, 0, sizeof(collector));
  g_xml_api.XML_SetUserData(parser, &collector);
  g_xml_api.XML_SetElementHandler(parser, md_shared_strings_start, md_shared_strings_end);
  g_xml_api.XML_SetCharacterDataHandler(parser, md_shared_strings_chars);
  if (!g_xml_api.XML_Parse(parser, (const char *)xml_blob, (int)xml_len, 1)) {
    md_xml_set_status(out_status, out_error_code, 2, (int32_t)g_xml_api.XML_GetErrorCode(parser));
    g_xml_api.XML_ParserFree(parser);
    free(collector.records);
    free(collector.strings.data);
    free(collector.current.data);
    return md_empty_bytes();
  }
  g_xml_api.XML_ParserFree(parser);
  md_xml_set_status(out_status, out_error_code, 0, 0);
  moonbit_bytes_t out = md_emit_shared_strings_blob(&collector);
  free(collector.records);
  free(collector.strings.data);
  free(collector.current.data);
  return out;
}

moonbit_bytes_t markitdown_xml_native_xlsx_scan_worksheet_blob(
  moonbit_bytes_t xml_blob,
  int32_t xml_len,
  int32_t *out_status,
  int32_t *out_error_code
) {
  md_xml_set_status(out_status, out_error_code, 1, 0);
  if (xml_blob == NULL || xml_len < 0) {
    return md_empty_bytes();
  }
  if (!md_try_open_expat()) {
    md_xml_set_status(out_status, out_error_code, 1, 1);
    return md_empty_bytes();
  }
  MdWorksheetScanner *scanner = md_new_worksheet_scanner(
    0,
    0,
    0,
    0,
    out_status,
    out_error_code
  );
  if (scanner == NULL) {
    return md_empty_bytes();
  }
  if (!md_feed_worksheet_scanner(
        scanner,
        (const char *)xml_blob,
        xml_len,
        1,
        out_status,
        out_error_code
      )) {
    md_free_worksheet_scanner(scanner);
    return md_empty_bytes();
  }
  moonbit_bytes_t out = md_finish_worksheet_scanner(scanner, out_status, out_error_code);
  md_free_worksheet_scanner(scanner);
  return out;
}

MOONBIT_FFI_EXPORT MdWorksheetScanner *markitdown_xml_native_xlsx_worksheet_scanner_new(
  int32_t limits_enabled,
  int32_t max_rows,
  int32_t max_cols,
  int32_t max_cells,
  int32_t *out_status,
  int32_t *out_error_code
) {
  return md_new_worksheet_scanner(
    limits_enabled,
    max_rows,
    max_cols,
    max_cells,
    out_status,
    out_error_code
  );
}

MOONBIT_FFI_EXPORT int32_t markitdown_xml_native_xlsx_worksheet_scanner_is_null(
  MdWorksheetScanner *scanner
) {
  return scanner == NULL ? 1 : 0;
}

MOONBIT_FFI_EXPORT int32_t markitdown_xml_native_xlsx_worksheet_scanner_feed(
  MdWorksheetScanner *scanner,
  moonbit_bytes_t xml_blob,
  int32_t xml_len,
  int32_t is_final,
  int32_t *out_status,
  int32_t *out_error_code
) {
  if (xml_blob == NULL && xml_len > 0) {
    md_xml_set_status(out_status, out_error_code, 2, 1);
    return 0;
  }
  return md_feed_worksheet_scanner(
    scanner,
    (const char *)xml_blob,
    xml_len,
    is_final != 0,
    out_status,
    out_error_code
  );
}

MOONBIT_FFI_EXPORT moonbit_bytes_t markitdown_xml_native_xlsx_worksheet_scanner_finish(
  MdWorksheetScanner *scanner,
  int32_t *out_status,
  int32_t *out_error_code
) {
  return md_finish_worksheet_scanner(scanner, out_status, out_error_code);
}

MOONBIT_FFI_EXPORT void markitdown_xml_native_xlsx_worksheet_scanner_free(
  MdWorksheetScanner *scanner
) {
  md_free_worksheet_scanner(scanner);
}
