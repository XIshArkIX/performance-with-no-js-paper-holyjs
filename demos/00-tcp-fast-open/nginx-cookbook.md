# Nginx: включение TCP Fast Open (TFO)

Используйте эти директивы, чтобы включить TCP Fast Open для входящих соединений в Nginx.

## 1) Включить TFO в ОС (Linux)

```bash
sudo sysctl -w net.ipv4.tcp_fastopen=3
```

Сделать настройку постоянной:

```bash
echo "net.ipv4.tcp_fastopen=3" | sudo tee /etc/sysctl.d/99-tcp-fastopen.conf
sudo sysctl --system
```

Значение `3` включает поддержку и на стороне клиента, и на стороне сервера на уровне ядра.

## 2) Включить TFO в `listen` Nginx

В вашем блоке `server` добавьте параметр `fastopen=<queue_size>` к директиве `listen`.

```nginx
server {
    listen 443 ssl fastopen=256;
    listen [::]:443 ssl fastopen=256;

    server_name example.com;
    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    location / {
        proxy_pass http://app_backend;
    }
}
```

Также можно использовать для обычного HTTP:

```nginx
server {
    listen 80 fastopen=256;
    listen [::]:80 fastopen=256;
    server_name example.com;
}
```

## 3) Проверить конфигурацию и перезагрузить

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Примечания

- `fastopen=256` — длина очереди ожидающих TFO-соединений. Подбирайте под характер трафика.
- TFO в основном помогает повторным клиентам, у которых уже есть валидный TFO cookie.
- Некоторые middlebox’ы/фаерволы могут уменьшить эффект от TFO или полностью его нивелировать.
- Для TLS убедитесь, что TLS и стек приложения тюнятся отдельно (например, TLS 1.3, session resumption), ~~поскольку оптимизации TFO и TLS дополняют друг друга.~~
