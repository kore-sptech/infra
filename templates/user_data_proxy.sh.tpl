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

# ==========================================
# GitHub Actions Self-Hosted Runner (Frontend)
# ==========================================
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//')
GITHUB_OWNER="${github_owner}"
REPO_FRONT="${github_repo_frontend}"
GH_PAT="${github_pat}"

setup_runner() {
  DIR=$1
  REPO=$2
  NAME=$3

  if [ -z "$GH_PAT" ]; then
    echo "GH_PAT vazio, pulando registro do runner $NAME"
    return 0
  fi

  mkdir -p /home/ubuntu/$DIR && cd /home/ubuntu/$DIR
  curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz
  tar xzf ./actions-runner.tar.gz
  chown -R ubuntu:ubuntu /home/ubuntu/$DIR

  REG_TOKEN=$(curl -s -X POST -H "Authorization: token $${GH_PAT}" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/$${GITHUB_OWNER}/$${REPO}/actions/runners/registration-token | jq -r .token)

  if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
    echo "Falha ao obter registration token para $${GITHUB_OWNER}/$${REPO}. Verifique o GH_PAT e o nome do repositorio."
    return 1
  fi

  su - ubuntu -c "cd /home/ubuntu/$DIR && ./config.sh --url https://github.com/$${GITHUB_OWNER}/$${REPO} --token $${REG_TOKEN} --name $${NAME} --unattended --replace"
  cd /home/ubuntu/$DIR && ./svc.sh install ubuntu && ./svc.sh start
}

setup_runner "runner-frontend" "$REPO_FRONT" "ec2-frontend"

echo "Proxy configurado com sucesso!" > /tmp/user_data_finished.log
