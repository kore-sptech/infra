#!/bin/bash
set -e

# Atualizacao do sistema e instalacao de dependencias via NAT Gateway
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

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

# Pasta do projeto no servidor privado
mkdir -p /home/ubuntu/app
cat << 'EOF' > /home/ubuntu/app/docker-compose.yml
${backend_docker_compose}
EOF

cat << 'EOF' > /home/ubuntu/app/.env
${backend_env_file}
EOF
chmod 600 /home/ubuntu/app/.env

chown -R ubuntu:ubuntu /home/ubuntu/app
cd /home/ubuntu/app
docker compose up -d

echo "Backend configurado com sucesso!" > /tmp/user_data_backend_finished.log
