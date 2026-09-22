#include "profile.h"
#include "guard.h"
#include "project.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PROFILE_TIMEOUT 30U

typedef struct {
  uint64_t *addresses;
  uint64_t *counts;
  uint64_t *words;
  size_t count;
  size_t capacity;
} AddressSet;

static int ends_with(const char *text, const char *suffix) {
  size_t text_length = strlen(text);
  size_t suffix_length = strlen(suffix);
  return text_length >= suffix_length && strcmp(text + text_length - suffix_length, suffix) == 0;
}

static void set_free(AddressSet *set) {
  free(set->addresses);
  free(set->counts);
  free(set->words);
  set->addresses = NULL;
  set->counts = NULL;
  set->words = NULL;
  set->count = 0U;
  set->capacity = 0U;
}

static int set_find(const AddressSet *set, uint64_t address, size_t *position) {
  size_t index;
  for (index = 0U; index < set->count; ++index) {
    if (set->addresses[index] == address) {
      *position = index;
      return 1;
    }
  }
  return 0;
}

static int set_add(AddressSet *set, uint64_t address, uint64_t count, int reject_duplicate) {
  size_t position;
  if (set_find(set, address, &position)) {
    if (reject_duplicate) {
      return g_error("duplicate MMIX instruction address %016llx", (unsigned long long)address);
    }
    if (UINT64_MAX - set->counts[position] < count) {
      return g_error("profile count overflow at %016llx", (unsigned long long)address);
    }
    set->counts[position] += count;
    return 0;
  }
  if (set->count == set->capacity) {
    size_t next = set->capacity == 0U ? 32U : set->capacity * 2U;
    uint64_t *addresses;
    uint64_t *counts;
    uint64_t *words;
    if (next < set->capacity || next > SIZE_MAX / sizeof(*addresses)) {
      return g_internal("too many MMIX instruction addresses");
    }
    addresses = (uint64_t *)realloc(set->addresses, next * sizeof(*addresses));
    if (addresses == NULL) {
      return g_internal("out of memory parsing MMIX addresses");
    }
    set->addresses = addresses;
    counts = (uint64_t *)realloc(set->counts, next * sizeof(*counts));
    if (counts == NULL) {
      return g_internal("out of memory parsing MMIX counts");
    }
    set->counts = counts;
    words = (uint64_t *)realloc(set->words, next * sizeof(*words));
    if (words == NULL) {
      return g_internal("out of memory parsing MMIX instruction words");
    }
    set->words = words;
    set->capacity = next;
  }
  set->addresses[set->count] = address;
  set->counts[set->count] = count;
  set->words[set->count] = UINT64_MAX;
  ++set->count;
  return 0;
}

static int hex_exact(const char *text, size_t digits, uint64_t *value) {
  char buffer[17];
  size_t index;
  if (digits == 0U || digits > 16U) {
    return -1;
  }
  for (index = 0U; index < digits; ++index) {
    if (!isxdigit((unsigned char)text[index])) {
      return -1;
    }
    buffer[index] = text[index];
  }
  buffer[digits] = '\0';
  return g_u64(buffer, 16U, value) == 0 ? 0 : -1;
}

static int listing_row(const char *line, uint64_t *last, int *have_last, uint64_t *address,
                       int *is_instruction, int *continuation, uint64_t *word, int *word_known) {
  const char *colon = strchr(line, ':');
  const char *start;
  const char *after;
  size_t digits;
  uint64_t suffix;
  size_t word_index;
  *is_instruction = 0;
  *continuation = 0;
  *word_known = 0;
  if (colon == NULL) {
    return 0;
  }
  start = colon;
  while (start > line && isxdigit((unsigned char)start[-1])) {
    --start;
  }
  digits = (size_t)(colon - start);
  if (digits == 0U || digits > 16U || hex_exact(start, digits, &suffix) != 0) {
    return 0;
  }
  if (start >= line + 3 && start[-1] == '.' && start[-2] == '.' && start[-3] == '.') {
    uint64_t mask;
    if (!*have_last || digits == 16U) {
      return -1;
    }
    mask = (UINT64_C(1) << (digits * 4U)) - 1U;
    *address = (*last & ~mask) | suffix;
    *continuation = 1;
  } else {
    if (digits != 16U) {
      return 0;
    }
    *address = suffix;
  }
  *last = *address;
  *have_last = 1;
  after = colon + 1;
  while (*after == ' ' || *after == '\t') {
    ++after;
  }
  if (strlen(after) < 8U) {
    return -1;
  }
  for (word_index = 0U; word_index < 8U; ++word_index) {
    if (!isxdigit((unsigned char)after[word_index]) && after[word_index] != 'x' &&
        after[word_index] != 'X') {
      return 0;
    }
  }
  if (!isxdigit((unsigned char)after[0]) || !isxdigit((unsigned char)after[1])) {
    return -1;
  }
  if (hex_exact(after, 8U, word) == 0) {
    *word_known = 1;
  }
  *is_instruction = *address < UINT64_C(0x2000000000000000);
  return 1;
}

static int parse_listing_data(const unsigned char *data, size_t size, AddressSet *instructions,
                              int require_main) {
  size_t start = 0U;
  uint64_t last = 0U;
  int have_last = 0;
  int main_symbols = 0;
  while (start < size) {
    size_t end = start;
    char *line;
    uint64_t address;
    uint64_t word = 0U;
    int instruction;
    int continuation;
    int word_known;
    int parsed;
    while (end < size && data[end] != '\n') {
      ++end;
    }
    line = (char *)malloc(end - start + 1U);
    if (line == NULL) {
      return g_internal("out of memory parsing listing");
    }
    memcpy(line, data + start, end - start);
    line[end - start] = '\0';
    if (strstr(line, " Main = #") != NULL || strncmp(line, " Main = #", 9U) == 0) {
      ++main_symbols;
    }
    parsed = listing_row(line, &last, &have_last, &address, &instruction, &continuation, &word,
                         &word_known);
    free(line);
    if (parsed < 0) {
      return g_error("malformed abbreviated address in MMIX listing");
    }
    if (parsed > 0 && instruction) {
      if (set_add(instructions, address, 0U, 1) != 0) {
        return 1;
      }
      if (word_known) {
        instructions->words[instructions->count - 1U] = word;
      }
    }
    start = end < size ? end + 1U : end;
  }
  if (instructions->count == 0U) {
    return g_error("listing contains no executable MMIX instructions");
  }
  if (require_main && main_symbols != 1) {
    return g_error("listing must contain exactly one Main symbol, got %d", main_symbols);
  }
  return 0;
}

static int load_listing(const char *path, AddressSet *instructions) {
  unsigned char *data = NULL;
  size_t size = 0U;
  int result = g_read(path, &data, &size);
  if (result == 0) {
    result = parse_listing_data(data, size, instructions, 1);
  }
  free(data);
  return result;
}

int g_listing(const char *path) {
  AddressSet instructions = {0};
  int result = load_listing(path, &instructions);
  set_free(&instructions);
  return result;
}

static int parse_object_data(const unsigned char *data, size_t size) {
  size_t start = 0U;
  int entry_count = 0;
  int main_count = 0;
  int entry_word_count = 0;
  uint64_t entry = 0U;
  uint64_t main_address = 0U;
  while (start < size) {
    size_t end = start;
    char *line;
    while (end < size && data[end] != '\n') {
      ++end;
    }
    line = (char *)malloc(end - start + 1U);
    if (line == NULL) {
      return g_internal("out of memory parsing mmotype output");
    }
    memcpy(line, data + start, end - start);
    line[end - start] = '\0';
    if (strncmp(line, "g255: ", 6U) == 0) {
      if (strlen(line + 6U) != 16U || hex_exact(line + 6U, 16U, &entry) != 0) {
        free(line);
        return g_error("malformed g255 entry metadata in mmotype output");
      }
      ++entry_count;
    } else if (strncmp(line, "    Main = #", 12U) == 0) {
      const char *digits = line + 12U;
      const char *space = strchr(digits, ' ');
      size_t count = space == NULL ? 0U : (size_t)(space - digits);
      if (count == 0U || count > 16U || hex_exact(digits, count, &main_address) != 0 ||
          space[1] != '(') {
        free(line);
        return g_error("malformed Main metadata in mmotype output");
      }
      ++main_count;
    }
    free(line);
    start = end < size ? end + 1U : end;
  }
  if (entry_count != 1 || main_count != 1 || entry != main_address || (entry & UINT64_C(3)) != 0U ||
      entry >= UINT64_C(0x2000000000000000)) {
    return g_error("object requires one aligned executable Main equal to g255");
  }
  start = 0U;
  while (start < size) {
    size_t end = start;
    const char *line = (const char *)data + start;
    uint64_t address;
    uint64_t word;
    while (end < size && data[end] != '\n') {
      ++end;
    }
    if (end - start >= 26U && line[16] == ':' && line[17] == ' ' &&
        hex_exact(line, 16U, &address) == 0 && hex_exact(line + 18U, 8U, &word) == 0 &&
        address == entry) {
      (void)word;
      ++entry_word_count;
    }
    start = end < size ? end + 1U : end;
  }
  if (entry_word_count != 1) {
    return g_error("mmotype output lacks exactly one executable word at Main");
  }
  return 0;
}

int g_object(const char *path) {
  const char *arguments[4];
  char output[128];
  char errors[128];
  unsigned char *data = NULL;
  size_t size = 0U;
  int status;
  int result;
  int written = snprintf(output, sizeof(output), "build/tmp/mmotype-%08lx.out",
                         (unsigned long)(strlen(path) * 2654435761UL) & 0xffffffffUL);
  if (written < 0 || (size_t)written >= sizeof(output)) {
    return g_internal("mmotype output path is too long");
  }
  written = snprintf(errors, sizeof(errors), "build/tmp/mmotype-%08lx.err",
                     (unsigned long)(strlen(path) * 2654435761UL) & 0xffffffffUL);
  if (written < 0 || (size_t)written >= sizeof(errors)) {
    return g_internal("mmotype error path is too long");
  }
  arguments[0] = G_OBJECT_TOOL;
  arguments[1] = path;
  arguments[2] = NULL;
  arguments[3] = NULL;
  result = g_run(arguments, NULL, output, errors, &status, PROFILE_TIMEOUT);
  if (result != 0) {
    return result;
  }
  if (status != 0 || g_empty(errors) != 0 || g_read(output, &data, &size) != 0) {
    free(data);
    return g_error("mmotype rejected or warned about %s", path);
  }
  result = parse_object_data(data, size);
  free(data);
  return result;
}

static int profile_record(const char *line, uint64_t *count, uint64_t *address,
                          uint64_t *instruction) {
  const char *cursor = line;
  const char *dot;
  const char *colon;
  char number[32];
  size_t length;
  while (*cursor == ' ' || *cursor == '\t') {
    ++cursor;
  }
  dot = strchr(cursor, '.');
  if (dot == NULL || dot == cursor) {
    return 0;
  }
  length = (size_t)(dot - cursor);
  if (length >= sizeof(number)) {
    return -1;
  }
  memcpy(number, cursor, length);
  number[length] = '\0';
  if (g_u64(number, 10U, count) != 0 || *count == 0U) {
    return 0;
  }
  cursor = dot + 1;
  while (*cursor == ' ') {
    ++cursor;
  }
  if (strlen(cursor) < 8U) {
    return -1;
  }
  colon = strchr(cursor, ':');
  if (colon == NULL || (size_t)(colon - cursor) != 16U || hex_exact(cursor, 16U, address) != 0) {
    return -1;
  }
  cursor = colon + 1;
  while (*cursor == ' ') {
    ++cursor;
  }
  if (hex_exact(cursor, 8U, instruction) != 0) {
    return -1;
  }
  cursor += 8U;
  while (*cursor == ' ') {
    ++cursor;
  }
  if (*cursor != '(' || strchr(cursor, ')') == NULL) {
    return -1;
  }
  return 1;
}

static int decimal_field(const char **cursor, uint64_t *value) {
  char number[32];
  size_t digits = 0U;
  while (isdigit((unsigned char)(*cursor)[digits])) {
    if (digits + 1U >= sizeof(number)) {
      return -1;
    }
    number[digits] = (*cursor)[digits];
    ++digits;
  }
  if (digits == 0U) {
    return -1;
  }
  number[digits] = '\0';
  if (g_u64(number, 10U, value) != 0) {
    return -1;
  }
  *cursor += digits;
  return 0;
}

static int literal_field(const char **cursor, const char *literal) {
  size_t length = strlen(literal);
  if (strncmp(*cursor, literal, length) != 0) {
    return -1;
  }
  *cursor += length;
  return 0;
}

static int statistics_line(const char *line, uint64_t *reported) {
  const char *cursor = line;
  uint64_t instructions, mems, oops, good, bad;
  while (*cursor == ' ') {
    ++cursor;
  }
  if (decimal_field(&cursor, &instructions) != 0 ||
      literal_field(&cursor, instructions == 1U ? " instruction, " : " instructions, ") != 0 ||
      decimal_field(&cursor, &mems) != 0 ||
      literal_field(&cursor, mems == 1U ? " mem, " : " mems, ") != 0 ||
      decimal_field(&cursor, &oops) != 0 ||
      literal_field(&cursor, oops == 1U ? " oop; " : " oops; ") != 0 ||
      decimal_field(&cursor, &good) != 0 ||
      literal_field(&cursor, good == 1U ? " good guess, " : " good guesses, ") != 0 ||
      decimal_field(&cursor, &bad) != 0 || strcmp(cursor, " bad") != 0) {
    return -1;
  }
  *reported = instructions;
  return 0;
}

static int halt_line(const char *line) {
  static const char prefix[] = "  (halted at location #";
  uint64_t unused;
  size_t prefix_length = sizeof(prefix) - 1U;
  return strncmp(line, prefix, prefix_length) == 0 && strlen(line + prefix_length) == 17U &&
         hex_exact(line + prefix_length, 16U, &unused) == 0 && line[prefix_length + 16U] == ')';
}

static int parse_profile_data(const unsigned char *data, size_t size, const AddressSet *listing,
                              AddressSet *aggregate) {
  size_t start = 0U;
  AddressSet current = {0};
  int header = 0;
  int statistics = 0;
  int halted = 0;
  uint64_t reported = 0U;
  uint64_t observed = 0U;
  int result = 0;
  while (start < size) {
    size_t end = start;
    char *line;
    uint64_t count;
    uint64_t address;
    uint64_t instruction;
    int parsed;
    size_t unused;
    while (end < size && data[end] != '\n') {
      ++end;
    }
    line = (char *)malloc(end - start + 1U);
    if (line == NULL) {
      result = g_internal("out of memory parsing profile");
      break;
    }
    memcpy(line, data + start, end - start);
    line[end - start] = '\0';
    if (strcmp(line, "Program profile:") == 0) {
      if (header) {
        free(line);
        result = g_error("duplicate Program profile header");
        break;
      }
      header = 1;
    } else if (header && !statistics &&
               (strstr(line, " instructions, ") != NULL ||
                strstr(line, " instruction, ") != NULL)) {
      if (current.count == 0U || statistics_line(line, &reported) != 0) {
        free(line);
        result = g_error("malformed or misplaced profile statistics");
        break;
      }
      statistics = 1;
    } else if (header && statistics && !halted && halt_line(line)) {
      halted = 1;
    } else if (header && !statistics) {
      parsed = profile_record(line, &count, &address, &instruction);
      if (parsed < 0) {
        result = g_error("malformed MMIX profile record: %s", line);
        free(line);
        break;
      }
      if (parsed > 0) {
        if (!set_find(listing, address, &unused)) {
          free(line);
          result = g_error("profile address %016llx is absent from listing",
                           (unsigned long long)address);
          break;
        }
        if (listing->words[unused] != UINT64_MAX && listing->words[unused] != instruction) {
          free(line);
          result = g_error("profile instruction differs from listing at %016llx",
                           (unsigned long long)address);
          break;
        }
        if (set_add(&current, address, count, 1) != 0) {
          free(line);
          result = 1;
          break;
        }
        if (UINT64_MAX - observed < count) {
          free(line);
          result = g_error("total profile instruction count overflow");
          break;
        }
        observed += count;
      } else {
        const char *cursor = line;
        while (*cursor == ' ' || *cursor == '\t') {
          ++cursor;
        }
        if (*cursor != '\0' && strcmp(cursor, "0.        ...") != 0) {
          result = g_error("unknown line in MMIX profile: %s", line);
          free(line);
          break;
        }
      }
    } else if (header) {
      const char *cursor = line;
      while (*cursor == ' ' || *cursor == '\t') {
        ++cursor;
      }
      if (*cursor != '\0') {
        result = g_error("unknown or out-of-order line in MMIX profile: %s", line);
        free(line);
        break;
      }
    }
    free(line);
    start = end < size ? end + 1U : end;
  }
  if (result == 0 && (!header || !statistics || !halted || current.count == 0U)) {
    result = g_error("incomplete MMIX profile (header, records, stats, halt required)");
  }
  if (result == 0 && reported != observed) {
    result = g_error("profile statistics report %llu instructions but records total %llu",
                     (unsigned long long)reported, (unsigned long long)observed);
  }
  if (result == 0) {
    size_t index;
    for (index = 0U; index < current.count; ++index) {
      if (set_add(aggregate, current.addresses[index], current.counts[index], 0) != 0) {
        result = 1;
        break;
      }
    }
  }
  set_free(&current);
  return result;
}

static int load_profile(const char *path, const AddressSet *listing, AddressSet *aggregate) {
  unsigned char *data = NULL;
  size_t size = 0U;
  int result = g_read(path, &data, &size);
  if (result == 0) {
    result = parse_profile_data(data, size, listing, aggregate);
  }
  free(data);
  return result;
}

static int threshold(unsigned *minimum) {
  GConfig config;
  const char *text;
  uint64_t value;
  int result = g_config_load("config/coverage.conf", &config);
  if (result != 0) {
    return result;
  }
  text = g_config_get(&config, "minimum");
  if (config.count != 1U || text == NULL || g_u64(text, 10U, &value) != 0 || value > 100U) {
    g_config_free(&config);
    return g_error("config/coverage.conf requires exactly minimum=0..100");
  }
  *minimum = (unsigned)value;
  g_config_free(&config);
  return 0;
}

static int coverage_report(const AddressSet *listing, const AddressSet *executed) {
  size_t index;
  size_t reached = 0U;
  unsigned minimum;
  double percentage;
  if (threshold(&minimum) != 0) {
    return 1;
  }
  for (index = 0U; index < listing->count; ++index) {
    size_t unused;
    if (set_find(executed, listing->addresses[index], &unused)) {
      ++reached;
    }
  }
  percentage = (100.0 * (double)reached) / (double)listing->count;
  printf("Instructions: %zu\nExecuted:     %zu\nMissed:       %zu\nCoverage:     %.2f%%\n",
         listing->count, reached, listing->count - reached, percentage);
  if (percentage + 0.000001 < (double)minimum) {
    return g_error("instruction coverage %.2f%% is below %u%%", percentage, minimum);
  }
  return 0;
}

int g_coverage(const char *listing_path, const char *profile_path) {
  AddressSet listing = {0};
  AddressSet profile = {0};
  int result = load_listing(listing_path, &listing);
  if (result == 0) {
    result = load_profile(profile_path, &listing, &profile);
  }
  if (result == 0) {
    result = coverage_report(&listing, &profile);
  }
  set_free(&listing);
  set_free(&profile);
  return result;
}

static int run_profile_test(const char *test_path, const AddressSet *listing, AddressSet *aggregate,
                            size_t sequence) {
  GConfig config;
  const char *program;
  const char *input;
  const char *expected_error;
  const char *exit_text;
  const char **arguments;
  size_t argument_count = 0U;
  size_t index;
  char output[128];
  char errors[128];
  int status;
  uint64_t expected_status;
  int result = g_config_load(test_path, &config);
  if (result != 0) {
    return result;
  }
  if (g_config_get(&config, "run") != NULL) {
    g_config_free(&config);
    return 0;
  }
  result = g_test(test_path);
  if (result != 0) {
    g_config_free(&config);
    return result;
  }
  program = g_config_get(&config, "program");
  input = g_config_get(&config, "stdin");
  expected_error = g_config_get(&config, "stderr");
  exit_text = g_config_get(&config, "exit");
  if (program == NULL || input == NULL || expected_error == NULL || exit_text == NULL ||
      g_u64(exit_text, 10U, &expected_status) != 0 || expected_status > 255U) {
    g_config_free(&config);
    return g_error("%s is not a complete CLI test", test_path);
  }
  for (;;) {
    char key[40];
    (void)snprintf(key, sizeof(key), "arg.%zu", argument_count + 1U);
    if (g_config_get(&config, key) == NULL) {
      break;
    }
    ++argument_count;
  }
  arguments = (const char **)calloc(argument_count + 4U, sizeof(*arguments));
  if (arguments == NULL) {
    g_config_free(&config);
    return g_internal("out of memory preparing coverage test");
  }
  arguments[0] = G_SIMULATOR;
  arguments[1] = "-P";
  arguments[2] = program;
  for (index = 0U; index < argument_count; ++index) {
    char key[40];
    (void)snprintf(key, sizeof(key), "arg.%zu", index + 1U);
    arguments[index + 3U] = g_config_get(&config, key);
  }
  if (snprintf(output, sizeof(output), "build/profiles/cli-%zu.profile", sequence) < 0 ||
      snprintf(errors, sizeof(errors), "build/profiles/cli-%zu.stderr", sequence) < 0) {
    free(arguments);
    g_config_free(&config);
    return g_internal("coverage output path formatting failed");
  }
  result = g_run(arguments, *input == '\0' ? "build/tmp/empty" : input, output, errors, &status,
                 PROFILE_TIMEOUT);
  free(arguments);
  if (result != 0) {
    g_config_free(&config);
    return result;
  }
  if (status != (int)expected_status ||
      (*expected_error == '\0' ? g_empty(errors) : g_equal(errors, expected_error)) != 0) {
    g_config_free(&config);
    return g_error("coverage execution failed for %s", test_path);
  }
  result = load_profile(output, listing, aggregate);
  g_config_free(&config);
  return result;
}

int g_coverage_all(void) {
  AddressSet listing = {0};
  AddressSet aggregate = {0};
  GPaths tests;
  size_t index;
  size_t ran = 0U;
  char listing_path[512];
  int written = snprintf(listing_path, sizeof(listing_path), "%s.mml", G_APP);
  int result;
  if (written < 0 || (size_t)written >= sizeof(listing_path)) {
    return g_internal("application listing path is too long");
  }
  result = load_listing(listing_path, &listing);
  if (result != 0) {
    return result;
  }
  result = g_list("tests/cli", &tests);
  if (result != 0) {
    set_free(&listing);
    return result;
  }
  for (index = 0U; index < tests.count; ++index) {
    if (!ends_with(tests.items[index], ".test")) {
      continue;
    }
    result = run_profile_test(tests.items[index], &listing, &aggregate, ran);
    if (result != 0) {
      break;
    }
    ++ran;
  }
  g_paths_free(&tests);
  if (result == 0 && ran == 0U) {
    result = g_error("coverage requires at least one CLI test");
  }
  if (result == 0) {
    result = coverage_report(&listing, &aggregate);
  }
  set_free(&listing);
  set_free(&aggregate);
  return result;
}

int g_profile_selftest(void) {
  static const char *const rejected[] = {"tools/guard/fixtures/profile-malformed.txt",
                                         "tools/guard/fixtures/profile-invalid-hex.txt",
                                         "tools/guard/fixtures/profile-overflow.txt",
                                         "tools/guard/fixtures/profile-duplicate.txt",
                                         "tools/guard/fixtures/profile-missing-header.txt",
                                         "tools/guard/fixtures/profile-missing-halt.txt",
                                         "tools/guard/fixtures/profile-truncated.txt",
                                         "tools/guard/fixtures/profile-truncated-1.txt",
                                         "tools/guard/fixtures/profile-truncated-2.txt",
                                         "tools/guard/fixtures/profile-truncated-3.txt",
                                         "tools/guard/fixtures/profile-truncated-4.txt",
                                         "tools/guard/fixtures/profile-truncated-5.txt",
                                         "tools/guard/fixtures/profile-truncated-6.txt",
                                         "tools/guard/fixtures/profile-truncated-7.txt",
                                         "tools/guard/fixtures/profile-stats-before-record.txt",
                                         "tools/guard/fixtures/profile-record-after-stats.txt",
                                         "tools/guard/fixtures/profile-malformed-halt.txt",
                                         "tools/guard/fixtures/profile-inconsistent.txt",
                                         "tools/guard/fixtures/profile-unknown.txt"};
  AddressSet listing = {0};
  AddressSet profile = {0};
  unsigned char *data = NULL;
  size_t size = 0U;
  size_t index;
  int result = g_read("tools/guard/fixtures/profile-listing.mml", &data, &size);
  if (result == 0) {
    result = parse_listing_data(data, size, &listing, 1);
  }
  free(data);
  if (result != 0) {
    set_free(&listing);
    return result;
  }
  {
    static const char *const bad_listings[] = {"tools/guard/fixtures/listing-truncated-1.mml",
                                               "tools/guard/fixtures/listing-truncated-2.mml",
                                               "tools/guard/fixtures/listing-truncated-3.mml",
                                               "tools/guard/fixtures/listing-truncated-4.mml",
                                               "tools/guard/fixtures/listing-truncated-5.mml",
                                               "tools/guard/fixtures/listing-truncated-6.mml",
                                               "tools/guard/fixtures/listing-truncated-7.mml"};
    for (index = 0U; index < sizeof(bad_listings) / sizeof(bad_listings[0]); ++index) {
      AddressSet bad_listing = {0};
      result = g_read(bad_listings[index], &data, &size);
      if (result == 0) {
        result = parse_listing_data(data, size, &bad_listing, 1);
      }
      free(data);
      data = NULL;
      set_free(&bad_listing);
      if (result == 0) {
        set_free(&listing);
        return g_error("self-test: truncated listing was accepted: %s", bad_listings[index]);
      }
    }
  }
  result = g_read("tools/guard/fixtures/object-valid.txt", &data, &size);
  if (result == 0) {
    result = parse_object_data(data, size);
  }
  free(data);
  data = NULL;
  if (result != 0) {
    set_free(&listing);
    return result;
  }
  {
    static const char *const bad_objects[] = {"tools/guard/fixtures/object-entry-wrong.txt",
                                              "tools/guard/fixtures/object-invalid-hex.txt",
                                              "tools/guard/fixtures/object-truncated.txt"};
    for (index = 0U; index < sizeof(bad_objects) / sizeof(bad_objects[0]); ++index) {
      result = g_read(bad_objects[index], &data, &size);
      if (result == 0) {
        result = parse_object_data(data, size);
      }
      free(data);
      data = NULL;
      if (result == 0) {
        set_free(&listing);
        return g_error("self-test: malformed object output was accepted: %s", bad_objects[index]);
      }
    }
  }
  result = load_profile("tools/guard/fixtures/profile-valid.txt", &listing, &profile);
  if (result != 0 || profile.count != 1U) {
    set_free(&listing);
    set_free(&profile);
    return g_error("self-test: valid profile was not parsed");
  }
  set_free(&profile);
  result = load_profile("tools/guard/fixtures/profile-large.txt", &listing, &profile);
  if (result != 0 || profile.count != 1U || profile.counts[0] != UINT64_MAX) {
    set_free(&listing);
    set_free(&profile);
    return g_error("self-test: large valid profile count was not preserved");
  }
  set_free(&profile);
  for (index = 0U; index < sizeof(rejected) / sizeof(rejected[0]); ++index) {
    result = load_profile(rejected[index], &listing, &profile);
    set_free(&profile);
    if (result == 0) {
      set_free(&listing);
      return g_error("self-test: malformed profile was accepted: %s", rejected[index]);
    }
  }
  set_free(&listing);
  return 0;
}
