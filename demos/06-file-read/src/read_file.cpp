/// A trivial program that opens and reads a file.
/// Used as the tracee target for the SyscallTracer demo.

#include <cstdio>
#include <cstdlib>

int main(int argc, char* argv[]) {
  const char* path = (argc > 1) ? argv[1] : "/etc/hostname";

  FILE* f = fopen(path, "r");
  if (!f) {
    perror("fopen");
    return 1;
  }

  char buf[4096];
  while (fgets(buf, sizeof(buf), f)) {
    fputs(buf, stdout);
  }

  fclose(f);
  return 0;
}
