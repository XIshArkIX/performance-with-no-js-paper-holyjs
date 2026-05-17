# Nginx: TLS 1.3 и early data (0-RTT на уровне TLS)

В **TLS 1.3** после возобновления сессии клиент может отправить прикладные данные в том же раунде, что и часть рукопожатия — это **early data** (в просторечии 0-RTT для TLS). Nginx у терминатора TLS может принимать такие байты и передавать их дальше (например, в бэкенд), если явно включить поддержку.

## 1) Минимальная конфигурация на терминаторе

Нужен **TLS 1.3** (`ssl_early_data` работает только с ним).

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_early_data on;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Early-Data $ssl_early_data;
        proxy_http_version 1.1;
    }
}
```

Директива [`ssl_early_data`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_early_data) разрешает обработку ранних данных на этом `server`. Переменная `$ssl_early_data` помечает запросы, пришедшие в ранних данных (до завершения полного рукопожатия с точки зрения приложения).

## 2) Проксирование и приложение

Если за Nginx — своё приложение, ему нужно **знать**, что запрос мог быть доставлен в зоне повторного воспроизведения (см. ниже). Заголовок `Early-Data: 1` — распространённый способ передать это дальше (пример выше).

## 3) Безопасность: повторное воспроизведение (replay)

Early data **может быть повторно отправлена** злоумышленником, пока билет/сессия валидны. Поэтому для таких запросов обычно:

- не выполняют **неидемпотентные** операции (`POST`, платежи, смена состояния) без дополнительной защиты;
- или принимают early data только для **GET/HEAD** на «безопасных» URL;
- или откладывают обработку до полного завершения рукопожатия.

Официальное описание механизма и оговорки — в документации Nginx по [`ssl_early_data`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_early_data).

## 4) Проверка и перезагрузка

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Примечания

- Early data в TLS 1.3 и **0-RTT в QUIC** — разные уровни стека; для HTTP/3 см. [`../03-quic-0-rtt/nginx-cookbook.md`](../03-quic-0-rtt/nginx-cookbook.md).
- Отключение early data: `ssl_early_data off;` (или не включать директиву, если по умолчанию выключено в вашей сборке).
