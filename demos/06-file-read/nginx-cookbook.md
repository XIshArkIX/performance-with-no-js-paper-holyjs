# Nginx: эффективная отдача файлов

Ниже — один связный фрагмент: контекст **`main`** (процесс и пул потоков для `aio`), блок **`http`** (общие умолчанья), затем **`server`** и два **`location`**. Директивы `sendfile`, `aio`, `directio` относятся к HTTP и **не** бывают «просто рядом с `worker_processes` без обёртки `http`».

## Пример

```nginx
worker_processes auto;

# main: пул для aio threads (Linux, сборка с --with-threads)
thread_pool default threads=32 max_queue=65536;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    # Уровень http: общие умолчанья для всех server {}
    sendfile        on;
    tcp_nopush      on;
    aio             threads;

    server {
        listen       80;
        server_name  example.com;
        root         /var/www/html;

        # Обычные запросы — как в http {} (наследуют sendfile/nopush/aio)

        location / {
            try_files $uri $uri/ =404;
        }

        # Крупные файлы: directio с порогом лучше ограничить отдельным location
        location /large/ {
            alias /var/www/large/;
            directio           4m;
            directio_alignment 4k;
        }
    }
}
```

- **[sendfile](https://nginx.org/en/docs/http/ngx_http_core_module.html#sendfile)** — отдача из кэша страниц без лишнего копирования в пользовательский буфер.
- **[tcp_nopush](https://nginx.org/en/docs/http/ngx_http_core_module.html#tcp_nopush)** — аккуратнее склеивает заголовки и первый кусок тела при `sendfile`.
- **[aio](https://nginx.org/en/docs/http/ngx_http_core_module.html#aio)** — асинхронное чтение при нагрузке; `threads` — пул потоков для чтения.
- **[directio](https://nginx.org/en/docs/http/ngx_http_core_module.html#directio)** — для файлов **больше порога** обход страничного кэша; на мелких объектах часто **вреден** рядом с `sendfile`, поэтому выносите в свой `location`.

При необходимости переопределите `sendfile off` или `aio off` точечно внутри `location` (например, для маленьких ответов из `memcached`).

Для **`aio threads`** на Linux нужны сборка с **`--with-threads`** и пул в **`main`** (как выше); иначе используйте `aio off` и полагайтесь на `sendfile`.

## Проверка

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Для сравнения путей чтения удобен `strace` к worker-процессу (см. материалы в `assets/`).
