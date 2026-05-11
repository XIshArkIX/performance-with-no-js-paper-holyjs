### Команда:
```sh
nginx_pid=$(ps aux | grep nginx | grep worker | awk '{print $2}') ; strace -p $nginx_pid -tt -T -e all -o /tmp/strace-nginx-sync-file-read-with-sendfile.txt
```

### Вывод:
```log
08:57:10.373499 epoll_wait(14, [{events=EPOLLIN, data=0x55c9cf49f5c0}], 512, -1) = 1 <3.606858>
08:57:13.980795 accept4(4, {sa_family=AF_INET, sin_port=htons(64211), sin_addr=inet_addr("192.168.1.197")}, [112 => 16], SOCK_NONBLOCK) = 12 <0.000168>
08:57:13.981256 epoll_ctl(14, EPOLL_CTL_ADD, 12, {events=EPOLLIN|EPOLLRDHUP|EPOLLET, data=0x55c9cf4a0ef1}) = 0 <0.000156>
08:57:13.981664 epoll_wait(14, [{events=EPOLLIN, data=0x55c9cf4a0ef1}], 512, 60000) = 1 <0.000135>
08:57:13.981970 recvfrom(12, "GET / HTTP/1.1\r\nHost: tst.playti"..., 1024, 0, NULL, NULL) = 86 <0.000038>
08:57:13.982378 newfstatat(AT_FDCWD, "/usr/share/nginx/html/index.html", {st_mode=S_IFREG|0644, st_size=615, ...}, 0) = 0 <0.000039>
08:57:13.982546 openat(AT_FDCWD, "/usr/share/nginx/html/index.html", O_RDONLY|O_NONBLOCK) = 17 <0.000038>
08:57:13.982664 fstat(17, {st_mode=S_IFREG|0644, st_size=615, ...}) = 0 <0.000027>
08:57:13.982788 writev(12, [{iov_base="HTTP/1.1 200 OK\r\nServer: nginx/1"..., iov_len=238}], 1) = 238 <0.000103>
08:57:13.982979 sendfile(12, 17, [0] => [615], 615) = 615 <0.000059>
08:57:13.983128 write(3, "192.168.1.197 - - [21/Apr/2026:0"..., 90) = 90 <0.000068>
08:57:13.983281 close(17)               = 0 <0.000030>
08:57:13.983373 setsockopt(12, SOL_TCP, TCP_NODELAY, [1], 4) = 0 <0.000060>
08:57:13.983506 epoll_wait(14, [{events=EPOLLIN|EPOLLRDHUP, data=0x55c9cf4a0ef1}], 512, 75000) = 1 <0.003879>
08:57:13.987477 recvfrom(12, "", 1024, 0, NULL, NULL) = 0 <0.000125>
08:57:13.987802 close(12)               = 0 <0.000145>
08:57:13.988040 epoll_wait(14 <detached ...>
```

### Дока:
[sendfile](https://nginx.org/en/docs/http/ngx_http_core_module.html#sendfile)

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
httpress -c 100 -n 1000000 http://tst.playtime.home:8888
```

### Результаты:
```
Target: http://tst.playtime.home:8888 Get
Concurrency: 100
Stop condition: Requests(1000000)

Starting benchmark with 100 workers...

--- Benchmark Complete ---
Requests:     1000000 total, 1000000 success, 0 errors
Duration:     60.12s
Throughput:   16633.26 req/s
Transferred:  586.51 MB

Latency:
  Min:    1.90ms
  Max:    120.82ms
  Mean:   5.87ms
  p50:    5.70ms
  p90:    6.97ms
  p95:    7.49ms
  p99:    9.59ms

Status codes:
  200: 1000000
```