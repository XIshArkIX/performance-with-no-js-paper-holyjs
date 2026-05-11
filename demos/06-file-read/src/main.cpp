/// Demo driver: uses SyscallTracer to trace openat/read syscalls
/// made by the companion read_file program (or any other command).
///
/// Usage:
///     ./trace_demo                     # traces ./read_file /etc/hostname
///     ./trace_demo <program> [args...] # traces an arbitrary command

#include <fcntl.h>  // O_RDONLY, etc.

#include <cinttypes>
#include <cstdio>
#include <string>
#include <vector>

#include "syscall_tracer.h"

/// Decode common open(2) flags to a readable string.
static std::string flags_str(int flags) {
  std::string s;
  int access = flags & O_ACCMODE;
  if (access == O_RDONLY)
    s += "O_RDONLY";
  else if (access == O_WRONLY)
    s += "O_WRONLY";
  else if (access == O_RDWR)
    s += "O_RDWR";

  if (flags & O_CREAT) s += "|O_CREAT";
  if (flags & O_TRUNC) s += "|O_TRUNC";
  if (flags & O_APPEND) s += "|O_APPEND";
  if (flags & O_CLOEXEC) s += "|O_CLOEXEC";
  return s.empty() ? "0" : s;
}

int main(int argc, char* argv[]) {
  SyscallTracer tracer;
  int seq = 0;  // shared sequence counter across callbacks

  // --- Print every openat() ---
  tracer.on_open([&seq](const SyscallTracer::OpenEvent& ev) {
    ++seq;
    fprintf(stderr, "%d. openat(dirfd=%d, \"%s\", %s) = %d ~ %" PRId64 "us\n",
            seq, ev.dirfd, ev.pathname.c_str(), flags_str(ev.flags).c_str(),
            ev.result, ev.delta_us);
  });

  // --- Print every read() ---
  tracer.on_read([&seq](const SyscallTracer::ReadEvent& ev) {
    ++seq;
    fprintf(stderr, "%d. read(fd=%d, count=%zu) = %zd ~ %" PRId64 "us\n", seq,
            ev.fd, ev.count, ev.result, ev.delta_us);
  });

  std::string program;
  std::vector<std::string> args;

  if (argc > 1) {
    // Trace whatever command the user specified.
    program = argv[1];
    for (int i = 2; i < argc; ++i) args.emplace_back(argv[i]);
  } else {
    // Default: trace the companion read_file binary.
    program = "./read_file";
    args.push_back("/etc/hostname");
  }

  fprintf(stderr, "[trace] Tracing: %s", program.c_str());
  for (const auto& a : args) fprintf(stderr, " %s", a.c_str());
  fprintf(stderr, "\n");

  int rc = tracer.trace(program, args);

  fprintf(stderr, "[trace] Process exited with status %d\n", rc);
  return rc;
}
