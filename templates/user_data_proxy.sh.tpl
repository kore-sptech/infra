#!/bin/bash
set -e

# Atualizacao do sistema e instalacao do Nginx e utilitarios
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release nginx jq

# Instalacao do Docker e Docker Compose
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu

# Aplicar configuracao do Nginx
cat << 'EOF' > /etc/nginx/nginx.conf
${nginx_config}
EOF

# Container do Frontend React servido localmente para o Nginx do host
mkdir -p /home/ubuntu/app
cat << 'EOF' > /home/ubuntu/app/docker-compose.yml
${proxy_docker_compose}
EOF

chown -R ubuntu:ubuntu /home/ubuntu/app
cd /home/ubuntu/app
docker compose up -d

# Pagina de fallback usada quando o container do frontend ainda nao subiu
cat << 'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Projeto Kore - Iniciando</title>
</head>
<body>
  <h1>Projeto Kore</h1>
  <p>Frontend em inicializacao. Backend privado: ${backend_private_ip}:8080</p>
</body>
</html>
EOF

# Testar e reiniciar o Nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

echo "Proxy configurado com sucesso!" > /tmp/user_data_finished.log
