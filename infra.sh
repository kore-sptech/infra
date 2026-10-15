#!/usr/bin/env bash

# ==============================================================================
# Projeto Kore - Script de Gerenciamento da Infraestrutura AWS
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Cores para o terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Carrega .env se existir
if [ -f "$DIR/.env" ]; then
  # shellcheck source=/dev/null
  set -a
  source "$DIR/.env"
  set +a
fi

function print_banner() {
  echo -e "${BLUE}====================================================${NC}"
  echo -e "${BLUE}   🚀 PROJETO KORE - INFRAESTRUTURA AWS (ACADEMY)    ${NC}"
  echo -e "${BLUE}====================================================${NC}"
}

function show_help() {
  print_banner
  echo -e "Uso: ./infra.sh [comando]\n"
  echo -e "Comandos disponíveis:"
  echo -e "  ${GREEN}creds${NC}        Atualiza as credenciais da AWS Academy (cole o bloco de texto)"
  echo -e "  ${GREEN}up${NC}           Provisiona toda a infraestrutura na AWS (VPC, Subnets, EC2s, Nginx)"
  echo -e "  ${GREEN}down${NC}         Destrói todos os recursos (evita gastar créditos do Lab)"
  echo -e "  ${GREEN}status${NC}       Exibe os IPs e URLs públicas da infraestrutura ativa"
  echo -e "  ${GREEN}ssh-proxy${NC}    Conecta via SSH na máquina pública (Proxy / Frontend)"
  echo -e "  ${GREEN}ssh-backend${NC}  Conecta via SSH na máquina privada (Backend / RabbitMQ) via Jump"
  echo -e "  ${GREEN}reset-state${NC}  Limpa o estado do Terraform local (caso mude de conta do Lab)"
  echo ""
}

function check_terraform() {
  if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Erro: Terraform não encontrado no PATH.${NC}"
    exit 1
  fi
}

function update_creds() {
  print_banner
  echo -e "${YELLOW}Cole abaixo o bloco de credenciais copiado da AWS Academy (AWS Details):${NC}"
  echo -e "Exemplo: [default] aws_access_key_id=... aws_secret_access_key=... aws_session_token=..."
  echo -e "Pressione ${GREEN}Ctrl+D${NC} em uma linha vazia quando terminar de colar:\n"

  RAW_INPUT=$(cat)

  if [ -z "$RAW_INPUT" ]; then
    echo -e "${RED}Nenhuma credencial informada.${NC}"
    exit 1
  fi

  # Cria o diretório ~/.aws se não existir
  mkdir -p ~/.aws

  # Se for o formato [default] ...
  if echo "$RAW_INPUT" | grep -q "aws_access_key_id"; then
    echo "$RAW_INPUT" > ~/.aws/credentials
    echo -e "\n${GREEN}✔ Arquivo ~/.aws/credentials atualizado com sucesso!${NC}"
  fi

  # Extrai para o arquivo .env local também para garantir no shell
  ACCESS_KEY=$(echo "$RAW_INPUT" | grep -i "aws_access_key_id" | head -n1 | sed -E 's/.*=[ ]*"?([^" ]*)"?/\1/')
  SECRET_KEY=$(echo "$RAW_INPUT" | grep -i "aws_secret_access_key" | head -n1 | sed -E 's/.*=[ ]*"?([^" ]*)"?/\1/')
  SESSION_TOKEN=$(echo "$RAW_INPUT" | grep -i "aws_session_token" | head -n1 | sed -E 's/.*=[ ]*"?([^" ]*)"?/\1/')

  cat << EOF > "$DIR/.env"
export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_SESSION_TOKEN="$SESSION_TOKEN"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"
EOF

  echo -e "${GREEN}✔ Arquivo .env local atualizado!${NC}"
  echo -e "Credenciais configuradas para a região: ${BLUE}us-east-1${NC}\n"
}

function find_ssh_key() {
  if [ -f "$DIR/labsuser.pem" ]; then
    echo "$DIR/labsuser.pem"
  elif [ -f "$DIR/vockey.pem" ]; then
    echo "$DIR/vockey.pem"
  elif [ -f "$HOME/.ssh/labsuser.pem" ]; then
    echo "$HOME/.ssh/labsuser.pem"
  elif [ -f "$HOME/.ssh/vockey.pem" ]; then
    echo "$HOME/.ssh/vockey.pem"
  elif [ -f "$HOME/Downloads/labsuser.pem" ]; then
    echo "$HOME/Downloads/labsuser.pem"
  elif [ -f "$HOME/Downloads/vockey.pem" ]; then
    echo "$HOME/Downloads/vockey.pem"
  else
    echo ""
  fi
}

case "$1" in
  creds|auth)
    update_creds
    ;;

  up|apply)
    check_terraform
    print_banner
    echo -e "${GREEN}Iniciando provisionamento na AWS...${NC}\n"
    terraform init
    terraform apply -auto-approve
    echo ""
    echo -e "${GREEN}✔ Infraestrutura criada com sucesso!${NC}"
    echo -e "${BLUE}Acesse os endpoints abaixo:${NC}\n"
    terraform output
    ;;

  down|destroy)
    check_terraform
    print_banner
    echo -e "${YELLOW}Atenção: Destruindo todos os recursos na AWS para não gastar créditos...${NC}\n"
    terraform destroy -auto-approve
    echo -e "\n${GREEN}✔ Todos os recursos foram removidos com sucesso!${NC}"
    ;;

  status)
    check_terraform
    print_banner
    echo -e "${BLUE}Estado atual da infraestrutura:${NC}\n"
    terraform output
    ;;

  ssh-proxy)
    check_terraform
    KEY=$(find_ssh_key)
    if [ -z "$KEY" ]; then
      echo -e "${RED}Aviso: Chave .pem (labsuser.pem ou vockey.pem) não encontrada no diretório atual.${NC}"
      echo -e "Coloque o arquivo labsuser.pem aqui: $DIR/labsuser.pem"
      exit 1
    fi
    chmod 400 "$KEY"
    PROXY_IP=$(terraform output -raw proxy_public_ip 2>/dev/null || true)
    if [ -z "$PROXY_IP" ]; then
      echo -e "${RED}A infraestrutura parece não estar ativa. Execute ./infra.sh up primeiro.${NC}"
      exit 1
    fi
    echo -e "${GREEN}Conectando ao Proxy ($PROXY_IP)...${NC}"
    ssh -i "$KEY" ubuntu@"$PROXY_IP"
    ;;

  ssh-backend)
    check_terraform
    KEY=$(find_ssh_key)
    if [ -z "$KEY" ]; then
      echo -e "${RED}Aviso: Chave .pem (labsuser.pem ou vockey.pem) não encontrada no diretório atual.${NC}"
      echo -e "Coloque o arquivo labsuser.pem aqui: $DIR/labsuser.pem"
      exit 1
    fi
    chmod 400 "$KEY"
    PROXY_IP=$(terraform output -raw proxy_public_ip 2>/dev/null || true)
    BACKEND_IP=$(terraform output -raw backend_private_ip 2>/dev/null || true)
    if [ -z "$PROXY_IP" ] || [ -z "$BACKEND_IP" ]; then
      echo -e "${RED}A infraestrutura não está ativa. Execute ./infra.sh up primeiro.${NC}"
      exit 1
    fi
    echo -e "${GREEN}Conectando ao Backend privado ($BACKEND_IP) via Proxy Bastion ($PROXY_IP)...${NC}"
    ssh -i "$KEY" -J ubuntu@"$PROXY_IP" ubuntu@"$BACKEND_IP"
    ;;

  reset-state)
    print_banner
    echo -e "${YELLOW}Limpando estado local do Terraform (útil quando troca de conta de estudante)...${NC}"
    rm -rf .terraform terraform.tfstate* .env
    terraform init
    echo -e "${GREEN}✔ Estado limpo e reinicializado! Cole as novas credenciais com ./infra.sh creds${NC}"
    ;;

  *)
    show_help
    ;;
esac
