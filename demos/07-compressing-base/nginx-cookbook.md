# Nginx: сжатие ответов

## gzip (модуль по умолчанию во многих сборках)

```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
gzip_min_length 256;
```

## Brotli

Требуется модуль **ngx_brotli** (не во всех пакетах). Пример после подключения:

```nginx
# brotli on;
# brotli_types text/plain text/css application/json application/javascript text/xml application/xml;
```

## Zstandard (zstd) в Angie

В **vanilla Nginx** готового zstd часто нет; в **Angie** к нему относятся отдельные пакеты и два компонента: **http_zstd_filter** (сжатие на лету) и **http_zstd_static** (готовые `.zst` файлы рядом с оригиналом). Описание установки и поведения — в [документации Angie по модулю zstd](https://angie.software/angie/docs/installation/external-modules/zstd/).

Пакеты: `angie-module-zstd` (Angie) или `angie-pro-module-zstd` (Angie PRO).

Подключение `.so` в контексте **`main`**:

```nginx
load_module modules/ngx_http_zstd_filter_module.so;
load_module modules/ngx_http_zstd_static_module.so;
```

Пример `server` (по смыслу из той же документации):

```nginx
server {
    listen 80;

    zstd_types text/plain text/css;
    zstd_min_length 256;
    zstd_comp_level 3;

    location / {
        zstd on;
        root /usr/share/angie/html;
    }

    location /bk/ {
        zstd on;
        proxy_pass http://127.0.0.1:8081/;
    }

    location /static/ {
        zstd_static on;
        root /usr/share/angie;
    }
}
```

Клиент должен прислать `Accept-Encoding` с **`zstd`** (например `gzip, zstd`); при успехе в ответе будет `Content-Encoding: zstd`. При одновременном включении динамического и статического режима Angie сначала ищет предсжатый файл с суффиксом `.zst`, иначе сжимает на лету.

Исходники и подробности upstream-модуля: [tokers/zstd-nginx-module](https://github.com/tokers/zstd-nginx-module).

## Проверка

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Проверяйте заголовки `Content-Encoding` и размер тела ответа (`curl -v`, DevTools).
