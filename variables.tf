variable "aws_region" {
  description = "Região AWS padrão (us-east-1 para AWS Academy)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto para identificar os recursos"
  type        = string
  default     = "kore"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/22"
}

variable "public_subnet_cidr" {
  description = "CIDR block da Subnet Pública (Frontend / Proxy)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block da Subnet Privada (Backend / RabbitMQ)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Zona de disponibilidade (us-east-1a)"
  type        = string
  default     = "us-east-1a"
}

variable "ssh_admin_cidr" {
  description = "CIDR autorizado a abrir SSH no proxy (restrinja ao IP do administrador)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "key_name" {
  description = "Nome do par de chaves EC2 (vockey é o padrão da AWS Academy)"
  type        = string
  default     = "vockey"
}

variable "instance_type_proxy" {
  description = "Tipo de instância EC2 para o Proxy Nginx / Frontend"
  type        = string
  default     = "t2.micro"
}

variable "instance_type_backend" {
  description = "Tipo de instância EC2 para o Backend Spring Boot + RabbitMQ (recomendado t3.small ou t3.medium)"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size_proxy" {
  description = "Tamanho do disco da instância pública em GB (o Learner Lab limita a 30)"
  type        = number
  default     = 16
}

variable "root_volume_size_backend" {
  description = "Tamanho do disco da instância privada em GB (o Learner Lab limita a 30)"
  type        = number
  default     = 20
}

# ==========================================
# APLICAÇÃO (imagens Docker e variáveis de ambiente)
# ==========================================
variable "image_frontend" {
  description = "Imagem Docker do frontend React (roda na instância pública)"
  type        = string
  default     = "henryfranz/kore-front-end:latest"
}

variable "image_main" {
  description = "Imagem Docker do microserviço principal Spring Boot (porta 8080)"
  type        = string
  default     = "henryfranz/kore-back-end-main:latest"
}

variable "image_notification" {
  description = "Imagem Docker do microserviço de notificação (porta 8081)"
  type        = string
  default     = "henryfranz/kore-back-end-notification:latest"
}

variable "frontend_port" {
  description = "Porta no loopback da instância pública onde o container do frontend é publicado"
  type        = number
  default     = 3000
}

variable "rabbitmq_user" {
  description = "Usuário do RabbitMQ"
  type        = string
  default     = "guest"
}

variable "rabbitmq_password" {
  description = "Senha do RabbitMQ"
  type        = string
  default     = "guest"
  sensitive   = true
}

variable "backend_env" {
  description = "Conteúdo do arquivo .env usado pelos containers do backend (MySQL, Spring, RabbitMQ)"
  type        = map(string)
  sensitive   = true

  default = {
    MYSQL_ROOT_PASSWORD        = "change-me-root"
    MYSQL_DATABASE             = "kore"
    MYSQL_USER                 = "kore"
    MYSQL_PASSWORD             = "change-me"
    SPRING_DATASOURCE_URL      = "jdbc:mysql://database:3306/kore?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=America/Sao_Paulo"
    SPRING_DATASOURCE_USERNAME = "kore"
    SPRING_DATASOURCE_PASSWORD = "change-me"
    SPRING_RABBITMQ_HOST       = "rabbitmq"
    SPRING_RABBITMQ_PORT       = "5672"
    SPRING_RABBITMQ_USERNAME   = "guest"
    SPRING_RABBITMQ_PASSWORD   = "guest"
  }
}

# ==========================================
# S3 E ACESSO DO BACKEND AO BUCKET
# ==========================================
variable "s3_bucket_name" {
  description = "Nome do bucket de fotos. Vazio gera kore-fotos-<account_id> automaticamente"
  type        = string
  default     = ""
}

variable "create_s3_bucket" {
  description = "false apenas referencia um bucket já existente (padrão: a SCP do AWS Academy nega GetObjectLockConfiguration e quebra o aws_s3_bucket). true cria o bucket pelo Terraform, em contas sem essa restrição."
  type        = bool
  default     = false
}

variable "backend_instance_profile" {
  description = "Instance profile anexado à EC2 privada para o backend assumir permissões de S3 (no AWS Academy use LabInstanceProfile). Vazio desativa."
  type        = string
  default     = "LabInstanceProfile"
}

variable "backend_aws_access_key_id" {
  description = "Credencial estática para o container do backend. Deixe vazio para usar o instance profile (recomendado)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "backend_aws_secret_access_key" {
  description = "Credencial estática para o container do backend. Deixe vazio para usar o instance profile (recomendado)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "backend_aws_session_token" {
  description = "Token de sessão temporário do Learner Lab (expira em ~4h). Deixe vazio para usar o instance profile"
  type        = string
  default     = ""
  sensitive   = true
}
