#!/bin/bash
set -e

# Atualizacao do sistema e instalacao de dependencias via NAT Gateway
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release jq

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

# Credenciais e configuracao do S3, lidas apenas pelo container kore-main
cat << 'EOF' > /home/ubuntu/app/aws.env
${backend_aws_env_file}
EOF
chmod 600 /home/ubuntu/app/aws.env

chown -R ubuntu:ubuntu /home/ubuntu/app
cd /home/ubuntu/app
docker compose up -d

# ==========================================
# GitHub Actions Self-Hosted Runner (Backend)
# ==========================================
RUNNER_VERSION="${github_runner_version}"
GITHUB_OWNER="${github_owner}"
REPO_BACK="${github_repo_backend}"
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

setup_runner "runner-backend" "$REPO_BACK" "ec2-backend"

echo "Backend configurado com sucesso!" > /tmp/user_data_backend_finished.log
