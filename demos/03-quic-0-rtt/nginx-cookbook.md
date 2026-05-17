# Nginx: HTTP/3 (QUIC) и 0-RTT

**QUIC** переносит транспорт и шифрование так, что при возобновлении сессии клиент снова может отправить данные в первом полёте — это **0-RTT на уровне QUIC** (аналог early data, но не то же самое, что TLS 1.3 early data поверх TCP). Nginx с модулем HTTP/3 принимает такие соединения на отдельном `listen … quic`.

## 1) Требования

Нужна **сборка Nginx с HTTP/3**: обычно OpenSSL с QUIC или иной совместимый TLS-стек, в зависимости от пакета или инструкции поставщика. Проверьте, что в `nginx -V` и документации к вашей версии указан `http_v3`.

См. [ngx_http_v3_module](https://nginx.org/en/docs/http/ngx_http_v3_module.html).

## 2) Пример `server` с HTTP/2 и HTTP/3

Один и тот же порт **443**: классический TCP+TLS (HTTP/2) и QUIC.

```nginx
server {
    listen 443 quic reuseport;
    listen 443 ssl;
    listen [::]:443 quic reuseport;
    listen [::]:443 ssl;

    server_name example.com;

    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    http2 on;
    http3 on;

    add_header Alt-Svc 'h3=":443"; ma=86400' always;

    location / {
        root /var/www/html;
        # или proxy_pass ...
    }
}
```

- `listen … quic` — приём QUIC на UDP.
- `http3 on;` — включение HTTP/3 поверх QUIC.
- **`Alt-Svc`** подсказывает клиенту, что тот же хост доступен по **h3**, чтобы последующие запросы могли пойти по QUIC.

## 3) Связь с 0-RTT

Разрешение **0-RTT в QUIC** задаётся возможностями стека и политикой сервера/клиента; в конфигурации Nginx вы в первую очередь **включаете HTTP/3** и корректный listen. Повторное воспроизведение 0-RTT-данных возможно на уровне протокола — проектируйте API так же осторожно, как для [TLS early data](../02-tls-early-data/nginx-cookbook.md) (идемпотентность, безопасные методы).

## 4) Проверка и перезагрузка

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Примечания

- Для экспериментов «первый полёт vs 0-RTT» полезны захваты трафика и клиенты с явной поддержкой QUIC; поведение браузеров см. материалы в этой папке.
- Брандмауэр должен **пропускать UDP на порт**, где слушает QUIC (часто тот же 443).
