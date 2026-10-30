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
  echo -e "  ${GREEN}untrack-s3${NC}   Desvincula o bucket S3 do state (contorna a SCP do AWS Academy)"
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

  # Remove CR do Windows: um \r invisível no fim do token invalida a assinatura
  RAW_INPUT=$(printf '%s\n' "$RAW_INPUT" | tr -d '\r')

  # Cria o diretório ~/.aws se não existir
  mkdir -p ~/.aws

  # Se for o formato [default] ...
  if echo "$RAW_INPUT" | grep -q "aws_access_key_id"; then
    printf '%s\n' "$RAW_INPUT" > ~/.aws/credentials
    chmod 600 ~/.aws/credentials
    echo -e "\n${GREEN}✔ Arquivo ~/.aws/credentials atualizado com sucesso!${NC}"
  fi

  # Pega tudo depois do primeiro '=': o session token é base64 e contém '=' no final
  function extract_cred() {
    printf '%s\n' "$RAW_INPUT" \
      | grep -i -m1 "^[[:space:]]*$1[[:space:]]*=" \
      | cut -d= -f2- \
      | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//' || true
  }

  ACCESS_KEY=$(extract_cred "aws_access_key_id")
  SECRET_KEY=$(extract_cred "aws_secret_access_key")
  SESSION_TOKEN=$(extract_cred "aws_session_token")

  if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ] || [ -z "$SESSION_TOKEN" ]; then
    echo -e "${RED}Erro: não consegui extrair as 3 credenciais do texto colado.${NC}"
    echo -e "Cole o bloco completo da aba ${BLUE}AWS Details > AWS CLI${NC} do Learner Lab."
    exit 1
  fi

  cat << EOF > "$DIR/.env"
export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_SESSION_TOKEN="$SESSION_TOKEN"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"
EOF
  chmod 600 "$DIR/.env"

  echo -e "${GREEN}✔ Arquivo .env local atualizado!${NC}"
  echo -e "Credenciais configuradas para a região: ${BLUE}us-east-1${NC}\n"

  # Valida na hora para não descobrir o token expirado só no terraform apply
  if command -v aws &> /dev/null; then
    set -a
    # shellcheck source=/dev/null
    source "$DIR/.env"
    set +a
    if aws sts get-caller-identity > /dev/null 2>&1; then
      echo -e "${GREEN}✔ Credenciais válidas (STS respondeu).${NC}\n"
    else
      echo -e "${RED}As credenciais foram salvas mas o STS recusou.${NC}"
      echo -e "Clique em ${YELLOW}Start Lab${NC} no Learner Lab e copie as credenciais novamente.\n"
      exit 1
    fi
  fi
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

  untrack-s3)
    check_terraform
    print_banner
    echo -e "${YELLOW}Removendo o bucket S3 do state (ele continua existindo na AWS)...${NC}\n"
    S3_RESOURCES=$(terraform state list 2>/dev/null | grep '^aws_s3_bucket\.' || true)
    if [ -z "$S3_RESOURCES" ]; then
      echo -e "${GREEN}✔ Nada a remover: o bucket já não está no state.${NC}"
    else
      for RES in $S3_RESOURCES; do
        terraform state rm "$RES"
      done
      echo -e "\n${GREEN}✔ Bucket desvinculado. Agora rode ./infra.sh up normalmente.${NC}"
    fi
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
