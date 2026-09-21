/* Local report assertions. No external parsers or runtime libraries. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void fail(const char *message) {
    fprintf(stderr, "assert: %s\n", message);
    exit(EXIT_FAILURE);
}

static FILE *open_file(const char *path) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) fail(path);
    return file;
}

static FILE *open_text(const char *path) {
    FILE *file = fopen(path, "r");
    if (file == NULL) fail(path);
    return file;
}

static void close_file(FILE *file) {
    if (ferror(file)) fail("read failed");
    if (fclose(file) != 0) fail("close failed");
}

static void empty(const char *path) {
    FILE *file = open_file(path);
    if (fgetc(file) != EOF) fail("expected an empty diagnostic stream");
    close_file(file);
}

static void equal(const char *left, const char *right) {
    FILE *a = open_text(left);
    FILE *b = open_text(right);
    int ca;
    int cb;
    do {
        ca = fgetc(a);
        cb = fgetc(b);
        if (ca != cb) fail("output differs from expected bytes");
    } while (ca != EOF);
    close_file(a);
    close_file(b);
}

static int suffix(const char *path, const char *extension) {
    size_t a = strlen(path);
    size_t b = strlen(extension);
    return a >= b && strcmp(path + a - b, extension) == 0;
}

static void artifacts(const char *path, int tracked) {
    FILE *file = open_file(path);
    char name[4096];
    size_t used = 0;
    int ch;
    while ((ch = fgetc(file)) != EOF) {
        if (ch != 0) {
            if (used + 1 >= sizeof name) fail("artifact path too long");
            name[used++] = (char)ch;
            continue;
        }
        name[used] = '\0';
        if (strncmp(name, "build/", 6) == 0) {
            if (tracked) fail("build outputs must not be tracked");
        } else if (suffix(name, ".mms") && strcmp(name, "src/main.mms") != 0) {
            fail("source module outside the single executable contract");
        } else if (suffix(name, ".mmo") || suffix(name, ".mml") || suffix(name, ".mmb") ||
                   suffix(name, ".o") || suffix(name, ".obj") ||
                   suffix(name, ".exe") || suffix(name, ".dll") ||
                   suffix(name, ".so") || suffix(name, ".dylib") ||
                   suffix(name, ".a") || suffix(name, ".lib")) {
            fprintf(stderr, "unexpected binary artifact: %s\n", name);
            fail("keep generated artifacts in ignored build/");
        } else {
            unsigned char magic[4];
            FILE *candidate = open_file(name);
            size_t count = fread(magic, 1, sizeof magic, candidate);
            close_file(candidate);
            if (count == sizeof magic &&
                ((magic[0] == 0x7f && magic[1] == 'E' && magic[2] == 'L' && magic[3] == 'F') ||
                 (magic[0] == 'M' && magic[1] == 'Z') ||
                 (magic[0] == 0xcf && magic[1] == 0xfa && magic[2] == 0xed && magic[3] == 0xfe) ||
                 (magic[0] == 0x98 && magic[1] == 9))) {
                fail("binary content outside build/");
            }
        }
        used = 0;
    }
    if (used != 0) fail("unterminated git path record");
    close_file(file);
}

/* Report parsers are defined below. */
typedef struct {
    unsigned long long address;
    unsigned int word;
    int listed;
    int hit;
} Instruction;

static Instruction instructions[4096];
static size_t instruction_count;

static void object(const char *path) {
    FILE *file = open_text(path);
    char line[1024];
    int main_found = 0;
    int entry_found = 0;
    while (fgets(line, sizeof line, file) != NULL) {
        unsigned long long address;
        unsigned int word;
        if (strstr(line, "Main = #0100 (") != NULL) main_found++;
        if (strcmp(line, "g255: 0000000000000100\n") == 0) entry_found++;
        if (sscanf(line, "%16llx: %8x", &address, &word) == 2) {
            if (address >= 0x2000000000000000ULL && address < 0x4000000000000000ULL) continue;
            if (address != 0x100ULL + 4 * instruction_count) fail("noncontiguous code or forbidden object segment");
            if (instruction_count == sizeof instructions / sizeof instructions[0]) fail("too many instructions");
            instructions[instruction_count].address = address;
            instructions[instruction_count].word = word;
            instruction_count++;
        }
    }
    close_file(file);
    if (main_found != 1 || entry_found != 1 || instruction_count == 0) fail("missing Main, entry register, or code in object");
}

static void listing(const char *path) {
    FILE *file = open_text(path);
    char line[1024];
    unsigned long long base = 0;
    while (fgets(line, sizeof line, file) != NULL) {
        unsigned long long address;
        unsigned int word;
        unsigned int offset;
        int emitted = 0;
        if (strstr(line, "error:") != NULL || strstr(line, "warning:") != NULL) fail("assembler diagnostic in listing");
        if (line[0] != ' ' && sscanf(line, "%16llx:", &address) == 1) {
            base = address & ~0xfffULL;
            emitted = sscanf(line, "%16llx: %8x", &address, &word) == 2;
        } else if (sscanf(line, " ...%3x: %8x", &offset, &word) == 2) {
            address = base + offset;
            emitted = 1;
        }
        if (emitted && address < 0x2000000000000000ULL) {
            size_t index;
            if (address < 0x100 || (address - 0x100) % 4 != 0) fail("invalid listing code address");
            index = (size_t)((address - 0x100) / 4);
            if (index >= instruction_count || instructions[index].word != word || instructions[index].listed) fail("listing and object differ");
            instructions[index].listed = 1;
        }
    }
    close_file(file);
    for (size_t i = 0; i < instruction_count; i++) {
        if (!instructions[i].listed) fail("instruction missing from listing");
    }
}

static void coverage(const char *path) {
    FILE *file = open_text(path);
    char line[1024];
    int header = 0;
    size_t covered = 0;
    while (fgets(line, sizeof line, file) != NULL) {
        unsigned long long count;
        unsigned long long address;
        unsigned int word;
        if (strcmp(line, "Program profile:\n") == 0) header++;
        if (header && sscanf(line, " %llu. %16llx: %8x", &count, &address, &word) == 3) {
            size_t index;
            if (address < 0x100 || (address - 0x100) % 4 != 0) fail("invalid profile address");
            index = (size_t)((address - 0x100) / 4);
            if (index >= instruction_count || instructions[index].word != word || instructions[index].hit) fail("profile and object differ");
            if (count > 0) {
                instructions[index].hit = 1;
                covered++;
            }
        }
    }
    close_file(file);
    if (header != 1 || covered != instruction_count) fail("instruction coverage below required 100%");
    printf("Instruction coverage: %zu/%zu (100%%)\n", covered, instruction_count);
}

static void contains(const char *path, const char *needle) {
    FILE *file = open_file(path);
    char line[1024];
    int found = 0;
    while (fgets(line, sizeof line, file) != NULL) {
        if (strstr(line, needle) != NULL) found = 1;
    }
    close_file(file);
    if (!found) fail("expected state assertion missing");
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "empty") == 0) empty(argv[2]);
    else if (argc == 4 && strcmp(argv[1], "equal") == 0) equal(argv[2], argv[3]);
    else if (argc == 3 && strcmp(argv[1], "artifacts") == 0) artifacts(argv[2], 0);
    else if (argc == 3 && strcmp(argv[1], "tracked") == 0) artifacts(argv[2], 1);
    else if (argc == 3 && strcmp(argv[1], "object") == 0) object(argv[2]);
    else if (argc == 5 && strcmp(argv[1], "coverage") == 0) {
        object(argv[2]);
        listing(argv[3]);
        coverage(argv[4]);
    } else if (argc == 4 && strcmp(argv[1], "contains") == 0) contains(argv[2], argv[3]);
    else fail("invalid assertion arguments");
    return EXIT_SUCCESS;
}
