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
