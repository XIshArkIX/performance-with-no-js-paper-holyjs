#pragma once

#include <sys/types.h>

#include <chrono>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

/// A lightweight library for tracing file-related syscalls (open/openat, read)
/// of a child process using ptrace on Linux x86_64.
class SyscallTracer {
 public:
  /// Describes a captured openat() syscall (includes legacy open() via openat).
  struct OpenEvent {
    pid_t pid;             ///< Tracee PID
    int dirfd;             ///< Directory file descriptor (AT_FDCWD for open())
    std::string pathname;  ///< File path argument
    int flags;             ///< Open flags (O_RDONLY, etc.)
    int result;            ///< Return value: fd on success, -errno on failure
    int64_t
        delta_us;  ///< Microseconds elapsed since the previous traced syscall
  };

  /// Describes a captured read() syscall.
  struct ReadEvent {
    pid_t pid;       ///< Tracee PID
    int fd;          ///< File descriptor being read
    size_t count;    ///< Requested byte count
    ssize_t result;  ///< Return value: bytes read, 0 (EOF), or -errno
    int64_t
        delta_us;  ///< Microseconds elapsed since the previous traced syscall
  };

  using OpenCallback = std::function<void(const OpenEvent&)>;
  using ReadCallback = std::function<void(const ReadEvent&)>;

  SyscallTracer();
  ~SyscallTracer() = default;

  /// Register a callback invoked after every openat/open syscall completes.
  void on_open(OpenCallback cb);

  /// Register a callback invoked after every read syscall completes.
  void on_read(ReadCallback cb);

  /// Fork, exec the given program under ptrace, and trace until it exits.
  /// @return The exit status of the traced process, or -1 on error.
  int trace(const std::string& program,
            const std::vector<std::string>& args = {});

 private:
  /// Read a NUL-terminated string from the tracee's address space.
  std::string read_string(pid_t pid, unsigned long addr, size_t max_len = 4096);

  using Clock = std::chrono::steady_clock;
  using TimePoint = Clock::time_point;

  OpenCallback open_cb_;
  ReadCallback read_cb_;
};
