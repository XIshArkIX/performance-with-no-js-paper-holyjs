### Команда:
```sh
nginx_pid=$(ps aux | grep nginx | grep worker | awk '{print $2}') ; strace -p $nginx_pid -tt -T -e all -o /tmp/strace-nginx-sync-file-read.txt
```


### Вывод:
```log
08:57:19.053206 epoll_wait(14, [{events=EPOLLIN, data=0x55c9cf49f6b8}], 512, -1) = 1 <2.971837>
08:57:22.025537 accept4(5, {sa_family=AF_INET, sin_port=htons(64213), sin_addr=inet_addr("192.168.1.197")}, [112 => 16], SOCK_NONBLOCK) = 12 <0.000173>
08:57:22.025912 epoll_ctl(14, EPOLL_CTL_ADD, 12, {events=EPOLLIN|EPOLLRDHUP|EPOLLET, data=0x55c9cf4a0ef0}) = 0 <0.000055>
08:57:22.026063 epoll_wait(14, [{events=EPOLLIN, data=0x55c9cf4a0ef0}], 512, 60000) = 1 <0.000042>
08:57:22.026182 recvfrom(12, "GET / HTTP/1.1\r\nHost: tst.playti"..., 1024, 0, NULL, NULL) = 86 <0.000039>
08:57:22.026631 newfstatat(AT_FDCWD, "/usr/share/nginx/html/index.html", {st_mode=S_IFREG|0644, st_size=615, ...}, 0) = 0 <0.000042>
08:57:22.026821 openat(AT_FDCWD, "/usr/share/nginx/html/index.html", O_RDONLY|O_NONBLOCK) = 17 <0.000035>
08:57:22.026941 fstat(17, {st_mode=S_IFREG|0644, st_size=615, ...}) = 0 <0.000025>
08:57:22.027056 pread64(17, "<!DOCTYPE html>\n<html>\n<head>\n<t"..., 615, 0) = 615 <0.000028>
08:57:22.027157 writev(12, [{iov_base="HTTP/1.1 200 OK\r\nServer: nginx/1"..., iov_len=238}, {iov_base="<!DOCTYPE html>\n<html>\n<head>\n<t"..., iov_len=615}], 2) = 853 <0.000114>
08:57:22.027448 write(3, "192.168.1.197 - - [21/Apr/2026:0"..., 90) = 90 <0.000074>
08:57:22.027614 close(17)               = 0 <0.000025>
08:57:22.027707 setsockopt(12, SOL_TCP, TCP_NODELAY, [1], 4) = 0 <0.000035>
08:57:22.027808 epoll_wait(14, [{events=EPOLLIN|EPOLLRDHUP, data=0x55c9cf4a0ef0}], 512, 75000) = 1 <0.004643>
08:57:22.032713 recvfrom(12, "", 1024, 0, NULL, NULL) = 0 <0.000092>
08:57:22.033009 close(12)               = 0 <0.000178>
08:57:22.033251 epoll_wait(14 <detached ...>
```

### Железо:
```
OS: Arch Linux x86_64
Kernel: Linux 6.19.8-zen1-1-zen
CPU: Intel(R) N150 (4) @ 3.60 GHz
GPU: Intel Graphics @ 1.00 GHz [Integrated]
Memory: 1.31 GiB / 31.08 GiB (4%)
Swap: 0 B / 8.00 GiB (0%)
Disk (/): 169.96 GiB / 944.87 GiB (18%) - btrfs
*-network:0
  product: 82599ES 10-Gigabit SFI/SFP+ Network Connection
  vendor: Intel Corporation
  logical name: enp1s0f0
  version: 01
  size: 10Gbit/s
  capacity: 10Gbit/s
  width: 64 bits
  clock: 33MHz
  capabilities: pm msi msix pciexpress vpd bus_master cap_list ethernet physical fibre 10000bt-fd
  configuration: autonegotiation=off broadcast=yes connector=optical pigtail driver=ixgbe driverversion=6.19.8-zen1-1-zen duplex=full firmware=0x800003de ip=192.168.1.110 latency=0 link=yes maxlength=1m module=SFP-10G-AOC1M multicast=yes port=fibre sp
eed=10Gbit/s wavelength=850nm
```

### Команда:
[httpress](https://github.com/GabrielTecuceanu/httpress)
```sh
httpress -c 100 -n 1000000 http://tst.playtime.home:8889
```

### Результаты:
```
Target: http://tst.playtime.home:8889 Get
Concurrency: 100
Stop condition: Requests(1000000)

Starting benchmark with 100 workers...

--- Benchmark Complete ---
Requests:     1000000 total, 1000000 success, 0 errors
Duration:     66.28s
Throughput:   15087.86 req/s
Transferred:  586.51 MB

Latency:
  Min:    2.59ms
  Max:    130.90ms
  Mean:   6.49ms
  p50:    6.21ms
  p90:    7.49ms
  p95:    8.04ms
  p99:    11.10ms

Status codes:
  200: 1000000
```