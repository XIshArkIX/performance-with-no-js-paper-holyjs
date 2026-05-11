### Команда:
```sh
strace -o strace-cat-minimal-example.log -tt -T -e all cat /home/roman/Documents/perf-paper-holyjs/public/index.html
```

### Вывод:
```log
08:55:13.082963 execve("/usr/bin/cat", ["cat", "/home/roman/Documents/perf-paper"...], 0x7ffd182a1868 /* 32 vars */) = 0 <0.000362>
08:55:13.083635 brk(NULL)               = 0x5602c1f2c000 <0.000019>
08:55:13.083795 access("/etc/ld.so.preload", R_OK) = -1 ENOENT (No such file or directory) <0.000018>
08:55:13.083975 openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3 <0.000021>
08:55:13.084075 fstat(3, {st_mode=S_IFREG|0644, st_size=49323, ...}) = 0 <0.000014>
08:55:13.084162 mmap(NULL, 49323, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f8bde56a000 <0.000024>
08:55:13.084234 close(3)                = 0 <0.000013>
08:55:13.084298 openat(AT_FDCWD, "/usr/lib/libc.so.6", O_RDONLY|O_CLOEXEC) = 3 <0.000022>
08:55:13.084367 read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\0y\2\0\0\0\0\0"..., 832) = 832 <0.000015>
08:55:13.084429 pread64(3, "\6\0\0\0\4\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0"..., 840, 64) = 840 <0.000015>
08:55:13.084491 fstat(3, {st_mode=S_IFREG|0755, st_size=2010168, ...}) = 0 <0.000013>
08:55:13.084554 mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f8bde568000 <0.000018>
08:55:13.084624 pread64(3, "\6\0\0\0\4\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0\0"..., 840, 64) = 840 <0.000014>
08:55:13.084683 mmap(NULL, 2034544, PROT_READ, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7f8bde377000 <0.000017>
08:55:13.084743 mmap(0x7f8bde39b000, 1511424, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x24000) = 0x7f8bde39b000 <0.000026>
08:55:13.084814 mmap(0x7f8bde50c000, 319488, PROT_READ, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x195000) = 0x7f8bde50c000 <0.000019>
08:55:13.084872 mmap(0x7f8bde55a000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x1e2000) = 0x7f8bde55a000 <0.000019>
08:55:13.084937 mmap(0x7f8bde560000, 31600, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7f8bde560000 <0.000018>
08:55:13.085016 close(3)                = 0 <0.000012>
08:55:13.085079 mmap(NULL, 12288, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f8bde374000 <0.000016>
08:55:13.085160 arch_prctl(ARCH_SET_FS, 0x7f8bde374740) = 0 <0.000013>
08:55:13.085213 set_tid_address(0x7f8bde374d68) = 1969991 <0.000013>
08:55:13.085264 set_robust_list(0x7f8bde374a20, 24) = 0 <0.000011>
08:55:13.085312 rseq(0x7f8bde3746a0, 0x20, 0, 0x53053053) = 0 <0.000012>
08:55:13.085442 mprotect(0x7f8bde55a000, 16384, PROT_READ) = 0 <0.000026>
08:55:13.085531 mprotect(0x5602a838a000, 4096, PROT_READ) = 0 <0.000017>
08:55:13.085591 mprotect(0x7f8bde5b5000, 8192, PROT_READ) = 0 <0.000017>
08:55:13.085667 prlimit64(0, RLIMIT_STACK, NULL, {rlim_cur=8192*1024, rlim_max=RLIM64_INFINITY}) = 0 <0.000014>
08:55:13.085751 getrandom("\xe0\x5a\x03\xc3\x21\x46\xa1\xef", 8, GRND_NONBLOCK) = 8 <0.000014>
08:55:13.085812 munmap(0x7f8bde56a000, 49323) = 0 <0.000029>
08:55:13.085902 brk(NULL)               = 0x5602c1f2c000 <0.000012>
08:55:13.085952 brk(0x5602c1f4d000)     = 0x5602c1f4d000 <0.000015>
08:55:13.086014 openat(AT_FDCWD, "/usr/lib/locale/locale-archive", O_RDONLY|O_CLOEXEC) = 3 <0.000020>
08:55:13.086083 fstat(3, {st_mode=S_IFREG|0644, st_size=3069040, ...}) = 0 <0.000012>
08:55:13.086152 mmap(NULL, 3069040, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f8bde000000 <0.000018>
08:55:13.086217 close(3)                = 0 <0.000012>
08:55:13.086307 fstat(1, {st_mode=S_IFCHR|0600, st_rdev=makedev(0x88, 0x1), ...}) = 0 <0.000013>
08:55:13.086368 openat(AT_FDCWD, "/home/roman/Documents/perf-paper-holyjs/public/index.html", O_RDONLY) = 3 <0.000019>
08:55:13.086431 fstat(3, {st_mode=S_IFREG|0644, st_size=32768, ...}) = 0 <0.000012>
08:55:13.086486 fadvise64(3, 0, 0, POSIX_FADV_SEQUENTIAL) = 0 <0.000012>
08:55:13.086539 mmap(NULL, 270336, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f8bde332000 <0.000017>
08:55:13.086603 read(3, "<!DOCTYPE html>\n<html lang=\"en\">"..., 262144) = 32768 <0.000049>
08:55:13.086696 write(1, "<!DOCTYPE html>\n<html lang=\"en\">"..., 32768) = 32768 <0.000927>
08:55:13.087752 read(3, "", 262144)     = 0 <0.000028>
08:55:13.087865 munmap(0x7f8bde332000, 270336) = 0 <0.000094>
08:55:13.088085 close(3)                = 0 <0.000045>
08:55:13.088200 close(1)                = 0 <0.000016>
08:55:13.088264 close(2)                = 0 <0.000014>
08:55:13.088376 exit_group(0)           = ?
08:55:13.088608 +++ exited with 0 +++
```