# Nginx: OCSP stapling

Сервер может **прикреплять** свежий ответ OCSP к TLS-рукопожатию, чтобы клиенту не пришлось отдельно ходить к OCSP-responder УЦ.

## Конфигурация

```nginx
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/nginx/ssl/chain.pem;
```

- `ssl_trusted_certificate` — полная цепь (включая промежуточные), нужная для **проверки** подписи OCSP-ответа.
- Путь к файлу сертификата сервера задаётся как обычно (`ssl_certificate`).

См. [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_stapling).

## Проверка

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Для отладки можно использовать `openssl s_client -connect host:443 -status` и смотреть наличие `OCSP response` в выводе.
