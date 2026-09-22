/* Host-only adapter. The MMIX program and upstream simulator are unchanged. */
#define main mmixware_main
#include "../../vendor/mmixware/mmix-sim.c"
#undef main
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif
int main(int argc, char **argv) {
#ifdef _WIN32
    if (_setmode(_fileno(stdin), _O_BINARY) == -1 || _setmode(_fileno(stdout), _O_BINARY) == -1 ||
        _setmode(_fileno(stderr), _O_BINARY) == -1) {
        fprintf(stderr, "cannot establish binary MMIX streams\n");
        return 2;
    }
#endif
    return mmixware_main(argc, argv);
}
