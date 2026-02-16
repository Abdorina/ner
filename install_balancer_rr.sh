#!/usr/bin/env bash
set -euo pipefail

# ====== НАСТРОЙКИ ======
# Список NER-нод через пробел (round-robin по умолчанию)
NER_UPSTREAMS="${NER_UPSTREAMS:-127.0.0.1:8000}"

# Порт балансировщика
LB_PORT="${LB_PORT:-8080}"

# Имя nginx site
SITE_NAME="${SITE_NAME:-ner_balancer_rr}"

echo "=== NER Nginx Balancer (round-robin) ==="
echo "Upstreams: ${NER_UPSTREAMS}"
echo "Listen:    ${LB_PORT}"
echo "Site:      ${SITE_NAME}"
echo

# 1) Установка nginx
sudo apt-get update
sudo apt-get install -y nginx curl ca-certificates

# 2) Проверим, не занят ли порт (мягко)
if sudo ss -lntp | awk '{print $4}' | grep -qE "(^|:)${LB_PORT}\$"; then
  echo "❌ Port ${LB_PORT} is already in use."
  echo "   Try: LB_PORT=8081 bash $0"
  exit 1
fi

# 3) Сгенерируем upstream-блок
UPSTREAM_BLOCK=""
for addr in ${NER_UPSTREAMS}; do
  UPSTREAM_BLOCK="${UPSTREAM_BLOCK}    server ${addr};\n"
done

CONF_AVAIL="/etc/nginx/sites-available/${SITE_NAME}"
CONF_ENABLED="/etc/nginx/sites-enabled/${SITE_NAME}"

sudo tee "${CONF_AVAIL}" >/dev/null <<EOF
upstream ner_upstream {
$(printf "${UPSTREAM_BLOCK}")
}

server {
    listen ${LB_PORT};

    client_max_body_size 5m;

    location / {
        proxy_pass http://ner_upstream;
        proxy_http_version 1.1;

        proxy_connect_timeout 5s;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# 4) Включаем сайт
sudo ln -sf "${CONF_AVAIL}" "${CONF_ENABLED}"

# default не трогаем — чтобы не сломать чужие сервисы на 80 порту

# 5) Применяем
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

echo
echo "✅ Round-robin balancer is up."
echo "Test from balancer:"
echo "  curl -i http://127.0.0.1:${LB_PORT}/health"
echo "  curl -i http://127.0.0.1:${LB_PORT}/readyz"
echo "  curl -i http://127.0.0.1:${LB_PORT}/test_ru"
echo
echo "Client calls:"
echo "  http://10.20.14.85:${LB_PORT}/ner"