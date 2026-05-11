#include "syscall_tracer.h"

#include <sys/ptrace.h>
#include <sys/reg.h>      // ORIG_RAX, RAX, RDI, RSI, RDX, R10
#include <sys/syscall.h>  // SYS_openat, SYS_read
#include <sys/user.h>     // struct user_regs_struct
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

SyscallTracer::SyscallTracer() : open_cb_{nullptr}, read_cb_{nullptr} {}

void SyscallTracer::on_open(OpenCallback cb) { open_cb_ = std::move(cb); }
void SyscallTracer::on_read(ReadCallback cb) { read_cb_ = std::move(cb); }

// ---------------------------------------------------------------------------
// Helper: read a NUL-terminated C string from the tracee
// ---------------------------------------------------------------------------

std::string SyscallTracer::read_string(pid_t pid, unsigned long addr,
                                       size_t max_len) {
  std::string result;
  result.reserve(256);

  for (size_t i = 0; i < max_len; i += sizeof(long)) {
    errno = 0;
    long word = ptrace(PTRACE_PEEKDATA, pid, addr + i, nullptr);
    if (errno != 0) break;

    const char* p = reinterpret_cast<const char*>(&word);
    for (size_t j = 0; j < sizeof(long); ++j) {
      if (p[j] == '\0') return result;
      result.push_back(p[j]);
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Main tracing loop
// ---------------------------------------------------------------------------

int SyscallTracer::trace(const std::string& program,
                         const std::vector<std::string>& args) {
  pid_t child = fork();

  if (child < 0) {
    perror("fork");
    return -1;
  }

  // --- Child: request tracing, then exec ---
  if (child == 0) {
    if (ptrace(PTRACE_TRACEME, 0, nullptr, nullptr) < 0) {
      perror("ptrace(TRACEME)");
      _exit(127);
    }
    // Stop ourselves so the parent can set options before we exec.
    raise(SIGSTOP);

    // Build argv array.
    std::vector<const char*> argv;
    argv.push_back(program.c_str());
    for (const auto& a : args) argv.push_back(a.c_str());
    argv.push_back(nullptr);

    execvp(program.c_str(), const_cast<char* const*>(argv.data()));
    perror("execvp");
    _exit(127);
  }

  // --- Parent: wait for initial stop, then trace syscalls ---
  int status = 0;

  // Wait for the child's initial SIGSTOP.
  waitpid(child, &status, 0);
  if (!WIFSTOPPED(status)) {
    fprintf(stderr, "child did not stop as expected\n");
    return -1;
  }

  // Set PTRACE_O_TRACESYSGOOD so we can distinguish syscall-stops from
  // signal-delivery-stops (bit 7 of the signal number is set).
  ptrace(PTRACE_SETOPTIONS, child, nullptr, PTRACE_O_TRACESYSGOOD);

  // Let the child continue until the next syscall.
  ptrace(PTRACE_SYSCALL, child, nullptr, nullptr);

  // Tracks whether we are at syscall-enter (true) or syscall-exit (false).
  bool entering = true;

  // Stash entry-time register snapshots for matched syscalls.
  struct user_regs_struct entry_regs{};
  long tracked_syscall = -1;

  // Timing: record when each traced syscall completes.
  auto prev_time = Clock::now();

  while (true) {
    waitpid(child, &status, 0);

    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return -1;

    // Check for syscall-stop (signal == SIGTRAP | 0x80).
    if (WIFSTOPPED(status) && WSTOPSIG(status) == (SIGTRAP | 0x80)) {
      struct user_regs_struct regs{};
      ptrace(PTRACE_GETREGS, child, nullptr, &regs);

      if (entering) {
        // --- Syscall entry ---
        long scnum = regs.orig_rax;

        if (scnum == SYS_openat || scnum == SYS_read) {
          tracked_syscall = scnum;
          entry_regs = regs;
        } else {
          tracked_syscall = -1;
        }
      } else {
        // --- Syscall exit ---
        if (tracked_syscall == SYS_openat && open_cb_) {
          auto now = Clock::now();
          OpenEvent ev;
          ev.pid = child;
          ev.dirfd = static_cast<int>(entry_regs.rdi);
          ev.pathname = read_string(child, entry_regs.rsi);
          ev.flags = static_cast<int>(entry_regs.rdx);
          ev.result = static_cast<int>(regs.rax);
          ev.delta_us = std::chrono::duration_cast<std::chrono::microseconds>(
                            now - prev_time)
                            .count();
          prev_time = now;
          open_cb_(ev);
        } else if (tracked_syscall == SYS_read && read_cb_) {
          auto now = Clock::now();
          ReadEvent ev;
          ev.pid = child;
          ev.fd = static_cast<int>(entry_regs.rdi);
          ev.count = static_cast<size_t>(entry_regs.rdx);
          ev.result = static_cast<ssize_t>(regs.rax);
          ev.delta_us = std::chrono::duration_cast<std::chrono::microseconds>(
                            now - prev_time)
                            .count();
          prev_time = now;
          read_cb_(ev);
        }
        tracked_syscall = -1;
      }

      entering = !entering;
    }

    // Resume until the next syscall (forward any real signals).
    int sig = 0;
    if (WIFSTOPPED(status)) {
      int s = WSTOPSIG(status);
      if (s != SIGTRAP && s != (SIGTRAP | 0x80)) sig = s;
    }
    ptrace(PTRACE_SYSCALL, child, nullptr, sig);
  }
}
